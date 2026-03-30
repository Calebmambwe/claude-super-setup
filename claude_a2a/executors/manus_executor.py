import uuid
"""Manus.ai executor — wraps the Manus REST API behind an A2A interface."""

import asyncio
import json
import logging

import httpx

from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.types import (
    Artifact,
    Message,
    Part,
    Role,
    TaskState,
    TaskStatus,
    TaskStatusUpdateEvent,
    TaskArtifactUpdateEvent,
    TextPart,
)

from ..config import MANUS_API_KEY, MANUS_API_URL

logger = logging.getLogger(__name__)


class ManusExecutor(AgentExecutor):
    """Delegates tasks to Manus.ai's autonomous agent API."""

    def __init__(self, profile: str = "manus-1.6", mode: str = "agent"):
        self.profile = profile
        self.mode = mode

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        task_id = context.task_id
        context_id = context.context_id

        # Extract prompt
        prompt = ""
        for part in context.message.parts:
            if isinstance(part, TextPart):
                prompt += part.text
            elif hasattr(part, "text"):
                prompt += part.text

        if not MANUS_API_KEY:
            await self._fail(task_id, context_id, event_queue, "MANUS_API_KEY not configured")
            return

        logger.info("ManusExecutor: task=%s prompt=%s", task_id, prompt[:100])

        # Signal working
        await event_queue.enqueue_event(
            TaskStatusUpdateEvent(
                taskId=task_id,
                contextId=context_id,
                final=False,
                status=TaskStatus(
                    state=TaskState.working,
                    message=Message(messageId=str(uuid.uuid4()), 
                        role=Role.agent,
                        parts=[TextPart(text=f"Sending to Manus.ai ({self.profile})...")],
                    ),
                ),
            )
        )

        try:
            async with httpx.AsyncClient(timeout=300) as client:
                # Create Manus task
                resp = await client.post(
                    f"{MANUS_API_URL}/tasks",
                    headers={"API_KEY": MANUS_API_KEY, "Content-Type": "application/json"},
                    json={
                        "prompt": prompt,
                        "agentProfile": self.profile,
                        "taskMode": self.mode,
                        "locale": "en-US",
                    },
                )
                resp.raise_for_status()
                manus_task = resp.json()
                manus_task_id = manus_task.get("task_id", "unknown")

                logger.info("Manus task created: %s", manus_task_id)

                # Poll for completion
                max_polls = 120  # 10 minutes at 5s intervals
                for i in range(max_polls):
                    await asyncio.sleep(5)

                    poll_resp = await client.get(
                        f"{MANUS_API_URL}/tasks/{manus_task_id}",
                        headers={"API_KEY": MANUS_API_KEY},
                    )

                    if poll_resp.status_code != 200:
                        continue

                    task_data = poll_resp.json()
                    status = task_data.get("status", "")

                    if status in ("finished", "completed", "done"):
                        # Extract result
                        result = task_data.get("result", "")
                        if not result:
                            result = json.dumps(task_data, indent=2)

                        attachments = task_data.get("attachments", [])
                        attachment_info = ""
                        if attachments:
                            attachment_info = "\n\nAttachments:\n" + "\n".join(
                                f"- {a.get('name', 'file')}: {a.get('url', '')}"
                                for a in attachments
                            )

                        await event_queue.enqueue_event(
                            TaskArtifactUpdateEvent(
                                taskId=task_id,
                                contextId=context_id,
                                artifact=Artifact(
                                    artifactId=f"{task_id}-manus-result",
                                    name="manus-result",
                                    parts=[TextPart(text=result + attachment_info)],
                                ),
                            )
                        )

                        await event_queue.enqueue_event(
                            TaskStatusUpdateEvent(
                                taskId=task_id,
                                contextId=context_id,
                                final=True,
                                status=TaskStatus(
                                    state=TaskState.completed,
                                    message=Message(messageId=str(uuid.uuid4()), 
                                        role=Role.agent,
                                        parts=[TextPart(text=f"Manus task {manus_task_id} completed.")],
                                    ),
                                ),
                            )
                        )
                        return

                    if status in ("failed", "error", "cancelled"):
                        error = task_data.get("error", status)
                        await self._fail(task_id, context_id, event_queue, f"Manus task failed: {error}")
                        return

                    # Still working — send progress update every 30s
                    if i % 6 == 0 and i > 0:
                        progress = task_data.get("progress", {})
                        msg = progress.get("message", f"Still working... ({i * 5}s)")
                        await event_queue.enqueue_event(
                            TaskStatusUpdateEvent(
                                taskId=task_id,
                                contextId=context_id,
                                final=False,
                                status=TaskStatus(
                                    state=TaskState.working,
                                    message=Message(messageId=str(uuid.uuid4()), 
                                        role=Role.agent,
                                        parts=[TextPart(text=msg)],
                                    ),
                                ),
                            )
                        )

                # Timeout
                await self._fail(task_id, context_id, event_queue, "Manus task timed out after 10 minutes")

        except httpx.HTTPStatusError as e:
            await self._fail(task_id, context_id, event_queue, f"Manus API error: {e.response.status_code} {e.response.text[:200]}")
        except Exception as e:
            await self._fail(task_id, context_id, event_queue, f"Manus executor error: {e}")

    async def _fail(
        self, task_id: str, context_id: str, event_queue: EventQueue, reason: str
    ) -> None:
        logger.error("ManusExecutor failed: %s", reason)
        await event_queue.enqueue_event(
            TaskStatusUpdateEvent(
                taskId=task_id,
                contextId=context_id,
                final=True,
                status=TaskStatus(
                    state=TaskState.failed,
                    message=Message(messageId=str(uuid.uuid4()), 
                        role=Role.agent,
                        parts=[TextPart(text=reason)],
                    ),
                ),
            )
        )

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        await event_queue.enqueue_event(
            TaskStatusUpdateEvent(
                taskId=context.task_id,
                contextId=context.context_id,
                final=True,
                status=TaskStatus(state=TaskState.canceled),
            )
        )
