import ollama
import speech_recognition as sr
from gtts import gTTS
import pygame
import time
import os
from RPLCD.i2c import CharLCD

# 1. 하드웨어 설정 
lcd = CharLCD('PCF8574', 0x27)

def update_lcd(line1, line2=""):
    """LCD 상태 업데이트 함수 """
    try:
        lcd.clear()
        lcd.write_string(line1[:16])
        if line2:
            lcd.cursor_pos = (1, 0)
            lcd.write_string(line2[:16])
    except:
        pass

def speak(text):
    """한글 답변을 음성으로 변환 및 재생"""
    print(f"[AI]: {text}")
    update_lcd("AI Speaking...", "Check Speaker")
    
    # gTTS로 음성 생성 및 저장
    tts = gTTS(text=text, lang='ko')
    tts.save("response.mp3")
    
    # pygame으로 재생
    pygame.mixer.init()
    pygame.mixer.music.load("response.mp3")
    pygame.mixer.music.play()
    while pygame.mixer.music.get_busy():
        time.sleep(0.1)
    pygame.mixer.quit()
    
    # 임시 파일 삭제
    if os.path.exists("response.mp3"):
        os.remove("response.mp3")

def listen():
    """마이크를 통해 한글 음성 인식"""
    r = sr.Recognizer()
    with sr.Microphone() as source:
        print("\n[나]: (말씀하세요...)")
        update_lcd("Listening...", "Say something!")
        # 주변 소음 보정
        r.adjust_for_ambient_noise(source, duration=0.5)
        audio = r.listen(source)
    
    try:
        # Google STT로 한글 인식
        user_text = r.recognize_google(audio, language='ko-KR')
        print(f"[나]: {user_text}")
        return user_text
    except sr.UnknownValueError:
        print("음성을 인식하지 못했습니다.")
        return None
    except sr.RequestError:
        print("네트워크 연결을 확인하세요.")
        return None

def main():
    update_lcd("Chatbot Ready!", "Pi 5 16GB")
    print("=== 한글 AI 비서 실행 중 (종료: Ctrl+C) ===")

    while True:
        # 1. 음성 듣기
        user_input = listen()
        if not user_input:
            continue
            
        # 2. AI 생각 중 표시
        update_lcd("Thinking...", "Processing AI")
        
        try:
            # 3. Ollama (Llama 3) 호출
            # 답변이 너무 길면 재생이 오래 걸리므로 '짧게' 대답하도록 시스템 프롬프트 설정
            response = ollama.chat(model='llama3', messages=[
                {'role': 'system', 'content': '당신은 친절한 한국어 비서입니다. 답변은 반드시 한국어로, 한 문장(20자 내외)으로 아주 짧고 친절하게 하세요.'},
                {'role': 'user', 'content': user_input},
            ])
            
            ai_answer = response['message']['content']
            
            # 4. 음성 출력
            speak(ai_answer)
            
        except Exception as e:
            print(f"오류 발생: {e}")
            update_lcd("Error occurred", "Check Terminal")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        lcd.clear()
        print("\n프로그램을 종료합니다.")
