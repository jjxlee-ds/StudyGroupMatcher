from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client

from app.database import get_supabase_admin
from app.dependencies import get_current_user
from app.routers.chat import manager
from app.schemas.meeting import (
    MeetingProposalCreate,
    MeetingProposalResponse,
    MeetingResultResponse,
    MeetingVoteCreate,
)
from app.services.meeting_service import (
    assert_room_admin,
    assert_room_member,
    confirm_proposal,
    enrich_proposal,
    get_proposal_or_404,
    get_room_or_404,
    get_vote_summary,
)
from app.services.utils import handle_supabase_errors


router = APIRouter(prefix="/meetings", tags=["meetings"])


@router.post("/proposals", response_model=MeetingProposalResponse, status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def create_proposal(
    request: MeetingProposalCreate,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
) -> MeetingProposalResponse:
    """(방장 전용) 미팅 시간 후보 생성. 활성 후보 최대 3개."""
    assert_room_admin(supabase, request.room_id, current_user["id"])

    if request.start_time >= request.end_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_time must be after start_time",
        )

    now = datetime.now(timezone.utc)

    active = (
        supabase.table("meeting_proposals")
        .select("id", count="exact")
        .eq("room_id", request.room_id)
        .eq("is_confirmed", False)
        .gt("expires_at", now.isoformat())
        .execute()
    )
    if (active.count or 0) >= 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum 3 active proposals per room",
        )

    expires_at = now + timedelta(hours=12)

    result = supabase.table("meeting_proposals").insert({
        "room_id": request.room_id,
        "proposed_by": current_user["id"],
        "start_time": request.start_time.isoformat(),
        "end_time": request.end_time.isoformat(),
        "location": request.location,
        "expires_at": expires_at.isoformat(),
    }).execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create proposal",
        )

    return enrich_proposal(supabase, result.data[0])


@router.get("/proposals/{room_id}", response_model=List[MeetingProposalResponse])
@handle_supabase_errors
async def get_proposals(
    room_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
) -> List[MeetingProposalResponse]:
    """방의 미확정 후보 목록 (방 멤버만)."""
    assert_room_member(supabase, room_id, current_user["id"])

    result = (
        supabase.table("meeting_proposals")
        .select("*")
        .eq("room_id", room_id)
        .eq("is_confirmed", False)
        .order("created_at")
        .execute()
    )
    return [enrich_proposal(supabase, p) for p in (result.data or [])]


@router.post("/votes", status_code=status.HTTP_200_OK)
@handle_supabase_errors
async def cast_vote(
    request: MeetingVoteCreate,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    """미팅 후보에 투표. 전원 attend 시 즉시 확정."""
    proposal = get_proposal_or_404(supabase, request.proposal_id)

    if proposal["is_confirmed"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Proposal already confirmed",
        )

    expires_at = datetime.fromisoformat(
        proposal["expires_at"].replace("Z", "+00:00")
    )
    if expires_at < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Proposal has expired",
        )

    assert_room_member(supabase, proposal["room_id"], current_user["id"])

    supabase.table("meeting_votes").upsert({
        "proposal_id": request.proposal_id,
        "user_id": current_user["id"],
        "vote": request.vote,
        "voted_at": datetime.now(timezone.utc).isoformat(),
    }, on_conflict="proposal_id,user_id").execute()

    room = get_room_or_404(supabase, proposal["room_id"])
    summary = get_vote_summary(supabase, request.proposal_id, proposal["room_id"])

    await manager.broadcast(proposal["room_id"], {
        "type": "vote_update",
        "proposal_id": request.proposal_id,
        "attend_count": summary["attend_count"],
        "total_members": summary["total_members"],
        "votes": summary["votes"],
    })

    voted_count = len(summary["votes"])
    if (
        summary["total_members"] > 0
        and voted_count == summary["total_members"]
        and summary["attend_count"] == summary["total_members"]
    ):
        await confirm_proposal(supabase, proposal, room, "unanimous", manager)
        return {"message": "Vote cast. Meeting confirmed unanimously!"}

    return {"message": "Vote cast successfully"}


@router.get("/results/{room_id}", response_model=List[MeetingResultResponse])
@handle_supabase_errors
async def get_results(
    room_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
) -> List[MeetingResultResponse]:
    """확정된 미팅 목록 (방 멤버만)."""
    assert_room_member(supabase, room_id, current_user["id"])

    result = (
        supabase.table("meeting_results")
        .select("*, meeting_proposals(start_time, end_time, location)")
        .eq("room_id", room_id)
        .order("confirmed_at", desc=True)
        .execute()
    )

    rows = []
    for row in (result.data or []):
        proposal_data = row.pop("meeting_proposals", None) or {}
        rows.append({
            **row,
            "start_time": proposal_data.get("start_time"),
            "end_time": proposal_data.get("end_time"),
            "location": proposal_data.get("location"),
        })
    return rows
