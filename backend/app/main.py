from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, chat, course, meeting, schedule, user, user_course, study_group


@asynccontextmanager
async def lifespan(app: FastAPI):
    from app.tasks.meeting_expiry import start_scheduler, stop_scheduler
    start_scheduler()
    yield
    stop_scheduler()


app = FastAPI(
    title="Study Group Matcher API",
    description="API for matching NYU students with similar courses and work willingness",
    version="1.0.0",
    lifespan=lifespan,
)

# Include routers
app.include_router(auth.router)
app.include_router(user.router)
app.include_router(course.router)
app.include_router(user_course.router)
app.include_router(study_group.router)
app.include_router(chat.router)
app.include_router(schedule.router)
app.include_router(meeting.router)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    print(f"[422 DEBUG] body={await request.body()}")
    print(f"[422 DEBUG] errors={exc.errors()}")
    return JSONResponse(status_code=422, content={"detail": exc.errors()})


@app.get("/")
def root():
    return {"message": "Welcome to Study Group Matcher API"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}
