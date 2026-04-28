from pydantic import BaseModel
from datetime import datetime
from typing import Optional

from app.schemas.user import UserResponse


class JoinRequestResponse(BaseModel):
    id: str
    study_group_id: str
    user_id: str
    status: str
    created_at: datetime
    user: Optional[UserResponse] = None

    class Config:
        from_attributes = True
