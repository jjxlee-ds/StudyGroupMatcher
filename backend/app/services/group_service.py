from fastapi import HTTPException, status
from supabase import Client


def get_group_or_404(supabase: Client, group_id: str) -> dict:
    result = (
        supabase.table("study_groups")
        .select("*")
        .eq("id", group_id)
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Study group not found",
        )
    return result.data[0]


def assert_group_admin(supabase: Client, group_id: str, user_id: str) -> None:
    result = (
        supabase.table("user_study_groups")
        .select("role")
        .eq("study_group_id", group_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not result.data or result.data[0]["role"] != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the group admin can perform this action",
        )
