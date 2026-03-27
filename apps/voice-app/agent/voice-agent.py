"""
Voice Brainstorm Agent — Pipecat Pipeline

Real-time voice conversation pipeline:
  Silero VAD → Deepgram STT → Claude LLM → Cartesia TTS

Runs as a standalone server that connects to a LiveKit room.
The Next.js web app connects users to the same room.

Usage:
  python voice-agent.py --room <room-name>

Requires:
  pip install pipecat-ai[daily,deepgram,cartesia,silero,anthropic] python-dotenv
"""

import asyncio
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv

# Load env from project root
env_paths = [
    Path(__file__).parent.parent / ".env.local",
    Path(__file__).parent.parent / ".env",
    Path.home() / ".claude" / ".env.local",
    Path.home() / ".claude" / ".env",
]
for env_path in env_paths:
    if env_path.exists():
        load_dotenv(env_path)

try:
    from pipecat.frames.frames import (
        EndFrame,
        LLMMessagesFrame,
        TextFrame,
        TranscriptionFrame,
    )
    from pipecat.pipeline.pipeline import Pipeline
    from pipecat.pipeline.runner import PipelineRunner
    from pipecat.pipeline.task import PipelineParams, PipelineTask
    from pipecat.processors.aggregators.llm_response import LLMResponseAggregator
    from pipecat.processors.aggregators.sentence import SentenceAggregator
    from pipecat.services.anthropic import AnthropicLLMService
    from pipecat.services.cartesia import CartesiaTTSService
    from pipecat.services.deepgram import DeepgramSTTService
    from pipecat.transports.services.livekit import LiveKitTransport, LiveKitParams
    from pipecat.vad.silero import SileroVADAnalyzer
except ImportError:
    print("ERROR: pipecat-ai not installed. Run: pip install pipecat-ai[daily,deepgram,cartesia,silero,anthropic]", file=sys.stderr)
    sys.exit(1)


BRAINSTORM_SYSTEM_PROMPT = """You are a brainstorming partner helping a solo developer think through feature ideas via voice conversation. Your goal is to ask targeted questions that refine a vague idea into a structured feature brief.

## Your Approach
- Keep responses SHORT (2-3 sentences max) — this is a voice conversation, not a document
- Ask ONE question at a time — never multiple questions in one turn
- Be conversational and encouraging, not formal
- Push back gently on vague answers
- Track what you've learned and what's still unclear

## Questions to Cover (in flexible order)
1. What — What does this feature do? (one sentence)
2. Who — Who is the primary user?
3. Constraints — What are the technical, time, or budget constraints?
4. Scope — What is explicitly NOT included in v1?
5. Why Now — What triggered this idea?

## Session Flow
- Start by acknowledging the idea and asking your first clarifying question
- After 3-5 exchanges, when you have enough info, say: "I think I have enough to write a brief. Should I generate it?"
- If the user says "ship it", "build this", or "done" — summarize what you have

## Response Style
- Use natural spoken language (contractions, casual tone)
- No markdown, no bullet points — pure conversational text
- Reference what the user just said to show you're listening
- Keep under 50 words per response for natural TTS delivery"""


class TranscriptLogger:
    """Logs conversation exchanges to a session file."""

    def __init__(self, session_dir: str = "/tmp/voice-sessions"):
        self.session_dir = Path(session_dir)
        self.session_dir.mkdir(parents=True, exist_ok=True)
        self.session_id = f"vs-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}"
        self.exchanges: list[dict] = []
        self.started_at = datetime.now(timezone.utc).isoformat()

        # Create session file
        self._save()

    def add_exchange(self, role: str, text: str) -> None:
        self.exchanges.append({
            "turn": len(self.exchanges) + 1,
            "role": role,
            "text": text,
            "audio_path": None,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })
        self._save()

    def finalize(self) -> str:
        """Finalize session and return path to session file."""
        session_data = self._build_session()
        session_data["status"] = "completed"
        session_data["ended_at"] = datetime.now(timezone.utc).isoformat()

        path = self.session_dir / f"{self.session_id}.json"
        path.write_text(json.dumps(session_data, indent=2))
        return str(path)

    def _save(self) -> None:
        path = self.session_dir / f"{self.session_id}.json"
        path.write_text(json.dumps(self._build_session(), indent=2))

    def _build_session(self) -> dict:
        return {
            "id": self.session_id,
            "approach": "web",
            "status": "active",
            "started_at": self.started_at,
            "ended_at": None,
            "topic": "voice-brainstorm",
            "chat_id": None,
            "exchanges": self.exchanges,
            "questions_answered": [],
            "questions_remaining": ["what", "who", "constraints", "scope", "why_now"],
        }


async def main(room_name: str) -> None:
    """Run the voice brainstorm pipeline."""

    # Validate API keys
    anthropic_key = os.environ.get("ANTHROPIC_API_KEY")
    deepgram_key = os.environ.get("DEEPGRAM_API_KEY")
    cartesia_key = os.environ.get("CARTESIA_API_KEY")
    livekit_url = os.environ.get("LIVEKIT_URL", "ws://localhost:7880")
    livekit_api_key = os.environ.get("LIVEKIT_API_KEY")
    livekit_api_secret = os.environ.get("LIVEKIT_API_SECRET")

    missing = []
    if not anthropic_key:
        missing.append("ANTHROPIC_API_KEY")
    if not deepgram_key:
        missing.append("DEEPGRAM_API_KEY")
    if not cartesia_key:
        missing.append("CARTESIA_API_KEY")
    if not livekit_api_key:
        missing.append("LIVEKIT_API_KEY")
    if not livekit_api_secret:
        missing.append("LIVEKIT_API_SECRET")

    if missing:
        print(f"ERROR: Missing API keys: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)

    # Initialize transcript logger
    logger = TranscriptLogger()
    print(f"Session: {logger.session_id}", file=sys.stderr)

    # Configure services
    transport = LiveKitTransport(
        url=livekit_url,
        params=LiveKitParams(
            api_key=livekit_api_key,
            api_secret=livekit_api_secret,
            room_name=room_name,
            participant_name="Claude Brainstorm Agent",
        ),
    )

    stt = DeepgramSTTService(
        api_key=deepgram_key,
        params=DeepgramSTTService.InputParams(
            model="nova-2",
            language="en",
            punctuate=True,
        ),
    )

    llm = AnthropicLLMService(
        api_key=anthropic_key,
        model="claude-sonnet-4-6",
        params=AnthropicLLMService.InputParams(
            max_tokens=200,
        ),
    )

    tts = CartesiaTTSService(
        api_key=cartesia_key,
        voice_id="a0e99841-438c-4a64-b679-ae501e7d6091",  # Default Sonic voice
        params=CartesiaTTSService.InputParams(
            model_id="sonic-2",
            language="en",
            sample_rate=24000,
        ),
    )

    # VAD for detecting speech boundaries
    vad = SileroVADAnalyzer(
        params=SileroVADAnalyzer.InputParams(
            min_volume=0.5,
            start_secs=0.2,
            stop_secs=0.8,
        ),
    )

    # Message history for Claude
    messages = [
        {"role": "system", "content": BRAINSTORM_SYSTEM_PROMPT},
    ]

    # Aggregators
    sentence_aggregator = SentenceAggregator()
    llm_response_aggregator = LLMResponseAggregator(messages)

    # Track transcriptions for logging
    user_text_buffer = []

    async def on_transcription(frame: TranscriptionFrame) -> None:
        if frame.text.strip():
            user_text_buffer.append(frame.text.strip())

    async def on_llm_response(frame: TextFrame) -> None:
        # Log the exchange when LLM responds
        if user_text_buffer:
            user_text = " ".join(user_text_buffer)
            logger.add_exchange("user", user_text)
            user_text_buffer.clear()
        if frame.text.strip():
            logger.add_exchange("assistant", frame.text.strip())

    # Build pipeline
    pipeline = Pipeline(
        [
            transport.input(),
            vad,
            stt,
            llm_response_aggregator,
            llm,
            sentence_aggregator,
            tts,
            transport.output(),
        ]
    )

    task = PipelineTask(
        pipeline,
        params=PipelineParams(
            allow_interruptions=True,
            enable_metrics=True,
        ),
    )

    # Handle connection events
    @transport.event_handler("on_participant_joined")
    async def on_participant_joined(transport_inst, participant) -> None:
        print(f"Participant joined: {participant.identity}", file=sys.stderr)
        # Send initial greeting
        greeting = "Hey! I'm ready to brainstorm. What's the idea you're thinking about?"
        logger.add_exchange("assistant", greeting)
        await task.queue_frames([LLMMessagesFrame(messages + [
            {"role": "assistant", "content": greeting}
        ])])

    @transport.event_handler("on_participant_left")
    async def on_participant_left(transport_inst, participant) -> None:
        print(f"Participant left: {participant.identity}", file=sys.stderr)
        session_path = logger.finalize()
        print(f"Session saved: {session_path}", file=sys.stderr)
        await task.queue_frames([EndFrame()])

    # Run
    runner = PipelineRunner()
    print(f"Agent running in room: {room_name}", file=sys.stderr)
    print(f"LiveKit URL: {livekit_url}", file=sys.stderr)
    await runner.run(task)

    # Finalize on clean exit
    session_path = logger.finalize()
    print(f"Session finalized: {session_path}", file=sys.stderr)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Voice Brainstorm Agent")
    parser.add_argument("--room", required=True, help="LiveKit room name")
    args = parser.parse_args()

    asyncio.run(main(args.room))
