import os
import time
import queue
import threading
import sys
import tempfile
import numpy as np
import sounddevice as sd
import soundfile as sf
from google import genai
from groq import Groq  # OpenAI 대신 Groq 사용
from gtts import gTTS
import pygame

# --- [1. 환경 설정] ---
GEMINI_API_KEY = "1"
GROQ_API_KEY = "1"

client_gemini = genai.Client(api_key=GEMINI_API_KEY)
client_groq = Groq(api_key=GROQ_API_KEY)

MODEL_NAME = "gemma-3-4b-it" # 답변용 모델
SAMPLERATE = 16000
BLOCK_SIZE = 4000 

audio_queue = queue.Queue()
pygame.mixer.init()

# --- [2. 음성 출력 및 AI 대화 로직] ---

is_speaking = False  # 전역 변수

def speak(text):
    global is_speaking
    is_speaking = True 
    try:
        tts = gTTS(text=text, lang='ko')
        temp_mp3 = "/dev/shm/response.mp3"
        tts.save(temp_mp3)
        pygame.mixer.music.load(temp_mp3)
        pygame.mixer.music.play()
        while pygame.mixer.music.get_busy():
            time.sleep(0.1)
        pygame.mixer.music.unload()
    finally:
        # 💡 핵심: 0.3초에서 0.8초 정도로 늘려보세요. 
        # 스피커 소리가 방안에서 반사되어 사라지는 시간까지 고려합니다.
        time.sleep(0.8) 
        
        # 💡 말을 마친 직후에 큐를 한 번 더 비워서 '방금 한 말'의 잔상을 지웁니다.
        while not audio_queue.empty():
            try:
                audio_queue.get_nowait()
            except queue.Empty:
                break
        
        is_speaking = False

def get_gemini_response(prompt):
    """Gemma-3 모델 답변"""
    try:
        response = client_gemini.models.generate_content(
            model=MODEL_NAME,
            contents=f"너는 다정한 AI 손주야. 이모티콘은 말하지마.: {prompt}"
        )
        return response.text
    except Exception as e:
        print(f"Gemini API 에러: {e}")
        return "죄송해요 어르신, 다시 말씀해 주시겠어요?"

# --- [3. Groq 기반 실시간 STT 스레드] ---

def stt_processing_thread():
    """Groq STT 처리 (RMS 필터 및 들여쓰기 교정 완료)"""
    print("Groq 가동 중... 말씀하시면 즉시 인식합니다.")
    buffer = np.zeros((0, 1), dtype=np.float32)
    
    # 소음 문턱값 (환경에 따라 0.01~0.03 조절)
    THRESHOLD = 0.0044

    while True:
        try:
            # 1. AI가 말하는 중에는 마이크 무시
            if is_speaking:
                while not audio_queue.empty():
                    audio_queue.get()
                buffer = np.zeros((0, 1), dtype=np.float32)
                time.sleep(0.1)
                continue

            # 2. 데이터 가져오기
            try:
                data = audio_queue.get(timeout=1)
                buffer = np.concatenate((buffer, data), axis=0)
            except queue.Empty:
                continue

            # 3. 2.5초 분량이 모였을 때만 분석
            if len(buffer) >= SAMPLERATE * 2.5:
                rms = np.sqrt(np.mean(buffer**2))
                
                # 💡 [필터] 소리가 너무 작으면 Groq 호출 안 함
                if rms < THRESHOLD:
                    buffer = np.zeros((0, 1), dtype=np.float32)
                    continue

                temp_wav = "/dev/shm/temp_segment.wav"
                sf.write(temp_wav, buffer, SAMPLERATE)
                
                # 💡 [핵심] text 변수를 미리 초기화하여 UnboundLocalError 방지
                text = "" 
                
                with open(temp_wav, "rb") as file:
                    # 💡 이 블록 안에서 transcription이 생성됩니다.
                    transcription = client_groq.audio.transcriptions.create(
                        file=(temp_wav, file.read()),
                        model="whisper-large-v3",
                        language="ko"
                    )
                    # 💡 [라인 107 근처] 반드시 with 문 안에 들여쓰기가 맞아야 합니다.
                    text = transcription.text.strip()
                
                # 4. 결과 처리
                if text and len(text) > 2:
                    print(f"\n나: {text} (음량: {rms:.4f})")
                    
                    buffer = np.zeros((0, 1), dtype=np.float32)
                    ai_answer = get_gemini_response(text)
                    speak(ai_answer)
                    
                    while not audio_queue.empty():
                        audio_queue.get()
                else:
                    # 소음이거나 너무 짧으면 버퍼 절반 비우기
                    buffer = buffer[int(SAMPLERATE * 1.0):]

                if os.path.exists(temp_wav):
                    os.remove(temp_wav)

            audio_queue.task_done()

        except Exception as e:
            print(f"Groq 처리 에러: {e}")

# --- [4. 오디오 콜백 및 메인 실행] ---

def audio_callback(indata, frames, time, status):
    if status: print(status, file=sys.stderr)
    audio_queue.put(indata.copy())

def main():
    try:
        with sd.InputStream(samplerate=SAMPLERATE, channels=1, 
                          callback=audio_callback, blocksize=BLOCK_SIZE):
            t = threading.Thread(target=stt_processing_thread)
            t.daemon = True
            t.start()
            while True:
                time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 프로그램 종료")

if __name__ == "__main__":
    main()
