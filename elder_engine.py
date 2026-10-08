"""
OASIS 노인 맞춤 대화 엔진

어르신 발화 한 문장을 받아 아래 순서로 처리한다.
  1) 못 알아들은 말        → 추측하지 않고 다시 여쭤본다
  2) 위급 표현             → LLM을 거치지 않고 즉시 보호자 알림
  3) 애매한 몸 상태 표현    → "보호자분께 알릴까요?" 확인 후 알림
  4) 약 먹었다는 말         → 복약 완료로 DB에 기록
  5) 약·일정·시간 질문      → DB 값으로 바로 대답 (지어내기 차단, 빠름)
  6) 그 외 일상 대화        → LLM (로컬 ↔ 클라우드 자동 전환)

LLM은 OpenAI 호환 API 하나로 호출하므로 Groq / Gemini / 라즈베리파이 llama.cpp 서버를
주소와 모델 이름만 바꿔 쓸 수 있다. 설정은 .env 에서 읽는다 (.env.example 참고).
"""
import json
import os
import re
import time
from datetime import datetime, timedelta
from pathlib import Path

import httpx
from dotenv import load_dotenv
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from crypto import decrypt, encrypt
from difflib import SequenceMatcher

from models import Alert, Conversation, Medicine, Schedule, Setting, User

load_dotenv()
# 날씨 키는 앱 쪽 .env 에 있으므로 함께 읽는다 (이미 있는 값은 덮어쓰지 않음)
load_dotenv(Path(__file__).with_name("flutter_app") / ".env")

# ── LLM 설정 ──────────────────────────────────────────────────
# LLM_ORDER: 앞에서부터 시도. 실패하거나 시간 초과면 다음으로 넘어간다.
#   "local,cloud" = 파이 로컬 우선, 안 되면 클라우드 (하이브리드)
#   "cloud"       = 클라우드만 / "local" = 로컬만 (완전 오프라인)
LLM_ORDER = [x.strip() for x in os.getenv("LLM_ORDER", "local,cloud").split(",") if x.strip()]

LOCAL_LLM_URL   = os.getenv("LOCAL_LLM_URL", "http://raspberrypi.local:8080/v1")
LOCAL_LLM_MODEL = os.getenv("LOCAL_LLM_MODEL", "qwen2.5-1.5b-instruct")
LOCAL_TIMEOUT   = float(os.getenv("LOCAL_LLM_TIMEOUT", "25"))

# 클라우드: GROQ_API_KEY 가 있으면 Groq, 없으면 Gemini 의 OpenAI 호환 주소를 쓴다.
if os.getenv("GROQ_API_KEY"):
    CLOUD_LLM_URL   = os.getenv("CLOUD_LLM_URL", "https://api.groq.com/openai/v1")
    CLOUD_LLM_KEY   = os.getenv("GROQ_API_KEY", "")
    CLOUD_LLM_MODEL = os.getenv("CLOUD_LLM_MODEL", "qwen/qwen3-32b")
else:
    CLOUD_LLM_URL   = os.getenv("CLOUD_LLM_URL", "https://generativelanguage.googleapis.com/v1beta/openai")
    CLOUD_LLM_KEY   = os.getenv("GEMINI_API_KEY", "")
    CLOUD_LLM_MODEL = os.getenv("CLOUD_LLM_MODEL", "gemini-3.5-flash-lite")
CLOUD_TIMEOUT = float(os.getenv("CLOUD_LLM_TIMEOUT", "10"))

WEATHER_API_KEY = os.getenv("WEATHER_API_KEY", "")

# 어르신별 호칭·관심사·가족 (DB 스키마를 바꾸지 않고 개인화하기 위한 파일)
PROFILE_FILE = Path(__file__).with_name("senior_profiles.json")

# ── 문구 ──────────────────────────────────────────────────────
MSG_UNCLEAR  = "죄송해요, 잘 못 들었어요. 천천히 한 번 더 말씀해 주시겠어요?"
MSG_LLM_FAIL = "죄송해요, 잠깐 생각이 잘 안 나네요. 다시 한 번 말씀해 주시겠어요?"

# ── 의도 판단 규칙 ─────────────────────────────────────────────
# 띄어쓰기를 지운 문장에서 찾는다 (음성 인식 결과는 띄어쓰기가 들쭉날쭉하기 때문)
EMERGENCY_WORDS = ["살려", "도와줘", "도와주세요", "쓰러졌", "쓰러질것", "넘어졌", "일어날수가없",
                   "일어나지를못", "숨이안", "숨을못", "숨이차", "가슴이아파", "가슴이답답",
                   "불이야", "불났", "연기가", "가스냄새", "119", "응급", "피가나"]
FIRE_WORDS      = ["불이야", "불났", "연기가", "가스냄새"]
SYMPTOM_RE      = re.compile(r"어지러|아파(?!트)|아프|토할|열이나|몸이안좋|기운이없|힘이없")
# 짧은 대답(응/어/네)은 다른 단어 안에도 들어 있어서 문장 전체가 일치할 때만 인정
YES_EXACT       = {"응", "어", "네", "예", "그래", "응응", "네네", "그래요", "좋아"}
YES_WORDS       = ["알려", "불러", "부탁", "연락해", "그래줘", "알려줘"]
NO_WORDS        = ["아니", "괜찮아", "됐어", "하지마", "괜찮다"]

MED_TAKEN_RE = re.compile(r"약.{0,6}(먹었|드셨|복용했|챙겨먹었|먹음)|(먹었|복용했).{0,4}약")
MED_RE       = re.compile(r"약(?!속)")          # '약속'은 약이 아님
MED_ASK_RE   = re.compile(r"뭐|무슨|언제|몇|먹어야|드셔야|남았|있어|있나|알려|먹을")
SCHED_RE     = re.compile(r"일정|병원|약속|스케줄|예약|가는날|복지관|모임|진료")
TIME_RE      = re.compile(r"몇시|며칠|무슨요일|오늘날짜|지금시간")
WEATHER_RE   = re.compile(r"날씨|비와|비가와|더워|추워|우산")

# 세션별 "보호자분께 알릴까요?" 확인 대기 상태
_pending_confirm: dict[str, dict] = {}


# ════════════════════════════════════════════════════════════
#  이름 부르기 (호출어)
#   - 이름을 부른 말에만 대답한다 (TV 소리·다른 사람 대화에는 반응하지 않고 저장도 하지 않음)
#   - 이름만 부르면 "네, 말씀하세요" → WAKE_WINDOW_SEC 동안은 이름 없이 이어서 대화
#   - 위급한 말("살려줘", "불이야")은 이름이 없어도 바로 반응
#   - 이름은 앱 설정에서 바꾼다 (settings 테이블 key = "wake_name")
# ════════════════════════════════════════════════════════════
DEFAULT_WAKE_NAME = "오아시스"
WAKE_WINDOW_SEC   = float(os.getenv("WAKE_WINDOW_SEC", "20"))
END_WORDS         = ["그만", "됐어", "잘자", "잘있어", "조용히", "이제됐", "끝내"]
_awake_until: dict[str, float] = {}
_wake_cache = {"name": None, "at": 0.0}


def _jamo(s: str) -> str:
    """'오아' → 'ㅇㅗㅇㅏ' 처럼 자음·모음으로 풀어서, 받아쓰기가 조금 틀려도 비교할 수 있게 한다"""
    out = []
    for ch in s:
        code = ord(ch) - 0xAC00
        if 0 <= code < 11172:
            out += [chr(0x1100 + code // 588), chr(0x1161 + (code % 588) // 28)]
            if code % 28:
                out.append(chr(0x11A7 + code % 28))
        else:
            out.append(ch.lower())
    return "".join(out)


def find_wake_name(t: str, name: str):
    """띄어쓰기 없앤 문장 t 에서 이름을 찾는다 → 찾은 부분 문자열 또는 None.
    3글자 이상 이름은 받아쓰기 오차(오아시쓰, 아시스)도 허용, 2글자 이하는 정확히 일치할 때만."""
    name = _norm(name)
    if not name:
        return None
    if name in t:
        return name
    if len(name) < 3:
        return None
    target = _jamo(name)
    best, best_ratio = None, 0.0
    for size in (len(name) - 1, len(name), len(name) + 1):
        for i in range(0, max(len(t) - size + 1, 0)):
            sub = t[i:i + size]
            ratio = SequenceMatcher(None, _jamo(sub), target).ratio()
            if ratio > best_ratio:
                best, best_ratio = sub, ratio
    return best if best_ratio >= 0.8 else None


def strip_wake_name(text: str, found: str) -> str:
    """원래 문장에서 이름(+ '야', '아' 같은 부르는 말)을 떼어낸다"""
    pattern = r"\s*".join(map(re.escape, found)) + r"(?:\s*(?:야|아|이|씨|님))?[\s,.!?~]*"
    return re.sub(pattern, " ", text, count=1).strip()


def validate_wake_name(name: str) -> str:
    name = re.sub(r"\s+", "", name or "")
    if not 2 <= len(name) <= 6 or not re.fullmatch(r"[가-힣A-Za-z]+", name):
        raise ValueError("이름은 띄어쓰기 없이 한글이나 영어 2~6글자로 정해 주세요.")
    return name


async def get_wake_name(db: AsyncSession) -> str:
    if _wake_cache["name"] and time.time() - _wake_cache["at"] < 10:
        return _wake_cache["name"]
    res = await db.execute(select(Setting).where(Setting.key == "wake_name"))
    row = res.scalar_one_or_none()
    _wake_cache.update(name=(row.value if row and row.value else DEFAULT_WAKE_NAME), at=time.time())
    return _wake_cache["name"]


async def set_wake_name(db: AsyncSession, name: str) -> str:
    name = validate_wake_name(name)
    res = await db.execute(select(Setting).where(Setting.key == "wake_name"))
    row = res.scalar_one_or_none()
    if row:
        row.value = name
    else:
        db.add(Setting(key="wake_name", value=name))
    await db.commit()
    _wake_cache.update(name=name, at=time.time())
    return name


# ── 처음 이름 짓기 (어르신이 음성으로 챗봇 애칭을 정함) ─────────
#   이름이 아직 없으면 첫 대화에서 이름을 여쭤보고, 확인을 받은 뒤 저장한다.
#   "네 이름 바꾸고 싶어" 라고 하면 언제든 다시 짓는다.
_naming: dict[str, dict] = {}
RENAME_RE = re.compile(r"이름(을|좀)?(바꾸|바꿔|바꿀|새로|다시|지어|정하|정해)")
CANCEL_WORDS = ["안해", "안할래", "나중에", "됐어", "그냥둬", "하지마"]


def _calling(name: str) -> str:
    """부를 때 붙는 말: 받침 있으면 '아'(복실→복실아), 없으면 '야'(순이→순이야)"""
    last = name[-1]
    code = ord(last) - 0xAC00
    has_batchim = 0 <= code < 11172 and code % 28 != 0
    return name + ("아" if has_batchim else "야")


def _subject(name: str) -> str:
    code = ord(name[-1]) - 0xAC00
    return name + ("이에요" if 0 <= code < 11172 and code % 28 else "예요")


def extract_name(text: str) -> str:
    """'복실이로 해', '복실이라고 불러줄게', '음 복실이' → '복실이'"""
    t = _norm(text)
    t = re.sub(r"^(음+|어+|그럼|그러면|이름은|네이름은|너는|니이름은|너이름은)", "", t)
    t = re.sub(r"라고(불러줄게|부를게|불러|할게|해|하자|지을게)?(요)?$", "", t)   # '이'는 남김(복실이라고→복실이)
    t = re.sub(r"(으로|로)(해줘|할게|해|하자|정할게|지을게|부를게|불러줄게)?(요)?$", "", t)
    t = re.sub(r"(어때|어떠니|어떨까|할까)(요)?$", "", t)
    return t


async def is_wake_name_set(db: AsyncSession) -> bool:
    res = await db.execute(select(Setting).where(Setting.key == "wake_name"))
    row = res.scalar_one_or_none()
    return bool(row and row.value)


async def reset_wake_name(db: AsyncSession) -> None:
    """앱의 '처음 설정 다시 하기': 이름을 지우면 다음 대화에서 이름을 다시 여쭤본다"""
    res = await db.execute(select(Setting).where(Setting.key == "wake_name"))
    row = res.scalar_one_or_none()
    if row:
        await db.delete(row)
        await db.commit()
    _wake_cache.update(name=None, at=0.0)
    _naming.clear()


async def _naming_step(db: AsyncSession, session_id: str, t: str, text: str) -> str:
    """이름 짓기 대화 한 단계 → 오아시스가 할 말"""
    state = _naming.setdefault(session_id, {"stage": "ask"})
    if _has(CANCEL_WORDS, t):
        _naming.pop(session_id, None)
        if not await is_wake_name_set(db):
            await set_wake_name(db, DEFAULT_WAKE_NAME)
        name = await get_wake_name(db)
        return f"알겠어요. 그럼 '{_calling(name)}' 하고 불러 주세요."

    if state["stage"] == "confirm":
        if t in YES_EXACT or _has(["맞아", "그래", "좋아", "응"], t):
            name = await set_wake_name(db, state["name"])
            _naming.pop(session_id, None)
            _awake_until[session_id] = time.time() + WAKE_WINDOW_SEC
            return f"좋아요! 이제부터 저는 {_subject(name)}. '{_calling(name)}' 하고 부르시면 대답할게요."
        if _has(NO_WORDS, t) or "틀렸" in t or "다시" in t:
            state.update(stage="ask")
            return "그럼 뭐라고 불러 주실래요? 다시 한 번 말씀해 주세요."
        # 확인 대신 새 이름을 말씀하신 경우 → 새 이름으로 다시 확인

    candidate = extract_name(text)
    try:
        candidate = validate_wake_name(candidate)
    except ValueError:
        state.update(stage="ask")
        return "잘 못 들었어요. '복실이'처럼 두세 글자 이름으로 다시 말씀해 주세요."
    state.update(stage="confirm", name=candidate)
    return f"'{candidate}'라고 부르시는 거 맞아요?"


def _norm(text: str) -> str:
    return re.sub(r"[\s.,!?~…'\"]", "", text or "")


def _has(words: list[str], t: str) -> bool:
    return any(w in t for w in words)


def _korean_time(hhmm: str) -> str:
    """'19:00' → '저녁 7시', '08:30' → '아침 8시 30분'"""
    m = re.match(r"(\d{1,2}):(\d{2})", hhmm or "")
    if not m:
        return hhmm
    h, mi = int(m.group(1)), int(m.group(2))
    part = "새벽" if h < 6 else "아침" if h < 11 else "낮" if h < 17 else "저녁" if h < 21 else "밤"
    h12 = h if h <= 12 else h - 12
    h12 = 12 if h12 == 0 else h12
    return f"{part} {h12}시" + (f" {mi}분" if mi else "")


def _hhmm_minutes(hhmm: str) -> int | None:
    m = re.match(r"(\d{1,2}):(\d{2})", hhmm or "")
    return int(m.group(1)) * 60 + int(m.group(2)) if m else None


def _load_profile(senior_id: int, user: User | None) -> dict:
    profile = {}
    if PROFILE_FILE.exists():
        try:
            profile = json.loads(PROFILE_FILE.read_text(encoding="utf-8")).get(str(senior_id), {})
        except Exception:
            profile = {}
    if not profile.get("호칭"):
        name = (user.nickname if user and user.nickname else "") or ""
        profile["호칭"] = f"{name}님" if name else "어르신"
    return profile


# ════════════════════════════════════════════════════════════
#  DB 기반 답변
# ════════════════════════════════════════════════════════════
async def _my_meds(db: AsyncSession, senior_id: int) -> list[Medicine]:
    res = await db.execute(select(Medicine).where(
        or_(Medicine.senior_id == senior_id, Medicine.senior_id.is_(None))))
    meds = res.scalars().all()
    return sorted(meds, key=lambda m: _hhmm_minutes((m.alarm_times or "").split(",")[0]) or 0)


async def _answer_med_query(db: AsyncSession, senior_id: int) -> str:
    meds = await _my_meds(db, senior_id)
    if not meds:
        return "등록된 약이 없어요. 보호자분께 약을 등록해 달라고 말씀드려 볼게요."
    left = [m for m in meds if not m.taken]
    if not left:
        return "오늘 드실 약은 모두 드셨어요. 잘하셨어요!"
    parts = [f"{_korean_time((m.alarm_times or '').split(',')[0])} {m.name}" for m in left[:3]]
    if len(left) > 3:
        return f"오늘 남은 약은 {', '.join(parts)} 말고도 {len(left) - 3}개가 더 있어요."
    return f"오늘 남은 약은 {', '.join(parts)}이에요."


async def _record_med_taken(db: AsyncSession, senior_id: int, t: str) -> str:
    meds = [m for m in await _my_meds(db, senior_id) if not m.taken]
    if not meds:
        return "오늘 약은 이미 다 드신 걸로 되어 있어요."
    # 약 이름을 말씀하셨으면 그 약 중에서 고른다 ("혈압약(저녁)" → "혈압약")
    named = [m for m in meds if re.sub(r"\(.*?\)", "", m.name or "") and re.sub(r"\(.*?\)", "", m.name) in t]
    cands = named or meds
    now_min = datetime.now().hour * 60 + datetime.now().minute
    minutes = lambda m: _hhmm_minutes((m.alarm_times or "").split(",")[0]) or 0
    # 복용 시간이 이미 지났거나 30분 안인 약 중 가장 최근 것, 없으면 가장 이른 것
    due = [m for m in cands if minutes(m) <= now_min + 30]
    target = max(due, key=minutes) if due else min(cands, key=minutes)
    target.taken = True
    await db.commit()
    return f"잘하셨어요! {target.name} 드신 걸로 기록해 둘게요."


def _sched_date_time(dt: str) -> tuple[str | None, str]:
    """'2026-10-08 14:00' → ('2026-10-08', '14:00'), '15:00' → (None, '15:00')"""
    dt = (dt or "").strip()
    m = re.match(r"(\d{4}-\d{2}-\d{2})[ T](\d{1,2}:\d{2})", dt)
    if m:
        return m.group(1), m.group(2)
    return None, dt[-5:] if len(dt) >= 4 else dt


async def _answer_sched_query(db: AsyncSession, senior_id: int, text: str) -> str:
    day = datetime.now() + timedelta(days=1 if "내일" in text else 0)
    day_str, label = day.strftime("%Y-%m-%d"), ("내일" if "내일" in text else "오늘")
    res = await db.execute(select(Schedule).where(
        or_(Schedule.senior_id == senior_id, Schedule.senior_id.is_(None)),
        Schedule.is_completed == False))  # noqa: E712
    items = []
    for s in res.scalars().all():
        d, t = _sched_date_time(s.datetime)
        if d == day_str:
            items.append((t, s.title))
    if not items:
        return f"{label}은 잡힌 일정이 없어요. 편하게 쉬세요."
    items.sort()
    parts = [f"{_korean_time(t)}에 {title}" for t, title in items[:3]]
    return f"{label}은 {', '.join(parts)} 일정이 있어요."


def _answer_time() -> str:
    now = datetime.now()
    wd = "월화수목금토일"[now.weekday()]
    return f"오늘은 {now.month}월 {now.day}일 {wd}요일이고, 지금은 {_korean_time(now.strftime('%H:%M'))}이에요."


async def _answer_weather() -> str:
    if not WEATHER_API_KEY:
        return "지금은 날씨 정보를 가져올 수 없어요. 나가실 땐 창밖을 한 번 봐 주세요."
    try:
        async with httpx.AsyncClient(timeout=4) as client:
            r = await client.get("https://api.openweathermap.org/data/2.5/weather",
                                 params={"q": "Busan,KR", "appid": WEATHER_API_KEY,
                                         "units": "metric", "lang": "kr"})
        d = r.json()
        temp, desc = round(d["main"]["temp"]), d["weather"][0]["description"]
        tip = " 우산 꼭 챙기세요." if "비" in desc else (" 따뜻하게 입으세요." if temp <= 10 else "")
        return f"오늘 부산은 {desc}, {temp}도예요.{tip}"
    except Exception:
        return "지금은 날씨 정보를 가져올 수 없어요. 나가실 땐 창밖을 한 번 봐 주세요."


async def _raise_alert(db: AsyncSession, senior_id: int, text: str) -> None:
    db.add(Alert(senior_id=senior_id, type="긴급",
                 message=f"어르신 음성 긴급 감지: \"{text}\"", is_resolved=False))
    await db.commit()


# ════════════════════════════════════════════════════════════
#  LLM
# ════════════════════════════════════════════════════════════
def _system_prompt(profile: dict, wake_name: str = DEFAULT_WAKE_NAME) -> str:
    now = datetime.now()
    lines = [
        f"너의 이름은 '{wake_name}'이야. {profile['호칭']}과 이야기하는 다정한 말벗이야.",
        "규칙:",
        "1. 한국어 존댓말, 쉬운 말로 1~2문장만 말해.",
        "2. 이모티콘, 영어, 기호, 목록을 쓰지 마.",
        "3. 약, 일정, 건강 수치는 절대 지어내지 마. 모르면 '보호자분께 확인해 볼게요'라고 해.",
        "4. 병을 진단하거나 약을 바꾸라고 하지 마.",
        "5. 외롭거나 슬프다고 하시면 해결책보다 먼저 마음을 알아드리고, 짧은 질문으로 이야기를 이어가.",
        "6. 전화나 연락처럼 실제로 하지 않은 일을 했다고 말하지 마.",
        f"지금: {now.month}월 {now.day}일 {_korean_time(now.strftime('%H:%M'))}",
    ]
    if profile.get("관심사"):
        lines.append(f"어르신 관심사: {profile['관심사']}")
    if profile.get("가족"):
        lines.append(f"가족: {profile['가족']}")
    if profile.get("기억"):
        lines.append(f"기억할 것: {profile['기억']}")
    return "\n".join(lines)


async def _recent_turns(db: AsyncSession, session_id: str, limit: int = 6) -> list[dict]:
    res = await db.execute(select(Conversation).where(Conversation.session_id == session_id)
                           .order_by(Conversation.id.desc()).limit(limit))
    turns = []
    for c in reversed(res.scalars().all()):
        try:
            turns.append({"role": "assistant" if c.role != "user" else "user",
                          "content": decrypt(c.content)})
        except Exception:
            continue
    return turns


def _clean_reply(text: str) -> str:
    text = re.sub(r"<think>.*?</think>", "", text or "", flags=re.S)   # 추론형 모델의 생각 부분 제거
    text = re.sub(r"[*#`>\-•]+", " ", text)
    text = re.sub(r"[\U0001F300-\U0001FAFF☀-➿]", "", text)   # 이모티콘 제거 (TTS가 읽지 않게)
    text = re.sub(r"\s+", " ", text).strip()
    sentences = re.split(r"(?<=[.!?요다])\s+", text)
    return " ".join(sentences[:3]).strip()


async def _call_llm(kind: str, messages: list[dict]) -> str:
    url, model, key, timeout = (
        (LOCAL_LLM_URL, LOCAL_LLM_MODEL, os.getenv("LOCAL_LLM_KEY", "none"), LOCAL_TIMEOUT)
        if kind == "local" else
        (CLOUD_LLM_URL, CLOUD_LLM_MODEL, CLOUD_LLM_KEY, CLOUD_TIMEOUT))
    if kind == "cloud" and not key:
        raise RuntimeError("클라우드 API 키가 없습니다")
    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.post(f"{url.rstrip('/')}/chat/completions",
                              headers={"Authorization": f"Bearer {key}"},
                              json={"model": model, "messages": messages,
                                    "max_tokens": 150, "temperature": 0.6})
        r.raise_for_status()
        return r.json()["choices"][0]["message"]["content"]


# 연결이 안 되는 쪽을 매번 기다리지 않도록, 실패하면 잠시 건너뛴다
_skip_until: dict[str, float] = {}
SKIP_SECONDS = 60


async def _ask_llm(messages: list[dict]) -> tuple[str, str, int]:
    """(대답, 사용한 쪽 'local'/'cloud'/'fallback', LLM 소요 ms)"""
    for kind in LLM_ORDER:
        if time.time() < _skip_until.get(kind, 0) and kind != LLM_ORDER[-1]:
            continue
        t0 = time.perf_counter()
        try:
            reply = _clean_reply(await _call_llm(kind, messages))
            if reply:
                return reply, kind, int((time.perf_counter() - t0) * 1000)
        except Exception as e:
            _skip_until[kind] = time.time() + SKIP_SECONDS
            print(f"[elder_engine] {kind} LLM 실패 ({SKIP_SECONDS}초간 건너뜀): {type(e).__name__}: {e}")
    return MSG_LLM_FAIL, "fallback", 0


# ════════════════════════════════════════════════════════════
#  메인 진입점
# ════════════════════════════════════════════════════════════
async def _save(db: AsyncSession, session_id: str, senior_id: int, role: str, text: str, ctype: str):
    db.add(Conversation(session_id=session_id, senior_id=senior_id, role=role,
                        content=encrypt(text), type=ctype))
    await db.commit()


async def reply(db: AsyncSession, text: str, session_id: str, senior_id: int,
                require_wake: bool = True) -> dict:
    started = time.perf_counter()
    t = _norm(text)
    intent, ctype, source, llm_ms = "chat", "생활정보", "rule", 0

    # ── 이름 짓기: 처음 켰을 때(이름 없음) 또는 이름 바꾸는 중 ──
    urgent_now = _has(EMERGENCY_WORDS, t) and "뻔" not in t
    if not urgent_now and len(t) >= 1:
        first_time = require_wake and not await is_wake_name_set(db)
        if session_id in _naming or first_time:
            if first_time and session_id not in _naming:
                _naming[session_id] = {"stage": "ask"}
                answer = "안녕하세요! 저를 뭐라고 불러 주실래요? 부르기 편한 이름을 지어 주세요."
            else:
                answer = await _naming_step(db, session_id, t, text)
            await _save(db, session_id, senior_id, "user", text, "생활정보")
            await _save(db, session_id, senior_id, "assistant", answer, "생활정보")
            return {"respond": True, "reply": answer, "intent": "naming", "source": "rule",
                    "wake_name": await get_wake_name(db),
                    "latency_ms": int((time.perf_counter() - started) * 1000), "llm_ms": 0}

    # ── 호출어: 이름을 부른 말에만 대답 ─────────────────────
    wake_name = await get_wake_name(db)
    if require_wake:
        awake = time.time() < _awake_until.get(session_id, 0) or session_id in _pending_confirm
        urgent = _has(EMERGENCY_WORDS, t) and "뻔" not in t
        found = find_wake_name(t, wake_name)
        if not (awake or found or urgent):
            return {"respond": False, "reply": "", "intent": "ignored", "source": "rule",
                    "wake_name": wake_name, "latency_ms": int((time.perf_counter() - started) * 1000),
                    "llm_ms": 0}
        if found:
            text = strip_wake_name(text, found)
            t = _norm(text)
            if len(t) < 2:                       # 이름만 불렀을 때
                _awake_until[session_id] = time.time() + WAKE_WINDOW_SEC
                answer = "네, 말씀하세요."
                await _save(db, session_id, senior_id, "assistant", answer, ctype)
                return {"respond": True, "reply": answer, "intent": "wake", "source": "rule",
                        "wake_name": wake_name, "latency_ms": int((time.perf_counter() - started) * 1000),
                        "llm_ms": 0}
        if RENAME_RE.search(t):                  # "네 이름 바꾸고 싶어"
            _naming[session_id] = {"stage": "ask"}
            answer = "좋아요. 그럼 뭐라고 불러 주실래요?"
            await _save(db, session_id, senior_id, "user", text, ctype)
            await _save(db, session_id, senior_id, "assistant", answer, ctype)
            return {"respond": True, "reply": answer, "intent": "naming", "source": "rule",
                    "wake_name": wake_name, "latency_ms": int((time.perf_counter() - started) * 1000),
                    "llm_ms": 0}
        if _has(END_WORDS, t) and len(t) <= 8:   # "그만", "잘 자" → 대화 끝
            _awake_until.pop(session_id, None)
            answer = f"네, 필요하시면 '{_calling(wake_name)}' 하고 불러 주세요."
            await _save(db, session_id, senior_id, "user", text, ctype)
            await _save(db, session_id, senior_id, "assistant", answer, ctype)
            return {"respond": True, "reply": answer, "intent": "sleep", "source": "rule",
                    "wake_name": wake_name, "latency_ms": int((time.perf_counter() - started) * 1000),
                    "llm_ms": 0}

    # 0) 직전에 "보호자분께 알릴까요?"라고 여쭤본 경우
    pending = _pending_confirm.pop(session_id, None)
    if pending and (t in YES_EXACT or _has(YES_WORDS, t)) and not _has(NO_WORDS, t):
        await _raise_alert(db, senior_id, pending["text"])
        intent, ctype = "emergency_confirmed", "긴급"
        answer = "보호자분 앱으로 알림을 보냈어요. 편한 자세로 쉬고 계세요."
    elif pending and _has(NO_WORDS, t):
        intent = "emergency_declined"
        answer = "알겠어요. 계속 안 좋으시면 언제든 저를 불러 주세요."

    # 1) 못 알아들음
    elif len(t) < 2:
        intent, answer = "unclear", MSG_UNCLEAR

    # 2) 위급
    elif _has(EMERGENCY_WORDS, t) and "뻔" not in t:
        await _raise_alert(db, senior_id, text)
        intent, ctype = "emergency", "긴급"
        answer = ("많이 놀라셨죠. 보호자분 앱으로 바로 알림을 보냈어요. "
                  + ("가스 밸브를 잠그고 밖으로 나가세요." if _has(FIRE_WORDS, t)
                     else "무리하게 움직이지 마시고 그 자리에 계세요."))

    # 3) 애매한 몸 상태 → 확인 질문
    elif SYMPTOM_RE.search(t) and not MED_RE.search(t):
        _pending_confirm[session_id] = {"text": text}
        intent, ctype = "symptom_check", "긴급"
        answer = "괜찮으세요? 많이 불편하시면 보호자분께 알려 드릴까요?"

    # 4) 약 먹었어
    elif MED_TAKEN_RE.search(t):
        intent, ctype, source = "med_taken", "복약", "db"
        answer = await _record_med_taken(db, senior_id, t)

    # 5) 약·일정·시간·날씨 질문
    elif MED_RE.search(t) and MED_ASK_RE.search(t):
        intent, ctype, source = "med_query", "복약", "db"
        answer = await _answer_med_query(db, senior_id)
    elif SCHED_RE.search(t):
        intent, ctype, source = "sched_query", "일정", "db"
        answer = await _answer_sched_query(db, senior_id, t)
    elif TIME_RE.search(t):
        intent, answer = "time", _answer_time()
    elif WEATHER_RE.search(t):
        intent, source = "weather", "api"
        answer = await _answer_weather()

    # 6) 일상 대화 → LLM
    else:
        res = await db.execute(select(User).where(User.id == senior_id))
        profile = _load_profile(senior_id, res.scalar_one_or_none())
        messages = ([{"role": "system", "content": _system_prompt(profile, wake_name)}]
                    + await _recent_turns(db, session_id)
                    + [{"role": "user", "content": text}])
        answer, source, llm_ms = await _ask_llm(messages)

    await _save(db, session_id, senior_id, "user", text, ctype)
    await _save(db, session_id, senior_id, "assistant", answer, ctype)
    if require_wake:                             # 대답한 뒤에는 이름 없이 이어서 말해도 됨
        _awake_until[session_id] = time.time() + WAKE_WINDOW_SEC

    return {
        "respond": True,
        "wake_name": wake_name,
        "reply": answer,
        "intent": intent,
        "source": source,            # rule | db | api | local | cloud | fallback
        "latency_ms": int((time.perf_counter() - started) * 1000),
        "llm_ms": llm_ms,
    }
