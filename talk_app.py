"""
노인 맞춤 대화 엔진을 붙여서 백엔드를 실행하는 진입점 (김다혜)

아현님의 main.py 는 수정하지 않고, 그 앱에 /talk 라우터만 추가한다.
실행:  uvicorn talk_app:app --host 0.0.0.0 --port 8000 --reload
(기존 main:app 대신 talk_app:app 으로 켜면 기존 API + /talk 가 모두 동작)
"""
from main import app
from routers import talk

app.include_router(talk.router, prefix="/talk", tags=["노인 맞춤 대화"])
