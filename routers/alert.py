from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from database import get_db
from models import Alert
from schemas import AlertCreate, AlertResponse
from typing import List

router = APIRouter()

# 알림 추가
@router.post("/", response_model=AlertResponse)
async def create_alert(data: AlertCreate, db: AsyncSession = Depends(get_db)):
    alert = Alert(**data.model_dump())
    db.add(alert)
    await db.commit()
    await db.refresh(alert)

    # 위급 알림이면 자동으로 보호자 연락 알림 추가
    if data.type == "위급":
        guardian_alert = Alert(
            type="보호자연락",
            message=f"🚨 위급상황 발생! 보호자에게 연락이 필요합니다. ({data.message})",
            is_resolved=False
        )
        db.add(guardian_alert)
        await db.commit()

    return alert

# 알림 전체 조회
@router.get("/", response_model=List[AlertResponse])
async def get_alerts(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Alert).order_by(Alert.created_at.desc())
    )
    return result.scalars().all()

# 미해결 알림만 조회
@router.get("/unresolved", response_model=List[AlertResponse])
async def get_unresolved_alerts(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Alert)
        .where(Alert.is_resolved == False)
        .order_by(Alert.created_at.desc())
    )
    return result.scalars().all()

# 알림 해결 처리
@router.patch("/{alert_id}/resolve")
async def resolve_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert = result.scalar_one_or_none()
    if alert:
        alert.is_resolved = True
        await db.commit()
    return {"message": "알림 해결 처리됨"}

# 위급 알림 발생
@router.post("/emergency")
async def create_emergency(message: str, db: AsyncSession = Depends(get_db)):
    # 위급 알림 저장
    emergency = Alert(
        type="위급",
        message=f"🚨 {message}",
        is_resolved=False
    )
    db.add(emergency)

    # 보호자 연락 알림 자동 생성
    guardian = Alert(
        type="보호자연락",
        message=f"🚨 위급상황 발생! 보호자에게 연락이 필요합니다. ({message})",
        is_resolved=False
    )
    db.add(guardian)
    await db.commit()

    return {"message": "위급 알림이 발생했습니다. 보호자에게 연락 알림이 전송됐습니다."}