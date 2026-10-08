from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

import elder_engine
from database import get_db

router = APIRouter()


class TalkRequest(BaseModel):
    text: str                      # 음성 인식 결과 (어르신이 한 말)
    session_id: str = "default"
    senior_id: int = 4             # 기본: 시연용 어르신 계정 (senior1)
    require_wake: bool = True      # True: 이름을 불렀을 때만 대답 (기기). False: 항상 대답 (테스트용)


class WakeNameUpdate(BaseModel):
    name: str


# 어르신 발화 → 노인 맞춤 대답 (대화 저장까지 포함)
@router.post("/")
async def talk(req: TalkRequest, db: AsyncSession = Depends(get_db)):
    return await elder_engine.reply(db, req.text, req.session_id, req.senior_id, req.require_wake)


# 현재 LLM 설정 확인용
@router.get("/config")
async def talk_config():
    return {
        "llm_order": elder_engine.LLM_ORDER,
        "local": {"url": elder_engine.LOCAL_LLM_URL, "model": elder_engine.LOCAL_LLM_MODEL},
        "cloud": {"url": elder_engine.CLOUD_LLM_URL, "model": elder_engine.CLOUD_LLM_MODEL,
                  "key_set": bool(elder_engine.CLOUD_LLM_KEY)},
    }


# 챗봇 이름 (부르는 이름) 조회 / 변경 — 앱 설정 화면에서 사용
@router.get("/wake-name")
async def get_wake_name(db: AsyncSession = Depends(get_db)):
    return {"name": await elder_engine.get_wake_name(db)}


@router.put("/wake-name")
async def put_wake_name(body: WakeNameUpdate, db: AsyncSession = Depends(get_db)):
    try:
        return {"name": await elder_engine.set_wake_name(db, body.name)}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# 처음 설정 다시 하기: 이름을 지우면 기기가 다음 대화에서 어르신께 이름을 다시 여쭤본다
@router.delete("/wake-name")
async def delete_wake_name(db: AsyncSession = Depends(get_db)):
    await elder_engine.reset_wake_name(db)
    return {"message": "이름을 지웠어요. 다음에 말을 걸면 이름을 다시 여쭤봐요."}


# 먼저 말 걸기: 기기가 30초마다 호출 → say 가 있으면 말한다
#   force=med|morning|checkin : 시연용으로 시간 조건 없이 바로 실행
@router.get("/proactive")
async def get_proactive(session_id: str = "oasis-device-1", senior_id: int = 4,
                        force: str | None = None, db: AsyncSession = Depends(get_db)):
    return await elder_engine.proactive(db, session_id, senior_id, force)


# 보호자 일일 요약 (앱 홈 화면)
@router.get("/summary")
async def get_summary(senior_id: int = 4, date: str | None = None, db: AsyncSession = Depends(get_db)):
    return await elder_engine.daily_summary(db, senior_id, date)


# 장기기억 목록 / 지우기 (보호자 확인용)
@router.get("/memories")
async def get_memories(senior_id: int = 4, db: AsyncSession = Depends(get_db)):
    return {"memories": await elder_engine.load_memories(db, senior_id)}


@router.delete("/memories")
async def delete_memories(senior_id: int = 4, db: AsyncSession = Depends(get_db)):
    await elder_engine.save_memories(db, senior_id, [])
    return {"message": "기억을 모두 지웠어요."}
