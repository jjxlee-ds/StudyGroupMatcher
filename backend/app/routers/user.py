from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client

from app.database import get_supabase
from app.dependencies import get_current_user
from app.schemas.user import UserResponse, UserUpdate
from app.services.user_service import (
    get_user_by_id,
    update_user_in_db,
    update_user_password,
    delete_user_from_db
)
from app.services.utils import handle_supabase_errors


router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(
    current_user: dict = Depends(get_current_user)
) -> UserResponse:
    """Get the current logged-in user's profile."""
    return current_user


@router.get("/{user_id}", response_model=UserResponse)
@handle_supabase_errors
async def get_user_profile(
    user_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
) -> UserResponse:
    """Get a user's profile by ID. Requires authentication."""
    return get_user_by_id(supabase, user_id)


@router.put("/me", response_model=UserResponse)
@handle_supabase_errors
async def update_current_user_profile(
    user_update: UserUpdate,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
) -> UserResponse:
    """Update the current user's profile."""
    update_data = user_update.model_dump(exclude_none=True)

    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update"
        )

    # Handle password update separately
    if "password" in update_data:
        password = update_data.pop("password")
        update_user_password(supabase, password)

    # Update remaining fields in database
    if update_data:
        return update_user_in_db(supabase, current_user["id"], update_data)

    # If only password was updated, return refreshed user data
    return get_user_by_id(supabase, current_user["id"])


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
@handle_supabase_errors
async def delete_current_user(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
):
    """Delete the current user's account."""
    # Delete from database first
    delete_user_from_db(supabase, current_user["id"])

    # Delete from auth
    try:
        supabase.auth.admin.delete_user(current_user["id"])
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"User removed from database but auth deletion failed: {str(e)}"
        )
