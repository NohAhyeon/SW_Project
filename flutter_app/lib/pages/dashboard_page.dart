import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../data/api_service.dart';
import '../widgets/banner_widget.dart';
import '../models/log_item.dart';
import '../widgets/log_card.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart';

class DashboardPage extends StatefulWidget {
  final Function(int) onTabChange;
  const DashboardPage({super.key, required this.onTabChange});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _temp = '--';
  String _weatherDesc = '불러오는 중...';
  String _weatherCity = '부산';
  IconData _weatherIcon = Icons.wb_sunny_rounded;
  List<Map<String, dynamic>> _alerts = [];
  bool _alertLoading = true;

  List<Map> _meds = [];
  List<Map> _scheds = [];

  static const String _baseUrl = 'http://localhost:8000';
  String get _weatherApiKey => dotenv.env['WEATHER_API_KEY'] ?? '';


  @override
  void initState() {
    super.initState();
    _fetchWeather();
    _fetchAlerts();
    _fetchData();
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchAlerts();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final meds = await ApiService.getMedications();
      final scheds = await ApiService.getSchedules();
      if (mounted) {
        setState(() {
          _meds = meds;
          _scheds = scheds;
        });
      }
    } catch (e) {
      debugPrint('데이터 조회 오류: $e');
    }
  }

  Future<void> _fetchWeather() async {
    try {
      final res = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=Busan,KR&appid=$_weatherApiKey&units=metric&lang=kr',
      )).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final temp = data['main']['temp'].round();
        final weatherId = data['weather'][0]['id'] as int;
        IconData icon;
        if (weatherId < 300) icon = Icons.thunderstorm_rounded;
        else if (weatherId < 600) icon = Icons.umbrella_rounded;
        else if (weatherId < 700) icon = Icons.ac_unit_rounded;
        else if (weatherId == 800) icon = Icons.wb_sunny_rounded;
        else icon = Icons.cloud_rounded;
        String comment;
        if (weatherId == 800) comment = '산책하기 좋은 날씨예요 😊';
        else if (weatherId < 600) comment = '우산을 챙기세요 ☂️';
        else if (weatherId < 700) comment = '미끄럼에 주의하세요 🧤';
        else if (temp >= 30) comment = '더운 날씨예요. 수분을 챙기세요 💧';
        else if (temp <= 5) comment = '추운 날씨예요. 따뜻하게 입으세요 🧥';
        else comment = '오늘도 좋은 하루 되세요 😊';
        if (mounted) {
          setState(() {
            _temp = '$temp°C';
            _weatherCity = '부산';
            _weatherDesc = comment;
            _weatherIcon = icon;
          });
        }
      }
    } catch (e) {
      debugPrint('날씨 조회 오류: $e');
    }
  }

  Future<void> _fetchAlerts() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/alert/'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (mounted) {
          setState(() {
            final seen = <String>{};
            _alerts = data
                .where((a) => a['is_resolved'] == false || a['is_resolved'] == 0)
                .where((a) => seen.add(a['message'] ?? ''))
                .map((a) => Map<String, dynamic>.from(a))
                .toList()
                .reversed
                .take(3)
                .toList();
            _alertLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('알림 오류: $e');
      if (mounted) setState(() => _alertLoading = false);
    }
  }

  List<Map> _getTodayScheds() {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _scheds.where((s) {
      final t = s["time"].toString();
      return t.startsWith(todayStr) || (!t.contains('-') && !t.contains('202'));
    }).toList();
  }

  List<Map> _getTodayRemainingScheds() {
    return _getTodayScheds().where((s) {
      final status = s["status"].toString();
      return status != "완료" && status != "취소";
    }).toList();
  }

  String _resolveNickname() {
    final n = AppState.nickname ?? AppState.username;
    if (n == null || n.isEmpty) return '관리자';
    return n;
  }

  String _weekdayStr(int d) => ['월', '화', '수', '목', '금', '토', '일'][d - 1] + '요일';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? '좋은 아침이에요 ☀️' : now.hour < 18 ? '좋은 오후예요 🌤' : '좋은 저녁이에요 🌙';
    final emergencyAlerts = _alerts.where((a) =>
        a['type'] == '긴급' || a['type'] == '비활동' || a['type'] == '가스').toList();
    final medRemaining = _meds.where((m) => m['taken'] == false || m['taken'] == 0).length;
    final medTaken = _meds.where((m) => m['taken'] == true || m['taken'] == 1).length;
    final medTotal = _meds.length;
    final todayScheds = _getTodayScheds();
    final todayRemaining = _getTodayRemainingScheds();

    final nickname = _resolveNickname();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 인사 섹션 — 목업 스타일 (흰 배경, 둥근 하단)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                const SizedBox(height: 8),
                Text(
                  '$nickname님, 환영해요 👋',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                Text(
                  '${now.year}년 ${now.month}월 ${now.day}일 ${_weekdayStr(now.weekday)}',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_alertLoading && _alerts.isNotEmpty) ...[
                  const Text('🔔 주요 알림',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),
                  ..._alerts.map((alert) {
                    final isEmergency = alert['type'] == '긴급' || alert['type'] == '비활동';
                    return GestureDetector(
                      onTap: () => widget.onTabChange(isEmergency ? 4 : 1),
                      child: BannerWidget(
                        color: isEmergency ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                        borderColor: isEmergency ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                        icon: isEmergency ? Icons.emergency_rounded : Icons.warning_rounded,
                        iconColor: isEmergency ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                        text: alert['message'] ?? '알림',
                        textColor: isEmergency ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onTabChange(2),
                          child: _MetricCard(
                            label: '남은 일정',
                            value: '${todayRemaining.length}건',
                            sub: '오늘 기준',
                            color: const Color(0xFF6366F1),
                            icon: Icons.calendar_today_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onTabChange(1),
                          child: _MetricCard(
                            label: '복약 미완료',
                            value: '${medRemaining}건',
                            sub: '확인 필요',
                            color: const Color(0xFFEF4444),
                            icon: Icons.medication_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onTabChange(4),
                          child: _MetricCard(
                            label: '긴급 알림',
                            value: '${emergencyAlerts.length}건',
                            sub: '처리 중',
                            color: const Color(0xFFF59E0B),
                            icon: Icons.emergency_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ── 센서 현황 위젯 ──────────────────────────────────────
                const Text('🔍 센서 현황',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => widget.onTabChange(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                    ),
                    child: Row(children: [
                      _SensorStatus(
                        label: '비활동',
                        icon: Icons.accessibility_new_rounded,
                        isAlert: _alerts.any((a) => a['type'] == '비활동'),
                        alertColor: const Color(0xFFEF4444),
                      ),
                      _SensorDivider(),
                      _SensorStatus(
                        label: '가스',
                        icon: Icons.local_fire_department_rounded,
                        isAlert: _alerts.any((a) => a['type'] == '가스'),
                        alertColor: const Color(0xFFF97316),
                      ),
                      _SensorDivider(),
                      _SensorStatus(
                        label: '낙상',
                        icon: Icons.personal_injury_rounded,
                        isAlert: false,
                        alertColor: const Color(0xFFEF4444),
                      ),
                      _SensorDivider(),
                      _SensorStatus(
                        label: '재난',
                        icon: Icons.security_rounded,
                        isAlert: false,
                        alertColor: const Color(0xFFEF4444),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => widget.onTabChange(1),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.medication_rounded, color: Color(0xFF6366F1), size: 16),
                                SizedBox(width: 6),
                                Text('💊 복약 현황',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                              ],
                            ),
                            Text(
                              '$medTaken / $medTotal 완료',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: medTotal == 0 ? 0 : medTaken / medTotal,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_weatherIcon, color: Colors.white, size: 28),
                                const SizedBox(width: 8),
                                Text(_temp, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('$_weatherCity · 날씨', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(_weatherDesc, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('장치 상태', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 10),
                            ...["mic", "speaker", "network"].map((key) {
                              final labels = {"mic": "마이크", "speaker": "스피커", "network": "네트워크"};
                              final icons = {"mic": Icons.mic_rounded, "speaker": Icons.volume_up_rounded, "network": Icons.wifi_rounded};
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(icons[key], size: 14, color: const Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Text(labels[key]!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    const Spacer(),
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('📅 오늘 일정', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    GestureDetector(
                      onTap: () => widget.onTabChange(2),
                      child: const Text('전체 보기', style: TextStyle(fontSize: 13, color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...todayScheds.take(3).map((s) => LogCard(log: LogItem.fromJson(Map<String, dynamic>.from(s)))),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorStatus extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isAlert;
  final Color alertColor;

  const _SensorStatus({required this.label, required this.icon,
      required this.isAlert, required this.alertColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isAlert ? alertColor.withOpacity(0.1) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18,
              color: isAlert ? alertColor : const Color(0xFF10B981)),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(isAlert ? '감지됨' : '정상',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: isAlert ? alertColor : const Color(0xFF10B981))),
      ]),
    );
  }
}

class _SensorDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: const Color(0xFFE2E8F0),
          margin: const EdgeInsets.symmetric(horizontal: 4));
}

class _MetricCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final IconData icon;

  const _MetricCard({required this.label, required this.value, required this.sub, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}