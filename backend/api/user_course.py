from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from supabase import Client

from database import get_supabase
from dependencies import get_current_user
from schemas.user_course import UserCourseCreate, UserCourseResponse
from api.utils import handle_supabase_errors, normalize_code


router = APIRouter(prefix="/user-courses", tags=["user-courses"])


@router.get("/", response_model=List[UserCourseResponse])
@handle_supabase_errors
async def get_my_courses(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
) -> List[UserCourseResponse]:
    """Get all courses for the current user."""
    result = (
        supabase.table("user_courses")
        .select("*")
        .eq("nyu_id", current_user["nyu_id"])
        .execute()
    )
    return result.data or []


@router.get("/{enrollment_id}", response_model=UserCourseResponse)
@handle_supabase_errors
async def get_enrollment_by_id(
    enrollment_id: int,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
) -> UserCourseResponse:
    """Get a specific course enrollment by ID."""
    result = (
        supabase.table("user_courses")
        .select("*")
        .eq("id", enrollment_id)
        .eq("nyu_id", current_user["nyu_id"])
        .single()
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Enrollment not found"
        )
    return result.data


@router.post("/", response_model=UserCourseResponse, status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def enroll_in_course(
    request: UserCourseCreate,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
) -> UserCourseResponse:
    """Enroll the current user in a course."""
    # Ensure user can only enroll themselves
    normalized_nyu_id = request.nyu_id.strip().lower()
    if normalized_nyu_id != current_user["nyu_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only enroll yourself in courses"
        )

    # Check if already enrolled in this course/section/semester
    existing = (
        supabase.table("user_courses")
        .select("id")
        .eq("nyu_id", normalized_nyu_id)
        .eq("course_id", request.course_id)
        .eq("course_section", request.course_section)
        .eq("semester", request.semester)
        .execute()
    )

    if existing.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already enrolled in this course section for this semester"
        )

    user_course_data = {
        "nyu_id": normalized_nyu_id,
        "course_id": request.course_id,
        "course_section": request.course_section,
        "semester": request.semester,
        "current_course_time_start": request.current_course_time_start,
        "current_course_time_end": request.current_course_time_end
    }

    result = supabase.table("user_courses").insert(user_course_data).execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to enroll in course"
        )

    return result.data[0]


@router.delete("/{enrollment_id}", status_code=status.HTTP_204_NO_CONTENT)
@handle_supabase_errors
async def unenroll_from_course(
    enrollment_id: int,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
):
    """Remove a course enrollment."""
    # Verify ownership
    existing = (
        supabase.table("user_courses")
        .select("id")
        .eq("id", enrollment_id)
        .eq("nyu_id", current_user["nyu_id"])
        .execute()
    )

    if not existing.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Enrollment not found"
        )

    supabase.table("user_courses").delete().eq("id", enrollment_id).execute()
