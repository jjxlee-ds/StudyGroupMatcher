from fastapi import APIRouter, HTTPException, status, Depends
from typing import List
from schemas.user_course import User_Course_Create, User_Course_Response
from database import get_supabase
from api.dependencies import get_current_user

def normalize(s):
    if s == None or not s.strip():
        return None
    return s.strip().lower()
supabase = get_supabase()
router = APIRouter(prefix="/user_courses", tags=["user_courses"])

@router.get("/", response_model=List[User_Course_Response]) 
async def get_my_courses(current_user: dict = Depends(get_current_user)):
    try:
        result = supabase.table("user_courses")\
            .select("*")\
            .eq("nyu_id", current_user["nyu_id"])\
            .execute()
        
        if not result.data:
            return []
        
        return result.data  
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch courses: {str(e)}"
        )
    
@router.post("/create", response_model=User_Course_Response)
async def create_user_courses(request :User_Course_Create, current_user: dict = Depends(get_current_user)):
    try:
        if request.nyu_id != current_user["nyu_id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only enroll courses for yourself"
            )
        
        user_course_data = {"nyu_id" : request.nyu_id,
            "course_id": request.course_id,
            "course_section": request.course_section,
            "semester": request.semester,
            "current_course_time_start" : request.datetime,
            "current_course_time_end" : request.datetime
        }

        result = supabase.table("user_courses").insert(user_course_data).execute()

        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
                detail="Failed to save the course.")
        else:
            return result.data[0]
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=str(e))



