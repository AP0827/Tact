from typing import List
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        try:
            self.active_connections.remove(websocket)
        except ValueError:
            pass

    async def broadcast_json(self, message):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except Exception:
                # ignore send errors; connection cleanup happens on receive
                pass
