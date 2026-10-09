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
import asyncio
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

import dialect
from crypto import decrypt, encrypt
from database import AsyncSessionLocal
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
SYMPTOM_RE      = re.compile(r"어지러|어지럽|아파(?!트)|아프|토할|열이나|몸이안좋|기운이없|힘이없")
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


# 받아쓰기는 글자가 달라도 소리는 같은 경우가 많다 (지니↔진이, 복실아↔복시라, 찌니↔지니)
#   → 발음 기준 문자열로 바꿔서 비교한다
_TENSE = {"ᄁ": "ᄀ", "ᄄ": "ᄃ", "ᄈ": "ᄇ", "ᄊ": "ᄉ", "ᄍ": "ᄌ"}          # 된소리 → 예사소리
_VOWEL = {"ᅢ": "ᅦ", "ᅤ": "ᅨ", "ᅫ": "ᅰ", "ᅬ": "ᅰ"}                    # 헷갈리는 모음 합치기
_JONG_TO_CHO = {"ᆨ": "ᄀ", "ᆫ": "ᄂ", "ᆮ": "ᄃ", "ᆯ": "ᄅ", "ᆷ": "ᄆ", "ᆸ": "ᄇ",
                "ᆺ": "ᄉ", "ᆻ": "ᄉ", "ᆽ": "ᄌ", "ᆾ": "ᄌ", "ᆿ": "ᄀ", "ᇀ": "ᄃ",
                "ᇁ": "ᄇ", "ᇂ": "", "ᆩ": "ᄀ", "ᆼ": "ᆼ"}


def _phon(s: str) -> str:
    """발음 기준 문자열: 받침은 다음 글자로 넘어가는 소리처럼, 첫소리 ㅇ 은 소리가 없으니 뺀다"""
    out = []
    for ch in _jamo(s):
        if ch == "ᄋ":
            continue
        ch = _JONG_TO_CHO.get(ch, ch)
        out.append(_VOWEL.get(_TENSE.get(ch, ch), _TENSE.get(ch, ch)))
    return "".join(out)


def find_wake_name(t: str, name: str):
    """띄어쓰기 없앤 문장 t 에서 이름을 찾는다 → 찾은 부분 문자열(원래 글자) 또는 None.
    ① 글자가 같거나 ② 발음이 같으면 인정 (지니 ↔ 진이·찌니)
    ③ 3글자 이상 이름은 발음이 조금 달라도 인정 (오아시스 ↔ 오아시쓰·아시스)"""
    name = _norm(name)
    if not name:
        return None
    if name in t:
        return name
    target = _phon(name)
    windows = [t[i:i + size] for size in (len(name) - 1, len(name), len(name) + 1) if size > 0
               for i in range(0, max(len(t) - size + 1, 0))]
    for sub in windows:                                  # 발음이 똑같은 부분
        if _phon(sub) == target:
            return sub
    if len(name) < 3:                                    # 2글자 이름은 발음이 같을 때만 (오작동 방지)
        return None
    best, best_ratio = None, 0.0
    for sub in windows:
        ratio = SequenceMatcher(None, _phon(sub), target).ratio()
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
NAMING_TIMEOUT_SEC = 60              # 이름을 여쭤본 뒤 이 시간이 지나면 이름 짓기를 그만두고 평소 대화로
NAME_YES = ["맞아", "맞다", "맞네", "맞어", "맞습", "맞지", "그래", "그렇지", "그렇다", "좋아", "좋다", "하모", "오냐"]


def _strip_fillers(t: str) -> str:
    """음성 인식 앞뒤에 붙는 '아', '어', '음' 같은 군말 제거 ('아어맞다' → '맞다')"""
    return re.sub(r"^(아|어|음|으|에|저기|그)+(?=.)", "", t)


def _naming_yes(t: str) -> bool:
    core = _strip_fillers(t)
    return t in YES_EXACT or core in YES_EXACT or (_has(NAME_YES, core) and not _has(["아니", "틀렸"], core))


def _naming_cancel(t: str) -> bool:
    """짧은 말에서만 취소로 본다 ('나중에 고양이 키우고 싶어' 같은 긴 말은 취소 아님)"""
    return len(t) <= 8 and _has(CANCEL_WORDS, t)
# 한 번에 새 이름까지 말할 때: "이름을 철수로 바꿔줘", "네 이름 철수로 해", "이제부터 철수라고 부를게"
RENAME_TO_RE = [
    re.compile(r"이름(을|은|좀)?(?P<n>[가-힣A-Za-z]{2,6}?)(으로|로|라고)(바꿔|바꾸|바꿀|해|하자|할게|정해|정할게|부를게|불러)"),
    re.compile(r"(이제부터|앞으로|지금부터)(너|넌|너는|니|니는)?(?P<n>[가-힣A-Za-z]{2,6}?)(라고)(부를게|불러줄게|할게|해)"),
]


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
    state["at"] = time.time()
    if _naming_cancel(t):
        _naming.pop(session_id, None)
        if not await is_wake_name_set(db):
            await set_wake_name(db, DEFAULT_WAKE_NAME)
        name = await get_wake_name(db)
        return f"알겠어요. 그럼 '{_calling(name)}' 하고 불러 주세요."

    if state["stage"] == "confirm":
        if _naming_yes(t):
            name = await set_wake_name(db, state["name"])
            _naming.pop(session_id, None)
            _awake_until[session_id] = time.time() + WAKE_WINDOW_SEC
            return f"좋아요! 이제부터 저는 {_subject(name)}. '{_calling(name)}' 하고 부르시면 대답할게요."
        if _has(NO_WORDS, t) or "틀렸" in t or "다시" in t:
            state.update(stage="ask")
            return "그럼 뭐라고 불러 주실래요? 다시 한 번 말씀해 주세요."
        # 확인 대신 새 이름을 말씀하신 경우 → 새 이름으로 다시 확인 (짧은 말일 때만)
        if len(extract_name(text)) > 6:
            return f"'{state['name']}'가 맞으면 '응', 아니면 '아니'라고 말씀해 주세요."

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
        "7. 어르신이 말하지 않은 일을 하셨다고 단정하지 마. 관심사와 기억은 참고만 하고 궁금하면 여쭤봐.",
        f"8. 어르신은 {profile.get('지역') or '부산'} 분이라 경상도 사투리를 쓰실 수 있어. "
        "('묵다'=먹다, '머라카노'=뭐라고, '고마'=그만, '하모'=그럼, '단디'=단단히, '쪼매'=조금) "
        "사투리를 그대로 알아듣고, 대답은 알아듣기 쉬운 표준어 존댓말로 해.",
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
#  돌봄 대화 기능
#   ① "뭐라고?" → 직전 대답을 짧게, 천천히 다시
#   ② 먼저 말 걸기: 약 시간 확인 / 아침 인사 / 기억 기반 안부  (파이가 30초마다 /talk/proactive 확인)
#   ③ 장기기억: 대화 중 안부로 물어볼 만한 사실을 뽑아 저장 → 다음 대화·안부에 사용
#   ④ 밤 시간(QUIET_START~QUIET_END)과 "조용히" 이후에는 먼저 말 걸지 않기
#   ⑤ 보호자 일일 요약
# ════════════════════════════════════════════════════════════
REPEAT_RE   = re.compile(r"뭐라고|다시말해|다시한번|한번더말|못들었|잘안들|안들려|크게말|천천히말|뭐라했")
QUIET_START = int(os.getenv("QUIET_START", "22"))      # 22시부터
QUIET_END   = int(os.getenv("QUIET_END", "7"))         # 아침 7시까지는 먼저 말 걸지 않음
MUTE_SEC    = 2 * 60 * 60                              # "조용히" 하면 2시간 동안 먼저 말 걸지 않음
MED_ASK_WINDOW_MIN = 60                                # 약 시간부터 60분 안에 한 번 여쭤봄

_last_reply: dict[str, str] = {}
_muted_until: dict[str, float] = {}
_pending_med: dict[str, int] = {}                      # 세션 → "약 드셨어요?" 라고 여쭤본 약 id
_proactive_done: set[tuple] = set()                    # (어르신, 날짜, 종류[, 약 id]) 오늘 이미 한 것

MEMORY_HINT_RE = re.compile(r"아프|아파|병원|수술|약|손녀|손자|아들|딸|며느리|사위|가족|친구|외롭|슬프|"
                            r"우울|기분|잠|못잤|밥|산책|생일|제사|모임|여행|온대|온다|간대|간다|약속|넘어|다쳤")
POSITIVE = ["좋아", "좋다", "기쁘", "행복", "고마", "재밌", "맛있", "신나", "반가"]
NEGATIVE = ["외롭", "슬프", "아프", "아파", "힘들", "우울", "속상", "무서", "걱정", "못잤", "심심"]


def _short(text: str, n: int = 2) -> str:
    parts = re.split(r"(?<=[.!?요다])\s+", text.strip())
    return " ".join(parts[:n])


def _is_quiet(now: datetime | None = None) -> bool:
    h = (now or datetime.now()).hour
    return h >= QUIET_START or h < QUIET_END


# ── 장기기억 (settings 테이블 key = "memory:<어르신id>", JSON 목록) ──
async def load_memories(db: AsyncSession, senior_id: int) -> list[dict]:
    res = await db.execute(select(Setting).where(Setting.key == f"memory:{senior_id}"))
    row = res.scalar_one_or_none()
    try:
        return json.loads(row.value) if row and row.value else []
    except ValueError:
        return []


async def save_memories(db: AsyncSession, senior_id: int, items: list[dict]) -> None:
    key = f"memory:{senior_id}"
    res = await db.execute(select(Setting).where(Setting.key == key))
    row = res.scalar_one_or_none()
    value = json.dumps(items[-30:], ensure_ascii=False)     # 최근 30개만 유지
    if row:
        row.value = value
    else:
        db.add(Setting(key=key, value=value))
    await db.commit()


async def _extract_memory(text: str) -> str | None:
    """어르신 말에서 나중에 안부로 여쭐 만한 사실을 '~하셨어요.' 한 문장으로 뽑는다"""
    prompt = ("아래는 어르신이 한 말이야. 며칠 뒤 안부를 여쭐 때 쓸 만한 사실(건강 상태, 가족·지인 소식, "
              "약속·계획, 기분)이 있으면 '무릎이 아프다고 하셨어요.' 처럼 '~하셨어요.' 로 끝나는 짧은 한 문장으로 써. "
              "없으면 '없음' 이라고만 써.\n어르신: " + text)
    fact, _, _ = await _ask_llm([{"role": "user", "content": prompt}])
    fact = fact.strip().strip('"').split("\n")[0]
    if not fact or "없음" in fact or fact == MSG_LLM_FAIL or len(fact) < 6:
        return None
    return fact


async def _remember_later(senior_id: int, text: str) -> None:
    """대답을 먼저 돌려준 뒤 뒤에서 조용히 기억을 저장 (응답 속도에 영향 없음)"""
    try:
        fact = await _extract_memory(text)
        if not fact:
            return
        async with AsyncSessionLocal() as db:
            items = await load_memories(db, senior_id)
            if any(m["fact"] == fact for m in items):
                return
            items.append({"fact": fact, "date": datetime.now().strftime("%Y-%m-%d")})
            await save_memories(db, senior_id, items)
            print(f"[기억 저장] {fact}")
    except Exception as e:
        print(f"[기억 저장 실패] {e}")


# ── 먼저 말 걸기 ─────────────────────────────────────────────
async def _profile_for(db: AsyncSession, senior_id: int) -> dict:
    res = await db.execute(select(User).where(User.id == senior_id))
    return _load_profile(senior_id, res.scalar_one_or_none())


async def proactive(db: AsyncSession, session_id: str, senior_id: int, force: str | None = None) -> dict:
    """기기가 30초마다 호출. 지금 먼저 할 말이 있으면 say 에 담아 준다.
    force: 'med' | 'message' | 'morning' | 'checkin' — 시연용으로 시간 조건을 무시하고 바로 실행"""
    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    if not force and (_is_quiet(now) or time.time() < _muted_until.get(session_id, 0)):
        return {"say": None, "kind": None, "reason": "quiet"}
    profile = await _profile_for(db, senior_id)
    who = profile["호칭"]
    say, kind = None, None

    # 1) 약 시간: 복용 시간이 지났고(60분 안) 아직 안 드신 약
    if force in (None, "med"):
        now_min = now.hour * 60 + now.minute
        for m in await _my_meds(db, senior_id):
            due = _hhmm_minutes((m.alarm_times or "").split(",")[0])
            if m.taken or due is None or (senior_id, today, "med", m.id) in _proactive_done:
                continue
            if force == "med" or 0 <= now_min - due <= MED_ASK_WINDOW_MIN:
                _proactive_done.add((senior_id, today, "med", m.id))
                _pending_med[session_id] = m.id
                say, kind = f"{who}, {m.name} 드실 시간이에요. 드셨어요?", "med"
                break

    # 1-1) 보호자가 보낸 메시지 읽어 드리기
    if not say and force in (None, "message"):
        msg_say = await _deliver_message(db, session_id, senior_id, who)
        if msg_say:
            say, kind = msg_say, "message"

    # 2) 아침 인사 (7~11시, 하루 한 번) + 오늘 일정
    if not say and force in (None, "morning") and \
            (force == "morning" or (7 <= now.hour < 11 and (senior_id, today, "morning") not in _proactive_done)):
        _proactive_done.add((senior_id, today, "morning"))
        sched = await _answer_sched_query(db, senior_id, "오늘")
        say, kind = f"좋은 아침이에요, {who}! 잘 주무셨어요? {sched}", "morning"

    # 3) 기억 기반 안부 (13~20시, 하루 한 번, 오늘 이전에 저장된 기억)
    if not say and force in (None, "checkin") and \
            (force == "checkin" or (13 <= now.hour < 20 and (senior_id, today, "checkin") not in _proactive_done)):
        past = [m for m in await load_memories(db, senior_id) if force == "checkin" or m["date"] < today]
        if past:
            _proactive_done.add((senior_id, today, "checkin"))
            health = [m for m in past if re.search(r"아프|아파|병원|잠|못잤|기분|힘들|어지러|다쳤|넘어", m["fact"])]
            pick = (health or past)[-1]["fact"]
            ask = "오늘은 좀 어떠세요?" if health else "어떻게 되셨는지 궁금해요."
            say, kind = f"{who}, 지난번에 {pick} {ask}", "checkin"

    if say:
        _awake_until[session_id] = time.time() + WAKE_WINDOW_SEC    # 이름 없이 바로 대답하실 수 있게
        _last_reply[session_id] = say
        await _save(db, session_id, senior_id, "assistant", say, "복약" if kind == "med" else "생활정보")
    return {"say": say, "kind": kind}


# ── 보호자 일일 요약 ─────────────────────────────────────────
_summary_cache: dict[tuple, tuple] = {}


async def daily_summary(db: AsyncSession, senior_id: int, day: str | None = None) -> dict:
    day = day or datetime.now().strftime("%Y-%m-%d")
    res = await db.execute(select(Conversation).where(
        or_(Conversation.senior_id == senior_id, Conversation.senior_id.is_(None))).order_by(Conversation.id))
    all_convs = res.scalars().all()
    convs = [c for c in all_convs if str(c.created_at or "").startswith(day)]
    last_user = next((c for c in reversed(all_convs) if c.role == "user"), None)
    said = []
    for c in convs:
        if c.role == "user":
            try:
                said.append(decrypt(c.content))
            except Exception:
                pass
    topics: dict[str, int] = {}
    for c in convs:
        if c.role == "user":
            topics[c.type or "생활정보"] = topics.get(c.type or "생활정보", 0) + 1
    joined = _norm(dialect.normalize(" ".join(said)))
    joined = re.sub(r"걱정(말|마|하지마|안해|없)", "", joined)    # '걱정 말라'는 나쁜 기분이 아님
    pos, neg = sum(joined.count(w) for w in POSITIVE), sum(joined.count(w) for w in NEGATIVE)
    mood = "대화 없음" if not said else ("좋아 보여요" if pos > neg else "살펴봐 주세요" if neg > pos else "보통이에요")

    meds = await _my_meds(db, senior_id)
    res = await db.execute(select(Alert))
    urgent = [a for a in res.scalars().all()
              if str(a.created_at or "").startswith(day) and a.type in ("긴급", "위급", "가스감지", "가스", "낙상")]
    memories = [m["fact"] for m in await load_memories(db, senior_id) if m["date"] == day]

    # 한두 문장 요약 (대화 수가 바뀔 때만 다시 만든다)
    key = (senior_id, day)
    if key in _summary_cache and _summary_cache[key][0] == len(said):
        text = _summary_cache[key][1]
    elif said:
        prompt = ("아래는 오늘 어르신이 AI 말벗에게 한 말들이야. 보호자에게 전하듯 어르신의 하루와 기분을 "
                  "존댓말 두 문장 이내로 요약해. 진단하지 말고, 없는 내용은 지어내지 마.\n- " + "\n- ".join(said[-30:]))
        text, _, _ = await _ask_llm([{"role": "user", "content": prompt}])
        if text == MSG_LLM_FAIL:
            text = f"오늘 {len(said)}번 대화하셨어요."
        _summary_cache[key] = (len(said), text)
    else:
        text = "오늘은 아직 대화가 없어요."

    return {
        "date": day,
        "talk_count": len(said),
        "topics": topics,
        "mood": mood,
        "med_taken": sum(1 for m in meds if m.taken),
        "med_total": len(meds),
        "urgent_count": len(urgent),
        "new_memories": memories,
        "summary": text,
        "wake_name": await get_wake_name(db),
        "last_talk_at": str(last_user.created_at)[:16] if last_user and last_user.created_at else None,
    }


# ════════════════════════════════════════════════════════════
#  보호자 ↔ 어르신 음성 메시지
#   - 보호자가 앱에서 글을 보내면 → 기기가 먼저 말 걸기로 읽어 드리고 "답장하실 말씀 있으세요?"
#   - 어르신 대답은 답장으로 저장 → 보호자 앱에 표시
#   - 어르신이 먼저 "딸한테 저녁 먹었다고 전해 줘" 해도 보호자 앱으로 전달
#   - 저장: settings 테이블 key = "messages:<어르신id>" (JSON 목록, 최근 50개)
# ════════════════════════════════════════════════════════════
RELAY_REPLY_SEC = 45                                   # 읽어 드린 뒤 답장을 기다리는 시간
RELAY_VERB = r"(전해|전하|말해|알려|얘기해|이야기해)\s*(줘|주라|도|도고|다오|주이소|주세요|드려|라|요)?"
SEND_RE  = re.compile(r"^(?P<to>\S+?)(한테|에게|께|보고)\s+(?P<msg>.+?)\s*" + RELAY_VERB + r"\s*[.!?~]*$")
REPLY_TAIL_RE = re.compile(r"\s*(좀\s*)?" + RELAY_VERB + r"\s*[.!?~]*$")
FAMILY_RE = re.compile(r"아들|딸|며느리|사위|손녀|손자|보호자|자식|애들|큰애|작은애|아가|영감|할배|할매|언니|오빠|동생|형|누나")
_pending_relay: dict[str, tuple[int, float]] = {}      # 세션 → (답장 기다리는 메시지 id, 마감 시각)


async def load_messages(db: AsyncSession, senior_id: int) -> list[dict]:
    res = await db.execute(select(Setting).where(Setting.key == f"messages:{senior_id}"))
    row = res.scalar_one_or_none()
    try:
        return json.loads(row.value) if row and row.value else []
    except ValueError:
        return []


async def _save_messages(db: AsyncSession, senior_id: int, items: list[dict]) -> None:
    key = f"messages:{senior_id}"
    res = await db.execute(select(Setting).where(Setting.key == key))
    row = res.scalar_one_or_none()
    value = json.dumps(items[-50:], ensure_ascii=False)
    if row:
        row.value = value
    else:
        db.add(Setting(key=key, value=value))
    await db.commit()


async def send_guardian_message(db: AsyncSession, senior_id: int, text: str, sender: str = "") -> dict:
    """보호자 → 어르신 (앱에서 호출)"""
    text = (text or "").strip()
    if not text:
        raise ValueError("보낼 내용을 입력해 주세요.")
    if len(text) > 100:
        raise ValueError("어르신이 듣기 편하게 100자 이내로 써 주세요.")
    items = await load_messages(db, senior_id)
    msg = {"id": max([m["id"] for m in items], default=0) + 1, "from": "guardian",
           "sender": (sender or "").strip()[:10], "text": text,
           "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
           "delivered_at": None, "reply": None, "reply_at": None}
    items.append(msg)
    await _save_messages(db, senior_id, items)
    return msg


def _relay_body(text: str) -> str:
    """'알았다고 전해 도' → '알았다'"""
    body = REPLY_TAIL_RE.sub("", text.strip())
    body = re.sub(r"(?<=[다라냐자요])고$", "", body.strip())     # '먹었다고' → '먹었다', '말라고' → '말라'
    return re.sub(r"[\s,.!?~]+$", "", body).strip() or text.strip()


async def _deliver_message(db: AsyncSession, session_id: str, senior_id: int, who: str) -> str | None:
    """아직 읽어 드리지 않은 보호자 메시지가 있으면 읽어 드릴 문장을 만든다"""
    items = await load_messages(db, senior_id)
    msg = next((m for m in items if m["from"] == "guardian" and not m["delivered_at"]), None)
    if not msg:
        return None
    msg["delivered_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    await _save_messages(db, senior_id, items)
    _pending_relay[session_id] = (msg["id"], time.time() + RELAY_REPLY_SEC)
    sender = f"{msg['sender']}님이" if msg["sender"] else "보호자분이"
    return f"{who}, {sender} 메시지를 보내셨어요. \"{msg['text']}\" 답장하실 말씀 있으세요?"


async def _save_reply(db: AsyncSession, senior_id: int, msg_id: int, text: str) -> None:
    items = await load_messages(db, senior_id)
    for m in items:
        if m["id"] == msg_id:
            m["reply"], m["reply_at"] = text, datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    await _save_messages(db, senior_id, items)


async def _send_senior_message(db: AsyncSession, senior_id: int, to: str, text: str) -> None:
    """어르신 → 보호자 ("딸한테 ~ 전해 줘")"""
    items = await load_messages(db, senior_id)
    items.append({"id": max([m["id"] for m in items], default=0) + 1, "from": "senior", "sender": to,
                  "text": text, "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                  "delivered_at": None, "reply": None, "reply_at": None})
    await _save_messages(db, senior_id, items)


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
    std = dialect.normalize(text)                # 사투리 → 표준어 (규칙 판단용, 저장·LLM 에는 원래 말)
    t = _norm(std)
    intent, ctype, source, llm_ms = "chat", "생활정보", "rule", 0

    # ── 이름 짓기: 처음 켰을 때(이름 없음) 또는 이름 바꾸는 중 ──
    urgent_now = _has(EMERGENCY_WORDS, t) and "뻔" not in t
    if not urgent_now and len(t) >= 1:
        first_time = require_wake and not await is_wake_name_set(db)
        st = _naming.get(session_id)
        if st and not first_time and time.time() - st.get("at", time.time()) > NAMING_TIMEOUT_SEC:
            _naming.pop(session_id, None)          # 오래 전에 여쭤본 이름 짓기는 끝내고 평소 대화로
        if session_id in _naming or first_time:
            if first_time and session_id not in _naming:
                _naming[session_id] = {"stage": "ask", "at": time.time()}
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
        relay_wait = _pending_relay.get(session_id)
        awake = (time.time() < _awake_until.get(session_id, 0) or session_id in _pending_confirm
                 or session_id in _pending_med       # 먼저 여쭤본 질문에는 이름 없이 대답 가능
                 or (relay_wait and time.time() < relay_wait[1]))
        urgent = _has(EMERGENCY_WORDS, t) and "뻔" not in t
        found = find_wake_name(_norm(text), wake_name) or find_wake_name(t, wake_name)
        if not (awake or found or urgent):
            return {"respond": False, "reply": "", "intent": "ignored", "source": "rule",
                    "wake_name": wake_name, "latency_ms": int((time.perf_counter() - started) * 1000),
                    "llm_ms": 0}
        if found:
            text = strip_wake_name(text, found)
            std = dialect.normalize(text)
            t = _norm(std)
            if len(t) < 2:                       # 이름만 불렀을 때
                _awake_until[session_id] = time.time() + WAKE_WINDOW_SEC
                answer = "네, 말씀하세요."
                await _save(db, session_id, senior_id, "assistant", answer, ctype)
                return {"respond": True, "reply": answer, "intent": "wake", "source": "rule",
                        "wake_name": wake_name, "latency_ms": int((time.perf_counter() - started) * 1000),
                        "llm_ms": 0}
        new_name = next((m.group("n") for r in RENAME_TO_RE if (m := r.search(t))), None)
        if new_name:                             # "이름을 철수로 바꿔줘" → 바로 확인
            try:
                new_name = validate_wake_name(new_name)
                _naming[session_id] = {"stage": "confirm", "name": new_name, "at": time.time()}
                answer = f"'{new_name}'라고 부르시는 거 맞아요?"
            except ValueError:
                _naming[session_id] = {"stage": "ask", "at": time.time()}
                answer = "좋아요. 그럼 뭐라고 불러 주실래요?"
            await _save(db, session_id, senior_id, "user", text, ctype)
            await _save(db, session_id, senior_id, "assistant", answer, ctype)
            return {"respond": True, "reply": answer, "intent": "naming", "source": "rule",
                    "wake_name": wake_name, "latency_ms": int((time.perf_counter() - started) * 1000),
                    "llm_ms": 0}
        if RENAME_RE.search(t):                  # "네 이름 바꾸고 싶어"
            _naming[session_id] = {"stage": "ask", "at": time.time()}
            answer = "좋아요. 그럼 뭐라고 불러 주실래요?"
            await _save(db, session_id, senior_id, "user", text, ctype)
            await _save(db, session_id, senior_id, "assistant", answer, ctype)
            return {"respond": True, "reply": answer, "intent": "naming", "source": "rule",
                    "wake_name": wake_name, "latency_ms": int((time.perf_counter() - started) * 1000),
                    "llm_ms": 0}
        if _has(END_WORDS, t) and len(t) <= 8:   # "그만", "잘 자" → 대화 끝
            _awake_until.pop(session_id, None)
            if "조용히" in t or "잘자" in t:          # 먼저 말 걸기도 잠시 멈춤
                _muted_until[session_id] = time.time() + MUTE_SEC
            answer = f"네, 필요하시면 '{_calling(wake_name)}' 하고 불러 주세요."
            await _save(db, session_id, senior_id, "user", text, ctype)
            await _save(db, session_id, senior_id, "assistant", answer, ctype)
            return {"respond": True, "reply": answer, "intent": "sleep", "source": "rule",
                    "wake_name": wake_name, "latency_ms": int((time.perf_counter() - started) * 1000),
                    "llm_ms": 0}

    # 다시 말해 달라고 하시면 → 직전 대답을 짧게, 천천히
    if REPEAT_RE.search(t) and len(t) <= 15 and session_id in _last_reply:
        answer = _short(_last_reply[session_id])
        await _save(db, session_id, senior_id, "user", text, ctype)
        await _save(db, session_id, senior_id, "assistant", answer, ctype)
        _awake_until[session_id] = time.time() + WAKE_WINDOW_SEC
        return {"respond": True, "reply": answer, "intent": "repeat", "source": "rule",
                "speak_rate": "slow", "wake_name": wake_name, "heard_as": std if std != text.strip() else None,
                "latency_ms": int((time.perf_counter() - started) * 1000), "llm_ms": 0}

    # 0) 직전에 "보호자분께 알릴까요?" / "약 드셨어요?" 라고 여쭤본 경우
    med_pending = _pending_med.pop(session_id, None)
    pending = _pending_confirm.pop(session_id, None)
    relay = _pending_relay.pop(session_id, None)
    relay = relay if relay and time.time() < relay[1] else None
    send = SEND_RE.match(std)
    urgent_said = _has(EMERGENCY_WORDS, t) and "뻔" not in t
    said_no = _has(["아직", "안먹", "아니", "깜빡", "까먹"], t)
    if med_pending and not said_no and (t in YES_EXACT or "먹었" in t or "드셨" in t
                                        or t.startswith(("응", "네", "어", "그래", "예"))):
        med = next((m for m in await _my_meds(db, senior_id) if m.id == med_pending), None)
        if med:
            med.taken = True
            await db.commit()
        intent, ctype, source = "med_taken", "복약", "db"
        answer = f"잘하셨어요! {med.name if med else '약'} 드신 걸로 기록해 둘게요."
    elif med_pending and said_no:
        intent, ctype = "med_not_yet", "복약"
        answer = "지금 드시면 좋겠어요. 드시고 나서 '먹었어' 하고 말씀해 주세요."
    elif pending and (t in YES_EXACT or _has(YES_WORDS, t)) and not _has(NO_WORDS, t):
        await _raise_alert(db, senior_id, pending["text"])
        intent, ctype = "emergency_confirmed", "긴급"
        answer = "보호자분 앱으로 알림을 보냈어요. 편한 자세로 쉬고 계세요."
    elif pending and _has(NO_WORDS, t):
        intent = "emergency_declined"
        answer = "알겠어요. 계속 안 좋으시면 언제든 저를 불러 주세요."

    # 0-1) 보호자 메시지를 읽어 드린 뒤의 대답 → 답장으로 저장
    elif relay and not urgent_said and len(t) >= 2:
        if (t in YES_EXACT or _has(["없어", "없다", "됐어", "괜찮", "아니"], t)) and len(t) <= 6:
            intent, ctype = "relay_none", "생활정보"
            answer = "알겠어요. 메시지 잘 들으셨다고 보호자분께 표시해 둘게요."
            await _save_reply(db, senior_id, relay[0], "(잘 들으셨어요)")
        else:
            body = _relay_body(text)
            await _save_reply(db, senior_id, relay[0], body)
            intent, ctype, source = "relay_reply", "생활정보", "db"
            answer = f"네, \"{body}\" 하고 보호자분 앱으로 전해 드렸어요."

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

    # 2-1) "딸한테 저녁 먹었다고 전해 줘" → 보호자 앱으로 전달
    elif send and FAMILY_RE.search(send.group("to")):
        to = send.group("to")
        body = _relay_body(text.split(maxsplit=1)[1] if len(text.split(maxsplit=1)) > 1 else text)
        await _send_senior_message(db, senior_id, to, body)
        intent, ctype, source = "relay_send", "생활정보", "db"
        answer = f"네, {to}한테 \"{body}\" 하고 앱으로 전해 드렸어요."

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
        recent_mem = [m["fact"] for m in (await load_memories(db, senior_id))[-5:]]
        if recent_mem:
            profile["기억"] = " / ".join(filter(None, [profile.get("기억"), *recent_mem]))
        messages = ([{"role": "system", "content": _system_prompt(profile, wake_name)}]
                    + await _recent_turns(db, session_id)
                    + [{"role": "user", "content": text}])
        answer, source, llm_ms = await _ask_llm(messages)

    await _save(db, session_id, senior_id, "user", text, ctype)
    await _save(db, session_id, senior_id, "assistant", answer, ctype)
    if require_wake:                             # 대답한 뒤에는 이름 없이 이어서 말해도 됨
        _awake_until[session_id] = time.time() + WAKE_WINDOW_SEC
    _last_reply[session_id] = answer
    # 기억할 만한 말(건강·가족·약속·기분)이면 대답을 먼저 돌려준 뒤 뒤에서 저장
    if intent in ("chat", "symptom_check", "emergency", "emergency_declined") and MEMORY_HINT_RE.search(t):
        asyncio.create_task(_remember_later(senior_id, text))

    return {
        "respond": True,
        "speak_rate": "normal",
        "wake_name": wake_name,
        "reply": answer,
        "intent": intent,
        "source": source,            # rule | db | api | local | cloud | fallback
        "latency_ms": int((time.perf_counter() - started) * 1000),
        "llm_ms": llm_ms,
        "heard_as": std if std != text.strip() else None,   # 사투리를 표준어로 바꿔 알아들은 경우
    }
