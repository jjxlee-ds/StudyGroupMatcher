from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from supabase import Client

from app.database import get_supabase, get_supabase_admin
from app.dependencies import get_current_user
from app.schemas.chat import ChatRoomCreate, ChatRoomResponse, MessageResponse
from app.services.chat_service import (
    check_room_membership,
    create_room,
    get_messages,
    get_user_rooms,
    insert_message,
)
from app.services.schedule_service import assert_group_member
from app.services.utils import handle_supabase_errors
from app.ws.connection_manager import ConnectionManager

router = APIRouter(tags=["chat"])
manager = ConnectionManager()


@router.get("/rooms", response_model=List[ChatRoomResponse])
@handle_supabase_errors
async def list_my_rooms(
    current_user: dict = Depends(get_current_user),
    supabase_admin: Client = Depends(get_supabase_admin),
) -> List[ChatRoomResponse]:
    """내가 속한 채팅방 목록."""
    return get_user_rooms(supabase_admin, current_user["id"])


@router.post("/rooms", response_model=ChatRoomResponse, status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def create_chat_room(
    request: ChatRoomCreate,
    current_user: dict = Depends(get_current_user),
    supabase_admin: Client = Depends(get_supabase_admin),
) -> ChatRoomResponse:
    """스터디 그룹에 채팅방 생성."""
    assert_group_member(supabase_admin, request.group_id, current_user["id"])
    group_result = supabase_admin.table("study_groups").select("name").eq("id", request.group_id).execute()
    group_name = group_result.data[0]["name"] if group_result.data else ""
    return create_room(supabase_admin, request.group_id, current_user["id"], name=group_name)


@router.get("/rooms/{room_id}/messages", response_model=List[MessageResponse])
@handle_supabase_errors
async def get_room_messages(
    room_id: str,
    limit: int = Query(default=50, ge=1, le=100),
    before: Optional[str] = Query(default=None, description="커서 페이지네이션용 ISO timestamp"),
    current_user: dict = Depends(get_current_user),
    supabase_admin: Client = Depends(get_supabase_admin),
) -> List[MessageResponse]:
    """메시지 히스토리 조회 (커서 페이지네이션)."""
    if not check_room_membership(supabase_admin, room_id, current_user["id"]):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this room",
        )
    return get_messages(supabase_admin, room_id, limit, before)


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
    supabase_admin = get_supabase_admin()

    # 1. JWT 검증 — supabase.auth.get_user() uses algorithm-agnostic verification
    try:
        user_response = supabase_admin.auth.get_user(token)
        user_id: str = user_response.user.id
    except Exception:
        await websocket.close(code=4001)
        return

    # 2. 채팅방 멤버 권한 확인
    if not check_room_membership(supabase_admin, room_id, user_id):
        await websocket.close(code=4003)
        return

    # Resolve sender name once at connect time
    try:
        name_result = supabase_admin.table("users").select("name").eq("id", user_id).maybe_single().execute()
        sender_name: str | None = name_result.data.get("name") if name_result.data else None
    except Exception:
        sender_name = None

    # 3. 연결 등록
    await manager.connect(room_id, websocket)

    try:
        while True:
            data = await websocket.receive_json()
            content: str = data.get("content", "").strip()
            if not content:
                continue

            message = insert_message(supabase_admin, room_id, user_id, content)

            await manager.broadcast(room_id, {
                "id": message["id"],
                "room_id": message["room_id"],
                "sender_id": message["sender_id"],
                "sender_name": sender_name,
                "content": message["content"],
                "created_at": message["created_at"],
            })

    except WebSocketDisconnect:
        manager.disconnect(room_id, websocket)
    except Exception:
        manager.disconnect(room_id, websocket)
