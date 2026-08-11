# Tact — Minimal Desktop Agent (V0.1 starter)

Tact turns your phone into a developer control surface for your laptop. The desktop agent runs locally, exposes safe allowlisted actions, and streams state to a mobile web client over WebSocket.

Inspired by [OptiLab Smart Lab Utilization](https://github.com/ayushsrivastavaa/optilab-smart-lab-utilization) for monitoring patterns and the vibrant orange/white color scheme.

## What this contains

- FastAPI desktop agent with WebSocket server
- Allowlisted action registry (`system`, `vscode`, `git`)
- System telemetry (CPU, RAM, disk)
- Secure local pairing with 6-digit OTP and laptop-side approval
- JSON persistence for paired devices in `~/.tact/config.json`
- Event bus with severity levels
- Git tree visualization, branch switching, and improved commit interface
- VS Code open workspace detection and recent workspaces dropdown
- Minimal responsive web client with orange/white theme

## Quick start

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

## Secure pairing flow

1. Start the desktop agent. It prints a 6-digit OTP to the terminal, e.g.:

```
INFO:tact.startup:Tact Desktop Agent started
INFO:tact.startup:Client URL: http://0.0.0.0:8000/client/index.html
INFO:tact.startup:Pairing OTP (valid 5 min): 832544
INFO:tact.startup:To pair a device: open the client URL, enter the OTP, then approve here: http://0.0.0.0:8000/admin/pair/pending
```

2. From another device on the same LAN, open:

```
http://<laptop-ip>:8000/client/index.html
```

3. Enter the 6-digit OTP shown in the desktop terminal and tap **Request Pairing**.

4. On your laptop, open the approval page shown in the terminal:

```
http://<laptop-ip>:8000/admin/pair/pending
```

5. Click **Approve** next to the pending request.

6. After approval, the phone connects to the WebSocket and can execute safe actions.

**Security notes:**
- The OTP is only shown in the server terminal, not exposed via HTTP endpoints
- Pairing requires explicit approval from the laptop
- OTPs expire after 5 minutes
- Paired devices are stored locally in `~/.tact/config.json`

## Available actions

- `system.open_url`
- `system.volume_up`
- `system.volume_down`
- `system.mute`
- `system.lock_screen`
- `system.screenshot`
- `system.open_terminal`
- `system.open_project`
- `vscode.open_workspace`
- `vscode.status`
- `vscode.workspaces`
- `git.status`
- `git.branches`
- `git.tree`
- `git._switch_branch`
- `git.pull`
- `git.push`
- `git.commit`

## Project structure

```
tact/
├── agent/
│   ├── __main__.py
│   ├── main.py
│   ├── actions.py
│   ├── config.py
│   ├── events.py
│   ├── monitoring.py
│   ├── ws_manager.py
│   └── integrations/
│       ├── git.py
│       ├── vscode.py
│       └── system.py
client/
└── index.html
tests/
└── test_domain.py
└── test_integrations.py
```

## Color scheme

The client uses a vibrant orange/white palette adapted from OptiLab:
- Primary: `#f07316` (orange-500)
- Background: `#ffffff`
- Accents: warm orange gradients

## Next steps

- add Docker integration
- add build/test actions
- add richer event types (build.failed, tests.failed)
- improve client reconnect and offline handling
- add local metrics collector inspired by OptiLab's `combined_monitor.py`
