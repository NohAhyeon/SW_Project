from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy import select
from database import AsyncSessionLocal
from models import Medicine, Schedule, Alert
from datetime import datetime

scheduler = AsyncIOScheduler()

async def check_medicine_alarms():
    now = datetime.now().strftime("%H:%M")
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Medicine))
        medicines = result.scalars().all()
        for medicine in medicines:
            alarm_times = medicine.alarm_times.split(",")
            if now in alarm_times:
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
            schedule_time = schedule.datetime
            if len(schedule_time) >= 5:
                schedule_time = schedule_time[-5:]
            if now == schedule_time:
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