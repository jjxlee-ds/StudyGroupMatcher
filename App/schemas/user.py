from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional


def normalize_string(value: str) -> str:
    """Normalize string by stripping whitespace and converting to lowercase."""
    if value is None:
        return None
    return value.strip().lower()


class UserBase(BaseModel):
    """Base schema with common user fields."""
    name: str
    nyu_email: EmailStr
    nyu_id: str
    major: str
    minor: Optional[str] = None
    academic_standing: int = Field(..., ge=1, le=4, description="Year in school (1-4)")
    work_willingness: int = Field(..., ge=1, le=10, description="Work willingness score (1-10)")


class UserResponse(BaseModel):
    """Schema for user response data."""
    id: str
    name: str
    nyu_email: str
    nyu_id: str
    major: str
    minor: Optional[str] = None
    academic_standing: int
    work_willingness: int

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": "uuid-string",
                "name": "john doe",
                "nyu_email": "jd1234@nyu.edu",
                "nyu_id": "N12345678",
                "major": "computer science",
                "minor": "mathematics",
                "academic_standing": 3,
                "work_willingness": 8
            }
        }


class UserUpdate(BaseModel):
    """Schema for updating user profile."""
    name: Optional[str] = None
    major: Optional[str] = None
    minor: Optional[str] = None
    academic_standing: Optional[int] = Field(None, ge=1, le=4)
    work_willingness: Optional[int] = Field(None, ge=1, le=10)
    password: Optional[str] = Field(None, min_length=8)

    @field_validator('name', 'major', 'minor', mode='before')
    @classmethod
    def normalize_fields(cls, v):
        return normalize_string(v) if isinstance(v, str) else v


# Backward compatibility aliases
User_Response = UserResponse
Update_User = UserUpdate
