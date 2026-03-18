from typing import Optional

from fastapi import HTTPException, status
from supabase import Client


def get_user_rooms(supabase: Client, user_id: str) -> list[dict]:
    result = (
        supabase.table("room_members")
        .select("chat_rooms(*)")
        .eq("user_id", user_id)
        .execute()
    )
    return [item["chat_rooms"] for item in (result.data or []) if item.get("chat_rooms")]


def check_room_membership(supabase: Client, room_id: str, user_id: str) -> bool:
    result = (
        supabase.table("room_members")
        .select("user_id")
        .eq("room_id", room_id)
        .eq("user_id", user_id)
        .execute()
    )
    return bool(result.data)


def create_room(supabase: Client, group_id: str, creator_id: str) -> dict:
    existing = (
        supabase.table("chat_rooms")
        .select("id")
        .eq("group_id", group_id)
        .execute()
    )
    if existing.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Chat room already exists for this group",
        )

    result = supabase.table("chat_rooms").insert({"group_id": group_id}).execute()
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create chat room",
        )

    room = result.data[0]
    supabase.table("room_members").insert(
        {"room_id": room["id"], "user_id": creator_id}
    ).execute()

    return room


def insert_message(
    supabase: Client, room_id: str, sender_id: str, content: str
) -> dict:
    result = supabase.table("messages").insert(
        {"room_id": room_id, "sender_id": sender_id, "content": content}
    ).execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save message",
        )

    message = result.data[0]
    supabase.table("chat_rooms").update(
        {"last_message_at": message["created_at"]}
    ).eq("id", room_id).execute()

    return message


def get_messages(
    supabase: Client,
    room_id: str,
    limit: int = 50,
    before: Optional[str] = None,
) -> list[dict]:
    query = (
        supabase.table("messages")
        .select("*")
        .eq("room_id", room_id)
        .order("created_at", desc=True)
        .limit(limit)
    )
    if before:
        query = query.lt("created_at", before)

    result = query.execute()
    return list(reversed(result.data or []))
