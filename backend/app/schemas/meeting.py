from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List


class MeetingProposalCreate(BaseModel):
    room_id: str
    start_time: datetime
    end_time: datetime
    location: Optional[str] = None


class MeetingVoteCreate(BaseModel):
    proposal_id: str
    vote: bool  # True = attend, False = not attend


class VoteDetail(BaseModel):
    user_id: str
    vote: bool


class MeetingProposalResponse(BaseModel):
    id: str
    room_id: str
    proposed_by: str
    start_time: datetime
    end_time: datetime
    location: Optional[str] = None
    created_at: datetime
    expires_at: datetime
    is_confirmed: bool
    attend_count: int = 0
    total_members: int = 0
    votes: List[VoteDetail] = Field(default_factory=list)

    class Config:
        from_attributes = True


class MeetingResultResponse(BaseModel):
    id: str
    proposal_id: str
    room_id: str
    confirmed_at: datetime
    confirmation_type: str  # 'unanimous' | 'auto'
    start_time: datetime
    end_time: datetime
    location: Optional[str] = None

    class Config:
        from_attributes = True
