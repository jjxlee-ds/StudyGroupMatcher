from fastapi import HTTPException, status
from supabase import Client


def get_schedule_by_id(supabase: Client, schedule_id: str) -> dict:
    result = (
        supabase.table("schedule")
        .select("*")
        .eq("id", schedule_id)
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Schedule not found",
        )
    return result.data[0]


def assert_schedule_owner(schedule: dict, user_id: str) -> None:
    if schedule["created_by"] != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to modify this schedule",
        )


def assert_group_member(supabase: Client, group_id: str, user_id: str) -> None:
    result = (
        supabase.table("user_study_groups")
        .select("user_id")
        .eq("study_group_id", group_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this study group",
        )
