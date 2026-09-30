from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from database import get_db
from models import Conversation, Medicine, Schedule, Alert

router = APIRouter()

# 전체 시스템 현황 조회
@router.get("/status")
async def get_system_status(db: AsyncSession = Depends(get_db)):
    # 대화 수
    conv_count = await db.execute(select(func.count(Conversation.id)))
    # 복약 수
    med_count = await db.execute(select(func.count(Medicine.id)))
    # 일정 수
    sched_count = await db.execute(select(func.count(Schedule.id)))
    # 미해결 알림 수
    alert_count = await db.execute(
        select(func.count(Alert.id)).where(Alert.is_resolved == False)
    )

    return {
        "total_conversations": conv_count.scalar(),
        "total_medicines": med_count.scalar(),
        "total_schedules": sched_count.scalar(),
        "unresolved_alerts": alert_count.scalar(),
    }

# 전체 알림 현황
@router.get("/alerts")
async def get_all_alerts(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Alert).order_by(Alert.created_at.desc()).limit(50)
    )
    return result.scalars().all()

# 기기 상태 등록 (라즈베리파이에서 주기적으로 호출)
devices = {}

@router.post("/device/heartbeat")
async def device_heartbeat(device_id: str, status: str = "online"):
    from datetime import datetime
    devices[device_id] = {
        "device_id": device_id,
        "status": status,
        "last_seen": datetime.now().isoformat()
    }
    return {"message": f"{device_id} 상태 업데이트 완료"}

# 연결된 기기 목록 조회
@router.get("/devices")
async def get_devices():
    return {"devices": list(devices.values())}