"""
대화 엔진 성능 측정 (발표용 숫자) — 맥에서 실행

  python3 tools/measure_engine.py            # 기본 서버 http://localhost:8000
  python3 tools/measure_engine.py --repeat 3 # 같은 문장을 3번씩 (응답 시간 평균을 안정적으로)

측정하는 것
  · 의도 판단 정확도: 어르신 말 종류(약 질문, 일정, 위급 확인, 다시 말해줘 등)를 맞게 알아들었나
  · 응답 시간: 처리 방식(규칙/DB/클라우드 AI/로컬 AI)별 평균·최대
결과는 tools/measure_result.md 로 저장된다. 측정용 대화 기록은 끝나면 지운다.
(DB 를 바꾸는 말 — "약 먹었어", "살려줘" — 은 측정에서 뺐다)
"""
import argparse
import json
import sqlite3
import statistics
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# (어르신 말, 기대하는 의도)
CASES = [
    ("오늘 약 뭐 먹어야 돼?", "med_query"),
    ("혈압약 언제 먹더라", "med_query"),
    ("약 남은 거 있어?", "med_query"),
    ("오늘 병원 가는 날이야?", "sched_query"),
    ("내일 일정 있나", "sched_query"),
    ("복지관 언제 가지", "sched_query"),
    ("지금 몇 시야", "time"),
    ("오늘 무슨 요일이야", "time"),
    ("오늘 날씨 어때", "weather"),
    ("비 와?", "weather"),
    ("아이고 머리가 어지러워", "symptom_check"),
    ("배가 좀 아프네", "symptom_check"),
    ("음", "unclear"),
    ("요즘 혼자 있으니까 외롭네", "chat"),
    ("손녀가 주말에 온대", "chat"),
    ("오늘 트로트 프로그램 재밌더라", "chat"),
    ("점심에 국수 먹었어", "chat"),
    ("우리 아파트 앞에 꽃이 폈어", "chat"),
]


def post(base, text, session):
    req = urllib.request.Request(f"{base}/talk/", data=json.dumps(
        {"text": text, "session_id": session, "senior_id": 4, "require_wake": False}).encode(),
        headers={"Content-Type": "application/json"})
    t0 = time.perf_counter()
    r = json.load(urllib.request.urlopen(req, timeout=60))
    r["_wall_ms"] = int((time.perf_counter() - t0) * 1000)
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://localhost:8000")
    ap.add_argument("--repeat", type=int, default=1)
    args = ap.parse_args()
    session = f"measure-{int(time.time())}"

    rows, correct = [], 0
    for text, expect in CASES:
        for i in range(args.repeat):
            r = post(args.base, text, f"{session}-{len(rows)}")    # 문장마다 새 대화 (앞 대화 영향 없음)
            ok = r["intent"] == expect
            correct += ok
            rows.append((text, expect, r["intent"], ok, r["source"], r["_wall_ms"], r.get("reply", "")))
            print(f"{'✅' if ok else '❌'} {text:24s} → {r['intent']:13s} {r['source']:6s} {r['_wall_ms']:5d}ms  {r.get('reply','')[:40]}")

    # 처리 방식별 응답 시간
    by_src: dict[str, list[int]] = {}
    for *_, src, ms, _r in rows:
        by_src.setdefault(src, []).append(ms)

    lines = ["# 대화 엔진 측정 결과", "",
             f"- 측정 시각: {time.strftime('%Y-%m-%d %H:%M')}",
             f"- 의도 판단 정확도: **{correct}/{len(rows)} ({correct / len(rows) * 100:.0f}%)**", "",
             "| 처리 방식 | 횟수 | 평균 응답 | 최대 |", "|---|---|---|---|"]
    names = {"rule": "규칙", "db": "DB", "api": "외부 API", "cloud": "클라우드 AI", "local": "로컬 AI", "fallback": "실패 대체"}
    for src, ms in sorted(by_src.items()):
        lines.append(f"| {names.get(src, src)} | {len(ms)} | {statistics.mean(ms):.0f}ms | {max(ms)}ms |")
    lines += ["", "| 어르신 말 | 기대 | 결과 | 방식 | 시간 |", "|---|---|---|---|---|"]
    lines += [f"| {t} | {e} | {'✅' if ok else '❌ ' + g} | {s} | {ms}ms |" for t, e, g, ok, s, ms, _ in rows]
    out = ROOT / "tools" / "measure_result.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    print("\n" + "\n".join(lines[:12]))
    print(f"\n→ {out} 저장")

    # 측정용 대화 기록 정리 (로컬 서버일 때만)
    db = ROOT / "chatbot.db"
    if "localhost" in args.base and db.exists():
        con = sqlite3.connect(db)
        n = con.execute("delete from conversations where session_id like ?", (f"{session}%",)).rowcount
        con.commit()
        print(f"(측정용 대화 {n}건 정리)")


if __name__ == "__main__":
    main()
