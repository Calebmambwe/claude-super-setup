"""Gemini executor — wraps Google Gemini API for image and video generation."""

import asyncio
import base64
import json
import logging
from pathlib import Path

import httpx

from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.types import (
    Artifact,
    FilePart,
    Message,
    Role,
    TaskState,
    TaskStatus,
    TaskStatusUpdateEvent,
    TaskArtifactUpdateEvent,
    TextPart,
)

from ..config import GEMINI_API_KEY, GEMINI_API_URL

logger = logging.getLogger(__name__)

OUTPUT_DIR = Path.home() / ".claude" / "a2a-outputs"


class GeminiExecutor(AgentExecutor):
    """Generates images and videos via Google Gemini API."""

    def __init__(self, mode: str = "image"):
        """mode: 'image' or 'video'"""
        self.mode = mode
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        task_id = context.task_id
        context_id = context.context_id

        prompt = ""
        for part in context.message.parts:
            if isinstance(part, TextPart):
                prompt += part.text
            elif hasattr(part, "text"):
                prompt += part.text

        if not GEMINI_API_KEY:
            await self._fail(task_id, context_id, event_queue, "GEMINI_API_KEY not configured")
            return

        logger.info("GeminiExecutor[%s]: task=%s prompt=%s", self.mode, task_id, prompt[:100])

        await event_queue.enqueue_event(
            TaskStatusUpdateEvent(
                taskId=task_id,
                contextId=context_id,
                final=False,
                status=TaskStatus(
                    state=TaskState.working,
                    message=Message(
                        role=Role.agent,
                        parts=[TextPart(text=f"Generating {self.mode} with Gemini...")],
                    ),
                ),
            )
        )

        try:
            if self.mode == "video":
                await self._generate_video(task_id, context_id, prompt, event_queue)
            else:
                await self._generate_image(task_id, context_id, prompt, event_queue)
        except Exception as e:
            await self._fail(task_id, context_id, event_queue, f"Gemini error: {e}")

    async def _generate_image(
        self, task_id: str, context_id: str, prompt: str, event_queue: EventQueue
    ) -> None:
        model = "gemini-2.0-flash-exp"
        url = f"{GEMINI_API_URL}/models/{model}:generateContent"

        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                url,
                params={"key": GEMINI_API_KEY},
                json={
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {
                        "responseModalities": ["TEXT", "IMAGE"],
                    },
                },
            )
            resp.raise_for_status()
            data = resp.json()

        # Extract image from response
        candidates = data.get("candidates", [])
        if not candidates:
            await self._fail(task_id, context_id, event_queue, "No candidates in Gemini response")
            return

        parts = candidates[0].get("content", {}).get("parts", [])
        text_result = ""
        image_saved = False

        for i, part in enumerate(parts):
            if "text" in part:
                text_result += part["text"]
            elif "inlineData" in part:
                img_data = base64.b64decode(part["inlineData"]["data"])
                mime = part["inlineData"].get("mimeType", "image/png")
                ext = "png" if "png" in mime else "jpg"
                img_path = OUTPUT_DIR / f"{task_id}-{i}.{ext}"
                img_path.write_bytes(img_data)
                image_saved = True

                await event_queue.enqueue_event(
                    TaskArtifactUpdateEvent(
                        taskId=task_id,
                        contextId=context_id,
                        artifact=Artifact(
                            artifactId=f"{task_id}-image-{i}",
                            name=f"generated-image-{i}.{ext}",
                            parts=[TextPart(text=f"Image saved: {img_path}")],
                        ),
                    )
                )

        if text_result:
            await event_queue.enqueue_event(
                TaskArtifactUpdateEvent(
                    taskId=task_id,
                    contextId=context_id,
                    artifact=Artifact(
                        artifactId=f"{task_id}-text",
                        name="gemini-text",
                        parts=[TextPart(text=text_result)],
                    ),
                )
            )

        status_msg = "Image generated" if image_saved else "Generation complete (text only)"
        await event_queue.enqueue_event(
            TaskStatusUpdateEvent(
                taskId=task_id,
                contextId=context_id,
                final=True,
                status=TaskStatus(
                    state=TaskState.completed,
                    message=Message(role=Role.agent, parts=[TextPart(text=status_msg)]),
                ),
            )
        )

    async def _generate_video(
        self, task_id: str, context_id: str, prompt: str, event_queue: EventQueue
    ) -> None:
        model = "veo-2.0-generate-001"
        url = f"{GEMINI_API_URL}/models/{model}:predictLongRunning"

        async with httpx.AsyncClient(timeout=600) as client:
            # Start video generation
            resp = await client.post(
                url,
                params={"key": GEMINI_API_KEY},
                json={
                    "instances": [{"prompt": prompt}],
                    "parameters": {
                        "aspectRatio": "16:9",
                        "durationSeconds": "8",
                    },
                },
            )
            resp.raise_for_status()
            op = resp.json()
            op_name = op.get("name", "")

            if not op_name:
                await self._fail(task_id, context_id, event_queue, "No operation name returned")
                return

            # Poll for completion (up to 6 minutes)
            for i in range(72):
                await asyncio.sleep(5)
                poll_resp = await client.get(
                    f"{GEMINI_API_URL}/{op_name}",
                    params={"key": GEMINI_API_KEY},
                )

                if poll_resp.status_code != 200:
                    continue

                op_data = poll_resp.json()
                if op_data.get("done"):
                    videos = (
                        op_data.get("response", {})
                        .get("generatedVideos", [])
                    )
                    if videos:
                        video_uri = videos[0].get("video", {}).get("uri", "")
                        await event_queue.enqueue_event(
                            TaskArtifactUpdateEvent(
                                taskId=task_id,
                                contextId=context_id,
                                artifact=Artifact(
                                    artifactId=f"{task_id}-video",
                                    name="generated-video",
                                    parts=[TextPart(text=f"Video URI: {video_uri}\n(Expires in 2 days)")],
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
                                message=Message(
                                    role=Role.agent,
                                    parts=[TextPart(text="Video generated.")],
                                ),
                            ),
                        )
                    )
                    return

                # Progress update every 30s
                if i % 6 == 0 and i > 0:
                    await event_queue.enqueue_event(
                        TaskStatusUpdateEvent(
                            taskId=task_id,
                            contextId=context_id,
                            final=False,
                            status=TaskStatus(
                                state=TaskState.working,
                                message=Message(
                                    role=Role.agent,
                                    parts=[TextPart(text=f"Video rendering... ({i * 5}s)")],
                                ),
                            ),
                        )
                    )

            await self._fail(task_id, context_id, event_queue, "Video generation timed out")

    async def _fail(
        self, task_id: str, context_id: str, event_queue: EventQueue, reason: str
    ) -> None:
        logger.error("GeminiExecutor failed: %s", reason)
        await event_queue.enqueue_event(
            TaskStatusUpdateEvent(
                taskId=task_id,
                contextId=context_id,
                final=True,
                status=TaskStatus(
                    state=TaskState.failed,
                    message=Message(role=Role.agent, parts=[TextPart(text=reason)]),
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
