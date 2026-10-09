"""
OASIS 파이 ↔ 대화 엔진 연결 모듈 (아현님용) — my_ai_project/main.py 에 붙여서 쓴다

이 모듈 하나로 되는 것
  · 챗봇 이름(애칭)을 부른 말에만 대답, 처음 켰을 때 어르신께 이름 여쭤보기
  · 약·일정 질문은 DB 값으로 대답, "먹었어" → 복약 기록, 위급한 말 → 보호자 알림
  · "뭐라고?" → 직전 대답을 짧게, 천천히 다시
  · 먼저 말 걸기 (약 시간 "드셨어요?" / 아침 인사 / 지난 대화 기억으로 안부)
  · 낙상·가스가 감지되면 2초 안에 스피커로 안내
  · 대화 저장은 서버가 한다 → 기존 save_message() 호출은 지운다

main.py 에 붙이는 법 (세 군데)
  1) 위쪽 import 아래:
       from pi_client.oasis_bridge import OasisBridge
       bridge = OasisBridge(BACKEND_URL)
  2) stt_processing_thread() 안, 인식된 글자(text)가 나온 뒤:
       기존:  save_message("user", text); ai_answer = get_ai_response(text); save_message("assistant", ai_answer); speak(ai_answer)
       변경:  bridge.handle(text, speak)
  3) 프로그램 시작 부분(다른 스레드 시작하는 곳)에:
       bridge.start_proactive(speak, is_busy=lambda: is_speaking)

speak(text) 함수 하나만 있으면 된다. 천천히 말하기가 필요할 때는 speak(text, rate="-25%") 로 부르므로,
기존 speak 에 rate 인자를 추가해 두면 좋다 (Edge TTS: edge_tts.Communicate(text, voice, rate=rate)).
rate 인자가 없으면 그냥 보통 속도로 말한다.
"""
import inspect
import threading
import time

import requests


class OasisBridge:
    def __init__(self, backend_url, session_id="oasis-device-1", senior_id=4,
                 filler_after_sec=1.5, proactive_every_sec=30, urgent_every_sec=2, headers=None):
        self.url = backend_url.rstrip("/")
        self.session_id, self.senior_id = session_id, senior_id
        self.filler_after_sec = filler_after_sec
        self.proactive_every_sec = proactive_every_sec
        self.urgent_every_sec = urgent_every_sec
        self.headers = headers or {}
        self._lock = threading.Lock()          # 대답과 먼저 말 걸기가 겹치지 않게

    # ── 어르신이 말했을 때 ──────────────────────────────────
    def handle(self, text, speak):
        """인식된 글자를 엔진에 보내고, 대답할 게 있으면 말한다. 말한 내용(없으면 None)을 돌려준다."""
        text = (text or "").strip()
        if not text:
            return None
        with self._lock:
            filler = threading.Timer(self.filler_after_sec, lambda: speak("음, 잠시만요."))
            filler.start()
            try:
                res = requests.post(f"{self.url}/talk/", headers=self.headers, timeout=40, json={
                    "text": text, "session_id": self.session_id, "senior_id": self.senior_id})
                data = res.json()
            except Exception as e:
                print(f"[대화 엔진 오류] {e}")
                data = {"respond": True, "reply": "죄송해요, 지금은 대답하기가 어려워요. 잠시 후에 다시 말씀해 주세요."}
            finally:
                filler.cancel()

            if not data.get("respond", True):
                print(f"(이름을 부르지 않은 말이라 대답 안 함: {text})")
                return None
            reply = data.get("reply", "")
            print(f"[대화] {data.get('intent')} · {data.get('source')} · {data.get('latency_ms')}ms → {reply}")
            self._speak(speak, reply, slow=data.get("speak_rate") == "slow")
            return reply

    # ── 먼저 말 걸기 ────────────────────────────────────────
    def start_proactive(self, speak, is_busy=lambda: False):
        """30초마다 서버에 '지금 먼저 할 말 있어?' 를 묻고, 있으면 말한다."""
        def loop():
            while True:
                time.sleep(self.proactive_every_sec)
                if is_busy() or self._lock.locked():
                    continue
                try:
                    data = requests.get(f"{self.url}/talk/proactive", headers=self.headers, timeout=10,
                                        params={"session_id": self.session_id, "senior_id": self.senior_id}).json()
                except Exception as e:
                    print(f"[먼저 말 걸기 확인 실패] {e}")
                    continue
                if data.get("say") and not is_busy():
                    with self._lock:
                        print(f"[먼저 말 걸기] {data.get('kind')} → {data['say']}")
                        self._speak(speak, data["say"])
        threading.Thread(target=loop, daemon=True).start()
        print(f"[먼저 말 걸기] {self.proactive_every_sec}초마다 확인 시작")

        def urgent_loop():
            """낙상·가스가 감지되면 2초 안에 스피커로 안내 (다른 말 중이면 끝나고 바로)"""
            while True:
                time.sleep(self.urgent_every_sec)
                try:
                    data = requests.get(f"{self.url}/talk/urgent", headers=self.headers, timeout=5,
                                        params={"session_id": self.session_id, "senior_id": self.senior_id}).json()
                except Exception:
                    continue
                if data.get("say"):
                    with self._lock:
                        print(f"[위험 안내] {data.get('kind')} → {data['say']}")
                        self._speak(speak, data["say"])
        threading.Thread(target=urgent_loop, daemon=True).start()
        print(f"[위험 안내] {self.urgent_every_sec}초마다 낙상·가스 확인 시작")

    @staticmethod
    def _speak(speak, text, slow=False):
        if not text:
            return
        if slow and "rate" in inspect.signature(speak).parameters:
            speak(text, rate="-25%")
        else:
            speak(text)
