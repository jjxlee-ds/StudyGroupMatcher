from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


class UserCourseCreate(BaseModel):
    """Schema for enrolling a user in a course."""
    nyu_id: str
    course_id: int
    semester: str = Field(..., min_length=1, description="e.g., 'Fall 2024', 'Spring 2025'")
    current_course_time_start: str = Field(..., description="Course start time (e.g., '09:00')")
    current_course_time_end: str = Field(..., description="Course end time (e.g., '10:30')")

    @field_validator('nyu_id', 'semester', mode='before')
    @classmethod
    def normalize_fields(cls, v):
        if isinstance(v, str):
            return v.strip().lower()
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "nyu_id": "n12345678",
                "course_id": 1,
                "semester": "fall 2024",
                "current_course_time_start": "09:00",
                "current_course_time_end": "10:30"
            }
        }


class UserCourseResponse(BaseModel):
    """Schema for user course enrollment response."""
    id: Optional[int] = None
    nyu_id: str
    course_id: int
    semester: str
    current_course_time_start: str
    current_course_time_end: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserCourseUpdate(BaseModel):
    """Schema for updating user course enrollment."""
    semester: Optional[str] = None
    current_course_time_start: Optional[str] = None
    current_course_time_end: Optional[str] = None


# Backward compatibility aliases
User_Course_Create = UserCourseCreate
User_Course_Response = UserCourseResponse
