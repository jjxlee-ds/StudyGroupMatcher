from fastapi import APIRouter, HTTPException
from schemas.user import Create_User, User_Response
from database import get_supabase

router = APIRouter(prefix="\Auth", tags = ["Auth"])
@router.post("\signup",response_model = User_Response)

async def signup(user: Create_User):
    """
    Docstring for signup
    
    :param user: Description
    :type user: Create_User

    sinning up new user
    """
    supabase = get_supabase()
    try:
        auth_response = supabase.auth.sign_up({
            "email" : user.nyu_email,
            "password" : user.password
        })
        user_data = {
            "nyu_email" : user.nyu_email,
            "nyu_id" : user.nyu_id,
            "name" : user.name,
            "major" : user.major,
            "minor" : user.minor,
            "academic_year" : user.academic_year,
            "work_willingness": user.work_willingness
        }
        result = supabase.table("users").insert(user_data).execute()
        return result[0]

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))