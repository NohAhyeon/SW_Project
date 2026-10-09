"""
OASIS 비전 — USB 웹캠 하나로 ① 홈캠 실시간 영상 ② 낙상 감지 ③ 비활동 감지를 동시에 한다.

카메라는 한 프로그램만 열 수 있으므로, 기존 camera_stream.py(picamera2, 리본 케이블 카메라용)를
끄고 이 프로그램 하나로 대체한다. 앱이 보는 주소는 그대로 http://<파이IP>:5000/video 이다.

두 가지 모드
  ● AI HAT 모드 (기본): Hailo-8 로 사람 자세(관절 17개)를 인식 → 낙상 + 비활동 감지
      hailo-rpi5-examples 의 basic_pipelines 폴더에 이 파일을 넣고, 그 가상환경에서 실행:
        source setup_env.sh
        python basic_pipelines/oasis_vision.py --input usb
  ● 비상 모드: AI HAT 설정이 안 될 때. 홈캠 + 움직임 기반 비활동 감지만 동작 (낙상 감지 없음)
        OASIS_NO_HAILO=1 python3 oasis_vision.py

설정 (환경변수, 없으면 기본값)
  OASIS_BACKEND_URL   백엔드 주소            예) http://192.168.10.69:8000
  OASIS_INACTIVE_SEC  비활동 알림까지 초      시연 30, 실사용 1800(30분)
  OASIS_FALL_LYING_SEC 쓰러진 뒤 누워 있는 시간 2
  OASIS_STREAM_PORT   홈캠 영상 포트          5000
  OASIS_CAMERA        비상 모드 카메라 번호    0 (/dev/video0)

알림은 백엔드 POST /alert/ 로 보낸다 (type: "낙상" / "비활동"). 낙상이면 사진도 /camera/snapshot 에 올린다.
"""
import math
import os
import sys
import threading
import time
from collections import deque

import cv2
import numpy as np
import requests
from flask import Flask, Response

BACKEND_URL      = os.getenv("OASIS_BACKEND_URL", "http://192.168.10.69:8000").rstrip("/")
INACTIVE_SEC     = float(os.getenv("OASIS_INACTIVE_SEC", "30"))
FALL_LYING_SEC   = float(os.getenv("OASIS_FALL_LYING_SEC", "2"))
STREAM_PORT      = int(os.getenv("OASIS_STREAM_PORT", "5000"))
ALERT_COOLDOWN   = float(os.getenv("OASIS_ALERT_COOLDOWN", "60"))
NO_HAILO         = os.getenv("OASIS_NO_HAILO") == "1"
# 비활동 감지: 수면·TV 시청 중 오작동 우려로 기본 끔. 다시 쓰려면 OASIS_INACTIVITY=1
INACTIVITY_ON    = os.getenv("OASIS_INACTIVITY") == "1"

def _dur(sec: float) -> str:
    """1800 → '30분', 30 → '30초'"""
    return f"{int(sec // 60)}분" if sec >= 60 else f"{int(sec)}초"


# COCO 17 관절 번호
NOSE, L_SH, R_SH, L_HIP, R_HIP, L_KNEE, R_KNEE, L_ANK, R_ANK = 0, 5, 6, 11, 12, 13, 14, 15, 16
SKELETON = [(5, 7), (7, 9), (6, 8), (8, 10), (5, 6), (5, 11), (6, 12), (11, 12),
            (11, 13), (13, 15), (12, 14), (14, 16), (0, 5), (0, 6)]


# ════════════════════════════════════════════════════════════
#  알림 전송 (같은 종류는 ALERT_COOLDOWN 초에 한 번만)
# ════════════════════════════════════════════════════════════
class AlertSender:
    def __init__(self, backend_url=BACKEND_URL, cooldown=ALERT_COOLDOWN, post=requests.post):
        self.url, self.cooldown, self._post = backend_url, cooldown, post
        self._last: dict[str, float] = {}
        self._lock = threading.Lock()

    def send(self, kind: str, message: str, frame=None) -> bool:
        with self._lock:
            now = time.time()
            if now - self._last.get(kind, 0) < self.cooldown:
                return False
            self._last[kind] = now
        threading.Thread(target=self._send, args=(kind, message, frame), daemon=True).start()
        return True

    def _send(self, kind, message, frame):
        try:
            self._post(f"{self.url}/alert/", json={"type": kind, "message": message}, timeout=5)
            print(f"[알림 전송] {kind}: {message}")
            if frame is not None:
                ok, jpg = cv2.imencode(".jpg", frame)
                if ok:
                    self._post(f"{self.url}/camera/snapshot",
                               files={"file": ("event.jpg", jpg.tobytes(), "image/jpeg")}, timeout=5)
        except Exception as e:
            print(f"[알림 전송 실패] {kind}: {e}")


# ════════════════════════════════════════════════════════════
#  낙상 감지 — 관절 좌표 기반
#    1) 엉덩이가 1초 안에 '키의 35% 이상' 빠르게 내려감 (급격한 하강)
#    2) 그 뒤 몸이 누운 자세(몸통 기울기 60도 이상 또는 가로로 긴 몸)로 FALL_LYING_SEC 이상 유지
#    → 둘 다 만족하면 낙상. 천천히 눕는 것(침대)은 1)이 없어서 낙상으로 보지 않는다.
# ════════════════════════════════════════════════════════════
class FallDetector:
    def __init__(self, drop_ratio=0.35, drop_window=1.0, lying_sec=FALL_LYING_SEC,
                 lying_angle=60.0, min_score=0.3):
        self.drop_ratio, self.drop_window = drop_ratio, drop_window
        self.lying_sec, self.lying_angle, self.min_score = lying_sec, lying_angle, min_score
        self.hist: dict[int, deque] = {}       # 사람별 (시각, 엉덩이y, 키)
        self.dropped_at: dict[int, float] = {}
        self.lying_since: dict[int, float] = {}
        self.last_status: dict[int, str] = {}

    @staticmethod
    def _mid(kp, a, b):
        return ((kp[a][0] + kp[b][0]) / 2, (kp[a][1] + kp[b][1]) / 2)

    def posture(self, kp, bbox):
        """(누운 자세인가, 몸통 각도) — kp: [(x, y, score)]*17 픽셀, bbox: (x1, y1, x2, y2)"""
        x1, y1, x2, y2 = bbox
        wide = (x2 - x1) > 1.2 * (y2 - y1)
        if min(kp[L_SH][2], kp[R_SH][2], kp[L_HIP][2], kp[R_HIP][2]) < self.min_score:
            return wide, None
        sx, sy = self._mid(kp, L_SH, R_SH)
        hx, hy = self._mid(kp, L_HIP, R_HIP)
        angle = math.degrees(math.atan2(abs(hx - sx), abs(hy - sy) + 1e-6))   # 0 = 서 있음, 90 = 누움
        return (angle >= self.lying_angle) or wide, angle

    def update(self, pid: int, kp, bbox, now=None) -> bool:
        """한 프레임 갱신. 이번 프레임에 낙상이 '확정'되면 True"""
        now = time.time() if now is None else now
        lying, _ = self.posture(kp, bbox)
        h = self.hist.setdefault(pid, deque())          # (시각, 엉덩이y, 키, 누운 자세인가)
        if min(kp[L_HIP][2], kp[R_HIP][2]) >= self.min_score:
            _, hip_y = self._mid(kp, L_HIP, R_HIP)
            h.append((now, hip_y, max(bbox[3] - bbox[1], 1.0), lying))
        while h and now - h[0][0] > self.drop_window:
            h.popleft()
        # 급격한 하강: 1초 안에, '서 있던(누워 있지 않던)' 시점보다 엉덩이가 그때 키의 35% 이상 내려감
        # → 누운 채 뒤척이는 건 시작 자세가 누운 자세라 해당 없음
        if h and any(not e[3] and h[-1][1] - e[1] >= self.drop_ratio * e[2] for e in h):
            self.dropped_at[pid] = now

        if lying:
            self.lying_since.setdefault(pid, now)
        else:
            self.lying_since.pop(pid, None)

        recent_drop = now - self.dropped_at.get(pid, -1e9) <= self.drop_window + self.lying_sec + 1
        fallen = (recent_drop and pid in self.lying_since
                  and now - self.lying_since[pid] >= self.lying_sec)
        self.last_status[pid] = "FALL" if fallen else ("LYING" if lying else "OK")
        if fallen:
            self.dropped_at.pop(pid, None)       # 같은 낙상으로 중복 알림 방지
        return fallen


# ════════════════════════════════════════════════════════════
#  비활동 감지 — 사람이 보이는데 INACTIVE_SEC 동안 거의 안 움직이면 알림
#  (사람이 화면에 없으면 외출로 보고 세지 않는다)
# ════════════════════════════════════════════════════════════
class InactivityDetector:
    def __init__(self, inactive_sec=INACTIVE_SEC, move_ratio=0.03):
        self.inactive_sec, self.move_ratio = inactive_sec, move_ratio
        self.last_move = time.time()
        self.prev = None
        self.alerted = False

    def idle_seconds(self, now=None):
        return (time.time() if now is None else now) - self.last_move

    def update_keypoints(self, kp, bbox, now=None) -> bool:
        now = time.time() if now is None else now
        pts = np.array([(x, y) for x, y, s in kp if s >= 0.3], dtype=np.float32)
        size = max(bbox[3] - bbox[1], bbox[2] - bbox[0], 1.0)
        moved = self.prev is None or len(pts) == 0 or len(self.prev) != len(pts) or \
            float(np.mean(np.linalg.norm(pts - self.prev, axis=1))) > self.move_ratio * size
        self.prev = pts
        return self._tick(moved, now)

    def update_motion(self, motion_ratio: float, now=None) -> bool:
        """비상 모드용: 화면 중 움직인 픽셀 비율"""
        return self._tick(motion_ratio > 0.004, time.time() if now is None else now)

    def no_person(self, now=None):
        self.last_move = time.time() if now is None else now
        self.prev, self.alerted = None, False

    def _tick(self, moved, now) -> bool:
        if moved:
            self.last_move, self.alerted = now, False
            return False
        if not self.alerted and now - self.last_move >= self.inactive_sec:
            self.alerted = True
            return True
        return False


# ════════════════════════════════════════════════════════════
#  홈캠 영상 서버 (MJPEG) — 앱이 http://<파이>:5000/video 로 본다
# ════════════════════════════════════════════════════════════
class FrameHub:
    """AI 분석 줄(GStreamer)을 막지 않도록, 그림 그리기·JPEG 압축은 따로 도는 줄에서 한다.
    분석 줄은 최신 화면만 넘겨 두고 바로 돌아가고(submit), 압축 줄은 최대 STREAM_FPS 로 최신 것만 보낸다."""
    def __init__(self, max_width=640, quality=65, fps=None):
        self._jpg, self._cond = None, threading.Condition()
        self._pending, self._plock = None, threading.Lock()
        self.max_width, self.quality = max_width, quality
        self.interval = 1.0 / (fps or float(os.getenv("OASIS_STREAM_FPS", "20")))
        threading.Thread(target=self._encoder, daemon=True).start()

    def submit(self, frame, draw=None):
        """분석 줄에서 호출: 화면과 '나중에 그릴 함수'만 맡기고 즉시 돌아간다 (밀린 화면은 버림)"""
        with self._plock:
            self._pending = (frame, draw)

    def _encoder(self):
        while True:
            t0 = time.time()
            with self._plock:
                item, self._pending = self._pending, None
            if item is not None:
                frame, draw = item
                if draw is not None:
                    frame = draw(frame)
                self.push(frame)
            time.sleep(max(0.0, self.interval - (time.time() - t0)))

    def push(self, frame_bgr, quality=None):
        h, w = frame_bgr.shape[:2]
        if w > self.max_width:                       # 홈캠은 640px 이면 충분 (압축이 훨씬 빠름)
            frame_bgr = cv2.resize(frame_bgr, (self.max_width, int(h * self.max_width / w)))
        ok, jpg = cv2.imencode(".jpg", frame_bgr, [cv2.IMWRITE_JPEG_QUALITY, quality or self.quality])
        if ok:
            with self._cond:
                self._jpg = jpg.tobytes()
                self._cond.notify_all()

    def latest(self, timeout=2.0):
        with self._cond:
            self._cond.wait(timeout)
            return self._jpg


def start_stream_server(hub: FrameHub, port=STREAM_PORT):
    app = Flask("oasis_vision")

    @app.route("/video")
    def video():
        def gen():
            while True:
                jpg = hub.latest()
                if jpg:
                    yield b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + jpg + b"\r\n"
        return Response(gen(), mimetype="multipart/x-mixed-replace; boundary=frame")

    @app.route("/snapshot")
    def snapshot():
        jpg = hub.latest(0.5)
        return Response(jpg or b"", mimetype="image/jpeg")

    @app.route("/view")
    def view():
        # 앱(WebView)용: 화면에 꽉 차게 실시간 영상만 보여주는 페이지
        return ("<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
                "<style>html,body{margin:0;height:100%;background:#191F28}"
                "img{width:100%;height:100%;object-fit:cover;display:block}</style></head>"
                "<body><img src='/video' alt=''></body></html>")

    @app.route("/")
    def health():
        return {"status": "ok", "mode": "no-hailo" if NO_HAILO else "hailo"}

    threading.Thread(target=lambda: app.run(host="0.0.0.0", port=port, threaded=True),
                     daemon=True).start()
    print(f"[홈캠] http://<파이IP>:{port}/view (앱용 화면), /video (영상 원본)")


# ════════════════════════════════════════════════════════════
#  화면 표시 (영상 위 상태 글씨 — OpenCV 는 한글을 못 써서 영어로)
# ════════════════════════════════════════════════════════════
def draw_overlay(frame, people, fall_now, idle_sec, inactive_sec):
    for kp, bbox, status in people:
        color = (0, 0, 255) if status == "FALL" else (0, 200, 255) if status == "LYING" else (255, 160, 60)
        for a, b in SKELETON:
            if kp[a][2] > 0.3 and kp[b][2] > 0.3:
                cv2.line(frame, (int(kp[a][0]), int(kp[a][1])), (int(kp[b][0]), int(kp[b][1])), color, 2)
        cv2.rectangle(frame, (int(bbox[0]), int(bbox[1])), (int(bbox[2]), int(bbox[3])), color, 2)
        cv2.putText(frame, status, (int(bbox[0]), max(int(bbox[1]) - 8, 20)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
    label = "FALL DETECTED" if fall_now else (f"idle {int(idle_sec)}s / {int(inactive_sec)}s" if INACTIVITY_ON else "")
    cv2.putText(frame, f"OASIS  {time.strftime('%H:%M:%S')}  {label}", (12, 28),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255) if fall_now else (255, 255, 255), 2)
    return frame


# ════════════════════════════════════════════════════════════
#  AI HAT 모드 (hailo-apps 자세 인식 파이프라인 위에서 동작)
# ════════════════════════════════════════════════════════════
def run_hailo():
    import gi
    gi.require_version("Gst", "1.0")
    from gi.repository import Gst
    import hailo
    try:   # hailo-apps 버전에 따라 경로가 다르다
        from hailo_apps.hailo_app_python.core.common.buffer_utils import get_caps_from_pad, get_numpy_from_buffer
        from hailo_apps.hailo_app_python.core.gstreamer.gstreamer_app import app_callback_class
        from hailo_apps.hailo_app_python.apps.pose_estimation.pose_estimation_pipeline import GStreamerPoseEstimationApp
    except ImportError:
        from hailo_apps_infra.hailo_rpi_common import get_caps_from_pad, get_numpy_from_buffer, app_callback_class
        from hailo_apps_infra.pose_estimation_pipeline import GStreamerPoseEstimationApp

    hub, alerts = FrameHub(), AlertSender()
    fall, idle = FallDetector(), InactivityDetector()
    start_stream_server(hub)

    class UserData(app_callback_class):
        pass

    def callback(pad, info, user_data):
        buffer = info.get_buffer()
        if buffer is None:
            return Gst.PadProbeReturn.OK
        fmt, width, height = get_caps_from_pad(pad)
        if fmt is None or width is None:
            return Gst.PadProbeReturn.OK
        rgb = get_numpy_from_buffer(buffer, fmt, width, height)   # 색 변환·압축은 압축 줄에서 (여기선 복사만)
        frame = None

        people, fall_now = [], False
        roi = hailo.get_roi_from_buffer(buffer)
        persons = [d for d in roi.get_objects_typed(hailo.HAILO_DETECTION) if d.get_label() == "person"]
        for i, det in enumerate(persons):
            b = det.get_bbox()
            bbox = (b.xmin() * width, b.ymin() * height, b.xmax() * width, b.ymax() * height)
            ids = det.get_objects_typed(hailo.HAILO_UNIQUE_ID)
            pid = ids[0].get_id() if len(ids) == 1 else i
            lms = det.get_objects_typed(hailo.HAILO_LANDMARKS)
            if not lms:
                continue
            kp = [((p.x() * b.width() + b.xmin()) * width, (p.y() * b.height() + b.ymin()) * height,
                   p.confidence()) for p in lms[0].get_points()]
            if fall.update(pid, kp, bbox):
                fall_now = True
                frame = frame if frame is not None else cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
                alerts.send("낙상", "카메라에서 낙상이 감지되었어요. 어르신 상태를 확인해 주세요.", frame.copy())
            if INACTIVITY_ON and i == 0 and idle.update_keypoints(kp, bbox):
                frame = frame if frame is not None else cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
                alerts.send("비활동", f"어르신이 {_dur(INACTIVE_SEC)} 넘게 움직이지 않으세요.", frame.copy())
            people.append((kp, bbox, fall.last_status.get(pid, "OK")))
        if not persons:
            idle.no_person()

        idle_sec = idle.idle_seconds()
        hub.submit(rgb.copy(), lambda f, p=people, fn=fall_now, s=idle_sec:
                   draw_overlay(cv2.cvtColor(f, cv2.COLOR_RGB2BGR), p, fn, s, INACTIVE_SEC))
        return Gst.PadProbeReturn.OK

    if "--input" not in sys.argv:
        sys.argv += ["--input", "usb"]
    if "--disable-sync" not in sys.argv:             # 화면 시계에 맞춰 기다리지 않고 들어오는 대로 처리
        sys.argv.append("--disable-sync")
    print(f"[AI HAT 모드] 백엔드 {BACKEND_URL} / 비활동 {INACTIVE_SEC}초 / 낙상 후 누움 {FALL_LYING_SEC}초")
    # 화면 창 없이 실행 (아현 수정): 출력 끝을 fakesink 로 바꿔야 서비스(화면 없음)에서도 초당 20장이 나온다.
    #   fpsdisplaysink/autovideosink 는 화면을 못 잡아 느려지고, 큐를 버리지 않아 파이프라인 전체가 같이 느려졌다.
    #   --use-frame 도 쓰지 않는다 (화면 창 프로세스가 CPU 100% 로 헛돎). 영상은 콜백에서 버퍼를 직접 읽는다.
    class HeadlessPoseApp(GStreamerPoseEstimationApp):
        def get_pipeline_string(self):
            self.video_sink = "fakesink"
            return super().get_pipeline_string()

    HeadlessPoseApp(callback, UserData()).run()


# ════════════════════════════════════════════════════════════
#  비상 모드 (AI HAT 없이: 홈캠 + 움직임 기반 비활동 감지)
# ════════════════════════════════════════════════════════════
def find_usb_camera(base="/sys/class/video4linux"):
    """라즈베리파이5는 /dev/video0~ 를 자체 영상 장치가 쓰므로, 이름으로 USB 웹캠을 찾는다.
    OASIS_CAMERA 를 지정하면 그 번호를 쓴다."""
    if os.getenv("OASIS_CAMERA"):
        return [int(os.getenv("OASIS_CAMERA"))]
    usb, others = [], []

    for name in sorted(os.listdir(base) if os.path.isdir(base) else [], key=lambda n: int(n[5:] or 0)):
        try:
            label = open(f"{base}/{name}/name").read().strip()
        except OSError:
            continue
        idx = int(name.replace("video", ""))
        lower = label.lower()
        internal = any(k in lower for k in ("rp1-cfe", "pispbe", "hevc", "codec", "isp", "bcm2835", "unicam"))
        if internal:
            continue                                  # 파이 내부 영상 장치는 웹캠이 아님
        if any(k in lower for k in ("usb", "webcam", "camera", "uvc")):
            usb.append(idx)                           # 이름으로 확실한 웹캠
        else:
            others.append(idx)                        # 이름에 표시가 없는 웹캠도 시도
        print(f"  [카메라 후보] /dev/video{idx}: {label}")
    if not usb and not others:
        print("  ⚠ 파이가 USB 웹캠을 인식하지 못했어요 (lsusb 로 확인, 다른 USB 포트에 꽂아보기)")
    return usb + others or [0]


def open_camera():
    for idx in find_usb_camera():
        cap = cv2.VideoCapture(idx, cv2.CAP_V4L2)
        cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        ok, _ = cap.read() if cap.isOpened() else (False, None)
        if ok:
            print(f"[카메라] /dev/video{idx} 사용")
            return cap
        cap.release()
        print(f"  /dev/video{idx} 는 영상을 못 받았어요 (다른 프로그램이 쓰는 중이거나 영상 장치가 아님)")
    sys.exit("USB 웹캠을 열 수 없어요.\n"
             "  1) v4l2-ctl --list-devices 로 웹캠 번호 확인 → OASIS_CAMERA=번호 로 지정\n"
             "  2) 다른 프로그램(camera_stream.py 등)이 카메라를 쓰고 있지 않은지 확인\n"
             "  3) 웹캠을 뺐다 다시 꽂기")


def run_opencv():
    cap = open_camera()

    hub, alerts, idle = FrameHub(), AlertSender(), InactivityDetector()
    mog = cv2.createBackgroundSubtractorMOG2(history=300, varThreshold=32, detectShadows=False)
    start_stream_server(hub)
    print(f"[비상 모드] 홈캠만 동작 (낙상 감지 없음, 비활동 감지 {'켜짐' if INACTIVITY_ON else '꺼짐'}) / 백엔드 {BACKEND_URL}")

    while True:
        ok, frame = cap.read()
        if not ok:
            time.sleep(0.2)
            continue
        small = cv2.resize(frame, (320, 180))
        mask = mog.apply(small)
        motion = float(np.count_nonzero(mask)) / mask.size
        if INACTIVITY_ON and idle.update_motion(motion):
            alerts.send("비활동", f"{_dur(INACTIVE_SEC)} 넘게 움직임이 없어요.", frame.copy())
        hub.push(draw_overlay(frame, [], False, idle.idle_seconds(), INACTIVE_SEC))


if __name__ == "__main__":
    if NO_HAILO:
        run_opencv()
    else:
        try:
            run_hailo()
        except ImportError as e:
            print(f"[AI HAT 모듈 없음: {e}] → 비상 모드로 실행합니다 (낙상 감지 없음)")
            run_opencv()
