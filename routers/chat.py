from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from database import get_db
from models import Conversation
from schemas import ConversationCreate, ConversationResponse
from crypto import encrypt, decrypt
from typing import List
import httpx
import os
from dotenv import load_dotenv

load_dotenv()

router = APIRouter()

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
# gemini-2.0-flash 는 서비스 종료됨 → 빠른 flash-lite 사용 (.env 의 GEMINI_CLASSIFY_MODEL 로 변경 가능)
GEMINI_MODEL = os.environ.get("GEMINI_CLASSIFY_MODEL", "gemini-3.5-flash-lite")
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"


async def classify_chat(content: str) -> str:
    """Gemini로 대화 내용 분류"""
    prompt = f"""다음 대화 내용을 아래 4가지 중 하나로만 분류해줘. 반드시 딱 한 단어만 답해줘.

분류 기준:
- 복약: 약, 복약, 복용, 약 먹기 관련
- 일정: 일정, 예약, 병원, 약속, 방문 관련
- 긴급: 응급, 위험, 사고, 쓰러짐, 도움 요청 관련
- 생활정보: 날씨, 뉴스, 음악, 일상 대화 등 나머지

대화 내용: "{content}"

분류 결과 (복약/일정/긴급/생활정보 중 하나만):"""

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            res = await client.post(
                GEMINI_URL,
                json={"contents": [{"parts": [{"text": prompt}]}]}
            )
            if res.status_code == 200:
                text = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                for category in ["복약", "일정", "긴급", "생활정보"]:
                    if category in text:
                        return category
    except Exception as e:
        print(f"Gemini 분류 오류: {e}")

    # 실패하면 키워드 폴백
    if any(k in content for k in ["약", "복약", "복용", "먹을"]):
        return "복약"
    elif any(k in content for k in ["일정", "예약", "병원", "약속"]):
        return "일정"
    elif any(k in content for k in ["살려", "긴급", "응급", "쓰러"]):
        return "긴급"
    return "생활정보"


# 대화 저장 (암호화 + Gemini 분류)
@router.post("/", response_model=ConversationResponse)
async def create_conversation(data: ConversationCreate, db: AsyncSession = Depends(get_db)):
    chat_type = "생활정보"
    if data.role == "user":
        chat_type = await classify_chat(data.content)

    conversation = Conversation(
        session_id=data.session_id,
        role=data.role,
        content=encrypt(data.content),
        type=chat_type,
    )
    db.add(conversation)
    await db.commit()
    await db.refresh(conversation)

    conversation.content = decrypt(conversation.content)
    return conversation


# 대화 전체 조회 (페이지네이션 + 복호화)
@router.get("/", response_model=dict)
async def get_conversations(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=500),
    db: AsyncSession = Depends(get_db)
):
    offset = (page - 1) * size

    count_result = await db.execute(select(func.count(Conversation.id)))
    total = count_result.scalar()

    result = await db.execute(
        select(Conversation)
        .order_by(Conversation.created_at.desc())
        .offset(offset)
        .limit(size)
    )
    items = result.scalars().all()

    # items를 그대로 넣으면 500 에러가 나서 dict로 바꿔서 반환
    return {
        "total": total,
        "page": page,
        "size": size,
        "total_pages": (total + size - 1) // size,
        "items": [
            {
                "id": item.id,
                "session_id": item.session_id,
                "role": item.role,
                "content": decrypt(item.content),
                "type": item.type,
                "created_at": item.created_at.isoformat() if item.created_at else None
            }
            for item in items
        ]
    }


# 세션별 대화 조회 (복호화)
@router.get("/{session_id}", response_model=List[ConversationResponse])
async def get_conversation_by_session(session_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Conversation)
        .where(Conversation.session_id == session_id)
        .order_by(Conversation.created_at)
    )
    items = result.scalars().all()

    for item in items:
        item.content = decrypt(item.content)

    return items


# 멀티턴용 - 세션별 최근 대화 N개 조회 (복호화)
@router.get("/context/{session_id}")
async def get_conversation_context(
    session_id: str,
    limit: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Conversation)
        .where(Conversation.session_id == session_id)
        .order_by(Conversation.created_at.desc())
        .limit(limit)
    )
    items = result.scalars().all()
    items.reverse()

    return {
        "session_id": session_id,
        "context": [
            {"role": item.role, "content": decrypt(item.content)}
            for item in items
        ]
    }