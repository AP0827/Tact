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

    def disconnect(self, websocket: WebSocket):
        try:
            self.active_connections.remove(websocket)
        except ValueError:
            pass
        self.connection_meta.pop(websocket, None)

    async def broadcast_json(self, message):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except Exception:
                pass
