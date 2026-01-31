from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional

from schemas.user import UserResponse, normalize_string


class UserCreate(BaseModel):
    """Schema for user registration."""
    name: str = Field(..., min_length=1)
    nyu_email: EmailStr
    nyu_id: str = Field(..., min_length=1)
    password: str = Field(..., min_length=8)
    major: str = Field(..., min_length=1)
    minor: Optional[str] = None
    academic_standing: int = Field(..., ge=1, le=4, description="Year in school (1-4)")
    work_willingness: int = Field(..., ge=1, le=10, description="Work willingness score (1-10)")
    preferred_location: Optional[str] = None
    time_preference: Optional[str] = None
    gpa: Optional[float] = Field(None, ge=0.0, le=4.0, description="GPA (0.0-4.0)")

    @field_validator('nyu_email', 'name', 'major', 'minor', 'nyu_id', 'preferred_location', 'time_preference', mode='before')
    @classmethod
    def normalize_fields(cls, v):
        return normalize_string(v) if isinstance(v, str) else v

    @field_validator('nyu_email')
    @classmethod
    def validate_nyu_email(cls, v):
        if not v.endswith('@nyu.edu'):
            raise ValueError('Must be a valid NYU email address')
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "name": "John Doe",
                "nyu_email": "jd1234@nyu.edu",
                "nyu_id": "N12345678",
                "password": "securepassword123",
                "major": "Computer Science",
                "minor": "Mathematics",
                "academic_standing": 2,
                "work_willingness": 7,
                "preferred_location": "Bobst Library",
                "time_preference": "morning",
                "gpa": 3.5
            }
        }


class LoginRequest(BaseModel):
    """Schema for login request."""
    nyu_email: EmailStr
    password: str

    @field_validator('nyu_email', mode='before')
    @classmethod
    def normalize_email(cls, v):
        return normalize_string(v) if isinstance(v, str) else v


class TokenResponse(BaseModel):
    """Schema for authentication token response."""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class RefreshTokenRequest(BaseModel):
    """Schema for token refresh request."""
    refresh_token: str


class PasswordResetRequest(BaseModel):
    """Schema for password reset request."""
    email: EmailStr

    @field_validator('email', mode='before')
    @classmethod
    def normalize_email(cls, v):
        return normalize_string(v) if isinstance(v, str) else v


class PasswordResetConfirm(BaseModel):
    """Schema for password reset confirmation."""
    new_password: str = Field(..., min_length=8)


# Backward compatibility aliases
Create_User = UserCreate
Login_Request = LoginRequest
Token_Response = TokenResponse
Refresh_Token_Request = RefreshTokenRequest
Password_Reset_Request = PasswordResetRequest
Password_Reset_Confirm = PasswordResetConfirm
