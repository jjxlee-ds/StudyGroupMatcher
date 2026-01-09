from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class User_Course_Create(BaseModel):
    """
    Used to create a new user-course enrollment
    
    Attributes:
    user_id (str): User's ID from auth
    course_id (int): Course ID from courses table
    semester (str): Semester info (e.g., "2025 Spring")
    """
    nyu_id: str
    course_id: int
    course_section : int
    semester: str
    current_course_time_start : datetime
    current_course_time_end : datetime

class User_Course_Response(BaseModel):
    """
    Used to response user-course enrollment data
    
    Attributes:
    id (int): user_courses table primary key
    user_id (str): User's ID
    course_id (int): Course ID
    semester (str): Semester info
    created_at (datetime, optional): When enrolled
    """
    nyu_id: str
    course_id: int
    semester: str
    sectcourse_section : int
    current_course_time_start : datetime
    current_course_time_end : datetime
    created_at: Optional[datetime] = None