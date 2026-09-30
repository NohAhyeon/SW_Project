import cv2
import time
import requests
import logging
import logging.handlers
import threading
import os
from datetime import datetime
from dataclasses import dataclass
from typing import Optional
from http.server import BaseHTTPRequestHandler, HTTPServer


# 로깅 설정
def setup_logger():
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    file_handler = logging.handlers.RotatingFileHandler(
        'detection.log', maxBytes=5 * 1024 * 1024, backupCount=3
    )
    file_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)
    return logger


logger = setup_logger()

# 전역 프레임 버퍼 (스트리밍용)
latest_frame = None
frame_lock = threading.Lock()


@dataclass
class DetectionConfig:
    """노인 케어 비활동 감지 설정"""
    motion_threshold: int = 500
    inactive_alert_seconds: int = 10      # 테스트: 10초 / 실사용: 1800 (30분)
    inactive_warning_seconds: int = 5     # 테스트: 5초  / 실사용: 600  (10분)
    api_url: str = os.getenv("API_BASE_URL", "http://localhost:8000")
    camera_index: int = 0
    blur_kernel: int = 5
    min_contour_area: int = 300
    alert_cooldown: int = 300
    reconnect_delay: int = 5
    stream_port: int = 8080               # MJPEG 스트리밍 포트


# ===== MJPEG 스트리밍 서버 =====
class MJPEGHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # 로그 억제

    def do_GET(self):
        if self.path == '/video':
            self.send_response(200)
            self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=frame')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            try:
                while True:
                    with frame_lock:
                        frame = latest_frame
                    if frame is None:
                        time.sleep(0.05)
                        continue
                    ret, jpg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
                    if not ret:
                        continue
                    jpg_bytes = jpg.tobytes()
                    self.wfile.write(b'--frame\r\n')
                    self.wfile.write(b'Content-Type: image/jpeg\r\n')
                    self.wfile.write(f'Content-Length: {len(jpg_bytes)}\r\n\r\n'.encode())
                    self.wfile.write(jpg_bytes)
                    self.wfile.write(b'\r\n')
                    time.sleep(0.033)  # ~30fps
            except Exception:
                pass

        elif self.path == '/snapshot':
            with frame_lock:
                frame = latest_frame
            if frame is None:
                self.send_response(503)
                self.end_headers()
                return
            ret, jpg = cv2.imencode('.jpg', frame)
            if ret:
                self.send_response(200)
                self.send_header('Content-Type', 'image/jpeg')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(jpg.tobytes())

        elif self.path == '/status':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'{"status": "ok", "stream": "/video"}')

        else:
            self.send_response(404)
            self.end_headers()


def start_stream_server(port: int):
    server = HTTPServer(('0.0.0.0', port), MJPEGHandler)
    logger.info(f"MJPEG 스트리밍 서버 시작: http://0.0.0.0:{port}/video")
    server.serve_forever()


# ===== 비활동 감지 =====
class InactivityDetector:
    def __init__(self, config: DetectionConfig):
        self.config = config
        self.cap: Optional[cv2.VideoCapture] = None
        self.backsub = cv2.createBackgroundSubtractorMOG2(
            history=500, varThreshold=50, detectShadows=True
        )
        self.inactive_start: Optional[float] = None
        self.last_alert_time: Optional[float] = None
        self.is_warning_sent = False
        self.is_alert_sent = False
        self.is_running = True

    def initialize_camera(self) -> bool:
        self.cap = cv2.VideoCapture(self.config.camera_index, cv2.CAP_V4L2)
        if not self.cap.isOpened():
            logger.error("카메라를 열 수 없습니다.")
            return False
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        self.cap.set(cv2.CAP_PROP_FPS, 30)
        logger.info("카메라 초기화 완료")
        return True

    def detect_motion(self, frame):
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (self.config.blur_kernel, self.config.blur_kernel), 0)
        fgmask = self.backsub.apply(gray)
        _, fgmask = cv2.threshold(fgmask, 200, 255, cv2.THRESH_BINARY)
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
        fgmask = cv2.morphologyEx(fgmask, cv2.MORPH_OPEN, kernel)
        fgmask = cv2.morphologyEx(fgmask, cv2.MORPH_CLOSE, kernel)
        contours, _ = cv2.findContours(fgmask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        valid_contours = [c for c in contours if cv2.contourArea(c) > self.config.min_contour_area]
        motion_area = sum(cv2.contourArea(c) for c in valid_contours)
        return int(motion_area), valid_contours, fgmask

    def send_alert(self, alert_type: str, message: str):
        now = time.time()
        if self.last_alert_time and (now - self.last_alert_time) < self.config.alert_cooldown:
            return
        try:
            payload = {
                "type": alert_type,
                "message": message,
                "is_resolved": False,
                "created_at": datetime.now().isoformat()
            }
            response = requests.post(f"{self.config.api_url}/alert/", json=payload, timeout=5)
            if response.status_code in [200, 201]:
                logger.info(f"알림 전송 성공: {message}")
                self.last_alert_time = now
            else:
                logger.error(f"알림 전송 실패: {response.status_code}")
        except requests.exceptions.RequestException as e:
            logger.error(f"서버 연결 실패: {e}")

    def draw_status(self, frame, motion_area: int, contours: list, inactive_duration: Optional[float]):
        global latest_frame
        h, w = frame.shape[:2]
        cv2.drawContours(frame, contours, -1, (0, 255, 0), 2)
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (w, 120), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.4, frame, 0.6, 0, frame)
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        cv2.putText(frame, now_str, (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
        cv2.putText(frame, f"Motion Area: {motion_area}", (10, 55), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
        if inactive_duration is not None:
            minutes = int(inactive_duration // 60)
            seconds = int(inactive_duration % 60)
            if inactive_duration >= self.config.inactive_alert_seconds:
                color = (0, 0, 255)
                status = f"ALERT: INACTIVE {minutes}m {seconds}s"
                cv2.rectangle(frame, (0, 0), (w - 1, h - 1), (0, 0, 255), 5)
            elif inactive_duration >= self.config.inactive_warning_seconds:
                color = (0, 165, 255)
                status = f"WARNING: INACTIVE {minutes}m {seconds}s"
            else:
                color = (0, 255, 255)
                status = f"Monitoring: {minutes}m {seconds}s"
            cv2.putText(frame, status, (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)
        else:
            cv2.putText(frame, "Status: ACTIVE", (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

        # 스트리밍 버퍼 업데이트
        with frame_lock:
            latest_frame = frame.copy()

        return frame

    def process_inactivity(self, motion_area: int) -> Optional[float]:
        now = time.time()
        if motion_area < self.config.motion_threshold:
            if self.inactive_start is None:
                self.inactive_start = now
                self.is_warning_sent = False
                self.is_alert_sent = False
                logger.info("비활동 감지 시작")
            inactive_duration = now - self.inactive_start
            if inactive_duration >= self.config.inactive_warning_seconds and not self.is_warning_sent:
                self.send_alert("비활동", f"노인 비활동 경고: {int(inactive_duration // 60)}분 이상 움직임 없음")
                self.is_warning_sent = True
                logger.warning(f"비활동 경고 발송: {inactive_duration:.0f}초")
            if inactive_duration >= self.config.inactive_alert_seconds and not self.is_alert_sent:
                self.send_alert("비활동", f"노인 비활동 경보: {int(inactive_duration // 60)}분 이상 움직임 없음 — 즉시 확인 필요")
                self.is_alert_sent = True
                logger.error(f"비활동 경보 발송: {inactive_duration:.0f}초")
            return inactive_duration
        else:
            if self.inactive_start is not None:
                duration = now - self.inactive_start
                logger.info(f"활동 재개 (비활동 시간: {duration:.0f}초)")
                self.inactive_start = None
                self.is_warning_sent = False
                self.is_alert_sent = False
            return None

    def run(self):
        logger.info("OASIS 비활동 감지 시작")
        logger.info(f"경고 기준: {self.config.inactive_warning_seconds}초")
        logger.info(f"경보 기준: {self.config.inactive_alert_seconds}초")
        logger.info(f"스트리밍 주소: http://0.0.0.0:{self.config.stream_port}/video")

        while self.is_running:
            if not self.initialize_camera():
                logger.error(f"카메라 재연결 {self.config.reconnect_delay}초 후 재시도...")
                time.sleep(self.config.reconnect_delay)
                continue
            try:
                while self.is_running:
                    ret, frame = self.cap.read()
                    if not ret:
                        logger.error("프레임 읽기 실패 - 재연결 시도")
                        self.cap.release()
                        time.sleep(self.config.reconnect_delay)
                        break
                    motion_area, contours, fgmask = self.detect_motion(frame)
                    inactive_duration = self.process_inactivity(motion_area)
                    frame = self.draw_status(frame, motion_area, contours, inactive_duration)
                    cv2.imshow("OASIS - 노인 케어 모니터링", frame)
                    if cv2.waitKey(1) & 0xFF == 27:
                        logger.info("사용자 종료 요청")
                        self.is_running = False
                        break
            except KeyboardInterrupt:
                logger.info("키보드 인터럽트로 종료")
                self.is_running = False
            except Exception as e:
                logger.error(f"예외 발생: {e} - {self.config.reconnect_delay}초 후 재시작")
                time.sleep(self.config.reconnect_delay)
        self.cleanup()

    def cleanup(self):
        if self.cap:
            self.cap.release()
        cv2.destroyAllWindows()
        logger.info("리소스 정리 완료")


if __name__ == "__main__":
    config = DetectionConfig(
        motion_threshold=500,
        inactive_alert_seconds=10,
        inactive_warning_seconds=5,
        api_url=os.getenv("API_BASE_URL", "http://localhost:8000"),
        camera_index=4,
        stream_port=8080,
    )

    # 스트리밍 서버 백그라운드 실행
    stream_thread = threading.Thread(
        target=start_stream_server,
        args=(config.stream_port,),
        daemon=True
    )
    stream_thread.start()

    detector = InactivityDetector(config)
    detector.run()
