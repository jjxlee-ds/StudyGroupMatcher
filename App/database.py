import os
from functools import lru_cache

from supabase import create_client, Client


@lru_cache()
def get_supabase() -> Client:
    """
    Get Supabase client singleton.

    Uses environment variables:
        SUPABASE_URL: The Supabase project URL
        SUPABASE_KEY: The Supabase anon/service key

    Returns:
        Client: Supabase client instance
    """
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")

    if not url or not key:
        raise ValueError("SUPABASE_URL and SUPABASE_KEY environment variables must be set")

    return create_client(url, key)
