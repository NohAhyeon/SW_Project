from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base


# 유저 테이블
# role: "senior"(노인 사용자) | "guardian"(보호자) | "admin"
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String, nullable=True)
    role = Column(String, default="senior")       # senior | guardian | admin
    social_provider = Column(String, nullable=True)
    social_id = Column(String, nullable=True)
    nickname = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    address = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())

    # 보호자 → 어르신 관계 (보호자 측)
    guarding = relationship("GuardianRelation", foreign_keys="GuardianRelation.guardian_id", back_populates="guardian")
    # 어르신 → 보호자 관계 (어르신 측)
    guarded_by = relationship("GuardianRelation", foreign_keys="GuardianRelation.senior_id", back_populates="senior")


# 보호자-어르신 연결 테이블 (1 보호자 : N 어르신)
class GuardianRelation(Base):
    __tablename__ = "guardian_relations"

    id = Column(Integer, primary_key=True, index=True)
    guardian_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    senior_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    label = Column(String, nullable=True)         # 보호자가 붙인 어르신 별명 (예: "어머니")
    created_at = Column(DateTime, default=func.now())

    guardian = relationship("User", foreign_keys=[guardian_id], back_populates="guarding")
    senior = relationship("User", foreign_keys=[senior_id], back_populates="guarded_by")


# 대화 로그 테이블
class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(Integer, primary_key=True, index=True)
    senior_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # nullable: 기존 데이터 호환
    session_id = Column(String, index=True)
    role = Column(String)
    content = Column(String)
    type = Column(String, default="생활정보")
    created_at = Column(DateTime, default=func.now())

    senior = relationship("User", foreign_keys=[senior_id])


# 복약 정보 테이블
class Medicine(Base):
    __tablename__ = "medicines"

    id = Column(Integer, primary_key=True, index=True)
    senior_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    name = Column(String)
    dose = Column(String)
    alarm_times = Column(String)
    start_date = Column(String)
    end_date = Column(String)
    taken = Column(Boolean, default=False)

    senior = relationship("User", foreign_keys=[senior_id])


# 일정 테이블
class Schedule(Base):
    __tablename__ = "schedules"

    id = Column(Integer, primary_key=True, index=True)
    senior_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    title = Column(String)
    datetime = Column(String)
    memo = Column(String, nullable=True)
    is_completed = Column(Boolean, default=False)

    senior = relationship("User", foreign_keys=[senior_id])


# 위급 알림 테이블
class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True)
    senior_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    type = Column(String)
    message = Column(String)
    is_resolved = Column(Boolean, default=False)
    created_at = Column(DateTime, default=func.now())

    senior = relationship("User", foreign_keys=[senior_id])
