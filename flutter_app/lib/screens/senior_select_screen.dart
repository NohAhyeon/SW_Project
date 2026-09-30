import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart';
import '../pages/camera_page.dart';
import 'login_screen.dart';
import 'senior_main_page.dart';

final _guardianApiBase = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

// DESIGN TOKENS
const _bg = Color(0xFFF7F8FA);
const _surface = Colors.white;
const _line = Color(0xFFEAECEF);
const _text1 = Color(0xFF191F28);
const _text2 = Color(0xFF4E5968);
const _text3 = Color(0xFF8B95A1);
const _brand = Color(0xFF3182F6);
const _brandSoft = Color(0xFFE8F2FE);
const _danger = Color(0xFFF04452);
const _dangerSoft = Color(0xFFFDECEE);
const _warning = Color(0xFFFF8A00);
const _warnSoft = Color(0xFFFFF3E5);
const _success = Color(0xFF00B96B);
const _sucSoft = Color(0xFFE5F8EF);

class SeniorSelectScreen extends StatefulWidget {
  final int guardianId;
  const SeniorSelectScreen({super.key, required this.guardianId});

  @override
  State<SeniorSelectScreen> createState() => _SeniorSelectScreenState();
}

class _SeniorSelectScreenState extends State<SeniorSelectScreen> {
  List<Map<String, dynamic>> _seniors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('$_guardianApiBase/guardian/seniors?guardian_id=${widget.guardianId}'),
        headers: {
          if (AppState.accessToken != null) 'Authorization': 'Bearer ${AppState.accessToken}',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) setState(() { _seniors = data.cast<Map<String, dynamic>>(); _loading = false; });
      } else {
        if (mounted) setState(() { _error = '데이터를 불러올 수 없습니다'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '연결 오류: $e'; _loading = false; });
    }
  }

  void _logout() {
    AppState.accessToken = null;
    AppState.username = null;
    AppState.nickname = null;
    AppState.role = '';
    AppState.userId = 0;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final guardianName = AppState.nickname ?? AppState.username ?? '보호자';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 상단바 ──────────────────────────────────
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 16),
              child: Row(
                children: [
                  // OASIS 로고 (SIS 부분 brand색)
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      children: [
                        TextSpan(text: 'OA', style: TextStyle(color: _text1)),
                        TextSpan(text: 'SIS', style: TextStyle(color: _brand)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 알림 아이콘
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40, height: 40,
                        alignment: Alignment.center,
                        child: const Icon(Icons.notifications_outlined, color: _text2, size: 24),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _danger,
                            shape: BoxShape.circle,
                            border: Border.all(color: _surface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 인사말 ────────────────────────────────
            Container(
              width: double.infinity,
              color: _surface,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '보호자 ${guardianName}님, 안녕하세요 👋',
                    style: const TextStyle(fontSize: 14, color: _text3, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '어르신을 선택해주세요',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: _text1),
                  ),
                ],
              ),
            ),

            // ── 컨텐츠 영역 ─────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _brand))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off_rounded, size: 52, color: Color(0xFFCBD5E1)),
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(fontSize: 16, color: _text3)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _load,
                                style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
                                child: const Text('다시 시도'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: _brand,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                // 어르신 그리드
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                                  child: GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                      childAspectRatio: 0.78,
                                    ),
                                    itemCount: _seniors.length + 1, // +1 for add card
                                    itemBuilder: (ctx, i) {
                                      if (i < _seniors.length) {
                                        return _SelCard(
                                          data: _seniors[i],
                                          onTap: () {
                                            final seniorName = _seniors[i]['nickname'] as String?;
                                            Navigator.of(ctx).push(
                                              MaterialPageRoute(
                                                builder: (_) => SeniorMainPage(seniorName: seniorName),
                                              ),
                                            ).then((_) => _load());
                                          },
                                        );
                                      }
                                      // 어르신 추가 카드
                                      return _SelAddCard();
                                    },
                                  ),
                                ),

                                // 하단 보호자 정보 푸터
                                Container(
                                  margin: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                                  padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 보호자 아바타
                                      Container(
                                        width: 32, height: 32,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [Color(0xFF3182F6), Color(0xFF5BA0FF)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          guardianName.isNotEmpty ? guardianName[0] : 'G',
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('$guardianName 보호자',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _text1)),
                                          Text('${AppState.username ?? ''}',
                                              style: const TextStyle(fontSize: 11, color: _text3, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _logout,
                                        child: const Text('로그아웃',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text3)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  어르신 선택 카드  (sel-card in mockup)
// ════════════════════════════════════════════════════════════
class _SelCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _SelCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'ok';
    final stripColor = _statusColor(status);
    final onlineColor = _statusColor(status);

    final name = data['nickname'] as String? ?? '어르신';
    final label = data['label'] as String? ?? '';
    final alertCount = (data['unresolved_alerts'] as num?)?.toInt() ?? 0;
    final medDone = (data['med_done'] as num?)?.toInt() ?? 0;
    final medTotal = (data['med_total'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            // 상단 색 라인 (4px)
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: stripColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        // 아바타 + 온라인 점
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF3182F6), Color(0xFF5BA0FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                name.isNotEmpty ? name[0] : '?',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // 온라인 상태 점
                            Positioned(
                              bottom: 2, right: 2,
                              child: Container(
                                width: 16, height: 16,
                                decoration: BoxDecoration(
                                  color: onlineColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _surface, width: 2.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _text1,
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (label.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(label,
                              style: const TextStyle(fontSize: 12, color: _text3, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),

                    // 상태 배지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusSoftColor(status),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        alertCount > 0 ? '⚠️ 알림 ${alertCount}건' : _statusText(status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: stripColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    if (s == 'danger') return _danger;
    if (s == 'warning') return _warning;
    return _success;
  }

  Color _statusSoftColor(String s) {
    if (s == 'danger') return _dangerSoft;
    if (s == 'warning') return _warnSoft;
    return _sucSoft;
  }

  String _statusText(String s) {
    if (s == 'danger') return '⚠️ 위험';
    if (s == 'warning') return '🟡 주의';
    return '✅ 정상';
  }
}

// ── 어르신 추가 카드
class _SelAddCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD1D6DB), width: 2, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _bg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('＋', style: TextStyle(fontSize: 28, color: _text3, fontWeight: FontWeight.w300)),
          ),
          const SizedBox(height: 10),
          const Text('어르신 추가',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text3)),
        ],
      ),
    );
  }
}

// ── 공용 헬퍼 ──────────────────────────────────────────────
void _toast(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF191F28),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ),
  );
}

void _showEmergencyDialog(BuildContext ctx, Map<String, dynamic> data) {
  final name = data['nickname'] as String? ?? '어르신';
  showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _dangerSoft, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Text('📞', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Text('$name 긴급 연락', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _text1)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EmergencyContactTile(label: '119 응급구조', sub: '소방청 응급 구조', emoji: '🚑', color: _dangerSoft, textColor: _danger),
          const SizedBox(height: 8),
          _EmergencyContactTile(label: '112 경찰', sub: '긴급 신고', emoji: '🚓', color: _warnSoft, textColor: _warning),
          const SizedBox(height: 8),
          _EmergencyContactTile(label: '보호자 연락', sub: '가족에게 알림 전송', emoji: '👨‍👩‍👦', color: _brandSoft, textColor: _brand),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('닫기', style: TextStyle(color: _text3, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

class _EmergencyContactTile extends StatelessWidget {
  final String label, sub, emoji;
  final Color color, textColor;
  const _EmergencyContactTile({required this.label, required this.sub, required this.emoji, required this.color, required this.textColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                Text(sub, style: const TextStyle(fontSize: 12, color: _text3, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textColor.withOpacity(0.6), size: 20),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  어르신 상세 페이지  (GuardianSeniorDetailPage)
// ════════════════════════════════════════════════════════════
class GuardianSeniorDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const GuardianSeniorDetailPage({super.key, required this.data});

  @override
  State<GuardianSeniorDetailPage> createState() => _GuardianSeniorDetailPageState();
}

class _GuardianSeniorDetailPageState extends State<GuardianSeniorDetailPage> {
  // 센서 모니터링 상태
  bool _sensorBusy = false;
  bool _inactivity = false; // 비활동 감지 여부
  bool _gas = false;        // 가스 누출 여부
  bool _fall = false;       // 낙상 감지 여부
  bool _disaster = false;   // 재난 감지 여부

  @override
  void initState() {
    super.initState();
    _loadSensors();
  }

  Future<void> _loadSensors() async {
    if (!mounted) return;
    setState(() => _sensorBusy = true);
    try {
      final res = await http.get(
        Uri.parse('$_guardianApiBase/alert/'),
        headers: {
          if (AppState.accessToken != null) 'Authorization': 'Bearer ${AppState.accessToken}',
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List alerts = jsonDecode(res.body);
        bool inact = false, gas = false, fall = false, dis = false;
        for (final a in alerts) {
          if (a['is_resolved'] == true) continue;
          final type = (a['type'] as String? ?? '').toLowerCase();
          if (type == '비활동') inact = true;
          if (type == '가스') gas = true;
          if (type == '낙상') fall = true;
          if (type == '재난') dis = true;
        }
        if (mounted) setState(() {
          _inactivity = inact;
          _gas = gas;
          _fall = fall;
          _disaster = dis;
          _sensorBusy = false;
        });
      } else {
        if (mounted) setState(() => _sensorBusy = false);
      }
    } catch (_) {
      if (mounted) setState(() => _sensorBusy = false);
    }
  }

  void _openCamera(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF191F28)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            '${widget.data['nickname'] ?? '어르신'} 홈캠',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF191F28)),
          ),
          centerTitle: true,
        ),
        body: const CameraPage(),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final status = data['status'] as String? ?? 'ok';
    final statusColor = _detailStatusColor(status);
    final statusBadgeText = _detailStatusBadgeText(data);

    final name = data['nickname'] as String? ?? '어르신';
    final label = data['label'] as String? ?? '';
    final medDone = (data['med_done'] as num?)?.toInt() ?? 0;
    final medTotal = (data['med_total'] as num?)?.toInt() ?? 0;
    final alertCount = (data['unresolved_alerts'] as num?)?.toInt() ?? 0;
    final latestAlertMsg = data['latest_alert_message'] as String? ?? '';
    final latestAlertType = data['latest_alert_type'] as String? ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 상단바 (뒤로 + 이름 + 배지) ──────────
              Container(
                color: _surface,
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36, height: 36,
                        margin: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(color: _bg, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Text('←', style: TextStyle(fontSize: 18, color: _text1)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800,
                                color: _text1, letterSpacing: -0.3,
                              )),
                          if (label.isNotEmpty)
                            Text(label, style: const TextStyle(fontSize: 12, color: _text3, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _detailStatusSoftColor(status),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(statusBadgeText,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                    ),
                  ],
                ),
              ),

              // ── 알림 배너 (알림 있을 때만) ────────────
              if (alertCount > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: status == 'danger' ? _dangerSoft : _warnSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('⚠️', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          latestAlertMsg.isNotEmpty ? latestAlertMsg : '미해결 알림 ${alertCount}건',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ),
                      if (latestAlertType.isNotEmpty)
                        Text(latestAlertType,
                            style: TextStyle(fontSize: 13, color: statusColor.withOpacity(0.8), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ── 빠른 실행 그리드 ─────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('빠른 실행',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text3)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _QuickAction(
                            emoji: '📹', label: '홈캠', color: _brandSoft, textColor: _brand,
                            onTap: () => _openCamera(context),
                          ),
                          _QuickAction(
                            emoji: '💊', label: '복약', color: _sucSoft, textColor: _success,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => _SeniorMedDetailPage(data: data)),
                            ),
                          ),
                          _QuickAction(
                            emoji: '💬', label: '대화기록', color: _warnSoft, textColor: _warning,
                            onTap: () => _toast(context, '대화기록 기능 준비 중입니다'),
                          ),
                          _QuickAction(
                            emoji: '📞', label: '긴급통화', color: _dangerSoft, textColor: _danger,
                            onTap: () => _showEmergencyDialog(context, data),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── 복약 현황 카드 ────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('복약 현황',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _text1)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => _SeniorMedDetailPage(data: data)),
                            ),
                            child: const Text('관리 ›',
                                style: TextStyle(fontSize: 14, color: _brand, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('오늘 복용',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _text1)),
                          const Spacer(),
                          Text('$medDone / $medTotal 완료',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _brand)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: medTotal > 0 ? medDone / medTotal : 0,
                          minHeight: 8,
                          backgroundColor: _bg,
                          valueColor: const AlwaysStoppedAnimation(_brand),
                        ),
                      ),
                      if (medTotal > medDone) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: _brandSoft, borderRadius: BorderRadius.circular(10)),
                                alignment: Alignment.center,
                                child: const Text('💊', style: TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('미복용 약이 있어요',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _text1)),
                                    Text('복약을 확인해주세요',
                                        style: TextStyle(fontSize: 13, color: _text3, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => _SeniorMedDetailPage(data: data)),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(10)),
                                  child: const Text('복용 확인',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── 센서 모니터링 ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 섹션 헤더
                    Row(
                      children: [
                        const Expanded(
                          child: Text('센서 모니터링',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text3)),
                        ),
                        GestureDetector(
                          onTap: () => _openCamera(context),
                          child: const Text('홈캠 ›',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _brand)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 센서 2x2 그리드
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                      ),
                      child: _sensorBusy
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(color: _brand, strokeWidth: 2),
                              ),
                            )
                          : Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _SensorItem(emoji: '🚶', name: '비활동', isAlert: _inactivity, alertText: '감지됨')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _SensorItem(emoji: '🔥', name: '가스', isAlert: _gas, alertText: '누출')),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _SensorItem(emoji: '🩺', name: '낙상', isAlert: _fall, alertText: '감지됨')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _SensorItem(emoji: '🛡️', name: '재난', isAlert: _disaster, alertText: '경보')),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _detailStatusBadgeText(Map data) {
    final status = data['status'] as String? ?? 'ok';
    final alertCount = (data['unresolved_alerts'] as num?)?.toInt() ?? 0;
    if (alertCount > 0) return '⚠️ 알림 ${alertCount}건';
    if (status == 'danger') return '⚠️ 위험';
    if (status == 'warning') return '🟡 주의';
    return '✅ 정상';
  }

  Color _detailStatusColor(String s) {
    if (s == 'danger') return _danger;
    if (s == 'warning') return _warning;
    return _success;
  }

  Color _detailStatusSoftColor(String s) {
    if (s == 'danger') return _dangerSoft;
    if (s == 'warning') return _warnSoft;
    return _sucSoft;
  }
}

// ── 센서 아이템 위젯 ─────────────────────────────────────────
class _SensorItem extends StatelessWidget {
  final String emoji;
  final String name;
  final bool isAlert;
  final String alertText;

  const _SensorItem({
    required this.emoji,
    required this.name,
    required this.isAlert,
    required this.alertText,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isAlert ? _dangerSoft : _bg;
    final statusColor = isAlert ? _danger : _success;
    final statusText = isAlert ? alertText : '정상';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _text1)),
                Text(statusText,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 빠른 실행 아이콘
class _QuickAction extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.emoji,
    required this.label,
    required this.color,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text2)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  어르신 복약 상세 페이지  (_SeniorMedDetailPage)
// ════════════════════════════════════════════════════════════
class _SeniorMedDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const _SeniorMedDetailPage({required this.data});
  @override
  State<_SeniorMedDetailPage> createState() => _SeniorMedDetailPageState();
}

class _SeniorMedDetailPageState extends State<_SeniorMedDetailPage> {
  List<Map<String, dynamic>> _meds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seniorId = widget.data['senior_id'] as int? ?? 0;
    try {
      final res = await http.get(
        Uri.parse('$_guardianApiBase/guardian/senior/$seniorId/medicines'),
        headers: {
          if (AppState.accessToken != null) 'Authorization': 'Bearer ${AppState.accessToken}',
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) setState(() { _meds = data.cast<Map<String, dynamic>>(); _loading = false; });
      } else {
        if (mounted) setState(() { _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.data['nickname'] as String? ?? '어르신';
    final medDone = (widget.data['med_done'] as num?)?.toInt() ?? 0;
    final medTotal = (widget.data['med_total'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단바
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(4, 12, 16, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      margin: const EdgeInsets.only(left: 12),
                      decoration: const BoxDecoration(color: _bg, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text('←', style: TextStyle(fontSize: 18, color: _text1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$name 복약 현황',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _text1)),
                        Text('오늘 $medDone / $medTotal 완료',
                            style: const TextStyle(fontSize: 12, color: _text3, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 진행 바
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: medTotal > 0 ? medDone / medTotal : 0,
                  minHeight: 8,
                  backgroundColor: _bg,
                  valueColor: const AlwaysStoppedAnimation(_success),
                ),
              ),
            ),

            // 복약 목록
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _brand))
                  : _meds.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💊', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(medTotal == 0 ? '등록된 복약 없음' : '복약 목록을 불러올 수 없어요',
                                  style: const TextStyle(fontSize: 16, color: _text3)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _meds.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final m = _meds[i];
                            final taken = m['is_taken'] as bool? ?? false;
                            final mName = m['name'] as String? ?? '약';
                            final dosage = m['dosage'] as String? ?? '';
                            final time = m['scheduled_time'] as String? ?? '';
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: taken ? _sucSoft : _dangerSoft,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(taken ? '✅' : '💊', style: const TextStyle(fontSize: 20)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(mName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _text1)),
                                        if (dosage.isNotEmpty || time.isNotEmpty)
                                          Text('${dosage.isNotEmpty ? dosage : ''}${dosage.isNotEmpty && time.isNotEmpty ? '  ·  ' : ''}${time.isNotEmpty ? time : ''}',
                                              style: const TextStyle(fontSize: 13, color: _text3, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: taken ? _sucSoft : _dangerSoft,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      taken ? '복용 완료' : '미복용',
                                      style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w800,
                                        color: taken ? _success : _danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
