import os
os.environ["PA_ALSA_PLUGHW"] = "1"  # USB 마이크가 16kHz를 직접 지원 안 해도 알아서 변환되게 (sounddevice import 전에 해야 함)
import ssl
ssl._create_default_https_context = ssl._create_unverified_context
import urllib3
urllib3.disable_warnings()
import re
import time
import queue
import threading
import sys
import numpy as np
import sounddevice as sd
import requests
import spidev
from gpiozero import PWMOutputDevice
import pygame

NGROK_HEADERS = {'ngrok-skip-browser-warning': 'true'}
BACKEND_URL = "http://192.168.10.69:8000"
from pi_client.oasis_bridge import OasisBridge
bridge = OasisBridge(BACKEND_URL)
SESSION_ID = "rpi-001"

# 모델은 전부 도커 컨테이너에서 서버로 돌아감 (파이 OS가 32비트라 직접 못 올림)
# STT(Whisper small)/TTS(MeloTTS) -> 8001 포트, LLM(Qwen2.5 1.5B) -> 8080 포트
# 대답은 백엔드 대화 엔진(/talk/)이 만들고, 엔진이 8080 포트 LLM을 불러다 씀
SPEECH_URL = "http://localhost:8001"
LLM_URL = "http://localhost:8080"

# 꽂혀 있는 USB 마이크를 이름으로 찾음. 둘 다 꽂혀 있으면 앞에 적은 걸 씀
MIC_NAMES = ["UACDemo", "USB Composite"]

SAMPLERATE = 16000
BLOCK_SIZE = 4000        # 0.25초

# 2.5초마다 자르면 말이 중간에 끊겨서 인식이 잘 안 됨 -> 말이 끝날 때까지 듣고 보냄
SILENCE_BLOCKS = 4       # 1초 조용하면 말 끝난 걸로 봄
MAX_BLOCKS = 40          # 최대 10초까지만 들음
PRE_BLOCKS = 2           # 말 시작 부분 안 잘리게 앞 0.5초 붙임
MIN_VOICE_BLOCKS = 2     # 0.5초도 안 되는 소리는 무시

# 기기가 소리로 안내하고 끝내는 알림 / 소리 없이 끝내는 알림
# 가스, 긴급, 낙상 같은 건 여기서 해결 처리 안 함 (보호자가 앱에서 확인해야 해서)
SPEAK_ALERT_TYPES = {"일정알림"}
SILENT_ALERT_TYPES = {"복약알림"}   # 약 시간은 먼저 말 걸기(oasis_bridge)가 대신 여쭤봄
DEVICE_ALERT_TYPES = SPEAK_ALERT_TYPES | SILENT_ALERT_TYPES

FILLER_TEXT = "음, 잠시만요."       # oasis_bridge가 대답 기다리는 동안 하는 말

audio_queue = queue.Queue()
pygame.mixer.init()

is_speaking = False
speak_lock = threading.Lock()  # 가스 알림이랑 챗봇 답변이 동시에 말하면 안 돼서
tts_cache = {}                 # 자주 하는 짧은 말은 한 번 만든 음성을 다시 씀

# 가스 감지 설정
BUZZER_PIN = 18
buzzer = PWMOutputDevice(BUZZER_PIN, frequency=2000)
spi = spidev.SpiDev()
spi.open(0, 0)
spi.max_speed_hz = 1000000
GAS_THRESHOLD = 900

def wait_for_servers():
    # 컨테이너가 모델 올리는 데 시간이 걸려서 다 뜰 때까지 기다림
    print("모델 서버 기다리는 중...")
    while True:
        try:
            r1 = requests.get(f"{SPEECH_URL}/health", timeout=3)
            r2 = requests.get(f"{LLM_URL}/health", timeout=3)
            if r1.status_code == 200 and r2.status_code == 200:
                print("모델 서버 준비 완료!")
                return
        except Exception:
            pass
        time.sleep(3)

def find_mic():
    devices = sd.query_devices()
    for name in MIC_NAMES:
        for i, d in enumerate(devices):
            if name in d["name"] and d["max_input_channels"] > 0:
                print(f"마이크: {d['name']}")
                return i
    print("USB 마이크를 못 찾아서 기본 입력 장치를 씀")
    return None

def read_adc(channel):
    if channel < 0 or channel > 7:
        return -1
    adc = spi.xfer2([1, (8 + channel) << 4, 0])
    data = ((adc[1] & 3) << 8) + adc[2]
    return data

def send_gas_alert():
    try:
        requests.post(f"{BACKEND_URL}/alert/gas", verify=False, headers=NGROK_HEADERS)
        print("✅ 백엔드 가스 감지 알림 전송 완료!")
    except Exception as e:
        print(f"❌ 알림 전송 오류: {e}")

def gas_detection_thread():
    print("🔥 가스 감지 모니터링 시작!")
    while True:
        try:
            gas_level = read_adc(0)
            if gas_level > GAS_THRESHOLD:
                print(f"🚨 가스 감지됨! 수치: {gas_level}")
                buzzer.value = 0.5
                send_gas_alert()
                speak("위험! 가스가 감지되었습니다! 즉시 환기하세요!")
                time.sleep(5)
            else:
                buzzer.value = 0.0
            time.sleep(0.5)
        except Exception as e:
            print(f"가스 감지 오류: {e}")
            time.sleep(1)

def fetch_unresolved():
    res = requests.get(f"{BACKEND_URL}/alert/unresolved", verify=False, headers=NGROK_HEADERS, timeout=5)
    return res.json()

def resolve_alert(alert_id):
    requests.patch(f"{BACKEND_URL}/alert/{alert_id}/resolve", verify=False, headers=NGROK_HEADERS, timeout=5)

def alert_check_thread():
    while True:
        try:
            for alert in fetch_unresolved():
                if alert.get("type") in SPEAK_ALERT_TYPES:
                    speak(alert["message"])
                    resolve_alert(alert["id"])
                elif alert.get("type") in SILENT_ALERT_TYPES:
                    resolve_alert(alert["id"])
                # 가스, 긴급, 낙상 등은 안 건드림 -> 보호자 앱에 계속 표시됨
        except Exception as e:
            print(f"알림 확인 오류: {e}")
        time.sleep(30)

def check_alerts():
    # 시작할 때: 꺼져 있던 동안 쌓인 지난 복약/일정 안내만 조용히 정리
    try:
        for alert in fetch_unresolved():
            if alert.get("type") in DEVICE_ALERT_TYPES:
                resolve_alert(alert["id"])
    except Exception as e:
        print(f"알림 확인 오류: {e}")

def clear_audio_queue():
    while not audio_queue.empty():
        try:
            audio_queue.get_nowait()
        except queue.Empty:
            break

def split_sentences(text):
    # 마침표, 물음표, 느낌표 기준으로 문장 나눔
    parts = re.findall(r'[^.!?]+[.!?]*', text)
    return [p.strip() for p in parts if p.strip()]

def rate_to_speed(rate):
    # oasis_bridge는 "-25%" 같은 Edge TTS 방식으로 속도를 주는데 MeloTTS는 0.75 같은 숫자를 받음
    try:
        return 1.0 + int(rate.replace("%", "")) / 100
    except Exception:
        return 1.0

def get_wav(sentence, speed):
    key = (sentence, speed)
    if key in tts_cache:
        return tts_cache[key]
    res = requests.post(f"{SPEECH_URL}/tts", json={"text": sentence, "speed": speed}, timeout=120)
    res.raise_for_status()
    if len(sentence) <= 12:
        tts_cache[key] = res.content
    return res.content

def make_wavs(sentences, speed, wav_queue):
    # 문장마다 TTS 돌려서 파일로 저장하고 순서대로 넘겨줌
    for i, sentence in enumerate(sentences):
        try:
            path = f"/dev/shm/response_{i}.wav"
            with open(path, "wb") as f:
                f.write(get_wav(sentence, speed))
            wav_queue.put(path)
        except Exception as e:
            print(f"TTS 오류: {e}")
    wav_queue.put(None)  # 끝났다는 표시

def speak(text, rate="+0%"):
    global is_speaking
    with speak_lock:
        is_speaking = True
        try:
            # 전체를 다 만들고 틀면 너무 늦어서, 첫 문장 먼저 틀고 그동안 다음 문장을 만듦
            wav_queue = queue.Queue()
            t = threading.Thread(target=make_wavs, args=(split_sentences(text), rate_to_speed(rate), wav_queue))
            t.daemon = True
            t.start()
            while True:
                path = wav_queue.get()
                if path is None:
                    break
                pygame.mixer.music.load(path)
                pygame.mixer.music.play()
                while pygame.mixer.music.get_busy():
                    time.sleep(0.1)
                pygame.mixer.music.unload()
        except Exception as e:
            print(f"TTS 오류: {e}")
        finally:
            time.sleep(0.8)
            clear_audio_queue()
            is_speaking = False

def prepare_filler():
    # "음, 잠시만요."는 매번 나오는 말이라 미리 만들어둠 (안 그러면 이것도 몇 초 걸림)
    try:
        get_wav(FILLER_TEXT, 1.0)
    except Exception as e:
        print(f"TTS 오류: {e}")

def stt(audio):
    # audio: 16kHz 1채널 float32, wav로 안 바꾸고 그대로 보냄
    res = requests.post(f"{SPEECH_URL}/stt",
                        data=audio.astype(np.float32).tobytes(),
                        headers={"Content-Type": "application/octet-stream"},
                        timeout=120)
    res.raise_for_status()
    return res.json()["text"]

def measure_noise():
    # 시작할 때 1초 동안 주변 소음을 재서 말소리 기준을 정함 (이때는 조용히 있어야 함)
    values = []
    while len(values) < 4:
        data = audio_queue.get()
        values.append(np.sqrt(np.mean(data**2)))
    noise = float(np.mean(values))
    threshold = min(max(0.003, noise * 2.5), 0.01)
    print(f"주변 소음: {noise:.4f} / 말소리 기준: {threshold:.4f}")
    return threshold

def stt_processing_thread():
    threshold = measure_noise()
    check_alerts()
    clear_audio_queue()
    print("OASIS 챗봇 가동 중... 말씀하시면 즉시 인식합니다.")

    pre = []            # 말 시작 전 최근 소리
    utter = []          # 지금 듣고 있는 말
    recording = False
    silence = 0
    voice = 0

    while True:
        try:
            if is_speaking:
                clear_audio_queue()
                pre, utter, recording = [], [], False
                time.sleep(0.1)
                continue

            try:
                data = audio_queue.get(timeout=1)
            except queue.Empty:
                continue

            rms = np.sqrt(np.mean(data**2))

            # 아직 말 시작 전
            if not recording:
                if rms > threshold:
                    recording = True
                    utter = pre + [data]
                    silence = 0
                    voice = 1
                else:
                    pre.append(data)
                    pre = pre[-PRE_BLOCKS:]
                continue

            # 말하는 중
            utter.append(data)
            if rms > threshold:
                silence = 0
                voice += 1
            else:
                silence += 1

            if silence < SILENCE_BLOCKS and len(utter) < MAX_BLOCKS:
                continue

            # 말 끝남 -> 통째로 STT에 보냄
            audio = np.concatenate(utter, axis=0).flatten()
            pre, utter, recording = [], [], False

            if voice < MIN_VOICE_BLOCKS:
                continue

            t0 = time.time()
            text = stt(audio)
            stt_time = time.time() - t0

            if text and len(text) > 1:
                volume = np.sqrt(np.mean(audio**2))
                print(f"\n나: {text} (음량: {volume:.4f}, 길이: {len(audio) / SAMPLERATE:.1f}초, STT {stt_time:.1f}초)")
                # 대답 만들기, 대화 저장, 복약 기록 같은 건 전부 백엔드 대화 엔진이 함
                bridge.handle(text, speak)

            clear_audio_queue()

        except Exception as e:
            print(f"STT 처리 에러: {e}")

def audio_callback(indata, frames, time, status):
    if status: print(status, file=sys.stderr)
    audio_queue.put(indata.copy())

def main():
    try:
        wait_for_servers()
        prepare_filler()

        gas_thread = threading.Thread(target=gas_detection_thread)
        gas_thread.daemon = True
        gas_thread.start()

        alert_thread = threading.Thread(target=alert_check_thread)
        alert_thread.daemon = True
        alert_thread.start()

        bridge.start_proactive(speak, is_busy=lambda: is_speaking)

        with sd.InputStream(device=find_mic(), samplerate=SAMPLERATE, channels=1,
                          callback=audio_callback, blocksize=BLOCK_SIZE):
            stt_thread = threading.Thread(target=stt_processing_thread)
            stt_thread.daemon = True
            stt_thread.start()
            while True:
                time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 프로그램 종료")
    finally:
        spi.close()
        buzzer.value = 0.0
        buzzer.close()

if __name__ == "__main__":
    main()
