"""
부산·경상도 사투리 의도 판단 평가 (발표용 숫자) — 맥에서 실행, 서버 없이 엔진만 불러서 돌린다

  python3 tools/dialect_eval.py

· 같은 문장을 '사투리 변환 없이' / '변환해서' 두 번 판단해 정확도를 비교한다.
· DB·알림·날씨·AI 호출은 막아 두고 '무슨 말인지 판단(intent)'만 본다 (기록이 남지 않음).
· 결과는 tools/dialect_result.md 로 저장된다.
"""
import asyncio
import logging
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
logging.disable(logging.CRITICAL)

import dialect                      # noqa: E402
import elder_engine as e            # noqa: E402
from database import AsyncSessionLocal   # noqa: E402

# (어르신 말, 기대 의도) — 부산·경상도 어르신 말투로 쓴 53문장
CASES = [
    # 약 질문
    ("오늘 약 뭐 묵어야 되노", "med_query"), ("약 언제 묵노", "med_query"), ("아침 약 뭐고", "med_query"),
    ("혈압약 묵을 시간 됐나", "med_query"), ("약 남은 거 있나", "med_query"), ("저녁에 무슨 약 묵노", "med_query"),
    ("약 머 묵으라 캤노", "med_query"), ("비타민 언제 묵노", "med_query"),
    # 약 먹었다
    ("약 묵었다", "med_taken"), ("아까 혈압약 묵었데이", "med_taken"), ("약 다 뭇다", "med_taken"),
    ("방금 약 챙기 묵었다", "med_taken"), ("약 무따", "med_taken"), ("아침 약 묵었심더", "med_taken"),
    # 일정
    ("내일 병원 가나", "sched_query"), ("복지관 언제 가노", "sched_query"), ("오늘 일정 있나", "sched_query"),
    ("병원 예약 언제고", "sched_query"), ("이번 주 모임 있나", "sched_query"), ("내일 머 하는 날이고", "sched_query"),
    # 시간·날짜
    ("지금 몇 시고", "time"), ("오늘 며칠이고", "time"), ("오늘 무슨 요일이고", "time"),
    ("지금 몇 시나 됐노", "time"), ("오늘 날짜가 우째 되노", "time"),
    # 날씨
    ("비 오나", "weather"), ("오늘 덥나", "weather"), ("날씨 우떻노", "weather"),
    ("밖에 춥나", "weather"), ("우산 챙기야 되나", "weather"),
    # 몸 상태
    ("와 이리 어지럽노", "symptom_check"), ("다리가 억수로 아푸다", "symptom_check"),
    ("머리가 쪼매 아프네", "symptom_check"), ("속이 안 좋다", "symptom_check"),
    ("배가 살살 아프다", "symptom_check"), ("기운이 하나도 없다", "symptom_check"),
    # 위급
    ("날 좀 살리도", "emergency"), ("자빠졌다 일어나지를 못하겠다", "emergency"), ("가슴이 답답하다", "emergency"),
    ("불났다 카이", "emergency"), ("숨이 안 쉬어진다", "emergency"),
    # 다시 말해 달라
    ("머라카노", "repeat"), ("머라 캤노", "repeat"), ("다시 말해 도", "repeat"), ("잘 안 들린다", "repeat"),
    # 일상 대화
    ("손녀가 주말에 온다 카더라", "chat"), ("오늘 시장 갔다 왔데이", "chat"), ("텔레비전 보니까 재밌더라", "chat"),
    ("영감 생각이 많이 나네", "chat"), ("니는 밥 뭇나", "chat"), ("오늘 꽃이 억수로 이쁘게 폈더라", "chat"),
    ("이웃집 할매가 떡 갖다 줬다", "chat"), ("고마 심심하다", "chat"),
]


async def _noop(*a, **k):
    return "ok"


async def run(use_dialect: bool):
    # 부작용(기록·알림·복약 처리·날씨·AI·기억 저장)은 막고 판단만 본다
    e._save = _noop
    e._raise_alert = _noop
    e._record_med_taken = _noop
    e._answer_weather = _noop
    e._remember_later = _noop
    e.LLM_ORDER = []
    real = dialect.__dict__.setdefault("_real_normalize", dialect.normalize)
    dialect.normalize = real if use_dialect else (lambda x: x)
    rows = []
    async with AsyncSessionLocal() as db:
        for i, (text, expect) in enumerate(CASES):
            sid = f"dialect-eval-{use_dialect}-{i}"
            e._last_reply[sid] = "오늘 남은 약은 저녁 안약이에요."     # '다시 말해 줘' 판단용
            r = await e.reply(db, text, sid, 4, False)
            rows.append((text, expect, r["intent"]))
            e._pending_confirm.pop(sid, None)
    return rows


async def main():
    before = await run(False)
    after = await run(True)
    ok_b = sum(g == x for _, x, g in before)
    ok_a = sum(g == x for _, x, g in after)
    n = len(CASES)
    lines = ["# 부산·경상도 사투리 의도 판단 평가", "",
             f"- 문장 수: {n}개 (약 질문 8 · 약 먹음 6 · 일정 6 · 시간 5 · 날씨 5 · 몸 상태 6 · 위급 5 · 다시 말하기 4 · 일상 8)",
             f"- 사투리 변환 없이: **{ok_b}/{n} ({ok_b / n * 100:.0f}%)**",
             f"- 사투리 변환 후: **{ok_a}/{n} ({ok_a / n * 100:.0f}%)**", "",
             "| 어르신 말 | 기대 | 변환 없이 | 변환 후 |", "|---|---|---|---|"]
    for (t, x, gb), (_, _, ga) in zip(before, after):
        lines.append(f"| {t} | {x} | {'✅' if gb == x else '❌ ' + gb} | {'✅' if ga == x else '❌ ' + ga} |")
    out = ROOT / "tools" / "dialect_result.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    asyncio.run(main())
