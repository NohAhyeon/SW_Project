from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
from database import get_db
from models import User
from schemas import UserCreate, UserUpdate, UserResponse, Token
import httpx

router = APIRouter()

SECRET_KEY = "노인케어챗봇시크릿키2026"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24시간

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")


def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def verify_password(plain, hashed):
    return pwd_context.verify(plain, hashed)


def hash_password(password: str):
    return pwd_context.hash(password)


# ===== 일반 로그인 =====
@router.post("/token", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == form_data.username))
    user = result.scalar_one_or_none()

    if not user or not user.hashed_password or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="비활성화된 계정입니다")

    token = create_access_token({"sub": user.username, "role": user.role})
    return {"access_token": token, "token_type": "bearer"}


# ===== 회원가입 =====
@router.post("/register", response_model=UserResponse)
async def register(req: UserCreate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == req.username))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="이미 존재하는 아이디입니다")

    user = User(
        username=req.username,
        hashed_password=hash_password(req.password),
        role=req.role,
        nickname=req.nickname,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


# ===== 유저 목록 조회 (관리자용) =====
@router.get("/users", response_model=list[UserResponse])
async def get_users(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).order_by(User.created_at.desc()))
    return result.scalars().all()


# ===== 유저 수정 (관리자용) =====
@router.patch("/users/{user_id}", response_model=UserResponse)
async def update_user(user_id: int, req: UserUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="유저를 찾을 수 없습니다")

    if req.role is not None:
        user.role = req.role
    if req.nickname is not None:
        user.nickname = req.nickname
    if req.is_active is not None:
        user.is_active = req.is_active

    await db.commit()
    await db.refresh(user)
    return user


# ===== 유저 삭제 (관리자용) =====
@router.delete("/users/{user_id}")
async def delete_user(user_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="유저를 찾을 수 없습니다")

    await db.delete(user)
    await db.commit()
    return {"message": "삭제 완료"}


# ===== 카카오 소셜 로그인 =====
@router.post("/kakao", response_model=Token)
async def kakao_login(access_token: str, db: AsyncSession = Depends(get_db)):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://kapi.kakao.com/v2/user/me",
            headers={"Authorization": f"Bearer {access_token}"}
        )
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="카카오 인증 실패")

    kakao_user = response.json()
    social_id = str(kakao_user["id"])
    nickname = kakao_user.get("properties", {}).get("nickname", "카카오유저")

    result = await db.execute(select(User).where(User.social_provider == "kakao", User.social_id == social_id))
    user = result.scalar_one_or_none()

    if not user:
        user = User(username=f"kakao_{social_id}", social_provider="kakao", social_id=social_id, nickname=nickname, role="user")
        db.add(user)
        await db.commit()
        await db.refresh(user)

    token = create_access_token({"sub": user.username, "role": user.role})
    return {"access_token": token, "token_type": "bearer"}


# ===== 구글 소셜 로그인 =====
@router.post("/google", response_model=Token)
async def google_login(access_token: str, db: AsyncSession = Depends(get_db)):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://www.googleapis.com/oauth2/v3/userinfo",
            headers={"Authorization": f"Bearer {access_token}"}
        )
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="구글 인증 실패")

    google_user = response.json()
    social_id = google_user["sub"]
    nickname = google_user.get("name", "구글유저")

    result = await db.execute(select(User).where(User.social_provider == "google", User.social_id == social_id))
    user = result.scalar_one_or_none()

    if not user:
        user = User(username=f"google_{social_id}", social_provider="google", social_id=social_id, nickname=nickname, role="user")
        db.add(user)
        await db.commit()
        await db.refresh(user)

    token = create_access_token({"sub": user.username, "role": user.role})
    return {"access_token": token, "token_type": "bearer"}


# ===== 내 정보 조회 =====
@router.get("/me", response_model=UserResponse)
async def get_me(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=401, detail="토큰이 유효하지 않습니다")

    result = await db.execute(select(User).where(User.username == username))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="유저를 찾을 수 없습니다")
    return user