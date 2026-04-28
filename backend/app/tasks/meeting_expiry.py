import logging
from datetime import datetime, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.database import get_supabase_admin
from app.services.meeting_service import confirm_proposal, get_room_or_404

logger = logging.getLogger(__name__)
scheduler = AsyncIOScheduler()


async def check_expired_proposals() -> None:
    # 모듈 레벨 import 시 순환 참조 방지를 위해 지연 import
    from app.routers.chat import manager

    supabase = get_supabase_admin()  # RLS bypass 필요
    now_iso = datetime.now(timezone.utc).isoformat()

    result = (
        supabase.table("meeting_proposals")
        .select("*")
        .lt("expires_at", now_iso)
        .eq("is_confirmed", False)
        .execute()
    )
    expired = result.data or []
    if not expired:
        return

    # room_id 기준으로 그룹핑
    rooms: dict[str, list] = {}
    for p in expired:
        rooms.setdefault(p["room_id"], []).append(p)

    for room_id, proposals in rooms.items():
        try:
            room = get_room_or_404(supabase, room_id)
        except Exception:
            continue

        # attend 투표가 가장 많은 proposal 선택
        best_proposal = None
        best_count = -1
        for proposal in proposals:
            votes_result = (
                supabase.table("meeting_votes")
                .select("vote")
                .eq("proposal_id", proposal["id"])
                .eq("vote", True)
                .execute()
            )
            attend_count = len(votes_result.data or [])
            if attend_count > best_count:
                best_count = attend_count
                best_proposal = proposal

        if best_proposal:
            try:
                await confirm_proposal(supabase, best_proposal, room, "auto", manager)
                logger.info(
                    "Auto-confirmed proposal %s for room %s",
                    best_proposal["id"],
                    room_id,
                )
            except Exception as e:
                logger.error(
                    "Failed to confirm proposal %s: %s",
                    best_proposal["id"],
                    e,
                )


def start_scheduler() -> None:
    scheduler.add_job(
        check_expired_proposals,
        "interval",
        minutes=5,
        id="meeting_expiry",
    )
    scheduler.start()
    logger.info("Meeting expiry scheduler started")


def stop_scheduler() -> None:
    scheduler.shutdown()
    logger.info("Meeting expiry scheduler stopped")
