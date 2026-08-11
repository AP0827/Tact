import asyncio
import logging
import psutil
from pathlib import Path
from typing import Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles

from .ws_manager import ConnectionManager
from .actions import ActionRegistry

logging.basicConfig(level=logging.INFO)
app = FastAPI()
manager = ConnectionManager()
actions = ActionRegistry()

app.mount("/client", StaticFiles(directory="client"), name="client")


@app.get("/health")
async def health():
    return {"status": "ok"}


def snapshot_state() -> dict[str, Any]:
    current_root = actions.git.discover_root(Path.cwd())
    git_status = actions.git.status(current_root) if current_root else {"available": False, "root": None}
    vscode_status = actions.vscode.status(current_root)
    return {
        "system": {
            "cpu": psutil.cpu_percent(interval=None),
            "memory": psutil.virtual_memory().percent,
        },
        "workspace": {
            "cwd": str(Path.cwd()),
            "git_root": git_status.get("root"),
            "vscode": vscode_status,
            "git": git_status,
        },
    }


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    telemetry_task = None
    try:
        # send initial system snapshot
        await websocket.send_json({"type": "init", "payload": snapshot_state()})

        async def telemetry_loop(ws: WebSocket):
            while True:
                await asyncio.sleep(5)
                await ws.send_json({"type": "telemetry", "payload": snapshot_state()})

        telemetry_task = asyncio.create_task(telemetry_loop(websocket))

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
