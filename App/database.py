from supabase import create_client, Client
import os
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("https://tddbudcgoalnjnsaqtoo.supabase.co/")
SUPABASE_KEY = os.getenv("sb_publishable_AvMzV3Ompyi11LXpu65-wg_hgo2P3lV")

def get_supabase() -> Client:
    """Supabase 클라이언트 반환"""
    return create_client(SUPABASE_URL, SUPABASE_KEY)