from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api import auth, course, user, user_course


app = FastAPI(
    title="Study Group Matcher API",
    description="API for matching NYU students with similar courses and work willingness",
    version="1.0.0"
)

# Include routers
app.include_router(auth.router)
app.include_router(user.router)
app.include_router(course.router)
app.include_router(user_course.router)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    """Root endpoint."""
    return {"message": "Welcome to Study Group Matcher API"}


@app.get("/health")
def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}
