import cv2
import time
import threading
from flask import Flask, Response

# 파이 전용 카메라(picamera2) 대신 USB 웹캠을 OpenCV로 읽어서 MJPEG로 스트리밍

CAMERA_INDEX = 0      # /dev/video0 (웹캠이 다른 번호로 잡히면 여기만 바꾸면 됨)
WIDTH = 640
HEIGHT = 480
FPS = 10              # 모델 돌리는 데 CPU를 많이 써서 프레임은 낮게 잡음
PORT = 5000           # 기존 camera_stream.py랑 같은 포트
ROUTE = "/video"      # 기존 주소 그대로 (앱이랑 백엔드는 안 고쳐도 됨)

app = Flask(__name__)

cap = cv2.VideoCapture(CAMERA_INDEX, cv2.CAP_V4L2)
cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
cap.set(cv2.CAP_PROP_FRAME_WIDTH, WIDTH)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, HEIGHT)
cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # 옛날 프레임이 쌓여서 화면이 밀리는 거 방지

latest_frame = None
frame_lock = threading.Lock()

def capture_thread():
    # 카메라는 여기 한 군데서만 읽고, 접속한 쪽은 마지막 프레임만 가져감
    global latest_frame
    while True:
        ok, frame = cap.read()
        if not ok:
            print("카메라에서 프레임을 못 읽음")
            time.sleep(1)
            continue
        ok, jpg = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
        if ok:
            with frame_lock:
                latest_frame = jpg.tobytes()
        time.sleep(1 / FPS)

def generate():
    while True:
        with frame_lock:
            frame = latest_frame
        if frame is not None:
            yield (b"--frame\r\n"
                   b"Content-Type: image/jpeg\r\n\r\n" + frame + b"\r\n")
        time.sleep(1 / FPS)

@app.route(ROUTE)
def video_feed():
    return Response(generate(), mimetype="multipart/x-mixed-replace; boundary=frame")

@app.route("/")
def index():
    return f'''<html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
</head><body style="margin:0;background:#000">
<img src="{ROUTE}" style="width:100%">
</body></html>'''

if __name__ == "__main__":
    if not cap.isOpened():
        print("웹캠을 못 열었음. USB가 꽂혀 있는지, CAMERA_INDEX가 맞는지 확인")
    t = threading.Thread(target=capture_thread)
    t.daemon = True
    t.start()
    app.run(host="0.0.0.0", port=PORT, threaded=True)
