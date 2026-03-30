"""Telegram CC notifications for A2A inter-agent communication."""

import logging
from datetime import datetime, timezone

import httpx

from .config import TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, AGENT_NAME

logger = logging.getLogger(__name__)

# Which bot to use for sending CC notifications
# Use the Mac bot token from env, fallback to VPS bot
_BOT_TOKEN = TELEGRAM_BOT_TOKEN


async def send_cc(direction: str, peer: str, message: str, task_id: str = "") -> None:
    """Send a CC notification to Telegram about an A2A message.

    Args:
        direction: "INCOMING" or "OUTGOING"
        peer: Name or URL of the other agent
        message: The task/message content (truncated for readability)
        task_id: Optional task ID for tracking
    """
    if not _BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logger.debug("Telegram CC skipped — no bot token or chat ID configured")
        return

    arrow = "\u2b05\ufe0f" if direction == "INCOMING" else "\u27a1\ufe0f"
    timestamp = datetime.now(timezone.utc).strftime("%H:%M UTC")

    # Truncate long messages
    preview = message[:500] + "..." if len(message) > 500 else message

    text = (
        f"{arrow} **A2A {direction}**\n"
        f"**Agent:** {AGENT_NAME}\n"
        f"**Peer:** {peer}\n"
        f"**Time:** {timestamp}\n"
    )
    if task_id:
        text += f"**Task:** `{task_id}`\n"
    text += f"\n```\n{preview}\n```"

    try:
        async with httpx.AsyncClient(timeout=10) as http:
            await http.post(
                f"https://api.telegram.org/bot{_BOT_TOKEN}/sendMessage",
                data={
                    "chat_id": TELEGRAM_CHAT_ID,
                    "text": text,
                    "parse_mode": "Markdown",
                },
            )
    except Exception as e:
        logger.warning("Failed to send Telegram CC: %s", e)


async def send_cc_result(direction: str, peer: str, result: str, task_id: str = "") -> None:
    """Send a CC notification about a task result."""
    if not _BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return

    arrow = "\u2b05\ufe0f" if direction == "INCOMING" else "\u27a1\ufe0f"
    check = "\u2705"
    timestamp = datetime.now(timezone.utc).strftime("%H:%M UTC")

    preview = result[:500] + "..." if len(result) > 500 else result

    text = (
        f"{check} **A2A RESULT** {arrow}\n"
        f"**Agent:** {AGENT_NAME}\n"
        f"**Peer:** {peer}\n"
        f"**Time:** {timestamp}\n"
    )
    if task_id:
        text += f"**Task:** `{task_id}`\n"
    text += f"\n```\n{preview}\n```"

    try:
        async with httpx.AsyncClient(timeout=10) as http:
            await http.post(
                f"https://api.telegram.org/bot{_BOT_TOKEN}/sendMessage",
                data={
                    "chat_id": TELEGRAM_CHAT_ID,
                    "text": text,
                    "parse_mode": "Markdown",
                },
            )
    except Exception as e:
        logger.warning("Failed to send Telegram CC result: %s", e)
