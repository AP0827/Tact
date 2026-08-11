import asyncio
import logging
import psutil
import shutil
from pathlib import Path
from typing import Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, RedirectResponse

from .ws_manager import ConnectionManager
from .actions import ActionRegistry
from .monitoring import StateMonitor
from .events import Event
from .config import Config

logging.basicConfig(level=logging.INFO)
app = FastAPI()
manager = ConnectionManager()
actions = ActionRegistry()
monitor = StateMonitor(actions.event_bus)
config = Config()

_otp = config.generate_pairing_token()
_logger = logging.getLogger("tact.startup")
_logger.info("Tact Desktop Agent started")
_logger.info("Client URL: http://%s/client/index.html", "0.0.0.0:8000")
_logger.info("Pairing OTP (valid 5 min): %s", _otp)
_logger.info("To pair a device: open the client URL, enter the OTP, then approve here: http://%s/admin/pair/pending", "0.0.0.0:8000")

app.mount("/client", StaticFiles(directory="client", html=True), name="client")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/")
async def index():
    return RedirectResponse(url="/client/")

@app.get("/index.html")
async def index_html():
    return RedirectResponse(url="/client/")

@app.get("/api/debug/config")
async def debug_config():
    return {
        "paired_devices": [
            {"device_id": d.device_id, "label": d.label, "last_seen": d.last_seen}
            for d in config.list_devices()
        ],
        "pending_pairings": [
            {
                "pending_id": p.get("pending_id"),
                "device_id": p.get("device_id"),
                "label": p.get("label"),
                "created_at": p.get("created_at"),
            }
            for p in config._data.get("pending_pairings", [])
        ],
        "pairing_token_exists": config._data.get("pairing_token") is not None,
    }


@app.get("/api/pair/status")
async def pair_status():
    devices = config.list_devices()
    return {
        "paired": len(devices) > 0,
        "devices": [
            {"device_id": d.device_id, "label": d.label, "last_seen": d.last_seen}
            for d in devices
        ],
        "pairing_token": config._data.get("pairing_token") is not None,
    }


@app.post("/api/pair/request")
async def pair_request(payload: dict):
    token = payload.get("token")
    device_id = payload.get("device_id")
    label = payload.get("label") or device_id
    if not token or not device_id:
        raise HTTPException(status_code=400, detail="token and device_id required")
    if not config.consume_pairing_token(token):
        raise HTTPException(status_code=400, detail="invalid_or_expired_token")
    pending = config.create_pending_pairing(token, device_id, label)
    _logger.info(
        "Pairing request from %s (%s). Approve at http://%s/admin/pair/pending",
        label,
        device_id,
        "0.0.0.0:8000",
    )
    return {
        "ok": True,
        "status": "pending",
        "pending_id": pending.pending_id,
        "device_id": pending.device_id,
    }


@app.post("/api/pair/approve")
async def pair_approve(payload: dict):
    pending_id = payload.get("pending_id")
    if not pending_id:
        raise HTTPException(status_code=400, detail="pending_id required")
    device = config.approve_pending_pairing(pending_id)
    if device is None:
        raise HTTPException(status_code=404, detail="pending_not_found_or_expired")
    _logger.info("Pairing approved for %s (%s)", device.label, device.device_id)
    return {"ok": True, "device": {"device_id": device.device_id, "label": device.label}}


@app.post("/api/pair/reject")
async def pair_reject(payload: dict):
    pending_id = payload.get("pending_id")
    if not pending_id:
        raise HTTPException(status_code=400, detail="pending_id required")
    pendings = config._data.get("pending_pairings", [])
    new_pendings = [p for p in pendings if p.get("pending_id") != pending_id]
    if len(new_pendings) == len(pendings):
        raise HTTPException(status_code=404, detail="pending_not_found")
    config._data["pending_pairings"] = new_pendings
    config._save()
    return {"ok": True}


@app.get("/api/state")
async def get_state():
    return {"state": snapshot_state()}


def snapshot_state() -> dict[str, Any]:
    current_root = actions.git.discover_root(Path.cwd())
    git_status = actions.git.status(current_root) if current_root else {"available": False, "root": None}
    git_branches = actions.git.branches(current_root) if current_root else {"available": False, "branches": [], "current": None}
    git_tree = actions.git.tree(current_root) if current_root else {"available": False, "tree": []}
    vscode_status = actions.vscode.status(current_root)
    vscode_workspaces = actions.vscode.workspaces()
    terminal_available = bool(shutil.which("gnome-terminal") or shutil.which("konsole") or shutil.which("kitty") or shutil.which("alacritty") or shutil.which("xfce4-terminal"))
    return {
        "system": {
            "cpu": psutil.cpu_percent(interval=None),
            "memory": psutil.virtual_memory().percent,
            "disk": psutil.disk_usage(str(Path.cwd())).percent if Path.cwd().exists() else None,
        },
        "workspace": {
            "cwd": str(Path.cwd()),
            "git_root": git_status.get("root"),
            "vscode": vscode_status,
            "vscode_workspaces": vscode_workspaces,
            "git": git_status,
            "git_branches": git_branches,
            "git_tree": git_tree,
            "terminal_available": terminal_available,
        },
        "actions": sorted(actions._registry.keys()),
    }


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    _logger.info("WebSocket connection attempt from %s", websocket.client)
    await websocket.accept()
    _logger.info("WebSocket connection accepted from %s", websocket.client)
    device_id = None
    try:
        auth_msg = await asyncio.wait_for(websocket.receive_json(), timeout=5)
        if not isinstance(auth_msg, dict) or auth_msg.get("type") != "auth":
            _logger.warning("WebSocket auth rejected: missing auth type from %s", websocket.client)
            await websocket.send_json({"type": "error", "message": "auth_required"})
            await websocket.close(code=4001)
            return

        token = auth_msg.get("token")
        device_label = auth_msg.get("label") or "unknown"
        _logger.info("WebSocket auth attempt token=%s label=%s from %s", token, device_label, websocket.client)

        if not token:
            _logger.warning("WebSocket auth rejected: empty token from %s", websocket.client)
            await websocket.send_json({"type": "error", "message": "unauthorized"})
            await websocket.close(code=4003)
            return

        if token in [d.device_id for d in config.list_devices()]:
            device_id = token
            config.update_last_seen(device_id)
            _logger.info("WebSocket auth accepted for paired device %s from %s", device_id, websocket.client)
        elif token == config._data.get("pairing_token"):
            device_id = token
            config.pair_device(device_id, device_label)
            _logger.info("WebSocket auth accepted via OTP for new device %s from %s", device_id, websocket.client)
        else:
            _logger.warning("WebSocket auth rejected: unknown device %s from %s", token, websocket.client)
            await websocket.send_json({"type": "error", "message": "unauthorized"})
            await websocket.close(code=4003)
            return
        telemetry_task = None
        try:
            await websocket.send_json({"type": "init", "payload": snapshot_state()})

            async def telemetry_loop(ws: WebSocket):
                while True:
                    await asyncio.sleep(5)
                    try:
                        await ws.send_json({"type": "telemetry", "payload": snapshot_state()})
                    except Exception:
                        break

            def on_event(event: Event):
                if websocket in manager.active_connections:
                    try:
                        asyncio.create_task(
                            websocket.send_json({"type": "event", "payload": event.to_json()})
                        )
                    except Exception:
                        pass

            actions.event_bus.subscribe("git.state_changed", on_event)
            actions.event_bus.subscribe("vscode.state_changed", on_event)

            telemetry_task = asyncio.create_task(telemetry_loop(websocket))
            if not hasattr(app.state, "monitor_task") or app.state.monitor_task.done():
                app.state.monitor_task = asyncio.create_task(monitor.monitor_loop(interval=10.0))

            while True:
                data = await websocket.receive_json()
                if not isinstance(data, dict):
                    continue
                if data.get("type") == "action":
                    action_id = data.get("action_id")
                    payload = data.get("payload") or {}
                    logging.info("received action from client: %s payload=%s", action_id, payload)
                    result = actions.execute(action_id, payload)
                    logging.info("action result: %s", result)
                    await websocket.send_json({"type": "action_result", "action_id": action_id, "result": result})

        except WebSocketDisconnect:
            logging.info("WebSocket disconnected")
        finally:
            if telemetry_task:
                telemetry_task.cancel()
            manager.disconnect(websocket)

    except asyncio.TimeoutError:
        await websocket.send_json({"type": "error", "message": "auth_timeout"})
        await websocket.close(code=4001)
    except Exception as exc:
        logging.exception("websocket error")
        try:
            await websocket.send_json({"type": "error", "message": str(exc)})
        except Exception:
            pass
        manager.disconnect(websocket)


admin = FastAPI()


@admin.get("/pending")
async def admin_pending():
    pending = config._data.get("pending_pairings", [])
    devices = config.list_devices()
    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Tact Pairing Approvals</title>
<style>
body {{ font-family: sans-serif; background:#f5f5f5; color:#333; padding:24px; }}
.card {{ background:#fff; padding:16px; border-radius:8px; box-shadow:0 1px 3px rgba(0,0,0,0.1); max-width: 480px; margin: 0 auto; }}
h1 {{ font-size: 18px; margin-bottom: 12px; }}
a {{ color:#2d2d2d; }}
.approve {{ background:#28a745; color:#fff; border:none; padding:8px 12px; border-radius:4px; cursor:pointer; text-decoration:none; display:inline-block; margin:4px; }}
.reject {{ background:#dc3545; color:#fff; border:none; padding:8px 12px; border-radius:4px; cursor:pointer; text-decoration:none; display:inline-block; margin:4px; }}
</style>
</head>
<body>
<div class="card">
<h1>Pending Pairing Requests</h1>
<ul>
{''.join([f'<li>{p.get("label")} ({p.get("device_id")}) <a class="approve" href="/admin/approve?id={p.get("pending_id")}">Approve</a> <a class="reject" href="/admin/reject?id={p.get("pending_id")}">Reject</a></li>' for p in pending])}
</ul>
<p>Paired devices: {len(devices)}</p>
</div>
</body>
</html>"""
    return HTMLResponse(content=html)


async def _admin_approve(pending_id: str):
    if not pending_id:
        raise HTTPException(status_code=400, detail="pending_id required")
    device = config.approve_pending_pairing(pending_id)
    if device is None:
        raise HTTPException(status_code=404, detail="pending_not_found_or_expired")
    _logger.info("Pairing approved for %s (%s)", device.label, device.device_id)
    return HTMLResponse(content=f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Pairing Approved</title>
<style>
body {{ font-family: sans-serif; background:#f5f5f5; color:#333; padding:24px; }}
.card {{ background:#fff; padding:16px; border-radius:8px; box-shadow:0 1px 3px rgba(0,0,0,0.1); max-width: 480px; margin: 0 auto; }}
a {{ color:#2d2d2d; }}
</style>
</head>
<body>
<div class="card">
<h1>Pairing Approved</h1>
<p>Device <strong>{device.label}</strong> ({device.device_id}) is now paired.</p>
<p><a href="/">Back to agent home</a></p>
</div>
</body>
</html>""")


async def _admin_reject(pending_id: str):
    if not pending_id:
        raise HTTPException(status_code=400, detail="pending_id required")
    pendings = config._data.get("pending_pairings", [])
    new_pendings = [p for p in pendings if p.get("pending_id") != pending_id]
    if len(new_pendings) == len(pendings):
        raise HTTPException(status_code=404, detail="pending_not_found")
    config._data["pending_pairings"] = new_pendings
    config._save()
    return HTMLResponse(content="""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Pairing Rejected</title>
<style>
body {{ font-family: sans-serif; background:#f5f5f5; color:#333; padding:24px; }}
.card {{ background:#fff; padding:16px; border-radius:8px; box-shadow:0 1px 3px rgba(0,0,0,0.1); max-width: 480px; margin: 0 auto; }}
a {{ color:#2d2d2d; }}
</style>
</head>
<body>
<div class="card">
<h1>Pairing Rejected</h1>
<p>The request has been rejected.</p>
<p><a href="/">Back to agent home</a></p>
</div>
</body>
</html>""")


@admin.get("/approve")
async def admin_approve_get(id: str = ""):
    return await _admin_approve(id)


@admin.post("/approve")
async def admin_approve_post(payload: dict):
    return await _admin_approve(payload.get("id") or payload.get("pending_id") or "")


@admin.get("/reject")
async def admin_reject_get(id: str = ""):
    return await _admin_reject(id)


@admin.post("/reject")
async def admin_reject_post(payload: dict):
    return await _admin_reject(payload.get("id") or payload.get("pending_id") or "")


app.mount("/admin", admin)
