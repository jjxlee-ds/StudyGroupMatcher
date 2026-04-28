from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class UserCourseCreate(BaseModel):
    course_id: int
    term: str = Field(..., description="e.g., 'Fall', 'Spring', 'Summer'")
    year: int = Field(..., description="e.g., 2026")
    start_time: Optional[str] = Field(None, description="e.g., '09:00'")
    end_time: Optional[str] = Field(None, description="e.g., '10:30'")


class UserCourseResponse(BaseModel):
    user_id: str
    course_id: int
    term: str
    year: int
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserCourseUpdate(BaseModel):
    term: Optional[str] = None
    year: Optional[int] = None


User_Course_Create = UserCourseCreate
User_Course_Response = UserCourseResponse
