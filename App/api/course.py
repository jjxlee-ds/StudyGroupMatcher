from fastapi import APIRouter, HTTPException, status, Query
from typing import List
from schemas.course import Course_Response, Create_Course, Get_Course_Request
from database import get_supabase

def normalize(s):
    if s == None or not s.strip():
        return None
    return s.strip().replace(" ", "").upper()

router = APIRouter(prefix="/courses", tags=["courses"])
supabase = get_supabase()

@router.get("/", response_model=List[Course_Response])
async def get_course():

    try:
        result = supabase.table("courses")\
            .select("*")\
            .execute()
        
        if not result.data:
            return []
        
        return result.data  
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch courses: {str(e)}"
        )


@router.get("/search", response_model=List[Course_Response])
async def get_course_by_code(course_code: str = Query(..., description="Course code to search")):
    try:
        normalized = normalize(course_code)
        result = supabase.table("courses")\
            .select("*")\
            .eq("course_code",normalized)\
            .execute()
        
        if not result.data:
            return []
        
        return result.data  
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch courses: {str(e)}"
        )
    
@router.post("/create", response_model=Course_Response)
async def create_course(request: Create_Course):

    try:
        course_data = {
            "course_code": normalize(request.course_code),
            "course_name": normalize(request.course_name),
            "course_section" : request.course_section
        }

        result = supabase.table("courses").insert(course_data).execute()

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
    
