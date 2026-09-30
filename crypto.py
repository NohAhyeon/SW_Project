from cryptography.fernet import Fernet
import os

# 키 파일 경로
KEY_FILE = "secret.key"

def generate_key():
    """암호화 키 생성 및 저장"""
    key = Fernet.generate_key()
    with open(KEY_FILE, "wb") as f:
        f.write(key)
    return key

def load_key():
    """저장된 키 불러오기 (없으면 새로 생성)"""
    if not os.path.exists(KEY_FILE):
        return generate_key()
    with open(KEY_FILE, "rb") as f:
        return f.read()

# 앱 시작시 키 로드
fernet = Fernet(load_key())

def encrypt(text: str) -> str:
    """문자열 암호화"""
    if not text:
        return text
    return fernet.encrypt(text.encode()).decode()

def decrypt(text: str) -> str:
    """문자열 복호화"""
    if not text:
        return text
    try:
        return fernet.decrypt(text.encode()).decode()
    except Exception:
        return text  # 복호화 실패시 원문 반환