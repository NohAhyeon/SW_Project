"""
마이크 비교 도구 (라즈베리파이용) — 웹캠 내장 마이크 vs 기존 마이크, 어느 쪽이 음성 인식에 좋은가

사용법
  1) 마이크 목록 보기:           python3 mic_test.py
  2) 마이크 하나 녹음·측정:       python3 mic_test.py 2        (2 = 목록의 번호)
  3) 두 마이크 비교:             python3 mic_test.py 2 3
     → 각 마이크마다 '조용히 2초' + '문장 읽기 5초' 를 녹음하고
       잡음 크기, 목소리 크기, 신호 대 잡음비(SNR), 잘림(클리핑)을 비교한다.
     → 녹음 파일(mic_<번호>.wav, 16kHz 모노)이 저장되니 직접 들어보거나 인식기에 넣어볼 수 있다.

읽을 문장 (매번 같은 문장으로): "오늘 저녁에 무슨 약 먹어야 되는지 알려줘"

판단 기준
  SNR 이 높을수록 좋다 (20dB 이상이면 좋음, 10dB 아래면 인식이 어려움)
  클리핑이 0.1% 를 넘으면 소리가 너무 커서 찌그러짐 → 마이크에서 조금 떨어지기
"""
import sys
import time

import numpy as np
import sounddevice as sd
from scipy.io import wavfile
from scipy.signal import resample_poly

TARGET_SR = 16000          # 음성 인식 모델(Whisper, wav2vec2)이 원하는 형식
SENTENCE = "오늘 저녁에 무슨 약 먹어야 되는지 알려줘"


def list_inputs():
    print("== 입력(마이크) 장치 목록 ==")
    for i, d in enumerate(sd.query_devices()):
        if d["max_input_channels"] > 0:
            print(f"  [{i}] {d['name']}  (기본 {int(d['default_samplerate'])}Hz, {d['max_input_channels']}채널)")
    print("\n웹캠 마이크는 보통 이름에 'USB', 'Camera', 'Webcam' 이 들어가요.")
    print("비교: python3 mic_test.py <번호1> <번호2>")


def native_rate(device):
    """장치가 지원하는 녹음 속도 중 16kHz 를 우선, 안 되면 기본값"""
    for sr in (TARGET_SR, int(sd.query_devices(device)["default_samplerate"]), 48000, 44100):
        try:
            sd.check_input_settings(device=device, samplerate=sr, channels=1)
            return sr
        except Exception:
            continue
    raise RuntimeError("지원하는 녹음 속도를 찾지 못했어요")


def record(device, seconds, sr):
    audio = sd.rec(int(seconds * sr), samplerate=sr, channels=1, dtype="float32", device=device)
    sd.wait()
    return audio[:, 0]


def to_16k(x, sr):
    if sr == TARGET_SR:
        return x
    g = np.gcd(sr, TARGET_SR)
    return resample_poly(x, TARGET_SR // g, sr // g).astype(np.float32)


def rms(x):
    return float(np.sqrt(np.mean(x ** 2))) + 1e-12


def measure(device):
    name = sd.query_devices(device)["name"]
    sr = native_rate(device)
    print(f"\n▶ [{device}] {name}  ({sr}Hz 로 녹음)")
    input("  조용히 있을 준비가 되면 Enter → 2초 동안 아무 말도 하지 마세요")
    noise = record(device, 2, sr)
    input(f"  이제 Enter 누르고 5초 안에 읽어주세요: \"{SENTENCE}\"")
    voice = record(device, 5, sr)

    noise_rms, voice_rms = rms(noise), rms(voice)
    snr = 20 * np.log10(voice_rms / noise_rms)
    clip = float(np.mean(np.abs(voice) > 0.99)) * 100
    path = f"mic_{device}.wav"
    wavfile.write(path, TARGET_SR, (to_16k(voice, sr) * 32767).astype(np.int16))
    print(f"  잡음 크기 {noise_rms:.4f} / 목소리 크기 {voice_rms:.4f} / SNR {snr:.1f}dB / 클리핑 {clip:.2f}%  → {path} 저장")
    return {"device": device, "name": name, "sr": sr, "noise": noise_rms, "snr": snr, "clip": clip}


def main():
    if len(sys.argv) == 1:
        list_inputs()
        return
    results = [measure(int(a)) for a in sys.argv[1:]]
    print("\n== 결과 ==")
    for r in sorted(results, key=lambda r: -r["snr"]):
        grade = "좋음" if r["snr"] >= 20 else "보통" if r["snr"] >= 10 else "나쁨"
        warn = "  ⚠ 소리 찌그러짐(마이크와 거리 두기)" if r["clip"] > 0.1 else ""
        print(f"  [{r['device']}] {r['name']}: SNR {r['snr']:.1f}dB ({grade}), 잡음 {r['noise']:.4f}{warn}")
    best = max(results, key=lambda r: r["snr"])
    print(f"\n추천: [{best['device']}] {best['name']}")
    print(f"음성 프로그램의 sd.InputStream(...) 에 device={best['device']} 를 넣고,"
          f" samplerate={best['sr']}" + ("" if best["sr"] == TARGET_SR else " 로 녹음한 뒤 16kHz 로 변환해서 인식기에 넣으세요."))


if __name__ == "__main__":
    main()
