#!/bin/bash
# OASIS 낙상 감지 + 홈캠(oasis_vision.py)을 파이가 켜질 때 자동 실행하도록 설정한다. (AI HAT 파이에서 실행)
#
#   bash install_vision_service.sh http://172.20.10.13:8000
#
# 하는 일
#   1) 예전 홈캠 프로그램(camera_stream 등)의 자동 실행을 끄고, 지금 5000번을 쓰는 프로그램을 멈춘다
#   2) AI HAT 예제 폴더를 찾아 oasis_vision.py 최신본을 받는다
#   3) oasis-vision 서비스를 만들어 켠다 (파이 부팅 시 자동 실행, 멈추면 5초 뒤 다시 실행)
#
# 확인:   systemctl status oasis-vision      로그 보기:  journalctl -u oasis-vision -f
# 끄기:   sudo systemctl stop oasis-vision   자동 실행 해제:  sudo systemctl disable oasis-vision
set -e

BACKEND_URL="${1:-}"
if [ -z "$BACKEND_URL" ]; then
  echo "사용법: bash install_vision_service.sh http://<다혜 맥 IP>:8000"
  exit 1
fi
RUN_USER="${SUDO_USER:-$USER}"
RUN_HOME=$(eval echo "~$RUN_USER")

# ── AI HAT 예제 폴더 찾기 ───────────────────────────────
HAILO_DIR=""
for d in "$RUN_HOME/hailo-rpi5-examples" "$RUN_HOME/hailo-apps" "$RUN_HOME/hailo-apps-infra"; do
  if [ -f "$d/setup_env.sh" ]; then HAILO_DIR="$d"; break; fi
done
if [ -z "$HAILO_DIR" ]; then
  echo "⚠️  AI HAT 예제 폴더(setup_env.sh 가 있는 곳)를 못 찾았어요. 'ls ~' 결과를 다혜에게 보내 주세요."
  exit 1
fi
echo "✅ AI HAT 폴더: $HAILO_DIR"
mkdir -p "$HAILO_DIR/basic_pipelines"
curl -fsSL -o "$HAILO_DIR/basic_pipelines/oasis_vision.py" \
  https://raw.githubusercontent.com/NohAhyeon/SW_Project/dahye/midterm/pi_client/oasis_vision.py
echo "✅ oasis_vision.py 최신본 받음"

# ── 예전 홈캠 끄기 ──────────────────────────────────────
for f in $(grep -l -i -E "camera_stream|camera\.py|stream\.py" /etc/systemd/system/*.service 2>/dev/null || true); do
  name=$(basename "$f")
  [ "$name" = "oasis-vision.service" ] && continue
  echo "⏹  예전 홈캠 자동 실행 끄기: $name"
  sudo systemctl disable --now "$name" || true
done
OLD=$(sudo lsof -t -i :5000 2>/dev/null || true)
if [ -n "$OLD" ]; then
  echo "⏹  5000번을 쓰던 프로그램 멈춤 (PID $OLD)"
  sudo kill $OLD || true
  sleep 2
fi

# ── 서비스 만들기 ───────────────────────────────────────
sudo tee /etc/systemd/system/oasis-vision.service >/dev/null <<EOF
[Unit]
Description=OASIS 낙상 감지 + 홈캠 (AI HAT)
After=network-online.target graphical.target
Wants=network-online.target

[Service]
User=$RUN_USER
WorkingDirectory=$HAILO_DIR
Environment=OASIS_BACKEND_URL=$BACKEND_URL
Environment=DISPLAY=:0
Environment=PYTHONUNBUFFERED=1
ExecStart=/bin/bash -c 'source setup_env.sh && exec python basic_pipelines/oasis_vision.py --input usb'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now oasis-vision
sleep 8
echo
echo "── 상태 ──"
systemctl --no-pager --lines=15 status oasis-vision || true
echo
IP=$(hostname -I | awk '{print $1}')
echo "확인: 브라우저에서 http://$IP:5000/  →  \"mode\": \"hailo\" 가 보이면 성공"
echo "영상: http://$IP:5000/video"
