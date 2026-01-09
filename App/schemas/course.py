from pydantic import BaseModel

class Create_Course(BaseModel):
    """
    used to store new course data in schema

    Attributes:
    course_code (str): course code in nyu albert
    course_name (Str) : name of the course 
    """
    course_code : str
    course_name : str
    course_section : int

class Course_Response(BaseModel):
    """
    Used to response course data

    Attributes:
    course_code (str): course code in nyu albert
    course_name (Str) : name of the course 
    """
    id : int
    course_code : str
    course_name : str
    course_section : int