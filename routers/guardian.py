from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from datetime import date
from database import get_db
from models import GuardianRelation, User, Medicine, Alert
from schemas import GuardianRelationCreate, GuardianRelationResponse, SeniorStatusCard

router = APIRouter()


# ── 어르신 연결 등록 ─────────────────────────────────────────────
# POST /guardian/connect
# 보호자(guardian_id)가 어르신(senior_id)과 연결
@router.post("/connect", response_model=GuardianRelationResponse)
async def connect_senior(
    guardian_id: int,
    req: GuardianRelationCreate,
    db: AsyncSession = Depends(get_db),
):
    # 중복 연결 방지
    dup = await db.execute(
        select(GuardianRelation).where(
            and_(
                GuardianRelation.guardian_id == guardian_id,
                GuardianRelation.senior_id == req.senior_id,
            )
        )
    )
    if dup.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="이미 연결된 어르신입니다")

    # 대상이 senior 역할인지 확인
    senior = await db.execute(select(User).where(User.id == req.senior_id))
    senior = senior.scalar_one_or_none()
    if not senior or senior.role != "senior":
        raise HTTPException(status_code=404, detail="어르신 계정을 찾을 수 없습니다")

    relation = GuardianRelation(
        guardian_id=guardian_id,
        senior_id=req.senior_id,
        label=req.label,
    )
    db.add(relation)
    await db.commit()
    await db.refresh(relation)
    return relation


# ── 연결 해제 ────────────────────────────────────────────────────
# DELETE /guardian/connect/{relation_id}
@router.delete("/connect/{relation_id}")
async def disconnect_senior(
    relation_id: int,
    guardian_id: int,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(GuardianRelation).where(
            and_(
                GuardianRelation.id == relation_id,
                GuardianRelation.guardian_id == guardian_id,
            )
        )
    )
    relation = result.scalar_one_or_none()
    if not relation:
        raise HTTPException(status_code=404, detail="연결 정보를 찾을 수 없습니다")

    await db.delete(relation)
    await db.commit()
    return {"message": "연결 해제 완료"}


# ── 보호자의 어르신 목록 + 현황 요약 ────────────────────────────
# GET /guardian/seniors?guardian_id=1
# 보호자 대시보드 오버뷰용 — 어르신별 복약/알림 현황을 한 번에 반환
@router.get("/seniors", response_model=list[SeniorStatusCard])
async def get_seniors_overview(
    guardian_id: int,
    db: AsyncSession = Depends(get_db),
):
    # 연결된 어르신 목록 조회
    relations_result = await db.execute(
        select(GuardianRelation).where(GuardianRelation.guardian_id == guardian_id)
    )
    relations = relations_result.scalars().all()

    if not relations:
        return []

    today_str = date.today().isoformat()
    cards = []

    for rel in relations:
        senior_result = await db.execute(select(User).where(User.id == rel.senior_id))
        senior = senior_result.scalar_one_or_none()
        if not senior:
            continue

        # 오늘 복약 현황
        med_result = await db.execute(
            select(Medicine).where(
                and_(
                    Medicine.senior_id == rel.senior_id,
                    Medicine.start_date <= today_str,
                    Medicine.end_date >= today_str,
                )
            )
        )
        meds = med_result.scalars().all()
        med_total = len(meds)
        med_done = sum(1 for m in meds if m.taken)

        # 미해결 알림
        alert_result = await db.execute(
            select(Alert).where(
                and_(
                    Alert.senior_id == rel.senior_id,
                    Alert.is_resolved == False,
                )
            )
        )
        unresolved = alert_result.scalars().all()
        unresolved_count = len(unresolved)
        latest_alert_type = unresolved[0].type if unresolved else None

        # 종합 상태 판정
        if unresolved_count >= 1 and latest_alert_type in ("가스", "낙상", "재난"):
            status = "danger"
        elif unresolved_count >= 1:
            status = "warning"
        else:
            status = "ok"

        cards.append(
            SeniorStatusCard(
                senior_id=senior.id,
                nickname=senior.nickname or senior.username,
                label=rel.label,
                role=senior.role,
                is_active=senior.is_active,
                med_total=med_total,
                med_done=med_done,
                unresolved_alerts=unresolved_count,
                latest_alert_type=latest_alert_type,
                status=status,
            )
        )

    return cards
