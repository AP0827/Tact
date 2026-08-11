import asyncio
import logging
import psutil
import shutil
from pathlib import Path
from typing import Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.staticfiles import StaticFiles

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

app.mount("/client", StaticFiles(directory="client"), name="client")


@app.get("/health")
async def health():
    return {"status": "ok"}


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
async def pair_request():
    token = config.generate_pairing_token()
    return {"token": token, "expires_in_seconds": 300}


@app.post("/api/pair/confirm")
async def pair_confirm(payload: dict):
    token = payload.get("token")
    device_id = payload.get("device_id")
    label = payload.get("label") or device_id
    if not token or not device_id:
        raise HTTPException(status_code=400, detail="token and device_id required")
    if not config.consume_pairing_token(token):
        raise HTTPException(status_code=400, detail="invalid_or_expired_token")
    device = config.pair_device(device_id, label)
    return {"ok": True, "device": {"device_id": device.device_id, "label": device.label}}


@app.post("/api/pair/unpair")
async def pair_unpair(payload: dict):
    device_id = payload.get("device_id")
    if not device_id:
        raise HTTPException(status_code=400, detail="device_id required")
    if not config.unpair_device(device_id):
        raise HTTPException(status_code=404, detail="device_not_found")
    return {"ok": True}


@app.get("/api/state")
async def get_state():
    return {"state": snapshot_state()}


def snapshot_state() -> dict[str, Any]:
    current_root = actions.git.discover_root(Path.cwd())
    git_status = actions.git.status(current_root) if current_root else {"available": False, "root": None}
    vscode_status = actions.vscode.status(current_root)
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
            "git": git_status,
            "terminal_available": terminal_available,
        },
        "actions": sorted(actions._registry.keys()),
    }


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    device_id = None
    try:
        auth_msg = await asyncio.wait_for(websocket.receive_json(), timeout=5)
        if not isinstance(auth_msg, dict) or auth_msg.get("type") != "auth":
            await websocket.send_json({"type": "error", "message": "auth_required"})
            await websocket.close(code=4001)
            return

        token = auth_msg.get("token")
        device_label = auth_msg.get("label") or "unknown"
        if not token or token != config._data.get("pairing_token"):
            paired_ids = [d["device_id"] for d in config._data.get("paired_devices", [])]
            if token not in paired_ids:
                await websocket.send_json({"type": "error", "message": "unauthorized"})
                await websocket.close(code=4003)
                return
            device_id = token
            config.update_last_seen(device_id)
        else:
            device_id = token
            config.pair_device(device_id, device_label)

        await manager.connect(websocket, device_id=device_id)
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
