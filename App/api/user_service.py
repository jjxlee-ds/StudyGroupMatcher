from fastapi import HTTPException, status
from supabase import Client


def get_user_by_email(supabase: Client, email: str) -> dict:
    """Retrieve a user by their email address."""
    result = (
        supabase.table("users")
        .select("*")
        .eq("nyu_email", email)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    return result.data[0]


def get_user_by_id(supabase: Client, user_id: str) -> dict:
    """Retrieve a user by their ID."""
    result = (
        supabase.table("users")
        .select("*")
        .eq("id", user_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    return result.data[0]


def check_user_exists_by_email(supabase: Client, email: str) -> bool:
    """Check if a user with the given email exists."""
    result = (
        supabase.table("users")
        .select("id")
        .eq("nyu_email", email)
        .execute()
    )
    return len(result.data) > 0


def check_user_exists_by_nyu_id(supabase: Client, nyu_id: str) -> bool:
    """Check if a user with the given NYU ID exists."""
    result = (
        supabase.table("users")
        .select("id")
        .eq("nyu_id", nyu_id)
        .execute()
    )
    return len(result.data) > 0


def create_user_in_db(supabase: Client, user_data: dict) -> dict:
    """Create a new user in the database."""
    result = supabase.table("users").insert(user_data).execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save user data"
        )

    return result.data[0]


def update_user_in_db(supabase: Client, user_id: str, update_data: dict) -> dict:
    """Update a user's data in the database."""
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update"
        )

    result = (
        supabase.table("users")
        .update(update_data)
        .eq("id", user_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update user"
        )

    return result.data[0]


def delete_user_from_db(supabase: Client, user_id: str) -> None:
    """Delete a user from the database."""
    result = (
        supabase.table("users")
        .delete()
        .eq("id", user_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete user from database"
        )


def update_user_password(supabase: Client, new_password: str) -> None:
    """Update a user's password via Supabase auth."""
    try:
        supabase.auth.update_user({"password": new_password})
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to update password: {str(e)}"
        )
