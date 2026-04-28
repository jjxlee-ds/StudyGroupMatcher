from typing import TYPE_CHECKING

from fastapi import HTTPException, status
from supabase import Client

if TYPE_CHECKING:
    from app.ws.connection_manager import ConnectionManager


def get_room_or_404(supabase: Client, room_id: str) -> dict:
    result = (
        supabase.table("chat_rooms")
        .select("*")
        .eq("id", room_id)
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat room not found",
        )
    return result.data[0]


def get_proposal_or_404(supabase: Client, proposal_id: str) -> dict:
    result = (
        supabase.table("meeting_proposals")
        .select("*")
        .eq("id", proposal_id)
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meeting proposal not found",
        )
    return result.data[0]


def assert_room_member(supabase: Client, room_id: str, user_id: str) -> None:
    from app.services.chat_service import check_room_membership
    if not check_room_membership(supabase, room_id, user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this room",
        )


def assert_room_admin(supabase: Client, room_id: str, user_id: str) -> None:
    room = get_room_or_404(supabase, room_id)
    # Check via user_study_groups (admin_id column was removed from study_groups)
    admin_check = (
        supabase.table("user_study_groups")
        .select("role")
        .eq("study_group_id", room["group_id"])
        .eq("user_id", user_id)
        .eq("role", "admin")
        .execute()
    )
    if not admin_check.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the group admin can perform this action",
        )


def get_vote_summary(supabase: Client, proposal_id: str, room_id: str) -> dict:
    votes_result = (
        supabase.table("meeting_votes")
        .select("user_id, vote")
        .eq("proposal_id", proposal_id)
        .execute()
    )
    members_result = (
        supabase.table("room_members")
        .select("user_id", count="exact")
        .eq("room_id", room_id)
        .execute()
    )
    votes = votes_result.data or []
    return {
        "attend_count": sum(1 for v in votes if v["vote"]),
        "total_members": members_result.count or 0,
        "votes": votes,
    }


def enrich_proposal(supabase: Client, proposal: dict) -> dict:
    summary = get_vote_summary(supabase, proposal["id"], proposal["room_id"])
    return {**proposal, **summary}


async def confirm_proposal(
    supabase: Client,
    proposal: dict,
    room: dict,
    confirmation_type: str,
    manager: "ConnectionManager",
) -> None:
    proposal_id = proposal["id"]
    room_id = proposal["room_id"]

    # 1. 확정 표시
    supabase.table("meeting_proposals").update(
        {"is_confirmed": True}
    ).eq("id", proposal_id).execute()

    # 1b. 같은 방의 다른 미확정 후보들 삭제
    supabase.table("meeting_proposals").delete().eq(
        "room_id", room_id
    ).eq("is_confirmed", False).neq("id", proposal_id).execute()

    # 2. meeting_results 저장
    supabase.table("meeting_results").insert({
        "proposal_id": proposal_id,
        "room_id": room_id,
        "confirmation_type": confirmation_type,
    }).execute()

    # 3. schedules 저장
    group_result = (
        supabase.table("study_groups")
        .select("name")
        .eq("id", room["group_id"])
        .execute()
    )
    group_name = group_result.data[0].get("name", "Study Group") if group_result.data else "Study Group"

    supabase.table("schedule").insert({
        "title": f"Study Session - {group_name}",
        "start_time": proposal["start_time"],
        "end_time": proposal["end_time"],
        "location": proposal.get("location"),
        "group_id": room["group_id"],
        "created_by": proposal["proposed_by"],
    }).execute()

    # 4. WebSocket broadcast
    await manager.broadcast(room_id, {
        "type": "meeting_confirmed",
        "proposal_id": proposal_id,
        "confirmation_type": confirmation_type,
        "start_time": proposal["start_time"],
        "end_time": proposal["end_time"],
        "location": proposal.get("location"),
    })
