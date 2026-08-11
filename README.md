# Tact — Minimal Desktop Agent (V0.1 starter)

This workspace contains a minimal starting point for the Tact desktop agent and a tiny web client.

Quick start (create a virtualenv first):

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn tact.agent.main:app --reload --host 0.0.0.0 --port 8000
```

Or:

```bash
python -m tact.agent
```

Open the client from another device on the same LAN at:

```
http://<laptop-ip>:8000/client/index.html
```

Pairing:
1. Open the client on your phone.
2. Enter the pairing token shown by the desktop agent (or use the `/api/pair/request` endpoint to generate one).
3. Once paired, the phone can execute safe allowlisted actions.

What this contains:
- a FastAPI app exposing a WebSocket at `/ws`
- a small `ActionRegistry` with allowlisted `system`, `vscode`, and `git` actions
- a minimal HTML client that connects, shows CPU/memory telemetry, and exposes backend actions
- local pairing and authentication via token-based flow
- JSON persistence for paired devices in `~/.tact/config.json`
- event bus with severity levels and structured events
