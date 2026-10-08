from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from database import get_db
from models import Medicine
from schemas import MedicineCreate, MedicineResponse
from pydantic import BaseModel
from typing import List, Optional

class MedicineUpdate(BaseModel):
    name: Optional[str] = None
    schedule_time: Optional[str] = None

router = APIRouter()

# 복약 추가
@router.post("/", response_model=MedicineResponse)
async def create_medicine(data: MedicineCreate, db: AsyncSession = Depends(get_db)):
    medicine = Medicine(**data.model_dump())
    db.add(medicine)
    await db.commit()
    await db.refresh(medicine)
    return medicine

# 복약 전체 조회
@router.get("/", response_model=List[MedicineResponse])
async def get_medicines(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Medicine))
    return result.scalars().all()

# 복약 삭제
@router.delete("/{medicine_id}")
async def delete_medicine(medicine_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Medicine).where(Medicine.id == medicine_id))
    medicine = result.scalar_one_or_none()
    if medicine:
        await db.delete(medicine)
        await db.commit()
    return {"message": "삭제 완료"}

# 복약 수정
@router.put("/{medicine_id}", response_model=MedicineResponse)
async def update_medicine(medicine_id: int, data: MedicineUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Medicine).where(Medicine.id == medicine_id))
    medicine = result.scalar_one_or_none()
    if medicine:
        if data.name is not None: medicine.name = data.name
        if data.schedule_time is not None: medicine.schedule_time = data.schedule_time
        await db.commit()
        await db.refresh(medicine)
    return medicine

# 복약 완료 처리
@router.patch("/{medicine_id}/take")
async def take_medicine(medicine_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Medicine).where(Medicine.id == medicine_id))
    medicine = result.scalar_one_or_none()
    if medicine:
        medicine.taken = True
        await db.commit()
    return {"message": "복약 완료"}

# 복약 취소 (완료 → 미완료)
@router.patch("/{medicine_id}/untake")
async def untake_medicine(medicine_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Medicine).where(Medicine.id == medicine_id))
    medicine = result.scalar_one_or_none()
    if medicine:
        medicine.taken = False
        await db.commit()
    return {"message": "복약 취소"}