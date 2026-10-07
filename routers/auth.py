import os
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
import httpx

load_dotenv()

router = APIRouter()

SECRET_KEY = os.getenv("SECRET_KEY", "노인케어챗봇시크릿키2026")
KAKAO_CLIENT_ID = os.getenv("KAKAO_CLIENT_ID", "")
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")

ADMIN_USERS = {
    "admin": {
        "username": "admin",
        "hashed_password": pwd_context.hash("1234"),
        "role": "admin"
    }
}

class Token(BaseModel):
    access_token: str
    token_type: str

class SocialLoginRequest(BaseModel):
    access_token: str

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password[:72], hashed_password)

@router.post("/token", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    user = ADMIN_USERS.get(form_data.username)
    if not user or not verify_password(form_data.password, user["hashed_password"]):
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다")
    access_token = create_access_token({"sub": user["username"], "role": user["role"]})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/kakao", response_model=Token)
async def kakao_login(request: SocialLoginRequest):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://kapi.kakao.com/v2/user/me",
            headers={"Authorization": f"Bearer {request.access_token}"}
        )
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="카카오 인증 실패")
    kakao_user = response.json()
    user_id = str(kakao_user["id"])
    nickname = kakao_user.get("properties", {}).get("nickname", "사용자")
    access_token = create_access_token({"sub": f"kakao_{user_id}", "nickname": nickname, "role": "user"})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/google", response_model=Token)
async def google_login(request: SocialLoginRequest):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://www.googleapis.com/oauth2/v3/userinfo",
            headers={"Authorization": f"Bearer {request.access_token}"}
        )
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="구글 인증 실패")
    google_user = response.json()
    user_id = google_user["sub"]
    nickname = google_user.get("name", "사용자")
    access_token = create_access_token({"sub": f"google_{user_id}", "nickname": nickname, "role": "user"})
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me")
async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="토큰이 유효하지 않습니다")
        return {"username": username, "role": payload.get("role")}
    except JWTError:
        raise HTTPException(status_code=401, detail="토큰이 유효하지 않습니다")

class RegisterRequest(BaseModel):
    username: str
    password: str
    role: str = "admin"
    nickname: str = "관리자"

@router.post("/register")
async def register(data: RegisterRequest):
    if data.username in ADMIN_USERS:
        raise HTTPException(status_code=400, detail="이미 존재하는 아이디입니다")
    ADMIN_USERS[data.username] = {
        "username": data.username,
        "hashed_password": pwd_context.hash(data.password),
        "role": data.role,
        "nickname": data.nickname
    }
    return {"message": "회원가입 완료", "username": data.username}

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
@router.post("/google/login", response_model=Token)
async def google_login_only(request: SocialLoginRequest):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://www.googleapis.com/oauth2/v3/userinfo",
            headers={"Authorization": f"Bearer {request.access_token}"}
        )
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="구글 인증 실패")
    google_user = response.json()
    user_id = google_user["sub"]
    nickname = google_user.get("name", "사용자")
    if f"google_{user_id}" not in [u.get("sub", "") for u in ADMIN_USERS.values()]:
        raise HTTPException(status_code=404, detail="계정을 찾을 수 없습니다")
    access_token = create_access_token({"sub": f"google_{user_id}", "nickname": nickname, "role": "user"})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/google/signup", response_model=Token)
async def google_signup(request: SocialLoginRequest):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://www.googleapis.com/oauth2/v3/userinfo",
            headers={"Authorization": f"Bearer {request.access_token}"}
        )
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="구글 인증 실패")
    google_user = response.json()
    user_id = google_user["sub"]
    nickname = google_user.get("name", "사용자")
    if f"google_{user_id}" in ADMIN_USERS:
        raise HTTPException(status_code=409, detail="이미 가입된 계정입니다")
    ADMIN_USERS[f"google_{user_id}"] = {
        "username": f"google_{user_id}",
        "hashed_password": "",
        "role": "user",
        "nickname": nickname
    }
    access_token = create_access_token({"sub": f"google_{user_id}", "nickname": nickname, "role": "user"})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/kakao/login", response_model=Token)
async def kakao_login_only(request: SocialLoginRequest):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://kapi.kakao.com/v2/user/me",
            headers={"Authorization": f"Bearer {request.access_token}"}
        )
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="카카오 인증 실패")
    kakao_user = response.json()
    user_id = str(kakao_user["id"])
    nickname = kakao_user.get("properties", {}).get("nickname", "사용자")
    if f"kakao_{user_id}" not in ADMIN_USERS:
        raise HTTPException(status_code=404, detail="계정을 찾을 수 없습니다")
    access_token = create_access_token({"sub": f"kakao_{user_id}", "nickname": nickname, "role": "user"})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/kakao/signup", response_model=Token)
async def kakao_signup(request: SocialLoginRequest):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://kapi.kakao.com/v2/user/me",
            headers={"Authorization": f"Bearer {request.access_token}"}
        )
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="카카오 인증 실패")
    kakao_user = response.json()
    user_id = str(kakao_user["id"])
    nickname = kakao_user.get("properties", {}).get("nickname", "사용자")
    if f"kakao_{user_id}" in ADMIN_USERS:
        raise HTTPException(status_code=409, detail="이미 가입된 계정입니다")
    ADMIN_USERS[f"kakao_{user_id}"] = {
        "username": f"kakao_{user_id}",
        "hashed_password": "",
        "role": "user",
        "nickname": nickname
    }
    access_token = create_access_token({"sub": f"kakao_{user_id}", "nickname": nickname, "role": "user"})
    return {"access_token": access_token, "token_type": "bearer"}