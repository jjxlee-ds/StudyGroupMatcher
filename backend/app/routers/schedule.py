from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client

from app.database import get_supabase
from app.dependencies import get_current_user
from app.schemas.schedule import ScheduleCreate, ScheduleResponse, ScheduleUpdate
from app.services.schedule_service import (
    assert_group_member,
    assert_schedule_owner,
    get_schedule_by_id,
)
from app.services.utils import handle_supabase_errors


router = APIRouter(prefix="/schedules", tags=["schedules"])


def _as_datetime(value):
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    return value


@router.get("/me", response_model=List[ScheduleResponse])
@handle_supabase_errors
async def get_my_schedules(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> List[ScheduleResponse]:
    """내 개인 일정 목록 조회 (group_id가 없는 일정)."""
    result = (
        supabase.table("schedule")
        .select("*")
        .eq("created_by", current_user["id"])
        .is_("group_id", "null")
        .order("start_time")
        .execute()
    )
    return result.data or []


@router.get("/group/{group_id}", response_model=List[ScheduleResponse])
@handle_supabase_errors
async def get_group_schedules(
    group_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> List[ScheduleResponse]:
    """내가 속한 그룹의 일정 목록 조회."""
    assert_group_member(supabase, group_id, current_user["id"])

    result = (
        supabase.table("schedule")
        .select("*")
        .eq("group_id", group_id)
        .order("start_time")
        .execute()
    )
    return result.data or []


@router.get("/{schedule_id}", response_model=ScheduleResponse)
@handle_supabase_errors
async def get_schedule(
    schedule_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> ScheduleResponse:
    """단일 일정 조회. 본인 일정이거나 속한 그룹 일정만 접근 가능."""
    schedule = get_schedule_by_id(supabase, schedule_id)

    if schedule["group_id"]:
        assert_group_member(supabase, schedule["group_id"], current_user["id"])
    elif schedule["created_by"] != current_user["id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this schedule",
        )

    return schedule


@router.post("/", response_model=ScheduleResponse, status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def create_schedule(
    request: ScheduleCreate,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> ScheduleResponse:
    """일정 생성. group_id를 넣으면 그룹 일정, 없으면 개인 일정."""
    if request.start_time >= request.end_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_time must be after start_time",
        )

    if request.group_id:
        assert_group_member(supabase, request.group_id, current_user["id"])

    data = {
        "title": request.title,
        "description": request.description,
        "start_time": request.start_time.isoformat(),
        "end_time": request.end_time.isoformat(),
        "location": request.location,
        "group_id": request.group_id,
        "created_by": current_user["id"],
    }

    result = supabase.table("schedule").insert(data).execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create schedule",
        )

    return result.data[0]


@router.put("/{schedule_id}", response_model=ScheduleResponse)
@handle_supabase_errors
async def update_schedule(
    schedule_id: str,
    request: ScheduleUpdate,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> ScheduleResponse:
    """일정 수정. 생성자만 수정 가능."""
    schedule = get_schedule_by_id(supabase, schedule_id)
    assert_schedule_owner(schedule, current_user["id"])

    update_data = request.model_dump(exclude_none=True)
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update",
        )

    start = _as_datetime(update_data.get("start_time", schedule["start_time"]))
    end = _as_datetime(update_data.get("end_time", schedule["end_time"]))
    if start >= end:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_time must be after start_time",
        )

    # datetime → isoformat 변환
    for field in ("start_time", "end_time"):
        if field in update_data and hasattr(update_data[field], "isoformat"):
            update_data[field] = update_data[field].isoformat()

    result = (
        supabase.table("schedule")
        .update(update_data)
        .eq("id", schedule_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update schedule",
        )

    return result.data[0]


@router.delete("/{schedule_id}", status_code=status.HTTP_204_NO_CONTENT)
@handle_supabase_errors
async def delete_schedule(
    schedule_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> None:
    """일정 삭제. 생성자만 삭제 가능."""
    schedule = get_schedule_by_id(supabase, schedule_id)
    assert_schedule_owner(schedule, current_user["id"])

    supabase.table("schedule").delete().eq("id", schedule_id).execute()
