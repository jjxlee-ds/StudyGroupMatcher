# CLAUDE.md — Study Group Matcher Backend

This file provides context and conventions for Claude when working on this project.

---

## Project Overview

**Study Group Matcher** is an NYU student-facing app that helps students find study group partners based on shared courses and availability.

- **Backend**: FastAPI + Supabase (this repo — Jude's responsibility)
- **Frontend**: Flutter (separate, handled by teammate)
- **Database**: Supabase (PostgreSQL) — table creation handled by teammate
- **Auth**: Supabase Auth (JWT-based)
- **Testing**: Swagger UI at `http://localhost:8000/docs`

---

## Project Structure

```
App/
├── main.py                  # FastAPI app entry point, router registration, CORS
├── database.py              # Supabase client initialization
├── api/
│   ├── __init__.py
│   ├── auth.py              # Signup / Login
│   ├── users.py             # User profile CRUD
│   ├── courses.py           # Course management
│   ├── user_courses.py      # Course enrollment management
│   └── dependencies.py      # JWT auth dependency (get_current_user)
├── schemas/
│   ├── user.py
│   ├── course.py
│   └── user_course.py
└── services/                # Business logic layer (separate from API layer)
    └── auth_service.py
```

---

## Database Schema

Tables are created by teammate in Supabase. Do not create or modify tables directly.

| Table | Key Columns |
|---|---|
| `users` | `id UUID (PK, = Supabase Auth UID)`, `nyu_email`, `nyu_id`, `name`, `major`, `minor`, `academic_year`, `work_willingness (int)` |
| `courses` | `id`, `course_code`, `course_name` |
| `user_courses` | `id`, `nyu_id`, `course_id`, `course_section (int)`, `semester`, `current_course_time_start`, `current_course_time_end` |
| `user_available_time` | `id`, `user_id`, `day_of_week`, `start_time`, `end_time`, `preference`, `created_at`, `updated_at` |
| `studies` | `id`, `title`, `description`, `course_code`, `max_members`, `created_by` |
| `study_members` | `study_id`, `user_id`, `role` |
| `study_applications` | `study_id`, `user_id`, `message`, `status` |

**Important notes:**
- `users.id` is set to the Supabase Auth UID — always use this as the foreign key reference, not `nyu_id`
- `work_willingness` is an integer (scale, not boolean)
- Timestamp fields use `str` in Pydantic schemas — PostgreSQL handles the `timestamptz` conversion automatically

---

## Authentication Flow

1. Client calls `POST /auth/signup` or `POST /auth/login`
2. Supabase Auth handles password hashing and JWT issuance
3. JWT is returned to client; client sends it as `Authorization: Bearer <token>` on subsequent requests
4. `dependencies.py` → `get_current_user()` validates the token by calling `supabase.auth.get_user(token)`
5. All protected endpoints use `Depends(get_current_user)` to inject the current user

```python
# Pattern for protected endpoints
@router.get("/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    ...
```

---

## Implemented Endpoints

### Auth — `/auth`
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/signup` | ❌ | Register new user (Supabase Auth + users table) |
| POST | `/auth/login` | ❌ | Login → returns JWT |

### Users — `/users`
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/users/me` | ✅ | Get own profile |
| PUT | `/users/me` | ✅ | Update own profile |
| DELETE | `/users/delete_me` | ✅ | Delete own account |

### Courses — `/courses`
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/courses/` | ❌ | List all courses |
| POST | `/courses/create` | ❌ | Create a course |

### User Courses — `/user-courses`
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/user-courses/` | ✅ | Get own enrolled courses |
| POST | `/user-courses/` | ✅ | Enroll in a course |
| DELETE | `/user-courses/{id}` | ✅ | Drop a course |

---

## Coding Conventions

### Naming
- **Classes**: `PascalCase` — `UserResponse`, `CourseCreate`
- **Functions / variables**: `snake_case` — `get_current_user`, `course_code`
- **Constants**: `UPPER_CASE` — `MAX_MEMBERS`
- **Router prefixes**: kebab-case plural nouns — `/user-courses`, `/courses`
- **Tags (Swagger grouping)**: Title Case — `"User Courses"`, `"Auth"`

### Schema patterns
```python
# Create schema: only fields the client sends
class CourseCreate(BaseModel):
    course_code: str
    course_name: str

# Response schema: what the API returns (includes id, timestamps)
class CourseResponse(BaseModel):
    id: int
    course_code: str
    course_name: str
    created_at: Optional[str] = None
```

- Use `Optional[str] = None` for nullable fields
- Use `str` (not `datetime`) for timestamp fields — DB handles conversion
- Add `class Config: from_attributes = True` for ORM compatibility (Pydantic v2)

### API layer patterns

Always get Supabase inside the function, not at module level:
```python
# ❌ Avoid: module-level Supabase instance
supabase = get_supabase()

# ✅ Preferred: inside the function
async def my_endpoint():
    supabase = get_supabase()
```

Always separate business logic into a service layer:
```python
# api/auth.py — thin, just routing
@router.post("/signup")
async def signup(user: UserCreate):
    return await AuthService.register_user(user)

# services/auth_service.py — all logic lives here
class AuthService:
    @staticmethod
    async def register_user(user: UserCreate) -> dict:
        ...
```

Use the `@handle_supabase_errors` decorator to avoid repetitive try/except:
```python
# api/utils.py
def handle_supabase_errors(func):
    @wraps(func)
    async def wrapper(*args, **kwargs):
        try:
            return await func(*args, **kwargs)
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    return wrapper
```

### Input normalization

Always normalize `course_code` before DB operations:
```python
def normalize(s: str | None) -> str | None:
    if s is None or not s.strip():
        return None
    return s.strip().lower()
```

### Data ownership / authorization

Users can only read/modify their own data. Always verify using the JWT-derived user ID, not a client-supplied ID:
```python
# ❌ Don't trust the request body's user ID
if request.nyu_id != current_user["nyu_id"]:
    raise HTTPException(status_code=403, ...)

# ✅ Better: don't accept user_id from client at all — derive it from JWT
user_course_data = {
    "nyu_id": current_user["nyu_id"],  # from JWT, not request
    ...
}
```

---

## main.py Structure

```python
app = FastAPI(title="Study Group Matcher API", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], ...)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(courses.router)
app.include_router(user_courses.router)
```

When adding a new module, always register its router in `main.py`.

---

## Running the Server

```bash
cd App
uvicorn main:app --reload
```

API docs: `http://localhost:8000/docs`

To test protected endpoints in Swagger:
1. Call `POST /auth/login` and copy the JWT
2. Click "Authorize" (top right in Swagger)
3. Enter `Bearer <your_token>`

---

## Key Technical Decisions

| Decision | Rationale |
|---|---|
| Supabase Auth for JWT | No manual hashing/verification; Supabase handles it entirely |
| `str` for timestamps in Pydantic | Avoids Pydantic datetime parsing errors; PostgreSQL converts ISO strings to `timestamptz` automatically |
| `users.id` = Supabase Auth UID | Single source of truth; avoids sync issues between auth and profile tables |
| Service layer separation | Keeps API routes thin and business logic testable/reusable |
| `normalize()` on course_code | Prevents duplicate courses due to case or whitespace differences |
| Path vs query params | No real security difference; security is enforced by JWT auth, not URL structure |

---

## What's Not Built Yet

- [ ] Study Group API (`studies`, `study_members`, `study_applications` endpoints)
- [ ] Chat rooms — use **Supabase Realtime** (recommended over FastAPI WebSockets for this scale)
  - Flutter subscribes via `.stream()` directly; FastAPI only handles REST (create room, fetch history)
  - Tables needed: `chat_rooms (id, study_group_id, created_at)`, `messages (id, room_id, sender_id, content, created_at)`
- [ ] Matching algorithm — rule-based: same course + overlapping `user_available_time`
- [ ] Scheduling feature
- [ ] Feedback system