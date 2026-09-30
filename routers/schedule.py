from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from database import get_db
from models import Schedule
from schemas import ScheduleCreate, ScheduleResponse
from typing import List

router = APIRouter()

# 일정 추가
@router.post("/", response_model=ScheduleResponse)
async def create_schedule(data: ScheduleCreate, db: AsyncSession = Depends(get_db)):
    schedule = Schedule(**data.model_dump())
    db.add(schedule)
    await db.commit()
    await db.refresh(schedule)
    return schedule

# 일정 전체 조회
@router.get("/", response_model=List[ScheduleResponse])
async def get_schedules(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Schedule))
    return result.scalars().all()

# 일정 완료 처리
@router.patch("/{schedule_id}/complete")
async def complete_schedule(schedule_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Schedule).where(Schedule.id == schedule_id))
    schedule = result.scalar_one_or_none()
    if schedule:
        schedule.is_completed = True
        await db.commit()
    return {"message": "완료 처리됨"}

# 일정 삭제
@router.delete("/{schedule_id}")
async def delete_schedule(schedule_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Schedule).where(Schedule.id == schedule_id))
    schedule = result.scalar_one_or_none()
    if schedule:
        await db.delete(schedule)
        await db.commit()
    return {"message": "삭제 완료"}

# 일정 완료 취소
@router.patch("/{schedule_id}/uncomplete")
async def uncomplete_schedule(schedule_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Schedule).where(Schedule.id == schedule_id))
    schedule = result.scalar_one_or_none()
    if schedule:
        schedule.is_completed = False
        await db.commit()
    return {"message": "완료 취소됨"}