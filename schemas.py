from pydantic import BaseModel
from typing import Optional
from datetime import datetime

# 대화 로그
class ConversationCreate(BaseModel):
    session_id: str
    role: str
    content: str

class ConversationResponse(ConversationCreate):
    id: int
    created_at: datetime  # str → datetime 으로 변경

    class Config:
        from_attributes = True

# 복약 정보
class MedicineCreate(BaseModel):
    name: str
    dose: str
    alarm_times: str  # 예: "08:30,13:00,19:00"
    start_date: str
    end_date: str

class MedicineResponse(MedicineCreate):
    id: int

    class Config:
        from_attributes = True
        
class MedicineResponse(MedicineCreate):
    id: int
    taken: bool = False  # 추가!

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
    created_at: datetime  # str → datetime 으로 변경

    class Config:
        from_attributes = True

