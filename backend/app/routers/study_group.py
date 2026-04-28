from fastapi import APIRouter, Depends, HTTPException, Query, status
from typing import List, Optional
from supabase import Client

from app.database import get_supabase, get_supabase_admin
from app.dependencies import get_current_user
from app.schemas.join_request import JoinRequestResponse
from app.schemas.study_group import GroupMemberResponse, StudyGroupCreate, StudyGroupResponse, StudyGroupRecommendation
from app.services.chat_service import create_room
from app.services.group_service import assert_group_admin, get_group_or_404
from app.services.utils import handle_supabase_errors


router = APIRouter(prefix="/study-groups", tags=["study-groups"])


def _extract_member_count(group: dict) -> int:
    count_data = group.pop("user_study_groups", [])
    if count_data and isinstance(count_data, list):
        return count_data[0].get("count", 0)
    return 0


def _attach_group_metadata(supabase: Client, groups: List[dict]) -> List[dict]:
    """Attach fields the frontend expects but that are derived from memberships."""
    if not groups:
        return groups

    group_ids = [group["id"] for group in groups]
    memberships = (
        supabase.table("user_study_groups")
        .select("study_group_id, user_id, role")
        .in_("study_group_id", group_ids)
        .execute()
    )

    counts = {group_id: 0 for group_id in group_ids}
    admins: dict[str, str] = {}
    for row in memberships.data or []:
        group_id = row["study_group_id"]
        counts[group_id] = counts.get(group_id, 0) + 1
        if row.get("role") == "admin":
            admins[group_id] = row["user_id"]

    for group in groups:
        embedded_count = _extract_member_count(group)
        group_id = group["id"]
        group["current_members"] = counts.get(group_id) or embedded_count
        group["admin_id"] = admins.get(group_id)

    return groups


# ============== Recommendation Score Calculation ==============

# Weight constants
WEIGHT_WORK_WILLINGNESS = 50
WEIGHT_GPA = 30
WEIGHT_LOCATION = 10
WEIGHT_TIME = 10


def calculate_work_willingness_score(user_val: int, avg_val: float) -> float:
    """
    Calculate work_willingness score.
    Same value = 50 points, decreases by ~5 points per difference unit.
    """
    diff = abs(user_val - avg_val)
    # Max difference is 9 (1-10 scale), min score is 5
    score = max(5, WEIGHT_WORK_WILLINGNESS - (diff * 5))
    return score


def get_gpa_tier(gpa: Optional[float]) -> int:
    """Get GPA tier: 0 = None/unknown, 1 = <3.0, 2 = 3.0-3.5, 3 = 3.51-4.0"""
    if gpa is None:
        return 0
    if gpa < 3.0:
        return 1
    if gpa <= 3.5:
        return 2
    return 3


def calculate_gpa_score(user_gpa: Optional[float], avg_gpa: Optional[float]) -> float:
    """
    Calculate GPA score based on tier matching.
    <3.0 = 5pts, 3.0-3.5 = 7pts, 3.51-4.0 = 10pts (on 10-point scale)
    Scaled to 30-point weight.
    """
    user_tier = get_gpa_tier(user_gpa)
    avg_tier = get_gpa_tier(avg_gpa)

    # If either is unknown, give middle score
    if user_tier == 0 or avg_tier == 0:
        return WEIGHT_GPA * 0.7  # 21 points

    # Same tier = full points for that tier
    tier_scores = {1: 5, 2: 7, 3: 10}

    if user_tier == avg_tier:
        return (tier_scores[user_tier] / 10) * WEIGHT_GPA
    else:
        # Different tier - reduce score based on distance
        tier_diff = abs(user_tier - avg_tier)
        base_score = tier_scores[user_tier]
        penalty = tier_diff * 2
        return max(0.5, (base_score - penalty) / 10) * WEIGHT_GPA


def normalize_location(loc: Optional[str]) -> str:
    """Normalize location string for comparison."""
    if not loc:

        
        return "unknown"
    loc = loc.strip().lower()
    if "kimmel" in loc:
        return "kimmel"
    if "bobst" in loc or "bob" in loc:
        return "bobst"
    if "off" in loc and "campus" in loc:
        return "offcampus"
    return loc


def calculate_location_score(user_loc: Optional[str], avg_loc: Optional[str]) -> float:
    """
    Calculate location score.
    Same = 10, Kimmel/Bobst cross = 7, Off-campus vs others = 3
    """
    user_norm = normalize_location(user_loc)
    avg_norm = normalize_location(avg_loc)

    if user_norm == "unknown" or avg_norm == "unknown":
        return WEIGHT_LOCATION * 0.5  # 5 points for unknown

    if user_norm == avg_norm:
        return WEIGHT_LOCATION  # 10 points

    on_campus = {"kimmel", "bobst"}

    # Both on campus (Kimmel/Bobst) but different
    if user_norm in on_campus and avg_norm in on_campus:
        return 7

    # Off-campus vs any other
    if user_norm == "offcampus" or avg_norm == "offcampus":
        return 3

    # Other combinations
    return 5


def normalize_time(time_pref: Optional[str]) -> str:
    """Normalize time preference to 'before12' or 'after12'."""
    if not time_pref:
        return "unknown"
    time_pref = time_pref.strip().lower()
    if "before" in time_pref or "morning" in time_pref or "am" in time_pref:
        return "before12"
    if "after" in time_pref or "afternoon" in time_pref or "evening" in time_pref or "pm" in time_pref:
        return "after12"
    return time_pref


def calculate_time_score(user_time: Optional[str], avg_time: Optional[str]) -> float:
    """
    Calculate time preference score.
    Same = 10, Different = 5
    """
    user_norm = normalize_time(user_time)
    avg_norm = normalize_time(avg_time)

    if user_norm == "unknown" or avg_norm == "unknown":
        return WEIGHT_TIME * 0.75  # 7.5 points for unknown

    if user_norm == avg_norm:
        return WEIGHT_TIME  # 10 points

    return 5  # Different = 5 points


def calculate_member_averages(members: List[dict]) -> dict:
    """Calculate average values for all factors from group members."""
    if not members:
        return {
            "work_willingness": 5.0,
            "avg_gpa": None,
            "preferred_location": None,
            "time_preference": None
        }

    work_values = [m.get("work_willingness", 5) for m in members if m.get("work_willingness")]
    gpa_values = [m.get("avg_gpa") for m in members if m.get("avg_gpa") is not None]
    locations = [m.get("preferred_location") for m in members if m.get("preferred_location")]
    times = [m.get("time_preference") for m in members if m.get("time_preference")]

    # For location and time, find most common (mode)
    def get_mode(items):
        if not items:
            return None
        from collections import Counter
        counter = Counter(items)
        return counter.most_common(1)[0][0]

    return {
        "work_willingness": sum(work_values) / len(work_values) if work_values else 5.0,
        "avg_gpa": sum(gpa_values) / len(gpa_values) if gpa_values else None,
        "preferred_location": get_mode(locations),
        "time_preference": get_mode(times)
    }


def calculate_total_score(user: dict, group_averages: dict) -> tuple[float, dict]:
    """Calculate total match score and breakdown."""
    work_score = calculate_work_willingness_score(
        user.get("work_willingness", 5),
        group_averages["work_willingness"]
    )
    gpa_score = calculate_gpa_score(
        user.get("avg_gpa"),
        group_averages["avg_gpa"]
    )
    location_score = calculate_location_score(
        user.get("preferred_location"),
        group_averages["preferred_location"]
    )
    time_score = calculate_time_score(
        user.get("time_preference"),
        group_averages["time_preference"]
    )

    total = work_score + gpa_score + location_score + time_score

    breakdown = {
        "work_willingness": round(work_score, 2),
        "gpa": round(gpa_score, 2),
        "location": round(location_score, 2),
        "time_preference": round(time_score, 2)
    }

    return round(total, 2), breakdown


@router.post("/", response_model=StudyGroupResponse, status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def create_study_group(
    request: StudyGroupCreate,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
    supabase_admin: Client = Depends(get_supabase_admin),
) -> StudyGroupResponse:
    """Create a new study group and add the creator as admin."""
    group_data = {
        "course_id": request.course_id,
        "name": request.name,
        "max_members": request.max_members,
        "location": request.location,
    }

    result = supabase.table("study_groups").insert(group_data).execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create study group"
        )

    group = result.data[0]

    # Add creator as admin member
    membership_data = {
        "user_id": current_user["id"],
        "study_group_id": group["id"],
        "role": "admin",
    }
    supabase.table("user_study_groups").insert(membership_data).execute()

    # Auto-create chat room and add creator (admin client bypasses RLS)
    create_room(supabase_admin, group["id"], current_user["id"], name=request.name)

    group["current_members"] = 1
    group["admin_id"] = current_user["id"]
    return group


@router.get("/search", response_model=List[StudyGroupResponse])
@handle_supabase_errors
async def search_study_groups_by_name(
    name: str = Query(..., min_length=1, description="Study group name to search"),
    supabase: Client = Depends(get_supabase)
) -> List[StudyGroupResponse]:
    """Search for study groups by name (case-insensitive partial match)."""
    result = (
        supabase.table("study_groups")
        .select("*, user_study_groups(count)")
        .ilike("name", f"%{name}%")
        .execute()
    )

    return _attach_group_metadata(supabase, result.data or [])


@router.get("/course/{course_id}", response_model=List[StudyGroupResponse])
@handle_supabase_errors
async def get_study_groups_by_course(
    course_id: int,
    supabase: Client = Depends(get_supabase)
) -> List[StudyGroupResponse]:
    """Get all study groups for a specific course with current member counts."""
    result = (
        supabase.table("study_groups")
        .select("*, user_study_groups(count)")
        .eq("course_id", course_id)
        .execute()
    )

    return _attach_group_metadata(supabase, result.data or [])


@router.post("/{group_id}/join", status_code=status.HTTP_201_CREATED)
@handle_supabase_errors
async def request_join_study_group(
    group_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
):
    """스터디 그룹 참가 신청. 방장이 수락해야 최종 합류."""
    group = get_group_or_404(supabase, group_id)

    # 이미 멤버인지 확인
    existing_member = (
        supabase.table("user_study_groups")
        .select("user_id")
        .eq("user_id", current_user["id"])
        .eq("study_group_id", group_id)
        .execute()
    )
    if existing_member.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already a member of this study group",
        )

    # 이미 신청 중인지 확인
    existing_request = (
        supabase.table("group_join_requests")
        .select("id, status")
        .eq("user_id", current_user["id"])
        .eq("study_group_id", group_id)
        .eq("status", "pending")
        .execute()
    )
    if existing_request.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Join request already pending",
        )

    # 정원 초과 확인
    member_count = (
        supabase.table("user_study_groups")
        .select("*", count="exact")
        .eq("study_group_id", group_id)
        .execute()
    )
    if member_count.count is not None and member_count.count >= group["max_members"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Study group is full",
        )

    supabase.table("group_join_requests").insert({
        "user_id": current_user["id"],
        "study_group_id": group_id,
        "status": "pending",
    }).execute()

    return {"message": "Join request submitted. Waiting for admin approval."}


@router.delete("/{group_id}/leave", status_code=status.HTTP_204_NO_CONTENT)
@handle_supabase_errors
async def leave_study_group(
    group_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
    supabase_admin: Client = Depends(get_supabase_admin),
):
    """Leave a study group."""
    existing = (
        supabase.table("user_study_groups")
        .select("user_id, role")
        .eq("user_id", current_user["id"])
        .eq("study_group_id", group_id)
        .execute()
    )

    if not existing.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="You are not a member of this study group"
        )

    (
        supabase.table("user_study_groups")
        .delete()
        .eq("user_id", current_user["id"])
        .eq("study_group_id", group_id)
        .execute()
    )

    room_result = (
        supabase_admin.table("chat_rooms")
        .select("id")
        .eq("group_id", group_id)
        .execute()
    )
    if room_result.data:
        supabase_admin.table("room_members").delete().eq(
            "room_id", room_result.data[0]["id"]
        ).eq("user_id", current_user["id"]).execute()


@router.get("/me", response_model=List[StudyGroupResponse])
@handle_supabase_errors
async def get_my_study_groups(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
) -> List[StudyGroupResponse]:
    """Get all study groups the current user belongs to."""
    memberships = (
        supabase.table("user_study_groups")
        .select("study_group_id")
        .eq("user_id", current_user["id"])
        .execute()
    )

    if not memberships.data:
        return []

    group_ids = [m["study_group_id"] for m in memberships.data]

    result = (
        supabase.table("study_groups")
        .select("*, user_study_groups(count)")
        .in_("id", group_ids)
        .execute()
    )

    return _attach_group_metadata(supabase, result.data or [])


@router.get("/recommend", response_model=List[StudyGroupRecommendation])
@handle_supabase_errors
async def get_recommended_study_groups(
    limit: int = Query(default=10, ge=1, le=50, description="Maximum number of recommendations"),
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase)
) -> List[StudyGroupRecommendation]:
    """
    Get personalized study group recommendations for the current user.

    Recommendations are based on:
    - work_willingness (50% weight)
    - GPA similarity (30% weight)
    - preferred_location (10% weight)
    - time_preference (10% weight)

    Groups are scored based on the average of current members' attributes.
    """
    # Get user's enrolled courses
    user_courses = (
        supabase.table("user_courses")
        .select("course_id")
        .eq("user_id", current_user["id"])
        .execute()
    )

    if not user_courses.data:
        return []

    course_ids = [c["course_id"] for c in user_courses.data]

    # Get groups user already belongs to
    my_memberships = (
        supabase.table("user_study_groups")
        .select("study_group_id")
        .eq("user_id", current_user["id"])
        .execute()
    )
    my_group_ids = {m["study_group_id"] for m in (my_memberships.data or [])}

    # Get all study groups for user's courses
    groups_result = (
        supabase.table("study_groups")
        .select("*, user_study_groups(count)")
        .in_("course_id", course_ids)
        .execute()
    )

    if not groups_result.data:
        return []

    recommendations = []

    for group in groups_result.data:
        group_id = group["id"]

        # Skip groups user already belongs to
        if group_id in my_group_ids:
            continue

        # Get current member count
        metadata_group = _attach_group_metadata(supabase, [group])[0]
        current_members = metadata_group["current_members"]

        # Skip full groups
        if current_members >= group.get("max_members", 0):
            continue

        # Get member details for this group
        members_result = (
            supabase.table("user_study_groups")
            .select("user_id, users(work_willingness, avg_gpa, preferred_location, time_preference)")
            .eq("study_group_id", group_id)
            .execute()
        )

        # Extract user data from nested structure
        members = []
        for m in (members_result.data or []):
            user_data = m.get("users")
            if user_data:
                members.append(user_data)

        # Calculate group averages
        group_averages = calculate_member_averages(members)

        # Calculate match score
        total_score, breakdown = calculate_total_score(current_user, group_averages)

        recommendations.append({
            "id": group["id"],
            "course_id": group["course_id"],
            "name": group["name"],
            "max_members": group["max_members"],
            "location": group.get("location"),
            "created_at": group.get("created_at"),
            "current_members": current_members,
            "admin_id": metadata_group.get("admin_id"),
            "match_score": total_score,
            "score_breakdown": breakdown
        })

    # Sort by match_score descending
    recommendations.sort(key=lambda x: x["match_score"], reverse=True)

    return recommendations[:limit]


@router.get("/{group_id}/members", response_model=List[GroupMemberResponse])
@handle_supabase_errors
async def get_group_members(
    group_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> List[GroupMemberResponse]:
    """그룹 멤버 목록 조회. role 포함 — admin이 방장."""
    from app.services.schedule_service import assert_group_member
    assert_group_member(supabase, group_id, current_user["id"])

    result = (
        supabase.table("user_study_groups")
        .select("role, users(id, name, nyu_email, major, academic_standing, work_willingness, avg_gpa)")
        .eq("study_group_id", group_id)
        .execute()
    )

    members = []
    for row in (result.data or []):
        user = row.get("users") or {}
        members.append({
            "user_id": user.get("id"),
            "role": row["role"],
            "name": user.get("name"),
            "nyu_email": user.get("nyu_email"),
            "major": user.get("major"),
            "academic_standing": user.get("academic_standing"),
            "work_willingness": user.get("work_willingness"),
            "avg_gpa": user.get("avg_gpa"),
        })
    return members


# ============== Admin (방장) Endpoints ==============


@router.get("/{group_id}/requests", response_model=List[JoinRequestResponse])
@handle_supabase_errors
async def get_join_requests(
    group_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
) -> List[JoinRequestResponse]:
    """(방장 전용) 참가 신청 목록 조회 — 신청자 개인 정보 포함."""
    get_group_or_404(supabase, group_id)
    assert_group_admin(supabase, group_id, current_user["id"])

    requests_result = (
        supabase.table("group_join_requests")
        .select("*, users(*)")
        .eq("study_group_id", group_id)
        .eq("status", "pending")
        .order("created_at")
        .execute()
    )

    rows = requests_result.data or []
    return [
        {**row, "user": row.pop("users", None)}
        for row in rows
    ]


@router.post("/{group_id}/requests/{request_id}/accept", status_code=status.HTTP_200_OK)
@handle_supabase_errors
async def accept_join_request(
    group_id: str,
    request_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
    supabase_admin: Client = Depends(get_supabase_admin),
):
    """(방장 전용) 참가 신청 수락 — user_study_groups에 멤버로 추가."""
    get_group_or_404(supabase, group_id)
    assert_group_admin(supabase, group_id, current_user["id"])

    req_result = (
        supabase.table("group_join_requests")
        .select("*")
        .eq("id", request_id)
        .eq("study_group_id", group_id)
        .eq("status", "pending")
        .execute()
    )
    if not req_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pending join request not found",
        )

    applicant_id = req_result.data[0]["user_id"]

    supabase.table("user_study_groups").insert({
        "user_id": applicant_id,
        "study_group_id": group_id,
        "role": "member",
    }).execute()

    supabase.table("group_join_requests").update(
        {"status": "accepted"}
    ).eq("id", request_id).execute()

    # Add new member to chat room (admin client bypasses RLS)
    room_result = (
        supabase_admin.table("chat_rooms")
        .select("id")
        .eq("group_id", group_id)
        .execute()
    )
    if room_result.data:
        room_id = room_result.data[0]["id"]
        existing_room_member = (
            supabase_admin.table("room_members")
            .select("user_id")
            .eq("room_id", room_id)
            .eq("user_id", applicant_id)
            .execute()
        )
        if not existing_room_member.data:
            supabase_admin.table("room_members").insert(
                {"room_id": room_id, "user_id": applicant_id}
            ).execute()

    return {"message": "Join request accepted"}


@router.post("/{group_id}/requests/{request_id}/decline", status_code=status.HTTP_200_OK)
@handle_supabase_errors
async def decline_join_request(
    group_id: str,
    request_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    """(방장 전용) 참가 신청 거절."""
    get_group_or_404(supabase, group_id)
    assert_group_admin(supabase, group_id, current_user["id"])

    result = (
        supabase.table("group_join_requests")
        .update({"status": "declined"})
        .eq("id", request_id)
        .eq("study_group_id", group_id)
        .eq("status", "pending")
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pending join request not found",
        )

    return {"message": "Join request declined"}


@router.delete("/{group_id}/members/{user_id}", status_code=status.HTTP_200_OK)
@handle_supabase_errors
async def kick_member(
    group_id: str,
    user_id: str,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    """(방장 전용) 멤버 강퇴 — 스터디 그룹 + 채팅방에서 모두 제거."""
    get_group_or_404(supabase, group_id)
    assert_group_admin(supabase, group_id, current_user["id"])

    if user_id == current_user["id"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Admin cannot kick themselves",
        )

    target = (
        supabase.table("user_study_groups")
        .select("role")
        .eq("study_group_id", group_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not target.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found in this study group",
        )
    if target.data[0]["role"] == "admin":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot kick another admin",
        )

    # 스터디 그룹에서 제거
    supabase.table("user_study_groups").delete().eq(
        "study_group_id", group_id
    ).eq("user_id", user_id).execute()

    # 연결된 채팅방에서도 제거
    room_result = (
        supabase.table("chat_rooms")
        .select("id")
        .eq("group_id", group_id)
        .execute()
    )
    if room_result.data:
        room_id = room_result.data[0]["id"]
        supabase.table("room_members").delete().eq(
            "room_id", room_id
        ).eq("user_id", user_id).execute()

    return {"message": "Member has been removed from the group and chat room"}
