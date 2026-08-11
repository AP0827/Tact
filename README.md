# Tact — Minimal Desktop Agent (V0.1 starter)

This workspace contains a minimal starting point for the Tact desktop agent and a tiny web client.

Quick start (create a virtualenv first):

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn tact.agent.main:app --reload --host 0.0.0.0 --port 8000
```

Open the client from another device on the same LAN at:

```
http://<laptop-ip>:8000/client/index.html
```

What this contains:
- a FastAPI app exposing a WebSocket at `/ws`
- a small `ActionRegistry` with allowlisted `system`, `vscode`, and `git` actions
- a minimal HTML client that connects, shows CPU/memory telemetry, and exposes backend actions

Next steps I can take for you:
- add pairing/authentication
- add VS Code integration
- add tests and CI
