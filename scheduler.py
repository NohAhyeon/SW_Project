from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy import select
from database import AsyncSessionLocal
from models import Medicine, Schedule, Alert
from datetime import datetime


def _hhmm(t: str) -> str:
    """'9:00', ' 09:00', '2026-10-08 9:00' → '09:00' 으로 통일"""
    t = (t or "").strip().split(" ")[-1]
    try:
        h, m = t.split(":")[:2]
        return f"{int(h):02d}:{int(m):02d}"
    except ValueError:
        return t

scheduler = AsyncIOScheduler()

async def check_medicine_alarms():
    now = datetime.now().strftime("%H:%M")
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Medicine))
        medicines = result.scalars().all()
        for medicine in medicines:
            # "9:00", "2026-10-08 08:30" 처럼 형식이 달라도 시간만 맞춰서 비교
            alarm_times_only = [_hhmm(t) for t in (medicine.alarm_times or "").split(",")]
            if now in alarm_times_only:
                alert = Alert(
                    type="복약알림",
                    message=f"{medicine.name} 드실 시간이에요! ({medicine.dose})",
                    is_resolved=False
                )
                db.add(alert)
        await db.commit()

async def check_schedule_alarms():
    now = datetime.now().strftime("%H:%M")
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(Schedule).where(Schedule.is_completed == False)
        )
        schedules = result.scalars().all()
        for schedule in schedules:
            if now == _hhmm(schedule.datetime):
                alert = Alert(
                    type="일정알림",
                    message=f"📅 {schedule.title} 시간이에요!",
                    is_resolved=False
                )
                db.add(alert)
        await db.commit()

def start_scheduler():
    scheduler.add_job(
        check_medicine_alarms,
        CronTrigger(minute="*"),
        id="medicine_alarm",
        replace_existing=True
    )
    scheduler.add_job(
        check_schedule_alarms,
        CronTrigger(minute="*"),
        id="schedule_alarm",
        replace_existing=True
    )
    scheduler.start()