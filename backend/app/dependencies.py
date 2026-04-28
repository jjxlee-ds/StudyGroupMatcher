import traceback
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from supabase import Client

from app.database import get_supabase, get_supabase_admin


security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    supabase: Client = Depends(get_supabase),
    supabase_admin: Client = Depends(get_supabase_admin),
) -> dict:
    try:
        user_response = supabase.auth.get_user(credentials.credentials)
        if not user_response or not user_response.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials"
            )
        user_id: str = user_response.user.id
    except HTTPException:
        raise
    except Exception as e:
        print(f"[AUTH DEBUG] get_user failed: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials"
        )

    try:
        result = (
            supabase_admin.table("users")
            .select("*")
            .eq("id", user_id)
            .execute()
        )
    except Exception as e:
        print(f"[AUTH DEBUG] users table query failed: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error: {e}"
        )

    if not result.data:
        print(f"[AUTH DEBUG] user_id={user_id} not found in users table")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found in database"
        )

    return result.data[0]
