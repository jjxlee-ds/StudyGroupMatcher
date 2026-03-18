from fastapi import APIRouter, Depends, HTTPException, Query, status
from typing import List, Optional
from supabase import Client

from app.database import get_supabase
from app.schemas.course import CourseResponse, CourseCreate
from app.services.utils import handle_supabase_errors, normalize_code


router = APIRouter(prefix="/courses", tags=["courses"])


@router.get("/", response_model=List[CourseResponse])
@handle_supabase_errors
async def get_all_courses(
    supabase: Client = Depends(get_supabase)
) -> List[CourseResponse]:
    """Retrieve all available courses."""
    result = supabase.table("courses").select("*").execute()
    return result.data or []


@router.get("/search", response_model=List[CourseResponse])
@handle_supabase_errors
async def search_courses(
    course_code: str = Query(..., min_length=1, description="Course code to search"),
    supabase: Client = Depends(get_supabase)
) -> List[CourseResponse]:
    """Search for courses by course code."""
    normalized = normalize_code(course_code)
    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Course code cannot be empty"
        )

    result = (
        supabase.table("courses")
        .select("*")
        .eq("course_code", normalized)
        .execute()
    )
    return result.data or []


@router.get("/{course_id}", response_model=CourseResponse)
@handle_supabase_errors
async def get_course_by_id(
    course_id: int,
    supabase: Client = Depends(get_supabase)
) -> CourseResponse:
    """Retrieve a specific course by ID."""
    result = (
        supabase.table("courses")
        .select("*")
        .eq("id", course_id)
        .single()
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Course with id {course_id} not found"
        )
    return result.data


@router.post("/", response_model=CourseResponse, status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def create_course(
    request: CourseCreate,
    supabase: Client = Depends(get_supabase)
) -> CourseResponse:
    """Create a new course."""
    normalized_code = normalize_code(request.course_code)
    normalized_name = normalize_code(request.course_name)

    if not normalized_code or not normalized_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Course code and name are required"
        )

    # Check for duplicate course
    existing = (
        supabase.table("courses")
        .select("id")
        .eq("course_code", normalized_code)
        .execute()
    )

    if existing.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A course with this code already exists"
        )

    course_data = {
        "course_code": normalized_code,
        "course_name": normalized_name
    }

    result = supabase.table("courses").insert(course_data).execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create course"
        )

    return result.data[0]
