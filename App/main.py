from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api import auth

app = FastAPI(
    title = "Study Group Matcher API",
    version = "1.0.0"
)

app.include_router(auth.router)

app.add_middleware(
    CORSMiddleware,
    allow_origins = ["*"],
    allow_credentials = True,
    allow_methods = ["*"],
    allow_headers = ["*"],
)

@app.get("/")
def root():
    return {"Message":"Welcome to Study Matcher API"}


@app.get("/health")
def heath_check():
    return {"Status":"Healthy"}