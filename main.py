from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import engine, Base
from routers import chat, medicine, schedule, alert, admin, auth, guardian
from scheduler import start_scheduler

app = FastAPI(title="노인케어 챗봇 백엔드")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    start_scheduler()

@app.on_event("shutdown")
async def shutdown():
    from scheduler import scheduler
    scheduler.shutdown()

app.include_router(auth.router, prefix="/auth", tags=["인증"])
app.include_router(chat.router, prefix="/chat", tags=["대화 로그"])
app.include_router(medicine.router, prefix="/medicine", tags=["복약 관리"])
app.include_router(schedule.router, prefix="/schedule", tags=["일정 관리"])
app.include_router(alert.router, prefix="/alert", tags=["위급 알림"])
app.include_router(admin.router, prefix="/admin", tags=["중앙 관리"])
app.include_router(guardian.router, prefix="/guardian", tags=["보호자 관리"])

@app.get("/")
async def root():
    return {"status": "ok", "message": "노인케어 챗봇 백엔드 실행중 🤖"}
