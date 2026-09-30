from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

# 대화 로그
class ConversationCreate(BaseModel):
    session_id: str
    role: str
    content: str
    type: Optional[str] = "생활정보"

class ConversationResponse(ConversationCreate):
    id: int
    created_at: datetime
    type: Optional[str] = "생활정보"

    class Config:
        from_attributes = True

# 복약 정보
class MedicineCreate(BaseModel):
    name: str
    dose: str
    alarm_times: str
    start_date: str
    end_date: str

class MedicineResponse(MedicineCreate):
    id: int
    taken: bool = False

    class Config:
        from_attributes = True

# 일정
class ScheduleCreate(BaseModel):
    title: str
    datetime: str
    memo: Optional[str] = None

class ScheduleResponse(ScheduleCreate):
    id: int
    is_completed: bool

    class Config:
        from_attributes = True

# 위급 알림
class AlertCreate(BaseModel):
    type: str
    message: str

class AlertResponse(AlertCreate):
    id: int
    is_resolved: bool
    created_at: datetime

    class Config:
        from_attributes = True

# 유저
class UserCreate(BaseModel):
    username: str
    password: str
    role: Optional[str] = "user"
    nickname: Optional[str] = None

class UserUpdate(BaseModel):
    role: Optional[str] = None
    nickname: Optional[str] = None
    is_active: Optional[bool] = None

class UserResponse(BaseModel):
    id: int
    username: str
    role: str
    nickname: Optional[str]
    social_provider: Optional[str]
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class LoginRequest(BaseModel):
    username: str
    password: str


# ── 보호자-어르신 연결 ──────────────────────────────────────────
class GuardianRelationCreate(BaseModel):
    senior_id: int
    label: Optional[str] = None          # 예: "어머니", "할머니"

class GuardianRelationResponse(BaseModel):
    id: int
    guardian_id: int
    senior_id: int
    label: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


# ── 보호자 대시보드용 어르신 요약 카드 ──────────────────────────
class SeniorStatusCard(BaseModel):
    senior_id: int
    nickname: str                         # 어르신 이름/별명
    label: Optional[str]                  # 보호자가 붙인 라벨 (어머니 등)
    role: str
    is_active: bool

    # 복약 현황
    med_total: int                        # 오늘 총 복약 수
    med_done: int                         # 완료된 복약 수

    # 알림 현황
    unresolved_alerts: int                # 미해결 알림 수
    latest_alert_type: Optional[str]      # 가장 최근 알림 유형

    # 종합 상태
    status: str                           # "ok" | "warning" | "danger"

    class Config:
        from_attributes = True


# ── senior_id 포함 버전 (멀티 어르신 환경) ───────────────────────
class MedicineCreateV2(MedicineCreate):
    senior_id: int

class MedicineResponseV2(MedicineResponse):
    senior_id: Optional[int]

class ScheduleCreateV2(ScheduleCreate):
    senior_id: int

class ScheduleResponseV2(ScheduleResponse):
    senior_id: Optional[int]

class AlertCreateV2(AlertCreate):
    senior_id: int

class AlertResponseV2(AlertResponse):
    senior_id: Optional[int]
