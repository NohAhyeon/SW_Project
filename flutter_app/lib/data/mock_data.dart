final mockStatus = {
  "cpu": 28, "memory": 46,
  "mic": "정상", "speaker": "정상", "network": "연결됨",
  "board": "Raspberry Pi / 테스트 모드",
};

final mockMeds = [
  {"name": "혈압약", "time": "10:00", "taken": false},
  {"name": "당뇨약", "time": "18:00", "taken": false},
  {"name": "비타민", "time": "20:00", "taken": true},
];

final mockScheds = [
  {"title": "복지관 방문", "time": "15:00", "status": "예정"},
  {"title": "딸과 통화", "time": "19:00", "status": "예정"},
  {"title": "병원 예약", "time": "2026-03-12 11:00", "status": "예정"},
];

final mockLogs = [
  {"time": "09:10", "user": "오늘 날씨 알려줘", "bot": "오늘은 맑고 따뜻합니다.", "type": "생활정보"},
  {"time": "10:00", "user": "오늘 약 먹을 시간 알려줘", "bot": "오전 10시에 혈압약 드실 시간입니다.", "type": "복약"},
  {"time": "13:00", "user": "내 일정 알려줘", "bot": "오후 3시에 복지관 방문 일정이 있습니다.", "type": "일정"},
  {"time": "15:30", "user": "살려줘", "bot": "긴급 호출이 접수되었습니다.", "type": "긴급"},
];

final mockEmergencies = [
  {"time": "2026-03-11 15:30", "content": "긴급 호출 감지", "status": "처리 중"},
  {"time": "2026-03-10 21:10", "content": "도움 요청 음성 감지", "status": "처리 완료"},
];