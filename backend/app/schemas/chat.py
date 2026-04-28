from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ChatRoomCreate(BaseModel):
    group_id: str


class ChatRoomResponse(BaseModel):
    id: str
    group_id: str
    name: Optional[str] = None
    created_at: datetime
    last_message_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class MessageResponse(BaseModel):
    id: str
    room_id: str
    sender_id: str
    content: str
    created_at: datetime
    read_at: Optional[datetime] = None

    class Config:
        from_attributes = True
