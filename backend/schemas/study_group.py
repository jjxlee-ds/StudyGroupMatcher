from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class StudyGroupCreate(BaseModel):
    """Schema for creating a new study group."""
    course_id: str = Field(..., description="UUID of the course")
    name: str = Field(..., min_length=1, description="Study group name")
    max_members: int = Field(default=10, ge=2, description="Maximum number of members")
    location: Optional[str] = Field(None, description="Meeting location")

    class Config:
        json_schema_extra = {
            "example": {
                "course_id": "550e8400-e29b-41d4-a716-446655440000",
                "name": "DS&A Study Group A",
                "max_members": 10,
                "location": "Dibner Library 2nd Floor"
            }
        }


class StudyGroupResponse(BaseModel):
    """Schema for study group response."""
    id: str
    course_id: str
    name: str
    max_members: int
    location: Optional[str] = None
    created_at: Optional[datetime] = None
    current_members: Optional[int] = None

    class Config:
        from_attributes = True


class StudyGroupJoin(BaseModel):
    """Schema for joining a study group."""
    role: str = Field(default="member", description="Role in the group: 'admin' or 'member'")
