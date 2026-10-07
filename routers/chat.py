from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from database import get_db
from models import Conversation
from schemas import ConversationCreate, ConversationResponse
from crypto import encrypt, decrypt
from typing import List

router = APIRouter()

# 대화 저장 (암호화)
@router.post("/", response_model=ConversationResponse)
async def create_conversation(data: ConversationCreate, db: AsyncSession = Depends(get_db)):
    conversation = Conversation(
        session_id=data.session_id,
        role=data.role,
        content=encrypt(data.content)  # 암호화해서 저장
    )
    db.add(conversation)
    await db.commit()
    await db.refresh(conversation)

    # 응답할 때는 복호화해서 반환
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
                "created_at": item.created_at.isoformat() if item.created_at else None
            }
            for item in items
        ]
    }

    # 복호화해서 반환
    for item in items:
        item.content = decrypt(item.content)

    return {
        "total": total,
        "page": page,
        "size": size,
        "total_pages": (total + size - 1) // size,
        "items": items
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