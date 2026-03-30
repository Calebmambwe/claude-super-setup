"""Router executor — inspects the incoming message and delegates to the right executor."""

import logging
import re

from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.types import TextPart

from .claude_executor import ClaudeExecutor
from .manus_executor import ManusExecutor
from .gemini_executor import GeminiExecutor

logger = logging.getLogger(__name__)

# Patterns that trigger specific executors
MANUS_PATTERNS = re.compile(
    r"\b(manus|research deeply|market research|competitor analysis|deep research)\b",
    re.IGNORECASE,
)
GEMINI_IMAGE_PATTERNS = re.compile(
    r"\b(generate image|create image|draw|illustration|mockup|prototype image|design mockup)\b",
    re.IGNORECASE,
)
GEMINI_VIDEO_PATTERNS = re.compile(
    r"\b(generate video|create video|demo video|animate|video clip)\b",
    re.IGNORECASE,
)


class RouterExecutor(AgentExecutor):
    """Routes tasks to Claude, Manus, or Gemini based on content analysis."""

    def __init__(self) -> None:
        self.claude = ClaudeExecutor()
        self.manus = ManusExecutor()
        self.gemini_image = GeminiExecutor(mode="image")
        self.gemini_video = GeminiExecutor(mode="video")

    def _classify(self, text: str) -> AgentExecutor:
        """Determine which executor should handle this task."""
        # Check for explicit routing prefixes
        lower = text.strip().lower()
        if lower.startswith("[manus]") or lower.startswith("@manus"):
            return self.manus
        if lower.startswith("[gemini-image]") or lower.startswith("@gemini-image"):
            return self.gemini_image
        if lower.startswith("[gemini-video]") or lower.startswith("@gemini-video"):
            return self.gemini_video
        if lower.startswith("[claude]") or lower.startswith("@claude"):
            return self.claude

        # Pattern matching
        if GEMINI_VIDEO_PATTERNS.search(text):
            return self.gemini_video
        if GEMINI_IMAGE_PATTERNS.search(text):
            return self.gemini_image
        if MANUS_PATTERNS.search(text):
            return self.manus

        # Default: Claude handles everything else
        return self.claude

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        # Extract text for classification
        text = ""
        for part in context.message.parts:
            if isinstance(part, TextPart):
                text += part.text
            elif hasattr(part, "text"):
                text += part.text

        executor = self._classify(text)
        executor_name = type(executor).__name__
        logger.info("Router: dispatching to %s for task %s", executor_name, context.task_id)

        await executor.execute(context, event_queue)

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        # Cancel on all executors (only the active one matters)
        await self.claude.cancel(context, event_queue)
