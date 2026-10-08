"""
main.py 를 대화 엔진에 자동으로 연결해 주는 스크립트 (아현님용)

  cd ~/my_ai_project
  python3 pi_client/apply_bridge.py main.py http://192.168.10.69:8000

하는 일 (원본은 main_backup_<시각>.py 로 저장, 되돌리려면 그 파일을 main.py 로 복사)
  1) BACKEND_URL 을 새 주소로 바꾸고, 바로 아래에 OasisBridge 연결 추가
  2) 음성 인식 후 'save_message → get_ai_response → save_message → speak' 를 bridge.handle(text, speak) 로 교체
  3) speak(text) → speak(text, rate="+0%") ("뭐라고?" 하면 천천히 말하기)
  4) 알림 스레드 시작하는 곳에 먼저 말 걸기(start_proactive) 추가
이미 바뀐 곳은 건너뛰고, 못 찾은 곳은 알려 준다.
"""
import re
import shutil
import sys
import time


def main():
    if len(sys.argv) < 3:
        sys.exit("사용법: python3 pi_client/apply_bridge.py main.py http://<백엔드IP>:8000")
    path, url = sys.argv[1], sys.argv[2].rstrip("/")
    src = open(path, encoding="utf-8").read()
    s = src
    done, missed = [], []

    # 1) 백엔드 주소 + 연결
    if "OasisBridge" not in s:
        s, n = re.subn(r'^BACKEND_URL\s*=.*$',
                       f'BACKEND_URL = "{url}"\nfrom pi_client.oasis_bridge import OasisBridge\nbridge = OasisBridge(BACKEND_URL)',
                       s, count=1, flags=re.M)
        (done if n else missed).append("① 백엔드 주소 + OasisBridge 연결")
    else:
        s = re.sub(r'^BACKEND_URL\s*=.*$', f'BACKEND_URL = "{url}"', s, count=1, flags=re.M)
        done.append("① 백엔드 주소만 갱신 (연결은 이미 있음)")

    # 2) 대답 부분 교체: save_message("user", ...) 부터 speak(ai_answer) 까지
    pattern = re.compile(
        r'(?P<indent>[ \t]*)save_message\("user",\s*text\)\s*\n'
        r'(?P<body>(?:.*\n)*?)'
        r'(?P=indent)speak\(ai_answer\)[ \t]*\n')
    m = pattern.search(s)
    if m:
        ind = m.group("indent")
        keep = [l for l in m.group("body").splitlines()
                if "buffer" in l]                       # 버퍼 비우는 줄은 그대로 둔다
        new = "".join(l + "\n" for l in keep) + f"{ind}bridge.handle(text, speak)\n"
        s = s[:m.start()] + new + s[m.end():]
        done.append("② 대답 부분 → bridge.handle(text, speak)")
    elif "bridge.handle(" in s:
        done.append("② 대답 부분 (이미 교체됨)")
    else:
        missed.append("② 대답 부분 (save_message(\"user\", text) ~ speak(ai_answer) 를 못 찾음)")
    s = re.sub(r'if text and len\(text\) > 2:', 'if text and len(text) > 1:', s)

    # 3) 천천히 말하기
    if re.search(r'def speak\(text\):', s):
        s = s.replace("def speak(text):", 'def speak(text, rate="+0%"):', 1)
        s, n = re.subn(r'edge_tts\.Communicate\(text,\s*"([^"]+)"\)', r'edge_tts.Communicate(text, "\1", rate=rate)', s)
        done.append("③ speak 에 말하기 속도 추가" + ("" if n else " (Edge TTS 줄은 못 찾음 — 보통 속도로 말함)"))
    elif "rate" in (re.search(r'def speak\(([^)]*)\)', s) or [""])[0]:
        done.append("③ 말하기 속도 (이미 있음)")
    else:
        missed.append("③ def speak(text): 를 못 찾음")

    # 4) 먼저 말 걸기
    if "start_proactive" not in s:
        s, n = re.subn(r'^(?P<i>[ \t]*)(?P<v>\w+)\.daemon = True\s*\n(?P=i)(?P=v)\.start\(\)[ \t]*\n',
                       lambda mm: mm.group(0) + f"{mm.group('i')}bridge.start_proactive(speak, is_busy=lambda: is_speaking)\n",
                       s, count=1, flags=re.M)
        (done if n else missed).append("④ 먼저 말 걸기 시작")
    else:
        done.append("④ 먼저 말 걸기 (이미 있음)")

    if s == src:
        print("바꿀 곳이 없어요 (이미 연결되어 있음)")
        return
    backup = f"main_backup_{time.strftime('%m%d_%H%M')}.py"
    shutil.copy(path, backup)
    open(path, "w", encoding="utf-8").write(s)
    print(f"원본 백업: {backup}")
    for d in done:
        print("  ✅", d)
    for x in missed:
        print("  ⚠️", x, "→ 수동으로 바꿔야 해요 (oasis_bridge.py 맨 위 설명 참고)")
    try:
        compile(s, path, "exec")
        print("문법 검사 통과 → 이제 python3 main.py 로 실행하세요")
    except SyntaxError as e:
        print(f"⚠️ 문법 오류: {e} → {backup} 을 main.py 로 되돌리고 알려 주세요")


if __name__ == "__main__":
    main()
