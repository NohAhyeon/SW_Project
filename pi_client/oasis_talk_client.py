"""
라즈베리파이 음성 챗봇 → 백엔드 노인 맞춤 대화 엔진 연결 예시 (대영님용)

my_ai_project/main.py 의 get_ai_response() 와 save_message() 호출을 이 코드로 바꾸면 된다.
  - 대답 생성 + 대화 저장 + 약 복용 기록 + 위급 알림을 백엔드가 한 번에 처리한다.
  - 1.5초 안에 대답이 안 오면 "음, 잠시만요"를 먼저 말해 어르신이 기다리는 걸 알 수 있게 한다.
"""
import threading
import requests

BACKEND_URL = "http://<백엔드IP>:8000"   # 기존 main.py 의 BACKEND_URL 그대로 사용
SESSION_ID  = "oasis-device-1"
SENIOR_ID   = 4                         # 이 기기를 쓰는 어르신 계정 id
FILLER_AFTER_SEC = 1.5


def get_ai_response(text, speak):
    """text: 음성 인식 결과, speak: 기존 TTS 함수 (예: speak("안녕하세요"))"""
    filler = threading.Timer(FILLER_AFTER_SEC, lambda: speak("음, 잠시만요."))
    filler.start()
    try:
        res = requests.post(f"{BACKEND_URL}/talk/",
                            json={"text": text, "session_id": SESSION_ID, "senior_id": SENIOR_ID},
                            timeout=40)
        data = res.json()
        # 응답 시간 측정 로그 (발표 자료용)
        print(f"[talk] {data['intent']} · {data['source']} · 전체 {data['latency_ms']}ms · AI {data['llm_ms']}ms")
        return data["reply"]
    except Exception as e:
        print(f"[talk] 오류: {e}")
        return "죄송해요, 지금은 대답하기가 어려워요. 잠시 후에 다시 말씀해 주세요."
    finally:
        filler.cancel()

# 사용 예 (stt_processing_thread 안에서):
#   user_text = transcription.text
#   reply = get_ai_response(user_text, speak)
#   speak(reply)
# ※ 기존 save_message("user", ...) / save_message("assistant", ...) 는 지워야 대화가 두 번 저장되지 않는다.
