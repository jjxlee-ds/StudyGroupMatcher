from fastapi import HTTPException, status
from functools import wraps
from typing import Optional


def handle_supabase_errors(func):
    @wraps(func)
    async def wrapper(*args, **kwargs):
        try:
            return await func(*args, **kwargs)
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=str(e)
            )
    return wrapper


def normalize_code(value: Optional[str]) -> Optional[str]:
    """Normalize course codes by removing spaces and converting to uppercase."""
    if value is None or not value.strip():
        return None
    return value.strip().replace(" ", "").upper()