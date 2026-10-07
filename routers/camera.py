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