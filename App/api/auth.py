from fastapi import APIRouter, HTTPException, status
from schemas.user import Create_User, User_Response, Token_Response, Login_Request
from database import get_supabase

router = APIRouter(prefix="/auth", tags = ["auth"])
@router.post("/signup",response_model = User_Response)
async def signup(user: Create_User):
    """
    Docstring for signup

    used to singup the user.
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

        if not result.data:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail= "Fail to save the user.")
        else:
            return result.data[0]

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=str(e))
    
@router.post("/login",response_model = Token_Response)
async def login(credentials: Login_Request):
    supabase = get_supabase()

    try:
        auth_response = supabase.auth.sign_in_with_password({
            "email" : credentials.nyu_email,
            "password" :credentials.password})

        access_token = auth_response.session.access_token

        user_data = supabase.table("users")\
            .select("*")\
            .eq("nyu_email", credentials.nyu_email)\
            .execute()
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": user_data.data[0]
        }
    
    except Exception as e:
         raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
