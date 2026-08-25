from typing import Any, Dict, List
from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []
        self.connection_meta: Dict[WebSocket, Dict[str, Any]] = {}

    async def connect(self, websocket: WebSocket, **meta: Any):
        await websocket.accept()
        self.active_connections.append(websocket)
        self.connection_meta[websocket] = meta

    def register(self, websocket: WebSocket, **meta: Any):
        self.active_connections.append(websocket)
        self.connection_meta[websocket] = meta

    def disconnect(self, websocket: WebSocket):
        try:
            self.active_connections.remove(websocket)
        except ValueError:
            pass
        self.connection_meta.pop(websocket, None)

    async def terminate_device(self, device_id: str) -> int:
        matches = [
            connection
            for connection, meta in list(self.connection_meta.items())
            if meta.get("device_id") == device_id
        ]
        for connection in matches:
            try:
                await connection.send_json({"type": "error", "message": "connection_terminated_by_host"})
                await connection.close(code=4003)
            except Exception:
                pass
            self.disconnect(connection)
        return len(matches)

    def active_device_ids(self) -> set[str]:
        return {
            str(meta["device_id"])
            for meta in self.connection_meta.values()
            if meta.get("device_id")
        }

    async def broadcast_json(self, message):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except Exception:
                pass
