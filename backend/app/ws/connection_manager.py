from collections import defaultdict
from typing import Dict, List

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: Dict[str, List[WebSocket]] = defaultdict(list)

    async def connect(self, room_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections[room_id].append(websocket)

    def disconnect(self, room_id: str, websocket: WebSocket) -> None:
        connections = self._connections.get(room_id, [])
        if websocket in connections:
            connections.remove(websocket)
        if not connections:
            self._connections.pop(room_id, None)

    async def broadcast(self, room_id: str, payload: dict) -> None:
        dead: List[WebSocket] = []
        for ws in list(self._connections.get(room_id, [])):
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(room_id, ws)
