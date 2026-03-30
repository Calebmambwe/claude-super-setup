"""A2A Client — send tasks to peer agents (Mac, Manus, Gemini)."""

import asyncio
import logging
from typing import AsyncIterator

import httpx
from a2a.client import A2ACardResolver, A2AClient
from a2a.types import (
    MessageSendParams,
    SendMessageRequest,
    Message,
    Part,
    Role,
    TextPart,
)

from .config import PEER_AGENTS, A2A_API_KEY

logger = logging.getLogger(__name__)


async def discover_agent(base_url: str) -> A2AClient:
    """Discover a peer agent and return an A2A client."""
    async with httpx.AsyncClient() as http:
        resolver = A2ACardResolver(httpx_client=http, base_url=base_url)
        card = await resolver.get_agent_card()
        return A2AClient(httpx_client=http, agent_card=card)


async def send_task(agent_url: str, prompt: str, timeout: float = 600) -> str:
    """Send a task to a peer agent and wait for the result."""
    headers = {}
    if A2A_API_KEY:
        headers["X-Agent-Key"] = A2A_API_KEY

    async with httpx.AsyncClient(timeout=timeout, headers=headers) as http:
        resolver = A2ACardResolver(httpx_client=http, base_url=agent_url)
        card = await resolver.get_agent_card()
        client = A2AClient(httpx_client=http, agent_card=card)

        request = SendMessageRequest(
            params=MessageSendParams(
                message=Message(
                    role=Role.user,
                    parts=[TextPart(text=prompt)],
                ),
            )
        )

        result_parts = []
        response = await client.send_message(request)

        # Handle the response — could be a Task or streaming events
        if hasattr(response, "result"):
            task = response.result
            if hasattr(task, "artifacts") and task.artifacts:
                for artifact in task.artifacts:
                    for part in artifact.parts:
                        if isinstance(part, TextPart):
                            result_parts.append(part.text)
                        elif hasattr(part, "text"):
                            result_parts.append(part.text)
            if hasattr(task, "status") and task.status and task.status.message:
                for part in task.status.message.parts:
                    if isinstance(part, TextPart):
                        result_parts.append(part.text)

        return "\n".join(result_parts) if result_parts else "No result returned."


async def send_to_peer(peer_name: str, prompt: str) -> str:
    """Send a task to a named peer agent."""
    if peer_name not in PEER_AGENTS:
        available = ", ".join(PEER_AGENTS.keys()) if PEER_AGENTS else "none configured"
        return f"Unknown peer agent: {peer_name}. Available: {available}"

    url = PEER_AGENTS[peer_name]
    logger.info("Sending to peer %s at %s: %s", peer_name, url, prompt[:80])

    try:
        return await send_task(url, prompt)
    except Exception as e:
        return f"Failed to reach {peer_name} at {url}: {e}"


async def list_peers() -> dict[str, dict]:
    """List all configured peer agents and their status."""
    results = {}
    for name, url in PEER_AGENTS.items():
        try:
            async with httpx.AsyncClient(timeout=5) as http:
                resolver = A2ACardResolver(httpx_client=http, base_url=url)
                card = await resolver.get_agent_card()
                results[name] = {
                    "url": url,
                    "status": "online",
                    "name": card.name,
                    "skills": [s.name for s in (card.skills or [])],
                }
        except Exception as e:
            results[name] = {"url": url, "status": "offline", "error": str(e)}

    return results


# Synchronous wrapper for use in scripts
def send_task_sync(agent_url: str, prompt: str, timeout: float = 600) -> str:
    """Synchronous wrapper around send_task."""
    return asyncio.run(send_task(agent_url, prompt, timeout))
