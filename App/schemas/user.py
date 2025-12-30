from pydantic import BaseModel, EmailStr
from typing import Optional

class Create_User(BaseModel):
    name: str
    nyu_email : EmailStr
    nyu_id : str
    password: str
    major: str
    minor: Optional[str] = None
    academic_year: int
    work_willingness: int

class User_Response(BaseModel):
    name: str
    nyu_email : EmailStr
    nyu_id : str
    major: str
    minor: Optional[str] = None
    academic_year: int
    work_willingness: int
