from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from supabase import Client

from database import get_supabase
from dependencies import get_current_user
from schemas.study_group import StudyGroupCreate, StudyGroupResponse
from api.utils import handle_supabase_errors


router = APIRouter(prefix="/study-groups", tags=["study-groups"])


@router.post("/", response_model=StudyGroupResponse, status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def create_study_group(
    request: StudyGroupCreate,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
) -> StudyGroupResponse:
    """Create a new study group and add the creator as admin."""
    group_data = {
        "course_id": request.course_id,
        "name": request.name,
        "max_members": request.max_members,
        "location": request.location,
    }

    result = supabase.table("study_groups").insert(group_data).execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create study group"
        )

    group = result.data[0]

    # Add creator as admin member
    membership_data = {
        "user_id": current_user["id"],
        "study_group_id": group["id"],
        "role": "admin",
    }
    supabase.table("user_study_groups").insert(membership_data).execute()

    group["current_members"] = 1
    return group


@router.get("/course/{course_id}", response_model=List[StudyGroupResponse])
@handle_supabase_errors
async def get_study_groups_by_course(
    course_id: str,
    supabase: Client = Depends(get_supabase)
) -> List[StudyGroupResponse]:
    """Get all study groups for a specific course with current member counts."""
    result = (
        supabase.table("study_groups")
        .select("*, user_study_groups(count)")
        .eq("course_id", course_id)
        .execute()
    )

    groups = result.data or []
    for group in groups:
        count_data = group.pop("user_study_groups", [])
        if count_data and isinstance(count_data, list) and len(count_data) > 0:
            group["current_members"] = count_data[0].get("count", 0)
        else:
            group["current_members"] = 0

    return groups


@router.post("/{group_id}/join", status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def join_study_group(
    group_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
):
    """Join an existing study group."""
    # Verify group exists
    group_result = (
        supabase.table("study_groups")
        .select("*")
        .eq("id", group_id)
        .single()
        .execute()
    )

    if not group_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Study group not found"
        )

    group = group_result.data

    # Check if already a member
    existing = (
        supabase.table("user_study_groups")
        .select("user_id")
        .eq("user_id", current_user["id"])
        .eq("study_group_id", group_id)
        .execute()
    )

    if existing.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already a member of this study group"
        )

    # Check if group is full
    member_count = (
        supabase.table("user_study_groups")
        .select("*", count="exact")
        .eq("study_group_id", group_id)
        .execute()
    )

    if member_count.count is not None and member_count.count >= group["max_members"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Study group is full"
        )

    membership_data = {
        "user_id": current_user["id"],
        "study_group_id": group_id,
        "role": "member",
    }

    supabase.table("user_study_groups").insert(membership_data).execute()

    return {"message": "Successfully joined the study group"}


@router.delete("/{group_id}/leave", status_code=status.HTTP_204_NO_CONTENT)
@handle_supabase_errors
async def leave_study_group(
    group_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
):
    """Leave a study group."""
    existing = (
        supabase.table("user_study_groups")
        .select("user_id, role")
        .eq("user_id", current_user["id"])
        .eq("study_group_id", group_id)
        .execute()
    )

    if not existing.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="You are not a member of this study group"
        )

    (
        supabase.table("user_study_groups")
        .delete()
        .eq("user_id", current_user["id"])
        .eq("study_group_id", group_id)
        .execute()
    )


@router.get("/me", response_model=List[StudyGroupResponse])
@handle_supabase_errors
async def get_my_study_groups(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
) -> List[StudyGroupResponse]:
    """Get all study groups the current user belongs to."""
    memberships = (
        supabase.table("user_study_groups")
        .select("study_group_id")
        .eq("user_id", current_user["id"])
        .execute()
    )

    if not memberships.data:
        return []

    group_ids = [m["study_group_id"] for m in memberships.data]

    result = (
        supabase.table("study_groups")
        .select("*, user_study_groups(count)")
        .in_("id", group_ids)
        .execute()
    )

    groups = result.data or []
    for group in groups:
        count_data = group.pop("user_study_groups", [])
        if count_data and isinstance(count_data, list) and len(count_data) > 0:
            group["current_members"] = count_data[0].get("count", 0)
        else:
            group["current_members"] = 0

    return groups
