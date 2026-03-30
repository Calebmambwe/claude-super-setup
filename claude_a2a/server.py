"""A2A Server — exposes Claude VPS agent via the A2A protocol."""

import logging

import uvicorn
from a2a.server.apps import A2AStarletteApplication
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.tasks import InMemoryTaskStore
from a2a.types import (
    AgentCard,
    AgentCapabilities,
    AgentSkill,
)

from .config import (
    A2A_HOST,
    A2A_PORT,
    A2A_BASE_URL,
    AGENT_ID,
    AGENT_NAME,
    AGENT_DESCRIPTION,
    MANUS_API_KEY,
    GEMINI_API_KEY,
)
from .executors.router import RouterExecutor

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


def build_agent_card() -> AgentCard:
    """Build the Agent Card describing this agent's capabilities."""
    skills = [
        AgentSkill(
            id="code-and-deploy",
            name="Code and Deploy",
            description="Write, test, review, and deploy code changes to GitHub repos",
            tags=["coding", "deployment", "github"],
            inputModes=["text"],
            outputModes=["text"],
        ),
        AgentSkill(
            id="project-management",
            name="Project Management",
            description="Plan features, create tasks, manage sprints, track progress",
            tags=["planning", "tasks", "management"],
            inputModes=["text"],
            outputModes=["text"],
        ),
        AgentSkill(
            id="code-review",
            name="Code Review",
            description="Review PRs for correctness, security, and best practices",
            tags=["review", "security", "quality"],
            inputModes=["text"],
            outputModes=["text"],
        ),
    ]

    # Add Manus skill if configured
    if MANUS_API_KEY:
        skills.append(
            AgentSkill(
                id="deep-research",
                name="Deep Research (via Manus.ai)",
                description="Autonomous deep research using Manus.ai agent — market research, competitor analysis, technical deep dives",
                tags=["research", "manus", "analysis"],
                inputModes=["text"],
                outputModes=["text"],
            )
        )

    # Add Gemini skills if configured
    if GEMINI_API_KEY:
        skills.extend([
            AgentSkill(
                id="image-generation",
                name="Image Generation (via Gemini)",
                description="Generate images, mockups, and illustrations using Google Gemini",
                tags=["image", "gemini", "generation"],
                inputModes=["text"],
                outputModes=["text"],
            ),
            AgentSkill(
                id="video-generation",
                name="Video Generation (via Gemini Veo)",
                description="Generate demo videos and animations using Google Veo",
                tags=["video", "gemini", "generation"],
                inputModes=["text"],
                outputModes=["text"],
            ),
        ])

    return AgentCard(
        name=AGENT_NAME,
        description=AGENT_DESCRIPTION,
        url=A2A_BASE_URL,
        version="0.1.0",
        defaultInputModes=["text"],
        defaultOutputModes=["text"],
        capabilities=AgentCapabilities(
            streaming=True,
            pushNotifications=False,
        ),
        skills=skills,
    )


def create_app() -> A2AStarletteApplication:
    """Create the A2A Starlette application."""
    agent_card = build_agent_card()

    handler = DefaultRequestHandler(
        agent_executor=RouterExecutor(),
        task_store=InMemoryTaskStore(),
    )

    return A2AStarletteApplication(
        agent_card=agent_card,
        http_handler=handler,
    )


def main() -> None:
    """Entry point — start the A2A server."""
    logger.info("Starting A2A server on %s:%d", A2A_HOST, A2A_PORT)
    logger.info("Agent: %s (%s)", AGENT_NAME, AGENT_ID)
    logger.info("Manus: %s", "configured" if MANUS_API_KEY else "not configured")
    logger.info("Gemini: %s", "configured" if GEMINI_API_KEY else "not configured")

    app = create_app()
    uvicorn.run(app.build(), host=A2A_HOST, port=A2A_PORT)


if __name__ == "__main__":
    main()
