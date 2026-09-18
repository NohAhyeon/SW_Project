# 🤖 SW_Project (라즈베리파이 5 챗봇 & LCD 드라이버)

[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%205-red.svg)](https://www.raspberrypi.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)

**SW_Project** 저장소에 오신 것을 환영합니다! 이 저장소는 **라즈베리파이 5(Raspberry Pi 5)** 기반의 스마트 챗봇 및 AI 음성 비서 시스템과, 휴대용 모니터 설정을 위한 **LCDWiki 디스플레이 드라이버** 모듈을 통합한 프로젝트입니다.

---

## 📂 저장소 디렉토리 구조

프로젝트 소스 코드와 LCD 드라이버 유틸리티 스크립트를 명확히 구분하기 위해 다음과 같이 폴더 구조를 격리 및 정리했습니다.

```
SW_Project/
├── oasis/                     # 가스 센서 및 챗봇 메인 프로젝트
│   ├── mq5.py                 # MQ5 가스 센서 연동 스크립트
│   └── temporaryMain.py       # 메인 챗봇 제어 루프 및 프로그램
├── my_ai_project/             # AI 음성 비서 및 카메라 프로젝트
│   ├── main.py                # Gemini/Groq 음성 비서 & 카메라 스트림 메인 스크립트
│   ├── camera_stream.py       # 카메라 스트리밍 유틸리티
│   └── launcher.py            # 자동 실행 도우미
├── LCD-show/                  # 독립 격리된 LCDWiki 디스플레이 드라이버
│   ├── boot/, etc/, usr/      # 시스템 설정 및 디바이스 트리 오버레이 (.dtb)
│   ├── *.deb                  # 로컬 설치 의존성 패키지
│   ├── *show                  # 디스플레이 모델별 드라이버 설치 스크립트 (예: LCD35-show)
│   └── rotate.sh              # 화면 회전(각도) 제어 스크립트
├── rpi-fbcp/                  # 프레임버퍼 복사 라이브러리
├── requirements_env.txt       # 챗봇 및 센서 환경(env) 의존성 패키지 목록
├── requirements_myenv.txt     # AI 비서 및 카메라 환경(myenv) 의존성 패키지 목록
└── README.md                  # 프로젝트 설명 문서 (본 파일)
```

---

## 🚀 시작하기

### 1. 파이썬 가상환경 설정 및 라이브러리 설치
실행하려는 모듈에 따라 두 가지 가상환경 중 하나를 선택하여 설정하고 필요한 라이브러리를 다운로드합니다.

#### 옵션 A: 챗봇 및 센서 환경 (`env`)
GenAI, Groq, Pygame, 하드웨어 바인딩(CircuitPython 등)이 포함된 환경입니다.

* **방법 1: requirements 파일을 사용하여 한 번에 라이브러리 다운로드 (권장)**
  ```bash
  python -m venv env
  source env/bin/activate  # Windows 환경: env\Scripts\activate
  pip install -r requirements_env.txt
  ```
* **방법 2: 터미널 명령어로 핵심 패키지만 직접 개별 다운로드**
  ```bash
  pip install google-genai groq gTTS pygame sounddevice soundfile RPi.GPIO rpi_ws281x RPLCD smbus2 adafruit-circuitpython-mcp3xxx adafruit-blinka
  ```

#### 옵션 B: AI 음성 비서 및 카메라 환경 (`myenv`)
Edge-TTS, Flask 서버, OpenCV, Scipy 및 각종 미디어 인터페이스 패키지가 포함된 환경입니다.

* **방법 1: requirements 파일을 사용하여 한 번에 라이브러리 다운로드 (권장)**
  ```bash
  python -m venv myenv
  source myenv/bin/activate  # Windows 환경: myenv\Scripts\activate
  pip install -r requirements_myenv.txt
  ```
* **방법 2: 터미널 명령어로 핵심 패키지만 직접 개별 다운로드**
  ```bash
  pip install Flask edge-tts opencv-python sounddevice soundfile pydantic numpy groq google-genai gtts aiohttp
  ```

---

### 2. API 키 설정 (보안)
챗봇과 음성 비서 기능은 원격 AI 모델(Gemini, Groq)과 통신하기 때문에 API 키 설정이 필요합니다. **보안을 위해 소스 코드에 키를 직접 입력(하드코딩)하지 마시고**, 실행하기 전에 터미널에 환경 변수로 등록하여 사용하세요.

```bash
export GEMINI_API_KEY="본인의_Gemini_API_키"
export GROQ_API_KEY="본인의_Groq_API_키"
```

---

### 3. 프로젝트 실행 방법

#### 챗봇 실행 (`oasis`)
`env` 가상환경이 활성화되어 있는지 확인한 후 실행합니다:
```bash
python oasis/temporaryMain.py
```

#### AI 음성 비서 실행 (`my_ai_project`)
`myenv` 가상환경이 활성화되어 있는지 확인한 후 실행합니다:
```bash
python my_ai_project/main.py
```

---

## 🖥️ 3.5인치 LCD 터치 스크린 설정 가이드 (MPI3501)

본 프로젝트는 **3.5인치 라즈베리 파이 TFT 터치 스크린(모델명: MPI3501)** 모듈의 드라이버 설치 및 설정을 기본 지원합니다. 다른 팀원들이 실물 모듈을 하드웨어에 장착하고 소프트웨어를 설정하여 바로 사용할 수 있도록 정리한 가이드입니다.

---

### 📌 1. 모듈 주요 사양 (Specifications)
| 항목 | 상세 사양 |
| :--- | :--- |
| **모델명 / SKU** | MPI3501 (3.5inch RPi Display) |
| **화면 해상도** | 480 × 320 픽셀 (TFT LCD) |
| **디스플레이 인터페이스** | SPI (라즈베리파이 40핀 GPIO 헤더 장착) |
| **드라이버 IC** | ILI9486 |
| **터치 방식** | 감압식 터치 (Resistive Touch, 터치 펜 포함) |
| **소모 전력** | 5V / 0.13A |
| **크기** | 85.42mm × 55.60mm |

---

### 🔌 2. 하드웨어 연결 방법 (물리적 장착)

> [!CAUTION]
> **반드시 라즈베리 파이의 전원을 완전히 차단(OFF)한 상태에서 모듈을 장착하세요.** 전원이 켜진 상태에서 핀을 꽂으면 보드나 LCD 칩이 손상될 수 있습니다.

1. 라즈베리 파이의 40핀 GPIO 헤더와 LCD 모듈 뒷면의 암형 헤더 핀 위치를 맞춥니다.
2. LCD 모듈을 **1번 핀(SD 카드 슬롯 반대쪽 모서리 방향)** 기준으로 오차 없이 정렬합니다.
3. LCD가 흔들리지 않도록 아래 방향으로 가볍고 일정하게 힘을 주어 완전히 밀착되도록 장착합니다.
4. 장착이 완료되면 전원 공급 장치를 연결하여 라즈베리 파이를 부팅합니다.

---

### ⚙️ 3. 소프트웨어 드라이버 설치 (Software Setup)

라즈베리파이가 인터넷에 연결되어 있는지 확인한 후, 아래의 단계에 따라 터미널에서 명령어를 실행합니다.

#### Step 1. 저장소 이동 및 권한 부여
프로젝트 내의 `LCD-show` 디렉토리로 이동하여 설치 스크립트에 실행 권한을 부여합니다.
```bash
# 본 프로젝트 저장소 루트 디렉토리에서 실행
cd SW_Project/LCD-show/
chmod -R 755 .
```

#### Step 2. 드라이버 설치 스크립트 실행
3.5인치 일반형 디스플레이(`MPI3501`)에 맞는 설치 스크립트를 관리자 권한으로 실행합니다.
```bash
sudo ./LCD35-show
```

> [!IMPORTANT]
> **설치 스크립트가 완료되면 라즈베리 파이가 자동으로 재부팅(Reboot)됩니다.**
> 저장하지 않은 작업이 있다면 미리 저장한 후 실행해 주세요.
> 재부팅이 완료되면 연결한 3.5인치 LCD 화면으로 화면 출력이 전환됩니다.

---

### 🔄 4. 화면 및 터치 회전 설정 (Rotate Screen)

사용 방향에 맞게 화면의 출력 방향 및 터치 입력 좌표를 90도 단위로 회전할 수 있습니다. (지원 각도: `0`, `90`, `180`, `270`)

#### 드라이버가 이미 설치된 상태에서 회전하기:
```bash
cd SW_Project/LCD-show/
sudo ./rotate.sh 90
```
*(예: `rotate.sh 90`은 화면을 가로 방향으로 90도 회전시킵니다.)*

#### 드라이버 최초 설치 단계에서 회전 방향 지정하기:
```bash
cd SW_Project/LCD-show/
sudo ./LCD35-show 90
```

---

#### 🔌 5. HDMI 모니터 출력으로 원상복구 (Revert to HDMI)

LCD 모듈을 제거하고 다시 라즈베리 파이의 기본 HDMI 포트로 화면을 출력하고 싶다면 아래 명령어를 실행합니다.
```bash
cd SW_Project/LCD-show/
sudo ./LCD-hdmi
```
*(명령 실행 후 시스템이 자동으로 재부팅되며, 화면 출력이 HDMI 포트로 되돌아갑니다.)*

---

### 🔍 6. 문제 해결 (Troubleshooting)

#### Q1. 화면이 하얗게만 나오고 아무것도 뜨지 않습니다 (White Screen)
* **물리적 연결 확인**: LCD 모듈이 40핀 GPIO 헤더에 어긋남 없이 완전히 장착되었는지 전원을 끄고 다시 점검하세요.
* **드라이버 재설치**: 간혹 커널 업데이트 등으로 인해 드라이버가 누락될 수 있으므로, 다시 `sudo ./LCD35-show` 명령어를 통해 재설치를 시도해 보세요.

#### Q2. 터치 입력 위치와 화면의 클릭 위치가 맞지 않습니다 (Touch Calibration)
* 드라이버 설치 폴더 내의 회전 유틸리티(`rotate.sh`)를 사용하여 각도를 맞추었는지 다시 확인하세요.
* 좌표 보정이 세밀하게 필요할 경우 다음 패키지를 설치하여 보정을 진행할 수 있습니다.
  ```bash
  sudo apt-get install xinput-calibrator
  ```
  이후 GUI 환경의 [기본 메뉴] -> [기본 설정] -> [Calibrate Touchscreen]을 통해 보정 값을 갱신해 줍니다.
