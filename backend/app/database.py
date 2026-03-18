from functools import lru_cache

from supabase import create_client, Client

from app.config import get_settings


@lru_cache()
def get_supabase() -> Client:
    """
    Get Supabase client singleton.

    Returns:
        Client: Supabase client instance
    """
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_key)

@lru_cache()
def get_supabase_admin() -> Client:
    settings = get_settings()
    
    if not settings.supabase_service_role_key:
        raise ValueError("SUPABASE_SERVICE_ROLE_KEY is missing!")

    return create_client(settings.supabase_url, settings.supabase_service_role_key)