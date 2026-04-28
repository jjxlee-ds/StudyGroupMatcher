from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from supabase import Client

from app.database import get_supabase_admin
from app.dependencies import get_current_user
from app.schemas.user_course import UserCourseCreate, UserCourseResponse
from app.services.utils import handle_supabase_errors


router = APIRouter(prefix="/user-courses", tags=["user-courses"])


@router.get("/", response_model=List[UserCourseResponse])
@handle_supabase_errors
async def get_my_courses(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
) -> List[UserCourseResponse]:
    result = (
        supabase.table("user_courses")
        .select("*")
        .eq("user_id", current_user["id"])
        .execute()
    )
    return result.data or []


@router.post("/", response_model=UserCourseResponse, status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def enroll_in_course(
    request: UserCourseCreate,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
) -> UserCourseResponse:
    user_id = current_user["id"]

    existing = (
        supabase.table("user_courses")
        .select("user_id")
        .eq("user_id", user_id)
        .eq("course_id", request.course_id)
        .eq("term", request.term)
        .eq("year", request.year)
        .execute()
    )
    if existing.data:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already enrolled in this course for this term")

    row = {
        "user_id": user_id,
        "course_id": request.course_id,
        "term": request.term,
        "year": request.year,
    }
    if request.start_time is not None:
        row["start_time"] = request.start_time
    if request.end_time is not None:
        row["end_time"] = request.end_time

    result = supabase.table("user_courses").insert(row).execute()

    if not result.data:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to enroll in course")
    return result.data[0]


@router.delete("/", status_code=status.HTTP_204_NO_CONTENT)
@handle_supabase_errors
async def unenroll_from_course(
    course_id: int,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_admin),
):
    existing = (
        supabase.table("user_courses")
        .select("user_id")
        .eq("user_id", current_user["id"])
        .eq("course_id", course_id)
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Enrollment not found")
    supabase.table("user_courses").delete().eq("user_id", current_user["id"]).eq("course_id", course_id).execute()
