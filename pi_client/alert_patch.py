"""
라즈베리파이 알림 처리 수정본 (대영님용) — my_ai_project/main.py 의 두 함수를 이걸로 교체

문제:
  기존 alert_check_thread() 와 check_alerts() 는 서버의 '미해결 알림'을 전부 읽고
  모두 '해결됨'으로 바꿨다. 그래서 가스·긴급·낙상 알림이 보호자 앱에서 30초 안에 사라졌다.

수정:
  - 일정알림 → 어르신께 소리로 알려 드리고 해결 처리
  - 복약알림 → 소리 없이 해결 처리만. 약 시간 안내는 oasis_bridge 의 '먼저 말 걸기'가
    "○○ 드실 시간이에요. 드셨어요?" 로 여쭤보고 대답까지 받아 복약 기록을 한다 (같은 말 두 번 방지)
  - 가스 / 긴급 / 비활동 / 낙상 / 위급 → 해결 처리하지 않음 (보호자가 앱에서 확인 후 해결)
"""
import time
import requests

# 기존 main.py 에 이미 있는 값·함수를 그대로 사용: BACKEND_URL, NGROK_HEADERS, speak

# 기기가 소리로 안내하고 끝내는 알림 / 소리 없이 끝내는 알림
SPEAK_ALERT_TYPES  = {"일정알림"}
SILENT_ALERT_TYPES = {"복약알림"}          # 먼저 말 걸기(oasis_bridge)가 대신 여쭤봄
DEVICE_ALERT_TYPES = SPEAK_ALERT_TYPES | SILENT_ALERT_TYPES


def _fetch_unresolved():
    res = requests.get(f"{BACKEND_URL}/alert/unresolved", verify=False,
                       headers=NGROK_HEADERS, timeout=5)
    return res.json()


def _resolve(alert_id):
    requests.patch(f"{BACKEND_URL}/alert/{alert_id}/resolve", verify=False,
                   headers=NGROK_HEADERS, timeout=5)


def alert_check_thread():
    while True:
        try:
            for alert in _fetch_unresolved():
                if alert.get("type") in SPEAK_ALERT_TYPES:
                    speak(alert["message"])
                    _resolve(alert["id"])
                elif alert.get("type") in SILENT_ALERT_TYPES:
                    _resolve(alert["id"])
                # 가스·긴급·낙상 등은 건드리지 않는다 → 보호자 앱에 계속 표시됨
        except Exception as e:
            print(f"알림 확인 오류: {e}")
        time.sleep(30)


def check_alerts():
    """챗봇 시작 시: 전원이 꺼져 있던 동안 쌓인 '지난 복약/일정 안내'만 조용히 정리"""
    try:
        for alert in _fetch_unresolved():
            if alert.get("type") in DEVICE_ALERT_TYPES:
                _resolve(alert["id"])
    except Exception as e:
        print(f"알림 확인 오류: {e}")
