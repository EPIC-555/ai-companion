"""Flask backend for the AI Companion.

Serves the lip-sync frontend and proxies chat messages to the ADK agent in
``character.py``. Without that file the app degrades to a puppet that echoes
your message, which is the starting state of the workshop.
"""

import asyncio
import logging
import os

from flask import Flask, jsonify, render_template, request
from google.adk.runners import InMemoryRunner
from google.genai import types

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

APP_NAME = "ai-companion"
USER_ID = "inapp_user"

app = Flask(__name__)

runner = None
try:
    import character

    runner = InMemoryRunner(agent=character.root_agent, app_name=APP_NAME)
except ImportError:
    logger.warning("character.py not found: running in puppet (echo) mode.")


@app.get("/")
def index():
    return render_template("index.html")


@app.get("/healthz")
def healthz():
    return jsonify({"status": "ok", "brain": "agent" if runner else "puppet"})


@app.post("/chat")
def chat():
    payload = request.get_json(silent=True) or {}
    user_message = (payload.get("message") or "").strip()
    session_id = payload.get("session_id") or "default_session"

    if not user_message:
        return jsonify({"error": "message is required"}), 400
    if runner is None:
        return jsonify({"response": user_message})

    try:
        return jsonify({"response": asyncio.run(_ask_agent(user_message, session_id))})
    except Exception:
        logger.exception("Agent call failed")
        return jsonify({"error": "The companion could not answer. Check the server logs."}), 502


async def _ask_agent(user_message: str, session_id: str) -> str:
    session = await runner.session_service.get_session(
        app_name=APP_NAME, user_id=USER_ID, session_id=session_id
    )
    if session is None:
        session = await runner.session_service.create_session(
            app_name=APP_NAME, user_id=USER_ID, session_id=session_id
        )

    new_message = types.Content(role="user", parts=[types.Part(text=user_message)])
    parts = []
    async for event in runner.run_async(
        user_id=session.user_id, session_id=session.id, new_message=new_message
    ):
        if event.content and event.content.parts:
            parts.extend(part.text for part in event.content.parts if part.text)
    return "".join(parts)


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 5000)),
        debug=os.environ.get("FLASK_DEBUG") == "1",
    )
