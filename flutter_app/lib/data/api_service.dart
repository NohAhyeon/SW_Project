import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String apiKey = dotenv.env['WEATHER_API_KEY'] ?? "";
final String url = "https://api.openweathermap.org/data/2.5/weather?q=Busan,KR&appid=$apiKey&units=metric&lang=kr";

final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

// ── MOCK DATA (서버 미연결 시 목업) ──────────────────────────
const bool _useMock = false;

class ApiService {

  // ===== 대화 분류 =====
  static String _classifyChat(String content) {
    final c = content;
    if (c.contains('약') || c.contains('복약') || c.contains('약품') || c.contains('먹을') || c.contains('복용')) {
      return '복약';
    } else if (c.contains('일정') || c.contains('예약') || c.contains('병원') || c.contains('약속') || c.contains('방문')) {
      return '일정';
    } else if (c.contains('살려') || c.contains('도와줘') || c.contains('긴급') || c.contains('응급') || c.contains('아파') || c.contains('쓰러')) {
      return '긴급';
    }
    return '생활정보';
  }
  
  // ===== 복약 =====
  static Future<List<Map>> getMedications() async {
    if (_useMock) return [
      {"name": "혈압약", "time": "08:00", "taken": true, "id": 1},
      {"name": "당뇨약", "time": "12:00", "taken": true, "id": 2},
      {"name": "관절약", "time": "20:00", "taken": false, "id": 3},
    ];
    try {
      final res = await http.get(Uri.parse('$baseUrl/medicine/'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => {
          "name": e["name"] ?? '',
          "time": e["alarm_times"] ?? '',
          "taken": e["taken"] == 1 || e["taken"] == true,
          "id": e["id"],
        }).toList();
      }
    } catch (e) {
      print('복약 조회 오류: $e');
    }
    return [];
  }

  static Future<bool> addMedication(String name, String time) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/medicine/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "name": name,
          "dose": "1정",
          "alarm_times": time,
          "start_date": DateTime.now().toString().split(' ')[0],
          "end_date": DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0],
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      print('복약 추가 오류: $e');
      return false;
    }
  }

  static Future<bool> takeMedication(int id) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/medicine/$id/take'),
        headers: {'Content-Type': 'application/json'},
      );
      return res.statusCode == 200;
    } catch (e) {
      print('복약 완료 오류: $e');
      return false;
    }
  }

  static Future<bool> untakeMedication(int id) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/medicine/$id/untake'),
        headers: {'Content-Type': 'application/json'},
      );
      return res.statusCode == 200;
    } catch (e) {
      print('복약 취소 오류: $e');
      return false;
    }
  }

  static Future<bool> updateMedication(int id, String name, String time) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/medicine/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'schedule_time': time}),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('복약 수정 오류: $e');
      return false;
    }
  }

  static Future<bool> deleteMedication(int id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/medicine/$id'));
      return res.statusCode == 200;
    } catch (e) {
      print('복약 삭제 오류: $e');
      return false;
    }
  }

  // ===== 일정 =====
  static Future<List<Map>> getSchedules() async {
    if (_useMock) {
      final today = DateTime.now();
      final d = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
      return [
        {"title": "병원 진료", "time": "${d}T10:00:00", "status": "완료", "id": 1},
        {"title": "물리치료", "time": "${d}T14:00:00", "status": "", "id": 2},
        {"title": "복지관 방문", "time": "${d}T16:00:00", "status": "", "id": 3},
      ];
    }
    try {
      final res = await http.get(Uri.parse('$baseUrl/schedule/'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => {
          "title": e["title"] ?? '',
          "time": e["datetime"] ?? '',
          "status": e["is_completed"] == true ? "완료" : "",
          "id": e["id"],
        }).toList();
      }
    } catch (e) {
      print('일정 조회 오류: $e');
    }
    return [];
  }

  static Future<bool> addSchedule(String title, String time) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/schedule/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "title": title,
          "datetime": time,
          "memo": "",
          "is_completed": false,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      print('일정 추가 오류: $e');
      return false;
    }
  }

  static Future<bool> completeSchedule(int id) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/schedule/$id/complete'),
        headers: {'Content-Type': 'application/json'},
      );
      return res.statusCode == 200;
    } catch (e) {
      print('일정 완료 오류: $e');
      return false;
    }
  }

  static Future<bool> uncompleteSchedule(int id) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/schedule/$id/uncomplete'),
        headers: {'Content-Type': 'application/json'},
      );
      return res.statusCode == 200;
    } catch (e) {
      print('일정 취소 오류: $e');
      return false;
    }
  }

  static Future<bool> deleteSchedule(int id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/schedule/$id'));
      return res.statusCode == 200;
    } catch (e) {
      print('일정 삭제 오류: $e');
      return false;
    }
  }

  // ===== 대화 로그 =====
  static Future<List<Map>> getChatLogs() async {
    if (_useMock) return [
      {"role": "user", "content": "오늘 날씨 어때?", "time": "2026-06-22T09:00:00"},
      {"role": "assistant", "content": "오늘 서울은 맑고 기온은 26도예요. 외출하기 좋은 날씨네요! 😊", "time": "2026-06-22T09:00:05"},
      {"role": "user", "content": "혈압약 먹었어", "time": "2026-06-22T09:30:00"},
      {"role": "assistant", "content": "잘 하셨어요! 혈압약 복용 완료로 기록했습니다. 💊", "time": "2026-06-22T09:30:03"},
      {"role": "user", "content": "오후에 병원 예약 있어?", "time": "2026-06-22T10:00:00"},
      {"role": "assistant", "content": "오늘 오후 2시에 물리치료 일정이 있으세요. 잊지 마세요! 📅", "time": "2026-06-22T10:00:04"},
    ];
    try {
      final res = await http.get(Uri.parse('$baseUrl/chat/?page=1&size=500'));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List data = decoded is List ? decoded : (decoded['items'] ?? []);

        // id 기준 정렬 (DB 저장 순서가 정확)
        final List sorted = [...data];
        sorted.sort((a, b) {
          final ia = (a["id"] as num?)?.toInt() ?? 0;
          final ib = (b["id"] as num?)?.toInt() ?? 0;
          if (ia != ib) return ia.compareTo(ib);
          // id 같으면 시간으로 2차 정렬
          final ta = DateTime.tryParse((a["created_at"] ?? '').toString()) ?? DateTime(0);
          final tb = DateTime.tryParse((b["created_at"] ?? '').toString()) ?? DateTime(0);
          return ta.compareTo(tb);
        });

        return sorted.map((e) => {
          "role": e["role"]?.toString() ?? '',
          "content": e["content"]?.toString() ?? '',
          "time": e["created_at"]?.toString() ?? '',
          "type": e["type"]?.toString() ?? '',
        }).toList();
      }
    } catch (e) {
      print('대화 로그 조회 오류: $e');
    }
    return [];
  }

  // ===== 알림 =====
  static Future<List<Map>> getAlerts() async {
    if (_useMock) return [
      {"time": "2026-06-22T08:00:00", "content": "비활동 감지", "status": "처리 완료", "type": "비활동", "id": 1},
    ];
    try {
      final res = await http.get(Uri.parse('$baseUrl/alert/'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => {
          "time": e["created_at"] ?? '',
          "content": e["message"] ?? '',
          "status": e["is_resolved"] == true ? "처리 완료" : "처리 중",
          "type": _normalizeAlertType(e["type"]),
          "id": e["id"],
        }).toList();
      }
    } catch (e) {
      print('알림 조회 오류: $e');
    }
    return [];
  }

  // 백엔드가 만드는 알림 이름을 앱 화면에서 쓰는 이름으로 통일
  //   가스감지 → 가스, 위급 → 긴급 (센서·어르신 음성 긴급 알림이 화면에 뜨도록)
  static String _normalizeAlertType(dynamic type) {
    const alias = {'가스감지': '가스', '위급': '긴급', '낙상감지': '낙상', '비활동감지': '비활동'};
    final t = (type ?? '비활동').toString();
    return alias[t] ?? t;
  }

  static Future<bool> resolveAlert(int id) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/alert/$id/resolve'),
        headers: {'Content-Type': 'application/json'},
      );
      return res.statusCode == 200;
    } catch (e) {
      print('알림 해결 오류: $e');
      return false;
    }
  }

  // ===== 날씨 =====
  static Future<Map<String, dynamic>?> getWeather() async {
    if (_useMock) return {'temp': 26, 'desc': '맑음', 'main': 'Clear'};
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return {
          'temp': (data['main']['temp'] as num).round(),
          'desc': (data['weather'][0]['description'] as String? ?? ''),
          'main': (data['weather'][0]['main'] as String? ?? 'Clear'),
        };
      }
    } catch (e) {
      print('날씨 조회 오류: $e');
    }
    return null;
  }

  // ===== 미해결 알림만 조회 =====
  static Future<List<Map>> getUnresolvedAlerts() async {
    if (_useMock) return [];
    try {
      final res = await http.get(Uri.parse('$baseUrl/alert/unresolved'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => {
          "time": e["created_at"] ?? '',
          "content": e["message"] ?? '',
          "status": "처리 중",
          "type": e["type"] ?? '',
          "id": e["id"],
        }).toList();
      }
    } catch (e) {
      print('미해결 알림 조회 오류: $e');
    }
    return [];
  }
}
