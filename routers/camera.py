from fastapi import APIRouter, UploadFile, File
from datetime import datetime
import os

router = APIRouter()

UPLOAD_DIR = "camera_images"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# 사진 업로드
@router.post("/snapshot")
async def upload_snapshot(file: UploadFile = File(...)):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{timestamp}.jpg"
    filepath = os.path.join(UPLOAD_DIR, filename)
    
    with open(filepath, "wb") as f:
        content = await file.read()
        f.write(content)
    
    return {"message": "사진 저장됨", "filename": filename}

# 최근 사진 목록
@router.get("/snapshots")
async def get_snapshots():
    files = os.listdir(UPLOAD_DIR)
    files.sort(reverse=True)
    return {"snapshots": files[:10]}

# ── 파이 카메라 중계 ──────────────────────────────────────────
# 파이 카메라 서버가 MJPEG 연속 영상(/video)만 줄 때, 아이폰 앱(WebView)은 이걸 재생하지 못한다.
# 서버가 영상 연결 하나를 유지하며 가장 최근 사진 한 장을 보관하고, 앱은 /camera/live.jpg 를 빠르게 받아 보여 준다.
#   카메라 주소: .env 또는 flutter_app/.env 의 CAMERA_STREAM_URL (예: http://172.20.10.6:5000/video)
import asyncio
import time
from pathlib import Path

import httpx
from dotenv import load_dotenv
from fastapi import HTTPException
from fastapi.responses import Response

load_dotenv(Path(__file__).resolve().parent.parent / "flutter_app" / ".env")
_latest: dict = {"jpg": None, "at": 0.0, "url": None}
_reader: asyncio.Task | None = None


async def _read_stream(url: str):
    """MJPEG 영상을 계속 읽으며 JPEG 한 장(FFD8 … FFD9)이 끝날 때마다 보관한다"""
    while True:
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(10, read=15)) as client:
                async with client.stream("GET", url) as res:
                    buf = b""
                    async for chunk in res.aiter_bytes():
                        buf += chunk
                        start = buf.find(b"\xff\xd8")
                        end = buf.find(b"\xff\xd9", start + 2) if start >= 0 else -1
                        while start >= 0 and end >= 0:
                            _latest["jpg"], _latest["at"] = buf[start:end + 2], time.time()
                            buf = buf[end + 2:]
                            start = buf.find(b"\xff\xd8")
                            end = buf.find(b"\xff\xd9", start + 2) if start >= 0 else -1
                        if len(buf) > 2_000_000:          # 깨진 데이터가 쌓이지 않게
                            buf = b""
        except Exception as e:
            print(f"[카메라 중계] 연결 끊김, 3초 뒤 다시 연결: {e}")
        await asyncio.sleep(3)


@router.get("/live.jpg")
async def live_frame():
    global _reader
    url = os.getenv("CAMERA_STREAM_URL", "")
    if not url:
        raise HTTPException(status_code=503, detail="CAMERA_STREAM_URL 이 설정되지 않았어요")
    if _reader is None or _reader.done() or _latest["url"] != url:
        if _reader and not _reader.done():
            _reader.cancel()
        _latest.update(jpg=None, at=0.0, url=url)
        _reader = asyncio.create_task(_read_stream(url))
    for _ in range(30):                                    # 첫 사진을 최대 3초 기다림
        if _latest["jpg"] and time.time() - _latest["at"] < 5:
            break
        await asyncio.sleep(0.1)
    if not _latest["jpg"] or time.time() - _latest["at"] > 5:
        raise HTTPException(status_code=503, detail="카메라 영상을 받을 수 없어요")
    return Response(_latest["jpg"], media_type="image/jpeg", headers={"Cache-Control": "no-store"})
