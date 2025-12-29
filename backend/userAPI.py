#CRUD
#Create, Read, Update, Delete operations for a simple API
#https request 
#get, post, put, delete

from fastapi import FastAPI, HTTPException, status, Path
from typing import Optional
from pydantic import BaseModel

app = FastAPI()
users = {
    "N10515515":{
    "name" : "Seung Yun Mok",
    "major" : "Computer Science",
    "minor" : "Mathematics",
    "course" : ["CSCI101","DS111","MATH140","CORE-750"],
    "Academic_Year" : "Sophomore",
    }
}

#endpoint is like a url 
@app.get("/")
def root():
    return {"message":"Welcome to the NYU user API"}
# get user
@app.get("/users/{nyu_id}")
def get_user(nyu_id: str = Path(..., 
                            description="The NYU ID of the user to get", 
                            max_length = 9, 
                            min_length = 9, 
                            pattern = "^N[0-9]{8}$")):
    if nyu_id not in users: 
        raise HTTPException(status_code = 404, detail = "User not found")
    return users[nyu_id]

# Base pydantic model
class User(BaseModel):
    name: str
    major: str
    minor: Optional[str] = None
    course: list[str]
    Academic_Year: str

class UpdateUser(BaseModel):
    name: Optional[str] = None
    major: Optional[str] = None
    minor: Optional[str] = None
    course: Optional[list[str]] = None
    Academic_Year: Optional[str] = None 

# create user

# update user

# delete user

# search for user