from pydantic import BaseModel, EmailStr
from typing import Optional

class User_Response(BaseModel):
    """
    Docstring for User_Response
    
    used to reponse the user data

    Attributes:
    name (str): student name
    nyu_email (EmailStr) : nyu email 
    nyu_id (str) : id that starts with N and follows with 8 digit nunbers
    major (str): major
    minor(str,optional): minor
    academic_year (Integer): year of study(1,2,3,4)
    work_willingness (Integer): How willing to study in the group int
    """
    id: str
    name: str
    nyu_email : EmailStr
    nyu_id : str
    major: str
    minor: Optional[str] = None
    academic_standing: int
    work_willingness: int


class Update_User(BaseModel):
    name: Optional[str] = None
    password: Optional[str] = None
    major: Optional[str] = None
    minor: Optional[str] = None
    academic_standing: Optional[int]
    work_willingness: Optional[int]