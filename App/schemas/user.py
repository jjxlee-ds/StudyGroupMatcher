from pydantic import BaseModel, EmailStr
from typing import Optional

class Create_User(BaseModel):
    """
    Docstring for Create_User

    used to store new user data in schema

    Attributes:
    name (str): student name
    nyu_email (EmailStr) : nyu email 
    nyu_id (str) : id that starts with N and follows with 8 digit nunbers
    password (str): password
    major (str): major
    minor(str,optional): minor
    academic_year (Integer): year of study(1,2,3,4)
    work_willingness (Integer): How willing to study in the group int
    """
    name: str
    nyu_email : EmailStr
    nyu_id : str
    password: str
    major: str
    minor: Optional[str] = None
    academic_standing: int
    work_willingness: int

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

class Login_Request(BaseModel):
    """
    Docstring for Login_Request

    used to login user and Authentication
    
    attributes:
    nyu_email (EmailStr): student email
    password (Str): password
    """
    nyu_email : EmailStr
    password : str

class Token_Response(BaseModel):
    """
    Docstring for Token_Response

    used when login was success returns JWT Token and User data

    attributes:
    access_token (str): JWT AUTH Token(Bearer 토큰)
    token_type (str): Token Type ("bearer")
    user (UserResponse): user info from the db
    """
    access_token : str
    token_type: str = "bearer"
    user: User_Response
