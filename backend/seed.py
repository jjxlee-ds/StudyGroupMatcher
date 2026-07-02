"""
Seed script for Study Group Matcher portfolio demo.

Creates:
  - 1 demo account  (demo@nyu.edu / StudyMatch2025)
  - 12 seed users   (seed01@nyu.edu … seed12@nyu.edu / SeedPass2025)
  - Study groups drawn from existing courses in the DB
  - Chat room messages so rooms look alive

Safe to re-run: skips anything that already exists.

Usage:
    cd backend
    python seed.py
"""

import os
import sys
import random
import time
from datetime import datetime, timezone, timedelta

from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SERVICE_KEY  = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

supabase: Client = create_client(SUPABASE_URL, SERVICE_KEY)

DEMO_PASSWORD = "StudyMatch2025"
SEED_PASSWORD = "SeedPass2025"

# ---------------------------------------------------------------------------
# 1. Seed user profiles
# ---------------------------------------------------------------------------

DEMO_USER = {
    "nyu_email":          "demo@nyu.edu",
    "nyu_id":             "demo001",
    "name":               "Demo User",
    "major":              "Data Science",
    "minor":              None,
    "academic_standing":  3,        # Junior
    "work_willingness":   7,
    "preferred_location": "Bobst",
    "time_preference":    "After 12",
    "avg_gpa":            3.5,
}

SEED_USERS = [
    {"nyu_email": "seed01@nyu.edu", "nyu_id": "seed001", "name": "Alex Chen",
     "major": "Computer Science", "minor": None,
     "academic_standing": 2, "work_willingness": 9,
     "preferred_location": "Bobst", "time_preference": "After 12", "avg_gpa": 3.8},

    {"nyu_email": "seed02@nyu.edu", "nyu_id": "seed002", "name": "Maya Patel",
     "major": "Data Science", "minor": "Mathematics",
     "academic_standing": 3, "work_willingness": 8,
     "preferred_location": "Bobst", "time_preference": "After 12", "avg_gpa": 3.7},

    {"nyu_email": "seed03@nyu.edu", "nyu_id": "seed003", "name": "Jordan Lee",
     "major": "Mathematics", "minor": None,
     "academic_standing": 4, "work_willingness": 6,
     "preferred_location": "Kimmel", "time_preference": "Before 12", "avg_gpa": 3.4},

    {"nyu_email": "seed04@nyu.edu", "nyu_id": "seed004", "name": "Sam Rivera",
     "major": "Computer Science", "minor": "Economics",
     "academic_standing": 1, "work_willingness": 5,
     "preferred_location": "Kimmel", "time_preference": "After 12", "avg_gpa": 3.2},

    {"nyu_email": "seed05@nyu.edu", "nyu_id": "seed005", "name": "Priya Nair",
     "major": "Data Science", "minor": None,
     "academic_standing": 2, "work_willingness": 10,
     "preferred_location": "Bobst", "time_preference": "After 12", "avg_gpa": 3.9},

    {"nyu_email": "seed06@nyu.edu", "nyu_id": "seed006", "name": "Tyler Wang",
     "major": "Mathematics", "minor": "Computer Science",
     "academic_standing": 3, "work_willingness": 4,
     "preferred_location": "Off-campus", "time_preference": "Before 12", "avg_gpa": 3.1},

    {"nyu_email": "seed07@nyu.edu", "nyu_id": "seed007", "name": "Sofia Kim",
     "major": "Computer Science", "minor": None,
     "academic_standing": 4, "work_willingness": 7,
     "preferred_location": "Bobst", "time_preference": "After 12", "avg_gpa": 3.6},

    {"nyu_email": "seed08@nyu.edu", "nyu_id": "seed008", "name": "Marcus Johnson",
     "major": "Data Science", "minor": "Statistics",
     "academic_standing": 2, "work_willingness": 6,
     "preferred_location": "Kimmel", "time_preference": "Before 12", "avg_gpa": 3.3},

    {"nyu_email": "seed09@nyu.edu", "nyu_id": "seed009", "name": "Zoe Thompson",
     "major": "Mathematics", "minor": None,
     "academic_standing": 1, "work_willingness": 8,
     "preferred_location": "Bobst", "time_preference": "After 12", "avg_gpa": 3.5},

    {"nyu_email": "seed10@nyu.edu", "nyu_id": "seed010", "name": "Ethan Park",
     "major": "Computer Science", "minor": "Mathematics",
     "academic_standing": 3, "work_willingness": 9,
     "preferred_location": "Off-campus", "time_preference": "Before 12", "avg_gpa": 3.8},

    {"nyu_email": "seed11@nyu.edu", "nyu_id": "seed011", "name": "Aisha Rahman",
     "major": "Data Science", "minor": None,
     "academic_standing": 4, "work_willingness": 3,
     "preferred_location": "Kimmel", "time_preference": "Before 12", "avg_gpa": 2.9},

    {"nyu_email": "seed12@nyu.edu", "nyu_id": "seed012", "name": "Liam O'Brien",
     "major": "Mathematics", "minor": "Economics",
     "academic_standing": 2, "work_willingness": 7,
     "preferred_location": "Bobst", "time_preference": "After 12", "avg_gpa": 3.4},
]

# ---------------------------------------------------------------------------
# 2. Chat message pools (realistic study group conversations)
# ---------------------------------------------------------------------------

MESSAGES_BY_TOPIC = {
    "cs": [
        "Hey everyone, when do you want to meet for the algorithms assignment?",
        "I'm free Thursday after 3pm — anyone else?",
        "Thursday works for me! Should we meet at Bobst?",
        "Bobst 4th floor study rooms are usually open. I can book one.",
        "Can someone explain the dynamic programming problem on HW3?",
        "Yeah it's basically the same pattern as the knapsack problem from lecture.",
        "The key insight is you need a 2D DP table. Let me share my approach.",
        "Thanks! That makes way more sense now.",
        "Prof posted practice midterms on Brightspace btw",
        "Already printing them out lol",
        "Does anyone have notes from Monday? I had to miss class.",
        "I'll share mine in a sec — just cleaning them up",
        "Midterm is in 2 weeks, should we set up a study schedule?",
        "Yes! I was thinking we meet twice a week until then?",
        "Sounds good. Tuesday + Thursday?",
        "Works for me 👍",
        "Anyone stuck on the graph traversal section?",
        "BFS vs DFS — I keep mixing them up under pressure",
        "DFS uses a stack (or recursion), BFS uses a queue. Just remember that.",
        "Ok that's actually a super clean way to think about it",
        "Lab 4 is due Friday, how's everyone doing?",
        "Just started lol. Is the runtime O(n log n) for part 2?",
        "I got O(n²) but I think there's a smarter approach",
        "TA office hours are at 2pm tomorrow if anyone wants to go together",
    ],
    "ds": [
        "Hey team! When are we meeting to work on the regression project?",
        "I'm free anytime after 2 on Wednesdays",
        "Wednesday 3pm at Bobst works — I'll reserve a room",
        "Perfect. Should we divide up the data cleaning sections?",
        "Yes — I can handle the missing value imputation part",
        "I'll do the feature engineering. Anyone want EDA?",
        "I'll take EDA, I'm pretty comfortable with pandas",
        "Question — are we using scikit-learn or implementing from scratch?",
        "Prof said scikit-learn is fine for the final model but we need to explain the math",
        "Did anyone else get a really weird R² on the validation set?",
        "Mine was .03 lol. Something is definitely wrong with my features",
        "Make sure you're scaling before fitting! That got me the first time",
        "OH. That's why. Thank you 😭",
        "The bias-variance tradeoff section in the writeup is going to be tricky",
        "I can draft that part — I had a good lecture on it last semester",
        "Has anyone started the neural network extension?",
        "Not yet but I found a great tutorial, will share in a bit",
        "Reminder that the checkpoint is due Sunday — just the EDA section",
        "Already submitted mine! The dataset is surprisingly clean tbh",
        "Lucky. Mine had like 30% nulls in the income column",
        "Anyone joining the Kaggle competition the prof mentioned?",
        "I'm in if we can enter as a team",
        "Let's do it! More fun with a team anyway",
    ],
    "math": [
        "OK who else is completely lost on the epsilon-delta proofs?",
        "Same. I've been staring at this for 2 hours",
        "The key is to work backwards — figure out what delta needs to be, then prove it formally",
        "Can we go over problem 4 together? I think I'm close but something's off",
        "Yes! Let's meet tomorrow — I can show you what I did",
        "The textbook's proof for theorem 3.2 skips SO many steps",
        "Right?? I had to watch 3 YouTube videos to fill in the gaps",
        "Problem set is due Thursday, how's everyone doing?",
        "I finished the first 5. Problems 6 and 7 are killing me",
        "6 is easier once you realize it's just a special case of the mean value theorem",
        "Wait really? I was overcomplicating it completely",
        "Yeah check example 3.4 in the book, same setup",
        "Office hours with Prof tomorrow at 10 — anyone going?",
        "I'll be there for sure",
        "Me too, I have a whole list of questions",
        "Final exam is cumulative right? Even the topology stuff from week 2?",
        "I think so. Better to assume yes and be prepared",
        "Has anyone started the proof for the extra credit problem?",
        "I have a sketch but not sure it's rigorous enough",
        "I love this class but these proofs are humbling lol",
        "Same. But I feel like I'm actually learning math for the first time",
        "Study session Saturday at 1pm? I can grab a room in Courant",
        "I'll be there. Bring snacks",
        "Obviously 😂",
    ],
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def log(msg: str):
    print(f"  {msg}")


def create_auth_user(email: str, password: str, name: str) -> str | None:
    """Create a Supabase auth user. Returns user id or None if already exists."""
    try:
        resp = supabase.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {"name": name},
        })
        return resp.user.id if resp.user else None
    except Exception as e:
        if "already been registered" in str(e) or "already exists" in str(e):
            # Look up existing user id
            existing = supabase.table("users").select("id").eq("nyu_email", email).execute()
            if existing.data:
                return existing.data[0]["id"]
        log(f"    ⚠ Auth creation error for {email}: {e}")
        return None


def upsert_profile(user_id: str, profile: dict):
    """Insert user profile row, skip if already exists."""
    existing = supabase.table("users").select("id").eq("id", user_id).execute()
    if existing.data:
        return
    supabase.table("users").insert({
        "id": user_id,
        "nyu_email": profile["nyu_email"],
        "nyu_id":    profile["nyu_id"],
        "name":      profile["name"],
        "major":     profile["major"],
        "minor":     profile.get("minor"),
        "academic_standing":  profile["academic_standing"],
        "work_willingness":   profile["work_willingness"],
        "preferred_location": profile["preferred_location"],
        "time_preference":    profile["time_preference"],
        "avg_gpa":            profile.get("avg_gpa"),
    }).execute()


def enroll_user_in_course(user_id: str, course_id: int):
    existing = (
        supabase.table("user_courses")
        .select("user_id")
        .eq("user_id", user_id)
        .eq("course_id", course_id)
        .execute()
    )
    if existing.data:
        return
    supabase.table("user_courses").insert({
        "user_id":   user_id,
        "course_id": course_id,
        "term":      "Spring",
        "year":      2025,
    }).execute()


def create_group(course_id: int, name: str, location: str, max_members: int) -> str | None:
    """Create study group, return id (or existing id)."""
    existing = (
        supabase.table("study_groups")
        .select("id")
        .eq("name", name)
        .execute()
    )
    if existing.data:
        return existing.data[0]["id"]

    result = supabase.table("study_groups").insert({
        "course_id":   course_id,
        "name":        name,
        "max_members": max_members,
        "location":    location,
    }).execute()
    return result.data[0]["id"] if result.data else None


def add_member(group_id: str, user_id: str, role: str = "member"):
    existing = (
        supabase.table("user_study_groups")
        .select("user_id")
        .eq("study_group_id", group_id)
        .eq("user_id", user_id)
        .execute()
    )
    if existing.data:
        return
    supabase.table("user_study_groups").insert({
        "study_group_id": group_id,
        "user_id":        user_id,
        "role":           role,
    }).execute()


def get_or_create_room(group_id: str, group_name: str) -> str | None:
    existing = (
        supabase.table("chat_rooms")
        .select("id")
        .eq("group_id", group_id)
        .execute()
    )
    if existing.data:
        return existing.data[0]["id"]

    result = supabase.table("chat_rooms").insert({
        "group_id": group_id,
        "name":     group_name,
    }).execute()
    return result.data[0]["id"] if result.data else None


def add_room_member(room_id: str, user_id: str):
    existing = (
        supabase.table("room_members")
        .select("user_id")
        .eq("room_id", room_id)
        .eq("user_id", user_id)
        .execute()
    )
    if existing.data:
        return
    supabase.table("room_members").insert({
        "room_id": room_id,
        "user_id": user_id,
    }).execute()


def seed_messages(room_id: str, members: list[str], topic: str, count: int = 20):
    """Insert realistic messages only if room has no messages yet."""
    existing = (
        supabase.table("messages")
        .select("id")
        .eq("room_id", room_id)
        .limit(1)
        .execute()
    )
    if existing.data:
        return  # already seeded

    pool = MESSAGES_BY_TOPIC.get(topic, MESSAGES_BY_TOPIC["cs"])
    messages = pool[:count]

    last_ts = None
    for i, content in enumerate(messages):
        sender = members[i % len(members)]
        result = supabase.table("messages").insert({
            "room_id":   room_id,
            "sender_id": sender,
            "content":   content,
        }).execute()
        if result.data:
            last_ts = result.data[0]["created_at"]
        time.sleep(0.05)  # avoid timestamp collisions

    if last_ts:
        supabase.table("chat_rooms").update({"last_message_at": last_ts}).eq("id", room_id).execute()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("\n🌱 Study Group Matcher — Seed Script")
    print("=" * 50)

    # 1. Fetch existing courses
    print("\n📚 Fetching courses from database...")
    courses_result = supabase.table("courses").select("id, course_code, course_name").execute()
    all_courses = courses_result.data or []
    if not all_courses:
        print("  ❌ No courses found. Make sure courses are loaded first.")
        sys.exit(1)

    print(f"  Found {len(all_courses)} courses")

    # Categorise courses by keyword for assignment to groups
    def find_courses(keywords: list[str], limit: int = 3) -> list[dict]:
        matches = []
        for c in all_courses:
            code = c["course_code"].lower()
            name = c["course_name"].lower()
            if any(kw in code or kw in name for kw in keywords):
                matches.append(c)
            if len(matches) >= limit:
                break
        return matches

    cs_courses   = find_courses(["csci-ua1", "csci-ua2", "csci-ua3", "csci-ua4"], limit=4)
    ds_courses   = find_courses(["ds-ua"], limit=4)
    math_courses = find_courses(["math-ua1", "math-ua2", "math-ua3", "math-ua9"], limit=4)

    # Fallback: if categorisation misses, just use first available courses
    def fallback(lst, n=2):
        if len(lst) >= n:
            return lst
        return all_courses[:n]

    cs_courses   = fallback(cs_courses)
    ds_courses   = fallback(ds_courses, 2)
    math_courses = fallback(math_courses, 2)

    print(f"  CS courses:   {[c['course_code'] for c in cs_courses]}")
    print(f"  DS courses:   {[c['course_code'] for c in ds_courses]}")
    print(f"  Math courses: {[c['course_code'] for c in math_courses]}")

    # 2. Create demo + seed users
    print("\n👤 Creating users...")
    all_profiles = [DEMO_USER] + SEED_USERS
    user_ids: dict[str, str] = {}  # email -> supabase user id

    for profile in all_profiles:
        email = profile["nyu_email"]
        password = DEMO_PASSWORD if email == "demo@nyu.edu" else SEED_PASSWORD
        uid = create_auth_user(email, password, profile["name"])
        if uid:
            upsert_profile(uid, profile)
            user_ids[email] = uid
            log(f"✓ {profile['name']} ({email})")
        else:
            log(f"⚠ Skipped {email} (could not resolve ID)")

    demo_id = user_ids.get("demo@nyu.edu")
    seed_ids = [uid for email, uid in user_ids.items() if email.startswith("seed")]

    if not demo_id:
        print("  ❌ Demo user not created. Aborting.")
        sys.exit(1)

    # 3. Enroll users in courses
    print("\n📖 Enrolling users in courses...")

    def enroll_batch(user_id_list, course_list):
        for uid in user_id_list:
            for c in course_list:
                enroll_user_in_course(uid, c["id"])

    # Demo user: DS + CS courses
    for c in ds_courses[:2] + cs_courses[:1]:
        enroll_user_in_course(demo_id, c["id"])

    # Seed users split across domains
    enroll_batch(seed_ids[:4],  cs_courses)
    enroll_batch(seed_ids[4:8], ds_courses)
    enroll_batch(seed_ids[8:],  math_courses)

    # Cross-enroll some users so groups overlap (makes recs more interesting)
    for uid in seed_ids[:3]:
        for c in ds_courses[:1]:
            enroll_user_in_course(uid, c["id"])
    for uid in seed_ids[4:6]:
        for c in cs_courses[:1]:
            enroll_user_in_course(uid, c["id"])

    log("Done")

    # 4. Create study groups
    print("\n👥 Creating study groups...")

    groups: list[dict] = []  # {id, name, course_id, topic, members}

    def make_group(course: dict, name: str, location: str, max_m: int,
                   admin_id: str, member_ids: list[str], topic: str):
        gid = create_group(course["id"], name, location, max_m)
        if not gid:
            return
        add_member(gid, admin_id, role="admin")
        for mid in member_ids:
            add_member(gid, mid, role="member")
        groups.append({
            "id": gid, "name": name,
            "members": [admin_id] + member_ids,
            "topic": topic,
        })
        log(f"✓ {name}")

    # CS groups
    if cs_courses:
        make_group(cs_courses[0], "Algorithms Study Crew",      "Bobst",      4, seed_ids[0], [seed_ids[1], seed_ids[3], demo_id], "cs")
        make_group(cs_courses[0], "Data Structures Deep Dive",  "Kimmel",     4, seed_ids[1], [seed_ids[0], seed_ids[6]],          "cs")
    if len(cs_courses) > 1:
        make_group(cs_courses[1], "OS Concepts Study Group",    "Off-campus", 4, seed_ids[6], [seed_ids[3], seed_ids[9]],          "cs")

    # DS groups
    if ds_courses:
        make_group(ds_courses[0], "ML Project Team",            "Bobst",      4, seed_ids[4], [seed_ids[1], seed_ids[7], demo_id], "ds")
        make_group(ds_courses[0], "Regression Analysis Group",  "Bobst",      4, demo_id,     [seed_ids[4], seed_ids[7]],          "ds")
    if len(ds_courses) > 1:
        make_group(ds_courses[1], "Stat Learning Study Circle", "Kimmel",     4, seed_ids[7], [seed_ids[4], seed_ids[10]],         "ds")

    # Math groups
    if math_courses:
        make_group(math_courses[0], "Real Analysis Proof Group",  "Bobst",    4, seed_ids[2], [seed_ids[5], seed_ids[8]],              "math")
        make_group(math_courses[0], "Calculus Problem Solvers",   "Kimmel",   4, seed_ids[8], [seed_ids[2], seed_ids[11]],              "math")
    if len(math_courses) > 1:
        make_group(math_courses[1], "Linear Algebra Study Group", "Off-campus",4, seed_ids[5], [seed_ids[2], seed_ids[9]],              "math")

    # Demo user's personal group (they're admin)
    if ds_courses:
        make_group(ds_courses[0], "DS Capstone Prep",            "Bobst",     4, demo_id, [seed_ids[1], seed_ids[4]], "ds")

    # 5. Set up chat rooms and seed messages
    print("\n💬 Creating chat rooms and seeding messages...")
    for g in groups:
        room_id = get_or_create_room(g["id"], g["name"])
        if not room_id:
            continue
        for uid in g["members"]:
            add_room_member(room_id, uid)
        seed_messages(room_id, g["members"], g["topic"], count=18)
        log(f"✓ {g['name']}")

    # 6. Summary
    print("\n" + "=" * 50)
    print("✅ Seed complete!\n")
    print(f"  Demo login:  demo@nyu.edu  /  {DEMO_PASSWORD}")
    print(f"  Seed users:  seed01@nyu.edu … seed12@nyu.edu  /  {SEED_PASSWORD}")
    print(f"  Groups created: {len(groups)}")
    print(f"  Demo user is admin of: Regression Analysis Group, DS Capstone Prep")
    print(f"  Demo user is member of: Algorithms Study Crew, ML Project Team")
    print()


if __name__ == "__main__":
    main()
