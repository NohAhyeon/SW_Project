"""
음성 인식(STT) 비교 측정 — 라즈베리파이에서 실행 (발표용 숫자)

준비
  1) stt_test/ 폴더에 녹음 파일(wav, 16kHz 모노 권장)과 정답 파일 answers.txt 를 둔다.
       answers.txt 한 줄에 하나:  파일이름|정답 문장
         01.wav|오늘 저녁에 무슨 약 먹어야 되는지 알려줘
         02.wav|내일 병원 가는 날이야
     (mic_test.py 로 녹음하거나 휴대폰 녹음을 wav 로 바꿔서 넣어도 된다. 어르신 목소리면 가장 좋다)
  2) 실행:
       python3 stt_benchmark.py stt_test whisper-small
       python3 stt_benchmark.py stt_test wav2vec2-senior
       GROQ_API_KEY=... python3 stt_benchmark.py stt_test groq     # 클라우드 Whisper large-v3

결과: 모델별 글자 오류율(CER, 낮을수록 좋음)과 한 문장당 받아쓰는 시간
  CER 10% = 100글자 중 10글자 틀림. 띄어쓰기·문장부호는 빼고 비교한다.
"""
import os
import re
import sys
import time
from pathlib import Path


def norm(t: str) -> str:
    return re.sub(r"[\s.,!?~'\"]", "", t or "")


def cer(ref: str, hyp: str) -> float:
    r, h = norm(ref), norm(hyp)
    if not r:
        return 0.0
    prev = list(range(len(h) + 1))
    for i, rc in enumerate(r, 1):
        cur = [i] + [0] * len(h)
        for j, hc in enumerate(h, 1):
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (rc != hc))
        prev = cur
    return prev[-1] / len(r)


def load_engine(name: str):
    """파일 경로를 받아 글자를 돌려주는 함수를 만든다"""
    if name == "groq":
        from groq import Groq
        client = Groq(api_key=os.environ["GROQ_API_KEY"])

        def run(path):
            with open(path, "rb") as f:
                return client.audio.transcriptions.create(
                    file=(Path(path).name, f.read()), model="whisper-large-v3", language="ko").text
        return run

    if name == "whisper-small":
        try:                                   # 빠른 버전이 있으면 우선 사용
            from faster_whisper import WhisperModel
            model = WhisperModel("small", device="cpu", compute_type="int8")
            return lambda p: " ".join(s.text for s in model.transcribe(p, language="ko")[0])
        except ImportError:
            from transformers import pipeline
            asr = pipeline("automatic-speech-recognition", model="openai/whisper-small")
            return lambda p: asr(p, generate_kwargs={"language": "korean", "task": "transcribe"})["text"]

    if name == "wav2vec2-senior":
        import soundfile as sf
        import torch
        from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor
        mid = "hyyoka/wav2vec2-xlsr-korean-senior"
        proc, model = Wav2Vec2Processor.from_pretrained(mid), Wav2Vec2ForCTC.from_pretrained(mid)

        def run(path):
            audio, sr = sf.read(path, dtype="float32")
            if audio.ndim > 1:
                audio = audio.mean(axis=1)
            if sr != 16000:
                from scipy.signal import resample_poly
                audio = resample_poly(audio, 16000, sr)
            inputs = proc(audio, sampling_rate=16000, return_tensors="pt")
            with torch.no_grad():
                ids = model(inputs.input_values).logits.argmax(-1)
            return proc.batch_decode(ids)[0]
        return run

    sys.exit(f"모르는 엔진: {name}  (groq / whisper-small / wav2vec2-senior)")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    folder, engine = Path(sys.argv[1]), sys.argv[2]
    pairs = [l.split("|", 1) for l in (folder / "answers.txt").read_text(encoding="utf-8").splitlines() if "|" in l]
    print(f"[{engine}] 모델 불러오는 중…")
    run = load_engine(engine)
    run(str(folder / pairs[0][0]))              # 첫 실행 준비(측정에서 제외)

    total_err, times = [], []
    for fname, ref in pairs:
        t0 = time.perf_counter()
        hyp = run(str(folder / fname))
        times.append(time.perf_counter() - t0)
        e = cer(ref, hyp)
        total_err.append(e)
        print(f"  {fname}: CER {e * 100:5.1f}%  {times[-1]:.1f}초  | 정답: {ref} | 인식: {hyp.strip()}")
    print(f"\n[{engine}] 평균 CER {sum(total_err) / len(total_err) * 100:.1f}%  /  "
          f"평균 {sum(times) / len(times):.1f}초  ({len(pairs)}문장)")


if __name__ == "__main__":
    main()
