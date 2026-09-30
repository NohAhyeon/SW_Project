import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../data/api_service.dart';

final String _streamUrl = dotenv.env['CAMERA_STREAM_URL'] ?? 'http://localhost:5000/';
const int _refreshInterval = 30;

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with TickerProviderStateMixin {
  // ── 카메라 ──────────────────────────────────────────────────────────────────
  bool _isConnected = false;
  late WebViewController _webViewController;

  // ── 데이터 ──────────────────────────────────────────────────────────────────
  List<Map> _allAlerts = [];
  bool _isLoading = true;
  int _countdown = _refreshInterval;
  Timer? _pollingTimer;
  Timer? _countdownTimer;

  // ── 애니메이션 ────────────────────────────────────────────────────────────
  late AnimationController _pulseController;   // LIVE 점 깜빡임
  late AnimationController _bannerController;  // 경고 배너 페이드인
  late Animation<double> _pulseAnim;
  late Animation<double> _bannerAnim;

  // ── 파생 데이터 ──────────────────────────────────────────────────────────
  List<Map> get _inactivityAlerts =>
      _allAlerts.where((a) => a["type"] == "비활동").toList();
  List<Map> get _gasAlerts =>
      _allAlerts.where((a) => a["type"] == "가스").toList();
  List<Map> get _unresolvedAlerts =>
      _allAlerts.where((a) => a["status"] == "처리 중").toList();

  bool get _hasInactivityAlert =>
      _inactivityAlerts.any((a) => a["status"] == "처리 중");
  bool get _hasGasAlert =>
      _gasAlerts.any((a) => a["status"] == "처리 중");
  bool get _hasCriticalAlert => _hasInactivityAlert || _hasGasAlert;

  int get _todayCount {
    final today = DateTime.now();
    return _allAlerts.where((a) {
      try {
        final t = DateTime.parse((a["time"] as String).replaceAll(' ', 'T'));
        return t.year == today.year && t.month == today.month && t.day == today.day;
      } catch (_) { return false; }
    }).length;
  }

  int get _resolvedCount =>
      _allAlerts.where((a) => a["status"] == "처리 완료").length;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initAnimations();
    _loadAlerts();
    _startTimers();
  }

  void _initCamera() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isConnected = true);
          // style 태그를 head에 주입 → 이미지 생성 즉시 적용
          _webViewController.runJavaScript('''
            (function() {
              var s = document.createElement('style');
              s.textContent = 'html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:#000;} img{width:100%!important;height:100%!important;object-fit:fill!important;display:block!important;}';
              if (document.head) document.head.appendChild(s);
              else document.addEventListener("DOMContentLoaded", function(){ document.head.appendChild(s); });
            })();
          ''');
        },
        onPageFinished: (_) async {
          // 페이지가 완전히 로드됐으면 JSON 에러인지 확인
          try {
            final result = await _webViewController.runJavaScriptReturningResult(
              "document.body ? document.body.innerText.trim().startsWith('{') : false",
            );
            if (mounted) setState(() => _isConnected = result.toString() != 'true');
          } catch (_) {
            // MJPEG 스트리밍은 페이지 완료 없이 계속 전송 → 연결 유지
          }
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _isConnected = false);
        },
      ))
      ..loadRequest(Uri.parse(_streamUrl));
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bannerController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _bannerAnim = CurvedAnimation(parent: _bannerController, curve: Curves.easeOut);
  }

  void _startTimers() {
    _pollingTimer = Timer.periodic(
      const Duration(seconds: _refreshInterval),
      (_) => _loadAlerts(),
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown = _countdown > 0 ? _countdown - 1 : _refreshInterval;
      });
    });
  }

  Future<void> _loadAlerts() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _countdown = _refreshInterval; });

    final data = await ApiService.getAlerts();

    if (!mounted) return;
    final hadCritical = _hasCriticalAlert;
    setState(() {
      _allAlerts = data;
      _isLoading = false;
    });

    if (_hasCriticalAlert && !hadCritical) {
      _bannerController.forward(from: 0);
    } else if (!_hasCriticalAlert) {
      _bannerController.reverse();
    } else {
      _bannerController.forward();
    }
  }

  Future<void> _resolveAlert(int id) async {
    final ok = await ApiService.resolveAlert(id);
    if (!ok || !mounted) return;
    setState(() {
      final idx = _allAlerts.indexWhere((a) => a["id"] == id);
      if (idx != -1) _allAlerts[idx] = {..._allAlerts[idx], "status": "처리 완료"};
    });
    if (!_hasCriticalAlert) _bannerController.reverse();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF6366F1),
      onRefresh: _loadAlerts,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEmergencyBanner(),
            _buildCameraView(),
            _buildStatsRow(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSensorGrid(),
                  const SizedBox(height: 24),
                  _buildAlertTimeline(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 경고 배너 ────────────────────────────────────────────────────────────
  Widget _buildEmergencyBanner() {
    return FadeTransition(
      opacity: _bannerAnim,
      child: SizeTransition(
        sizeFactor: _bannerAnim,
        child: _hasCriticalAlert
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Opacity(
                        opacity: _pulseAnim.value,
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 6)],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('긴급 알림 발생',
                              style: TextStyle(color: Colors.white, fontSize: 13,
                                  fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (_hasInactivityAlert) '비활동 감지',
                              if (_hasGasAlert) '가스 누출 감지',
                            ].join(' · '),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _loadAlerts,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // ── 카메라 뷰 ────────────────────────────────────────────────────────────
  Widget _buildCameraView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w * 2 / 3; // 3:2 비율
    return Stack(
      children: [
        // WebView는 항상 렌더링 (연결 시 표시)
        SizedBox(
          width: w,
          height: h,
          child: Container(
            color: const Color(0xFF0F172A),
            child: WebViewWidget(controller: _webViewController),
          ),
        ),
        // Not Found / 미연결 시 네이비 블루 오버레이
        if (!_isConnected)
          SizedBox(
            width: w,
            height: h,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A1628), Color(0xFF0D2240)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_off_rounded,
                      color: Colors.white.withOpacity(0.28), size: 52),
                  const SizedBox(height: 14),
                  Text('카메라 연결 대기 중',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('서버와 연결되면 자동으로 시작됩니다',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.38), fontSize: 12)),
                ],
              ),
            ),
          ),
        // LIVE 배지
        Positioned(
          top: 12, left: 12,
          child: GestureDetector(
            onTap: _isConnected
                ? null
                : () => _webViewController.loadRequest(Uri.parse(_streamUrl)),
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_isConnected
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444))
                        .withOpacity(_isConnected ? _pulseAnim.value : 1.0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _isConnected ? _pulseAnim.value : 1.0,
                      child: Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: _isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: _isConnected
                              ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.6), blurRadius: 4)]
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isConnected ? 'LIVE' : 'OFFLINE · 탭하여 재연결',
                      style: TextStyle(
                        color: _isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 시간
        Positioned(
          top: 12, right: 12,
          child: _buildGlassBadge(
            child: Text(
              _formatTime(DateTime.now()),
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        // 디바이스 라벨
        Positioned(
          bottom: 12, left: 12,
          child: _buildGlassBadge(
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_rounded, color: Colors.white38, size: 12),
                SizedBox(width: 4),
                Text('OASIS CAM · Raspberry Pi',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ),
        // 자동 갱신 카운트다운
        Positioned(
          bottom: 12, right: 12,
          child: _buildGlassBadge(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    value: _countdown / _refreshInterval,
                    strokeWidth: 1.5,
                    color: Colors.white38,
                    backgroundColor: Colors.white12,
                  ),
                ),
                const SizedBox(width: 5),
                Text('${_countdown}s',
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
      },
    );
  }

  // ── 오늘 통계 바 ──────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.notifications_rounded,
            label: '오늘 발생',
            value: '$_todayCount건',
            color: const Color(0xFF6366F1),
          ),
          const _Divider(),
          _StatChip(
            icon: Icons.check_circle_rounded,
            label: '해결 완료',
            value: '$_resolvedCount건',
            color: const Color(0xFF10B981),
          ),
          const _Divider(),
          _StatChip(
            icon: Icons.warning_rounded,
            label: '미해결',
            value: '${_unresolvedAlerts.length}건',
            color: _unresolvedAlerts.isNotEmpty
                ? const Color(0xFFEF4444)
                : const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  // ── 센서 그리드 ──────────────────────────────────────────────────────────
  Widget _buildSensorGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('센서 모니터링'),
        const SizedBox(height: 12),
        // 3개 센서를 균등 Row로 배치 (빈 칸 없음)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SensorCard(
                  icon: Icons.accessibility_new_rounded,
                  label: '비활동 감지',
                  status: _hasInactivityAlert ? '감지됨' : '정상',
                  isAlert: _hasInactivityAlert,
                  count: _inactivityAlerts.length,
                  gradient: _hasInactivityAlert
                      ? const LinearGradient(colors: [Color(0xFFFEE2E2), Color(0xFFFEF2F2)])
                      : const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)]),
                  iconColor: _hasInactivityAlert ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SensorCard(
                  icon: Icons.local_fire_department_rounded,
                  label: '가스 감지',
                  status: _hasGasAlert ? '누출 감지' : '정상',
                  isAlert: _hasGasAlert,
                  count: _gasAlerts.length,
                  gradient: _hasGasAlert
                      ? const LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFFFFBEB)])
                      : const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)]),
                  iconColor: _hasGasAlert ? const Color(0xFFF97316) : const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SensorCard(
                  icon: Icons.personal_injury_rounded,
                  label: '낙상 감지',
                  status: '정상',
                  isAlert: false,
                  count: 0,
                  gradient: const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)]),
                  iconColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 알림 타임라인 ─────────────────────────────────────────────────────────
  Widget _buildAlertTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSectionHeader('감지 기록')),
            GestureDetector(
              onTap: _isLoading ? null : _loadAlerts,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF6366F1)),
                      )
                    : const Row(
                        key: ValueKey('refresh'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF6366F1)),
                          SizedBox(width: 3),
                          Text('새로고침',
                              style: TextStyle(fontSize: 12, color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('아래로 당겨서 갱신 · ${_countdown}초 후 자동 갱신',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 14),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          ),
        if (!_isLoading && _allAlerts.isEmpty)
          _buildEmptyState(),
        if (!_isLoading && _allAlerts.isNotEmpty)
          ..._allAlerts.take(6).toList().asMap().entries.map((entry) {
            final i = entry.key;
            final alert = entry.value;
            final items = _allAlerts.take(6).toList();
            return _buildTimelineItem(alert, i, i == items.length - 1);
          }),
        if (_allAlerts.length > 6)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => _showAllAlertsSheet(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('전체 기록 보기',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Color(0xFF6366F1))),
                    const SizedBox(width: 4),
                    Text('(${_allAlerts.length}건)',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF6366F1)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineItem(Map alert, int index, bool isLast) {
    final isUnresolved = alert["status"] == "처리 중";
    final type = alert["type"] as String? ?? '';
    final id = alert["id"] as int?;
    final isGas = type == "가스";

    final iconData = isGas
        ? Icons.local_fire_department_rounded
        : Icons.accessibility_new_rounded;
    final activeColor = isGas ? const Color(0xFFF97316) : const Color(0xFFEF4444);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 타임라인 선
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isUnresolved ? activeColor : const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isUnresolved
                        ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Icon(
                    isUnresolved ? iconData : Icons.check_rounded,
                    color: Colors.white, size: 15,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 카드
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnresolved ? activeColor.withOpacity(0.4) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isUnresolved
                          ? activeColor.withOpacity(0.06)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 8, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isUnresolved
                                ? activeColor.withOpacity(0.1)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type.isEmpty ? '알림' : type,
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: isUnresolved ? activeColor : const Color(0xFF10B981),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isUnresolved && id != null)
                          GestureDetector(
                            onTap: () => _resolveAlert(id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('해결',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ),
                          )
                        else
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF10B981), size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alert["content"] as String? ?? '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B), height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(alert["time"] as String? ?? ''),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 48),
          SizedBox(height: 12),
          Text('이상 감지 없음', style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          SizedBox(height: 4),
          Text('모든 센서가 정상 작동 중입니다',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  void _showAllAlertsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllAlertsSheet(alerts: _allAlerts, onResolve: _resolveAlert),
    );
  }

  // ── 유틸 ────────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A)));
  }

  Widget _buildGlassBadge({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw.replaceAll(' ', 'T')).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

// ── 전체 기록 바텀시트 ──────────────────────────────────────────────────────
class _AllAlertsSheet extends StatelessWidget {
  final List<Map> alerts;
  final Future<void> Function(int) onResolve;

  const _AllAlertsSheet({required this.alerts, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('전체 감지 기록',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
            ]),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('총 ${alerts.length}건',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            ]),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final alert = alerts[i];
                final isUnresolved = alert["status"] == "처리 중";
                final type = alert["type"] as String? ?? '';
                final isGas = type == "가스";
                final color = isGas ? const Color(0xFFF97316) : const Color(0xFFEF4444);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUnresolved ? color.withOpacity(0.3) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: isUnresolved ? color.withOpacity(0.1) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isUnresolved
                            ? (isGas ? Icons.local_fire_department_rounded : Icons.accessibility_new_rounded)
                            : Icons.check_circle_rounded,
                        color: isUnresolved ? color : const Color(0xFF10B981),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(alert["content"] as String? ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B))),
                      const SizedBox(height: 2),
                      Text(alert["time"] as String? ?? '',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ])),
                    if (isUnresolved && alert["id"] != null)
                      GestureDetector(
                        onTap: () {
                          onResolve(alert["id"] as int);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('해결',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ── 재사용 위젯 ─────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _StatChip({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFE2E8F0),
        margin: const EdgeInsets.symmetric(horizontal: 8));
  }
}

class _SensorCard extends StatelessWidget {
  final IconData icon;
  final String label, status;
  final bool isAlert;
  final int count;
  final LinearGradient gradient;
  final Color iconColor;

  const _SensorCard({required this.icon, required this.label, required this.status,
      required this.isAlert, required this.count, required this.gradient,
      required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert ? iconColor.withOpacity(0.4) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isAlert ? iconColor.withOpacity(0.1) : Colors.black.withOpacity(0.03),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(status,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: isAlert ? iconColor : const Color(0xFF10B981))),
            ],
          ),
        ],
      ),
    );
  }
}
