from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from jose import JWTError, jwt
from supabase import Client

from app.config import get_settings
from app.database import get_supabase
from app.dependencies import get_current_user
from app.schemas.chat import ChatRoomCreate, ChatRoomResponse, MessageResponse
from app.services.chat_service import (
    check_room_membership,
    create_room,
    get_messages,
    get_user_rooms,
    insert_message,
)
from app.services.utils import handle_supabase_errors
from app.ws.connection_manager import ConnectionManager

router = APIRouter(tags=["chat"])
manager = ConnectionManager()


@router.get("/rooms", response_model=List[ChatRoomResponse])
@handle_supabase_errors
async def list_my_rooms(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> List[ChatRoomResponse]:
    """내가 속한 채팅방 목록."""
    return get_user_rooms(supabase, current_user["id"])


@router.post("/rooms", response_model=ChatRoomResponse, status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def create_chat_room(
    request: ChatRoomCreate,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> ChatRoomResponse:
    """스터디 그룹에 채팅방 생성."""
    return create_room(supabase, request.group_id, current_user["id"])


@router.get("/rooms/{room_id}/messages", response_model=List[MessageResponse])
@handle_supabase_errors
async def get_room_messages(
    room_id: str,
    limit: int = Query(default=50, ge=1, le=100),
    before: Optional[str] = Query(default=None, description="커서 페이지네이션용 ISO timestamp"),
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> List[MessageResponse]:
    """메시지 히스토리 조회 (커서 페이지네이션)."""
    if not check_room_membership(supabase, room_id, current_user["id"]):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this room",
        )
    return get_messages(supabase, room_id, limit, before)


@router.websocket("/ws/rooms/{room_id}")
async def websocket_chat(
    room_id: str,
    websocket: WebSocket,
    token: str = Query(...),
) -> None:
    """실시간 채팅 WebSocket 엔드포인트.

    연결: ws://{host}/ws/rooms/{room_id}?token=<supabase_access_token>
    수신 페이로드: {"content": "메시지 내용"}
    발신 페이로드: {"id": "...", "room_id": "...", "sender_id": "...", "content": "...", "created_at": "..."}
    """
    settings = get_settings()

    # 1. JWT 검증
    try:
        payload = jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            options={"verify_aud": False},
        )
        user_id: str = payload["sub"]
    except JWTError:
        await websocket.close(code=4001)
        return

    supabase = get_supabase()

    # 2. 채팅방 멤버 권한 확인
    if not check_room_membership(supabase, room_id, user_id):
        await websocket.close(code=4003)
        return

    # 3. 연결 등록
    await manager.connect(room_id, websocket)

    try:
        while True:
            data = await websocket.receive_json()
            content: str = data.get("content", "").strip()
            if not content:
                continue

            message = insert_message(supabase, room_id, user_id, content)

            await manager.broadcast(room_id, {
                "id": message["id"],
                "room_id": message["room_id"],
                "sender_id": message["sender_id"],
                "content": message["content"],
                "created_at": message["created_at"],
            })

    except WebSocketDisconnect:
        manager.disconnect(room_id, websocket)
    except Exception:
        manager.disconnect(room_id, websocket)
