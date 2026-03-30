"""Claude CLI executor — delegates A2A tasks to the local Claude Code CLI."""

import asyncio
import json
import logging
import shutil

from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.types import (
    TaskState,
    TaskStatus,
    TaskStatusUpdateEvent,
    TaskArtifactUpdateEvent,
    Artifact,
    Part,
    TextPart,
    Message,
    Role,
    Task,
)

from ..config import CLAUDE_BIN, CLAUDE_PROJECT_DIR

logger = logging.getLogger(__name__)


def _extract_text(message: Message) -> str:
    """Extract plain text from an A2A message."""
    parts = []
    for part in message.parts:
        if isinstance(part, TextPart):
            parts.append(part.text)
        elif hasattr(part, "text"):
            parts.append(part.text)
    return "\n".join(parts)


class ClaudeExecutor(AgentExecutor):
    """Executes tasks by shelling out to the Claude CLI."""

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        task_id = context.task_id
        context_id = context.context_id
        prompt = _extract_text(context.message)

        logger.info("ClaudeExecutor: task=%s prompt=%s", task_id, prompt[:100])

        # Signal working
        await event_queue.enqueue_event(
            TaskStatusUpdateEvent(
                taskId=task_id,
                contextId=context_id,
                final=False,
                status=TaskStatus(
                    state=TaskState.working,
                    message=Message(
                        role=Role.agent,
                        parts=[TextPart(text=f"Delegating to Claude CLI: {prompt[:80]}...")],
                    ),
                ),
            )
        )

        # Find Claude binary
        claude_bin = shutil.which(CLAUDE_BIN) or CLAUDE_BIN

        # Run Claude in print mode (non-interactive)
        try:
            proc = await asyncio.create_subprocess_exec(
                claude_bin,
                "-p", prompt,
                "--output-format", "json",
                "--permission-mode", "auto",
                cwd=CLAUDE_PROJECT_DIR,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            stdout, stderr = await asyncio.wait_for(
                proc.communicate(), timeout=600  # 10 min max
            )

            result_text = stdout.decode("utf-8", errors="replace").strip()

            # Try to parse JSON output
            try:
                result_json = json.loads(result_text)
                if isinstance(result_json, dict) and "result" in result_json:
                    result_text = result_json["result"]
                elif isinstance(result_json, list):
                    # Extract text blocks from streaming JSON
                    texts = []
                    for item in result_json:
                        if isinstance(item, dict):
                            if item.get("type") == "text":
                                texts.append(item.get("content", ""))
                            elif item.get("type") == "result":
                                texts.append(item.get("content", ""))
                    if texts:
                        result_text = "\n".join(texts)
            except json.JSONDecodeError:
                pass  # Use raw text

            if proc.returncode != 0 and not result_text:
                error_text = stderr.decode("utf-8", errors="replace").strip()
                result_text = f"Claude CLI error (exit {proc.returncode}): {error_text}"

        except asyncio.TimeoutError:
            result_text = "Claude CLI timed out after 10 minutes."
        except FileNotFoundError:
            result_text = f"Claude CLI not found at: {claude_bin}"
        except Exception as e:
            result_text = f"Claude CLI execution error: {e}"

        # Emit artifact with the result
        await event_queue.enqueue_event(
            TaskArtifactUpdateEvent(
                taskId=task_id,
                contextId=context_id,
                artifact=Artifact(
                    artifactId=f"{task_id}-result",
                    name="claude-result",
                    parts=[TextPart(text=result_text)],
                ),
            )
        )

        # Signal completion
        await event_queue.enqueue_event(
            TaskStatusUpdateEvent(
                taskId=task_id,
                contextId=context_id,
                final=True,
                status=TaskStatus(
                    state=TaskState.completed,
                    message=Message(
                        role=Role.agent,
                        parts=[TextPart(text="Task completed.")],
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
                status=TaskStatus(
                    state=TaskState.canceled,
                    message=Message(
                        role=Role.agent,
                        parts=[TextPart(text="Task canceled.")],
                    ),
                ),
            )
        )
