"""
말 끝 감지(발화 단위 녹음) — 라즈베리파이 음성 인식 정확도 개선용 (아현님/대영님용)

문제:
  기존 stt_processing_thread() 는 소리가 2.5초 모이면 무조건 잘라서 인식기에 보냈다.
  문장이 중간에 잘리고, 말 시작 전 조용한 구간까지 포함돼 "단화다라 와봐서" 같은
  엉뚱한 결과가 나왔다. (어르신은 말이 느려서 더 심하다) 모델을 바꿔도 같은 문제가 난다.

해결:
  소리가 커지면 녹음 시작(직전 0.4초 포함) → 0.9초 조용하면 말이 끝난 것으로 보고
  문장 전체를 한 번에 인식기로 보낸다. 주변 소음 크기를 계속 재서 기준을 자동으로 맞춘다
  (부스처럼 시끄러운 곳 대비).

사용법 (main.py 의 stt_processing_thread 안):
    from stt_segmenter import UtteranceRecorder
    recorder = UtteranceRecorder(samplerate=SAMPLERATE)
    while True:
        if is_speaking:                       # 기존 에코 억제 그대로
            recorder.reset(audio_queue); time.sleep(0.1); continue
        audio = recorder.listen(audio_queue, is_busy=lambda: is_speaking)
        if audio is None:
            continue
        sf.write("/dev/shm/utt.wav", audio, SAMPLERATE)   # 16kHz 모노 그대로 인식기에
        text = 인식기(audio)                                 # Whisper 는 language="ko" 고정!
"""
import queue
from collections import deque

import numpy as np


class UtteranceRecorder:
    def __init__(self, samplerate=16000, min_threshold=0.0044, noise_ratio=3.0,
                 pre_roll_sec=0.4, end_silence_sec=0.9, min_speech_sec=0.4, max_sec=15.0,
                 calibrate_sec=1.0, start_blocks=2):
        self.sr = samplerate
        self.min_threshold = min_threshold      # 기존 코드의 THRESHOLD (가장 낮은 기준)
        self.noise_ratio = noise_ratio          # 주변 소음의 몇 배가 넘으면 '말소리'로 볼지
        self.pre_roll_sec = pre_roll_sec
        self.end_silence_sec = end_silence_sec
        self.min_speech_sec = min_speech_sec
        self.max_sec = max_sec
        self.noise = min_threshold / noise_ratio
        self.calibrate_sec = calibrate_sec      # 처음 1초는 주변 소음 크기만 잰다
        self.start_blocks = start_blocks        # 연속 몇 블록 커야 말 시작으로 볼지 (툭 소리 무시)
        self._calib = []

    def threshold(self):
        return max(self.min_threshold, self.noise * self.noise_ratio)

    def reset(self, audio_queue):
        """AI가 말하는 동안 들어온 소리(스피커 소리)는 버린다"""
        while not audio_queue.empty():
            try:
                audio_queue.get_nowait()
            except queue.Empty:
                break

    def listen(self, audio_queue, is_busy=lambda: False, idle_timeout=None):
        """말 한 문장이 끝날 때까지 기다렸다가 float32 모노 배열로 돌려준다. 너무 짧으면 None.
        idle_timeout(초): 그동안 소리가 전혀 안 들어오면 None (테스트용)"""
        pre = deque()
        pre_len = 0
        chunks, voiced, silence, total = [], 0.0, 0.0, 0.0
        recording, loud_run = False, 0

        while True:
            if is_busy():
                return None
            try:
                block = audio_queue.get(timeout=idle_timeout or 1)
            except queue.Empty:
                if idle_timeout:
                    return None
                continue
            block = np.asarray(block, dtype=np.float32).reshape(-1)
            dur = len(block) / self.sr
            rms = float(np.sqrt(np.mean(block ** 2))) if len(block) else 0.0

            # 처음 1초: 주변 소음 크기 측정 (시끄러운 곳에서 켜도 기준이 맞게)
            if sum(len(b) for b in self._calib) < self.calibrate_sec * self.sr:
                self._calib.append(block)
                if sum(len(b) for b in self._calib) >= self.calibrate_sec * self.sr:
                    self.noise = float(np.median([np.sqrt(np.mean(b ** 2)) for b in self._calib]))
                continue

            if not recording:
                # 조용할 때: 주변 소음 크기를 천천히 따라간다
                if rms < self.threshold():
                    self.noise = 0.95 * self.noise + 0.05 * rms
                pre.append(block)
                pre_len += len(block)
                while pre_len - len(pre[0]) >= self.pre_roll_sec * self.sr:
                    pre_len -= len(pre.popleft())
                loud_run = loud_run + 1 if rms >= self.threshold() else 0
                if loud_run >= self.start_blocks:
                    recording = True
                    chunks = list(pre)
                    total = pre_len / self.sr
                    voiced, silence = dur, 0.0
                continue

            chunks.append(block)
            total += dur
            if rms >= self.threshold():
                voiced += dur
                silence = 0.0
            else:
                silence += dur

            if silence >= self.end_silence_sec or total >= self.max_sec:
                if voiced < self.min_speech_sec:
                    return None          # 기침, 문 닫는 소리 같은 짧은 소리
                return np.concatenate(chunks)
