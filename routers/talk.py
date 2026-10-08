from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

import elder_engine
from database import get_db

router = APIRouter()


class TalkRequest(BaseModel):
    text: str                      # 음성 인식 결과 (어르신이 한 말)
    session_id: str = "default"
    senior_id: int = 4             # 기본: 시연용 어르신 계정 (senior1)


# 어르신 발화 → 노인 맞춤 대답 (대화 저장까지 포함)
@router.post("/")
async def talk(req: TalkRequest, db: AsyncSession = Depends(get_db)):
    return await elder_engine.reply(db, req.text, req.session_id, req.senior_id)


# 현재 LLM 설정 확인용
@router.get("/config")
async def talk_config():
    return {
        "llm_order": elder_engine.LLM_ORDER,
        "local": {"url": elder_engine.LOCAL_LLM_URL, "model": elder_engine.LOCAL_LLM_MODEL},
        "cloud": {"url": elder_engine.CLOUD_LLM_URL, "model": elder_engine.CLOUD_LLM_MODEL,
                  "key_set": bool(elder_engine.CLOUD_LLM_KEY)},
    }
