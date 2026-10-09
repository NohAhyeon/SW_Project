"""
예전 실행 명령(uvicorn talk_app:app)도 그대로 쓸 수 있게 남겨 둔 파일.
대화 엔진(/talk)은 이제 main.py 에 직접 붙어 있으므로 아래 둘 다 같다.
  uvicorn main:app --host 0.0.0.0 --port 8000
  uvicorn talk_app:app --host 0.0.0.0 --port 8000
"""
from main import app  # noqa: F401
