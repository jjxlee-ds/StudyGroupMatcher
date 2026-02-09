from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client

from database import get_supabase, get_supabase_admin
from dependencies import get_current_user
from schemas.user import UserResponse
from schemas.auth import (
    UserCreate,
    TokenResponse,
    LoginRequest,
    PasswordResetRequest,
    PasswordResetConfirm,
    RefreshTokenRequest
)
from api.user_service import (
    get_user_by_email,
    get_user_by_id,
    check_user_exists_by_email,
    check_user_exists_by_nyu_id,
    create_user_in_db
)
from api.utils import handle_supabase_errors


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def signup(
    user: UserCreate,
    supabase: Client = Depends(get_supabase_admin)
) -> UserResponse:
    """Register a new user account."""
    if check_user_exists_by_email(supabase, user.nyu_email):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered"
        )

    if check_user_exists_by_nyu_id(supabase, user.nyu_id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="NYU ID already registered"
        )

    auth_response = supabase.auth.admin.create_user({
        "email": user.nyu_email,
        "password": user.password,
        "email_confirm": True,
        "user_metadata": {
            "name": user.name
        }
    })

    if not auth_response.user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to create auth user"
        )

    user_data = {
        "id": auth_response.user.id,
        "nyu_email": user.nyu_email,
        "nyu_id": user.nyu_id,
        "name": user.name,
        "major": user.major,
        "minor": user.minor,
        "academic_standing": user.academic_standing,
        "work_willingness": user.work_willingness,
        "preferred_location": user.preferred_location,
        "time_preference": user.time_preference,        
        "avg_gpa": user.avg_gpa   
    }

    try:
        return create_user_in_db(supabase, user_data)
    except HTTPException:
        # Rollback: delete auth account if DB insert fails
        supabase.auth.admin.delete_user(auth_response.user.id)
        raise


@router.post("/login", response_model=TokenResponse)
@handle_supabase_errors
async def login(
    credentials: LoginRequest,
    supabase: Client = Depends(get_supabase)
) -> TokenResponse:
    """Authenticate user and return access token."""
    try:
        auth_response = supabase.auth.sign_in_with_password({
            "email": credentials.nyu_email,
            "password": credentials.password
        })
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )

    if not auth_response.session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )

    user_data = get_user_by_email(supabase, credentials.nyu_email)

    return {
        "access_token": auth_response.session.access_token,
        "refresh_token": auth_response.session.refresh_token,
        "expires_at": auth_response.session.expires_at,
        "token_type": "bearer",
        "user": user_data
    }


@router.post("/logout", status_code=status.HTTP_200_OK)
@handle_supabase_errors
async def logout(
    _current_user: dict = Depends(get_current_user),  # Auth required
    supabase: Client = Depends(get_supabase)
):
    """Log out the current user."""
    supabase.auth.sign_out()
    return {"message": "Successfully logged out"}


@router.post("/refresh", response_model=TokenResponse)
@handle_supabase_errors
async def refresh_token(
    refresh_request: RefreshTokenRequest,
    supabase: Client = Depends(get_supabase)
) -> TokenResponse:
    """Refresh access token using refresh token."""
    auth_response = supabase.auth.refresh_session(refresh_request.refresh_token)

    if not auth_response.session or not auth_response.user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )

    user_data = get_user_by_id(supabase, auth_response.user.id)

    return {
        "access_token": auth_response.session.access_token,
        "refresh_token": auth_response.session.refresh_token,
        "expires_at": auth_response.session.expires_at,
        "token_type": "bearer",
        "user": user_data
    }


@router.post("/password-reset/request", status_code=status.HTTP_200_OK)
@handle_supabase_errors
async def request_password_reset(
    reset_request: PasswordResetRequest,
    supabase: Client = Depends(get_supabase)
):
    """Send password reset email."""
    supabase.auth.reset_password_email(reset_request.email)
    # Always return success to prevent email enumeration
    return {"message": "If the email exists, a reset link has been sent"}


@router.post("/password-reset/confirm", status_code=status.HTTP_200_OK)
@handle_supabase_errors
async def confirm_password_reset(
    reset_confirm: PasswordResetConfirm,
    supabase: Client = Depends(get_supabase)
):
    """Confirm password reset with new password."""
    supabase.auth.update_user({"password": reset_confirm.new_password})
    return {"message": "Password updated successfully"}


@router.get("/verify-email-status", status_code=status.HTTP_200_OK)
@handle_supabase_errors
async def check_email_verification(
    _current_user: dict = Depends(get_current_user),  # Auth required
    supabase: Client = Depends(get_supabase)
):
    """Check if user's email is verified."""
    user = supabase.auth.get_user()
    return {
        "email_verified": user.user.email_confirmed_at is not None,
        "email": user.user.email
    }
