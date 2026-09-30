import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../main.dart';
import '../pages/camera_page.dart';

// ── DESIGN TOKENS ────────────────────────────────────────────
const _bg        = Color(0xFFF7F8FA);
const _surface   = Colors.white;
const _line      = Color(0xFFEAECEF);
const _text1     = Color(0xFF191F28);
const _text2     = Color(0xFF4E5968);
const _text3     = Color(0xFF8B95A1);
const _brand     = Color(0xFF3182F6);
const _brandSoft = Color(0xFFE8F2FE);
const _danger    = Color(0xFFF04452);
const _dangerSoft= Color(0xFFFDECEE);
const _warning   = Color(0xFFFF8A00);
const _warnSoft  = Color(0xFFFFF3E5);
const _success   = Color(0xFF00B96B);
const _sucSoft   = Color(0xFFE5F8EF);

// 폰트 크기 — 보호자(일반) / 어르신(심플)
const double _fXs = 14, _fSm = 16, _fMd = 18, _fLg = 22, _fXl = 28;
const double _sXs = 20, _sSm = 24, _sMd = 28, _sLg = 34, _sXl = 44;

// ════════════════════════════════════════════════════════════
//  SeniorMainPage
// ════════════════════════════════════════════════════════════
class SeniorMainPage extends StatefulWidget {
  final String? seniorName;
  const SeniorMainPage({super.key, this.seniorName});

  @override
  State<SeniorMainPage> createState() => _SeniorMainPageState();
}

class _SeniorMainPageState extends State<SeniorMainPage> {
  int  _tab        = 0;
  bool _seniorView = false;
  int  _refreshKey = 0;

  void _switchTab(int i) {
    if (_seniorView && i > 2) return;
    setState(() => _tab = i);
  }

  void _toggleView() {
    setState(() {
      _seniorView = !_seniorView;
      if (_seniorView && _tab > 2) _tab = 0;
    });
  }

  void _dataChanged() => setState(() => _refreshKey++);
  void _goToSettings() => setState(() => _tab = 5);
  void _goToCam() => setState(() => _tab = 4);

  String get _displayName =>
      widget.seniorName ?? AppState.nickname ?? AppState.username ?? '어르신';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(
            seniorView: _seniorView,
            onToggleView: _toggleView,
            onGoMed: () => _switchTab(1),
            onGoSched: () => _switchTab(2),
            onGoSettings: _goToSettings,
            onGoCam: _goToCam,
            displayName: _displayName,
            refreshKey: _refreshKey,
          ),
          _MedTab(seniorView: _seniorView, onDataChanged: _dataChanged),
          _SchedTab(seniorView: _seniorView, onDataChanged: _dataChanged),
          _LogTab(seniorView: _seniorView),
          const _CamTab(),
          _SettingsTab(seniorView: _seniorView, onToggleView: _toggleView),
        ],
      ),
      bottomNavigationBar: _NavBar(
        current: _tab,
        onTap: _switchTab,
        seniorView: _seniorView,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  BOTTOM NAV
// ════════════════════════════════════════════════════════════
class _NavBar extends StatelessWidget {
  final int current;
  final void Function(int) onTap;
  final bool seniorView;
  const _NavBar({required this.current, required this.onTap, required this.seniorView});

  @override
  Widget build(BuildContext context) {
    final items = seniorView
        ? [_NI('🏠', '홈', 0, current, onTap, senior: true),
           _NI('💊', '복약', 1, current, onTap, senior: true),
           _NI('📅', '일정', 2, current, onTap, senior: true)]
        : [_NI('🏠', '홈', 0, current, onTap),
           _NI('💊', '복약', 1, current, onTap),
           _NI('📅', '일정', 2, current, onTap),
           _NI('💬', '기록', 3, current, onTap),
           _NI('📹', '홈캠', 4, current, onTap),
           _NI('⚙️', '설정', 5, current, onTap)];
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: items),
      ),
    );
  }
}

class _NI extends StatelessWidget {
  final String emoji, label;
  final int index, current;
  final void Function(int) onTap;
  final bool senior;
  const _NI(this.emoji, this.label, this.index, this.current, this.onTap,
      {this.senior = false});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: senior ? 12 : 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: senior ? 28 : 22)),
              SizedBox(height: senior ? 5 : 3),
              Text(label,
                  style: TextStyle(
                    fontSize: senior ? 14 : 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? _brand : _text3,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  홈 TAB
// ════════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  final bool seniorView;
  final VoidCallback onToggleView, onGoMed, onGoSched, onGoSettings, onGoCam;
  final String displayName;
  final int refreshKey;

  const _HomeTab({
    required this.seniorView,
    required this.onToggleView,
    required this.onGoMed,
    required this.onGoSched,
    required this.onGoSettings,
    required this.onGoCam,
    required this.displayName,
    required this.refreshKey,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<Map> _meds   = [];
  List<Map> _scheds = [];
  List<Map> _alerts = [];
  Map<String, dynamic>? _weather;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(_HomeTab old) {
    super.didUpdateWidget(old);
    if (old.refreshKey != widget.refreshKey) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final meds    = await ApiService.getMedications();
    final scheds  = await ApiService.getSchedules();
    final weather = await ApiService.getWeather();
    final alerts  = await ApiService.getAlerts();
    if (mounted) setState(() {
      _meds = meds; _scheds = scheds; _weather = weather;
      _alerts = alerts; _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s   = widget.seniorView;
    final now = DateTime.now();
    final fXs = s ? _sXs : _fXs;
    final fSm = s ? _sSm : _fSm;
    final fMd = s ? _sMd : _fMd;
    final fXl = s ? _sXl : _fXl;

    final medDone  = _meds.where((m) => m['taken'] == true).length;
    final medTotal = _meds.length;
    final todayStr = _dateStr(now);
    final todayScheds = _scheds.where((sc) =>
        (sc['time']?.toString() ?? '').startsWith(todayStr)).toList();
    final todaySchedDone  = todayScheds.where((sc) => sc['status'] == '완료').length;
    final todaySchedTotal = todayScheds.length;

    // 센서 알림 상태
    final hasInactivity = _alerts.any((a) => a['type'] == '비활동' && a['status'] == '처리 중');
    final hasGas        = _alerts.any((a) => a['type'] == '가스' && a['status'] == '처리 중');
    final hasFall       = _alerts.any((a) => a['type'] == '낙상' && a['status'] == '처리 중');

    // 인사말 이름 — 보호자 뷰는 보호자 이름, 어르신 뷰는 어르신 이름
    final greetName   = s ? widget.displayName
        : (AppState.nickname ?? AppState.username ?? '보호자');
    final greetSuffix = s ? '님 😊' : ' 보호자님 😊';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: _brand,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 상단 바 ──────────────────────────────────
              Container(
                color: _surface,
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 16),
                child: Row(
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5),
                        children: [
                          TextSpan(text: 'OA', style: TextStyle(color: _text1)),
                          TextSpan(text: 'SIS', style: TextStyle(color: _brand)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 보호자 ↔ 어르신 뷰 전환
                    GestureDetector(
                      onTap: widget.onToggleView,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: s ? _brand : _bg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s ? '👵' : '👤',
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(s ? '어르신' : '보호자',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: s ? Colors.white : _text3,
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 설정 아이콘 (종 → 설정으로 변경)
                    GestureDetector(
                      onTap: widget.onGoSettings,
                      child: SizedBox(
                        width: 44, height: 44,
                        child: Center(
                          child: Icon(Icons.settings_rounded,
                              color: _text2, size: s ? 26 : 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 인사 + 날씨 카드 (전체 너비, 균형 레이아웃) ──
              Container(
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: EdgeInsets.fromLTRB(22, s ? 30 : 22, 22, s ? 30 : 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4FA8FF), Color(0xFF7B6FFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF637CFF).withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: s
                    // ── 어르신 뷰: 중앙 정렬, 대형 ─────────────
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_weather != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_weatherEmoji(_weather!['main']),
                                    style: const TextStyle(fontSize: 28)),
                                const SizedBox(width: 8),
                                Text('${_weather!['temp']}°C  ${_weather!['desc']}',
                                    style: TextStyle(
                                        fontSize: fXs,
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            '${now.year}년 ${now.month}월 ${now.day}일 ${_weekday(now.weekday)}',
                            style: TextStyle(
                                fontSize: fXs,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.85)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '안녕하세요,\n$greetName$greetSuffix',
                            style: TextStyle(
                                fontSize: fXl,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.2,
                                letterSpacing: -1),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '✅ 오늘도 건강하게 지내세요',
                              style: TextStyle(
                                  fontSize: fXs,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    // ── 보호자 뷰: 좌우 레이아웃 ───────────────
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${now.year}년 ${now.month}월 ${now.day}일 ${_weekday(now.weekday)}',
                                  style: TextStyle(
                                      fontSize: fXs,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.9)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '안녕하세요,\n$greetName$greetSuffix',
                                  style: TextStyle(
                                      fontSize: fXl,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.2,
                                      letterSpacing: -0.5),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    '✅ 오늘도 건강하게 지내세요',
                                    style: TextStyle(
                                        fontSize: fXs,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 날씨 위젯
                          if (_weather != null) ...[
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_weatherEmoji(_weather!['main']),
                                    style: const TextStyle(fontSize: 38)),
                                const SizedBox(height: 4),
                                Text('${_weather!['temp']}°',
                                    style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1)),
                                const SizedBox(height: 2),
                                Text(
                                  _weather!['desc'],
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),

              // ── 빠른 요약 칩 ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    _QuickChip(
                      emoji: '💊',
                      color: _success,
                      softColor: _sucSoft,
                      label: _loading ? '…' : '$medDone/$medTotal 완료',
                      onTap: widget.onGoMed,
                    ),
                    const SizedBox(width: 10),
                    _QuickChip(
                      emoji: '📅',
                      color: _warning,
                      softColor: _warnSoft,
                      label: _loading ? '…' : '$todaySchedDone/${todaySchedTotal == 0 ? 0 : todaySchedTotal}건 완료',
                      onTap: widget.onGoSched,
                    ),
                  ],
                ),
              ),

              // ── 복약 현황 카드 (실시간) ───────────────────
              if (!_loading) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text('💊 오늘 복약 현황',
                                  style: TextStyle(
                                      fontSize: s ? _sMd : _fMd,
                                      fontWeight: FontWeight.w800,
                                      color: _text1))),
                          GestureDetector(
                            onTap: widget.onGoMed,
                            child: const Text('자세히 ›',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _brand,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: medTotal > 0 ? medDone / medTotal : 0,
                          minHeight: s ? 16 : 12,
                          backgroundColor: _bg,
                          valueColor:
                              const AlwaysStoppedAnimation(_success),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        medTotal == 0
                            ? '등록된 복약이 없어요'
                            : (medDone == medTotal
                                ? '✅ 모두 완료했어요!'
                                : '$medTotal개 중 $medDone개 완료 · ${medTotal - medDone}개 남음'),
                        style: TextStyle(
                            fontSize: s ? _sSm : _fSm,
                            fontWeight: FontWeight.w700,
                            color: _success),
                      ),
                    ],
                  ),
                ),

                // ── 오늘 일정 현황 카드 (항상 표시) ──────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text('📅 오늘 일정 현황',
                                  style: TextStyle(
                                      fontSize: s ? _sMd : _fMd,
                                      fontWeight: FontWeight.w800,
                                      color: _text1))),
                          GestureDetector(
                            onTap: widget.onGoSched,
                            child: const Text('자세히 ›',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _brand,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: todaySchedTotal > 0
                              ? todaySchedDone / todaySchedTotal
                              : 0,
                          minHeight: s ? 16 : 12,
                          backgroundColor: _bg,
                          valueColor:
                              const AlwaysStoppedAnimation(_warning),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        todaySchedTotal == 0
                            ? '오늘 일정이 없어요'
                            : (todaySchedDone == todaySchedTotal
                                ? '✅ 모든 일정 완료!'
                                : '$todaySchedTotal건 중 $todaySchedDone건 완료 · ${todaySchedTotal - todaySchedDone}건 남음'),
                        style: TextStyle(
                            fontSize: s ? _sSm : _fSm,
                            fontWeight: FontWeight.w700,
                            color: _warning),
                      ),
                      // 일정 목록 미리보기 (최대 2개)
                      if (todayScheds.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: _line),
                        const SizedBox(height: 12),
                        ...todayScheds.take(2).map((sc) {
                          final t     = _fmtTime(sc['time']?.toString() ?? '');
                          final isDone = sc['status'] == '완료';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  child: Text(t,
                                      style: TextStyle(
                                          fontSize: s ? _sSm : _fSm,
                                          fontWeight: FontWeight.w700,
                                          color: isDone ? _text3 : _brand)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        sc['title'] as String? ?? '일정',
                                        style: TextStyle(
                                            fontSize: s ? _sSm : _fSm,
                                            fontWeight: FontWeight.w600,
                                            color: isDone ? _text3 : _text1,
                                            decoration: isDone
                                                ? TextDecoration.lineThrough
                                                : null))),
                                if (isDone)
                                  const Icon(Icons.check_circle_rounded,
                                      color: _success, size: 16),
                              ],
                            ),
                          );
                        }),
                        if (todayScheds.length > 2)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '+ ${todayScheds.length - 2}건 더 있어요',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _text3,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],

              // ── 센서 모니터링 요약 카드 ──────────────────
              if (!_loading)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text('🔍 센서 모니터링',
                                  style: TextStyle(
                                      fontSize: s ? _sMd : _fMd,
                                      fontWeight: FontWeight.w800,
                                      color: _text1))),
                          GestureDetector(
                            onTap: widget.onGoCam,
                            child: const Text('자세히 ›',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _brand,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                              child: _SensorMiniCard(
                                  icon: Icons.accessibility_new_rounded,
                                  label: '비활동',
                                  isAlert: hasInactivity)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _SensorMiniCard(
                                  icon: Icons.local_fire_department_rounded,
                                  label: '가스',
                                  isAlert: hasGas)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _SensorMiniCard(
                                  icon: Icons.personal_injury_rounded,
                                  label: '낙상',
                                  isAlert: hasFall)),
                        ],
                      ),
                      if (hasInactivity || hasGas || hasFall) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _dangerSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: _danger, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  [
                                    if (hasInactivity) '비활동 감지',
                                    if (hasGas) '가스 누출 감지',
                                    if (hasFall) '낙상 감지',
                                  ].join(' · '),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _danger),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _weekday(int w) =>
      ['월', '화', '수', '목', '금', '토', '일'][w - 1] + '요일';
  String _fmtTime(String t) =>
      t.length >= 16 ? t.substring(11, 16) : t;
  String _weatherEmoji(String? main) {
    switch (main) {
      case 'Clear':        return '☀️';
      case 'Clouds':       return '☁️';
      case 'Rain':         return '🌧️';
      case 'Drizzle':      return '🌦️';
      case 'Thunderstorm': return '⛈️';
      case 'Snow':         return '❄️';
      case 'Mist': case 'Fog': case 'Haze': return '🌫️';
      default:             return '🌤️';
    }
  }
}

// ── 빠른 요약 칩 위젯
class _QuickChip extends StatelessWidget {
  final String emoji, label;
  final Color color, softColor;
  final VoidCallback onTap;
  const _QuickChip({
    required this.emoji, required this.label,
    required this.color, required this.softColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: softColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  복약 TAB
// ════════════════════════════════════════════════════════════
class _MedTab extends StatefulWidget {
  final bool seniorView;
  final VoidCallback onDataChanged;
  const _MedTab({required this.seniorView, required this.onDataChanged});

  @override
  State<_MedTab> createState() => _MedTabState();
}

class _MedTabState extends State<_MedTab> {
  List<Map> _meds  = [];
  bool _loading    = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final meds = await ApiService.getMedications();
    if (mounted) setState(() { _meds = meds; _loading = false; });
  }

  Future<void> _toggle(Map med) async {
    final taken = med['taken'] == true;
    if (taken) await ApiService.untakeMedication(med['id']);
    else       await ApiService.takeMedication(med['id']);
    await _load();
    widget.onDataChanged();
  }

  Future<void> _delete(Map med) async {
    await ApiService.deleteMedication(med['id']);
    await _load();
    widget.onDataChanged();
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController(text: '1정');
    TimeOfDay pickedTime = const TimeOfDay(hour: 8, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: _line,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              const Text('복약 추가',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _text1)),
              const SizedBox(height: 16),
              _Field(controller: nameCtrl, label: '약 이름', hint: '예: 혈압약'),
              const SizedBox(height: 12),
              _Field(controller: doseCtrl, label: '복용량', hint: '예: 1정'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(
                      context: ctx, initialTime: pickedTime);
                  if (t != null) setModal(() => pickedTime = t);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: _text3, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '복용 시간:  ${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _text1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final timeStr =
                        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                    final ok = await ApiService.addMedication(
                        nameCtrl.text.trim(), timeStr);
                    if (mounted) Navigator.pop(ctx);
                    if (ok) { await _load(); widget.onDataChanged(); }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('저장',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s    = widget.seniorView;
    final done  = _meds.where((m) => m['taken'] == true).length;
    final total = _meds.length;
    final pct   = total > 0 ? done / total : 0.0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: _brand,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 바
              Container(
                color: _surface,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Row(
                  children: [
                    Text(s ? '오늘의 약 💊' : '복약 관리',
                        style: TextStyle(
                            fontSize: s ? _sLg : 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: _text1)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showAddDialog(context),
                      child: Container(
                        width: s ? 44 : 34,
                        height: s ? 44 : 34,
                        decoration: BoxDecoration(
                            color: _brandSoft,
                            borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Icon(Icons.add_rounded,
                            color: _brand, size: s ? 28 : 22),
                      ),
                    ),
                  ],
                ),
              ),

              if (s)
              // ── 어르신 뷰: 큰 카드 리스트 ─────────────────
                _buildSeniorMedList()
              else ...[
              // ── 보호자 뷰: 달성률 카드 + 리스트 ────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF6B73FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF4A90E2).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('오늘 복약 달성률',
                          style: TextStyle(
                              fontSize: _fSm,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9))),
                      const SizedBox(height: 8),
                      Text('${(pct * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -2,
                              height: 1)),
                      const SizedBox(height: 4),
                      Text(
                        total == 0
                            ? '등록된 복약이 없어요'
                            : (done == total
                                ? '모든 약을 복용했어요 🎉'
                                : '$total개 중 $done개 완료 · ${total - done}개 남음'),
                        style: TextStyle(
                            fontSize: _fXs,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Text('오늘 복용',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _text3)),
                ),
                if (_loading)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: _brand)))
                else if (_meds.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          const Text('💊',
                              style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          const Text('등록된 복약이 없어요',
                              style: TextStyle(
                                  fontSize: _fSm, color: _text3)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => _showAddDialog(context),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12))),
                            child: const Text('복약 추가하기'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8)
                      ],
                    ),
                    child: Column(
                      children: _meds.asMap().entries.map((e) {
                        final isLast = e.key == _meds.length - 1;
                        return _MedItem(
                          med: e.value,
                          isLast: isLast,
                          seniorView: false,
                          onToggle: () => _toggle(e.value),
                          onDelete: () => _delete(e.value),
                        );
                      }).toList(),
                    ),
                  ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // 어르신 뷰 – 큰 카드 리스트
  Widget _buildSeniorMedList() {
    if (_loading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(color: _brand)));
    }
    if (_meds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              const Text('💊', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              const Text('등록된 약이 없어요',
                  style: TextStyle(
                      fontSize: _sSm, color: _text3, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: () => _showAddDialog(context as BuildContext),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: const Text('약 추가하기',
                      style: TextStyle(
                          fontSize: _sSm, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: _meds.map((med) {
        final done    = med['taken'] == true;
        final timeRaw = med['time'] as String? ?? '';
        final name    = med['name'] as String? ?? '약';
        final parts = timeRaw.split(':');
        final h = int.tryParse(parts.first) ?? 0;
        final m = parts.length > 1 ? parts[1].padLeft(2, '0').substring(0, 2) : '00';
        final timeLabel = timeRaw.isNotEmpty
            ? '${h < 12 ? '오전' : '오후'} ${h == 0 ? 12 : (h > 12 ? h - 12 : h)}:$m'
            : '';
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: done ? _sucSoft : _surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: done ? _success.withOpacity(0.3) : _line, width: 1.5),
            boxShadow: done
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💊', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: _sMd,
                                fontWeight: FontWeight.w900,
                                color: done ? _text3 : _text1,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null)),
                        if (timeLabel.isNotEmpty)
                          Text(timeLabel,
                              style: const TextStyle(
                                  fontSize: _sXs,
                                  color: _text3,
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => _toggle(med),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: done ? _success : _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    done ? '✅  복용 완료' : '복용하기',
                    style: const TextStyle(
                        fontSize: _sSm, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MedItem extends StatelessWidget {
  final Map med;
  final bool isLast, seniorView;
  final VoidCallback onToggle, onDelete;

  const _MedItem({
    required this.med, required this.isLast,
    required this.seniorView, required this.onToggle, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done    = med['taken'] == true;
    final timeRaw = med['time'] as String? ?? '';
    final name    = med['name'] as String? ?? '약';

    return Dismissible(
      key: ValueKey(med['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _danger,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(isLast ? 20 : 0),
            bottomRight: Radius.circular(isLast ? 20 : 0),
          ),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('복약 삭제',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              content: Text('$name을(를) 삭제할까요?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('삭제',
                        style: TextStyle(
                            color: _danger, fontWeight: FontWeight.w700))),
              ],
            ),
          ) ??
          false,
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: _line)),
          ),
          child: Row(
            children: [
              Container(
                width: 60, height: 50,
                decoration: BoxDecoration(
                    color: _bg, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_fmtTime(timeRaw),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _text1)),
                    Text(_ampm(timeRaw),
                        style: const TextStyle(
                            fontSize: 11,
                            color: _text3,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: done ? _text3 : _text1,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                        )),
                    if ((med['dose'] as String? ?? '').isNotEmpty)
                      Text(med['dose'] as String,
                          style: const TextStyle(
                              fontSize: 13, color: _text3)),
                  ],
                ),
              ),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? _success : Colors.transparent,
                  border: Border.all(
                      color: done ? _success : _line, width: 2),
                ),
                alignment: Alignment.center,
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTime(String t) {
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(t)) {
      final p = t.split(':');
      return '${int.parse(p[0])}:${p[1]}';
    }
    return t;
  }

  String _ampm(String t) {
    if (!RegExp(r'^\d{1,2}:\d{2}').hasMatch(t)) return '';
    return (int.tryParse(t.split(':')[0]) ?? 0) < 12 ? 'AM' : 'PM';
  }
}

// ════════════════════════════════════════════════════════════
//  일정 TAB
// ════════════════════════════════════════════════════════════
class _SchedTab extends StatefulWidget {
  final bool seniorView;
  final VoidCallback onDataChanged;
  const _SchedTab({required this.seniorView, required this.onDataChanged});

  @override
  State<_SchedTab> createState() => _SchedTabState();
}

class _SchedTabState extends State<_SchedTab> {
  List<Map> _scheds  = [];
  bool _loading      = true;
  DateTime _selected = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final scheds = await ApiService.getSchedules();
    if (mounted) setState(() { _scheds = scheds; _loading = false; });
  }

  List<Map> get _dayScheds {
    final s   = _selected;
    final key = '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
    return _scheds
        .where((sc) =>
            (sc['time']?.toString() ?? '').startsWith(key))
        .toList()
      ..sort((a, b) => (a['time'] as String? ?? '')
          .compareTo(b['time'] as String? ?? ''));
  }

  List<Map> get _todayScheds {
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _scheds
        .where((sc) => (sc['time']?.toString() ?? '').startsWith(key))
        .toList()
      ..sort((a, b) => (a['time'] as String? ?? '')
          .compareTo(b['time'] as String? ?? ''));
  }

  Future<void> _deleteSchedule(Map sc) async {
    await ApiService.deleteSchedule(sc['id']);
    await _load();
    widget.onDataChanged();
  }

  Future<void> _toggleComplete(Map sc) async {
    final done = sc['status'] == '완료';
    if (done) await ApiService.uncompleteSchedule(sc['id']);
    else      await ApiService.completeSchedule(sc['id']);
    await _load();
    widget.onDataChanged();
  }

  void _showAddDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    DateTime pickedDate = _selected;
    TimeOfDay pickedTime = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: _line,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              const Text('일정 추가',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _text1)),
              const SizedBox(height: 16),
              _Field(
                  controller: titleCtrl, label: '제목', hint: '예: 병원 진료'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: pickedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setModal(() => pickedDate = d);
                },
                child: _PickerBox(
                  icon: Icons.calendar_today_rounded,
                  text:
                      '${pickedDate.year}년 ${pickedDate.month}월 ${pickedDate.day}일',
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(
                      context: ctx, initialTime: pickedTime);
                  if (t != null) setModal(() => pickedTime = t);
                },
                child: _PickerBox(
                  icon: Icons.access_time_rounded,
                  text:
                      '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final dt = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute);
                    final ok = await ApiService.addSchedule(
                        titleCtrl.text.trim(), dt.toIso8601String());
                    if (mounted) Navigator.pop(ctx);
                    if (ok) { await _load(); widget.onDataChanged(); }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('저장',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.seniorView;

    // 어르신 뷰: 오늘 일정만 단순 표시
    if (s) return _buildSeniorView(context);

    // 보호자 뷰: 주간 달력 + 상세 일정
    final now       = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekDays  = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final weekLabel = _weekLabel(now);
    final dayList   = _dayScheds;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load, color: _brand,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: _surface,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    const Text('일정',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: _text1)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showAddDialog(context),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                            color: _brandSoft,
                            borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: const Icon(Icons.add_rounded,
                            color: _brand, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: _surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(weekLabel,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _text3)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: weekDays.map((d) {
                        final isSelected = d.day == _selected.day &&
                            d.month == _selected.month &&
                            d.year == _selected.year;
                        final isToday = d.day == now.day &&
                            d.month == now.month &&
                            d.year == now.year;
                        final key =
                            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        final hasSched = _scheds.any((s) =>
                            (s['time']?.toString() ?? '').startsWith(key));
                        return GestureDetector(
                          onTap: () => setState(() => _selected = d),
                          child: Column(
                            children: [
                              Text(
                                ['월','화','수','목','금','토','일'][d.weekday - 1],
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? _brand : _text3,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _text1
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text('${d.day}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : (isToday ? _brand : _text1),
                                    )),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 5, height: 5,
                                decoration: BoxDecoration(
                                  color: hasSched
                                      ? _brand
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Text(
                  '${_selected.day == now.day ? '오늘' : '${_selected.month}/${_selected.day}'} 일정 ${dayList.length}건',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _text3),
                ),
              ),
              if (_loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: _brand)))
              else if (dayList.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Text('📅',
                            style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        const Text('일정이 없어요 😊',
                            style: TextStyle(
                                fontSize: 16, color: _text3)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _showAddDialog(context),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12))),
                          child: const Text('일정 추가하기'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...dayList.map((sc) => _SchedItem(
                      data: sc,
                      onComplete: () => _toggleComplete(sc),
                      onDelete: () => _deleteSchedule(sc),
                    )),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // 어르신 뷰: 오늘 일정만 심플하게
  Widget _buildSeniorView(BuildContext context) {
    final now      = DateTime.now();
    final todayList = _todayScheds;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load, color: _brand,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: _surface,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Row(
                  children: [
                    Text('오늘 일정 📅',
                        style: const TextStyle(
                            fontSize: _sLg,
                            fontWeight: FontWeight.w800,
                            color: _text1)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showAddDialog(context),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                            color: _brandSoft,
                            borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: const Icon(Icons.add_rounded,
                            color: _brand, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: _brandSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${now.month}월 ${now.day}일 ${_weekday(now.weekday)}',
                  style: const TextStyle(
                      fontSize: _sSm,
                      fontWeight: FontWeight.w800,
                      color: _brand),
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(60),
                        child: CircularProgressIndicator(color: _brand)))
              else if (todayList.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        const Text('📅',
                            style: TextStyle(fontSize: 60)),
                        const SizedBox(height: 16),
                        const Text('오늘 일정이 없어요 😊',
                            style: TextStyle(
                                fontSize: _sSm,
                                color: _text3,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 60,
                          child: ElevatedButton(
                            onPressed: () => _showAddDialog(context),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16))),
                            child: const Text('일정 추가하기',
                                style: TextStyle(
                                    fontSize: _sSm,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...todayList.map((sc) {
                  final time   = _fmtTime(sc['time']?.toString() ?? '');
                  final title  = sc['title'] as String? ?? '일정';
                  final isDone = sc['status'] == '완료';
                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDone ? _sucSoft : _surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: isDone
                              ? _success.withOpacity(0.3)
                              : _line,
                          width: 1.5),
                      boxShadow: isDone
                          ? []
                          : [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(time,
                            style: const TextStyle(
                                fontSize: _sXs,
                                fontWeight: FontWeight.w700,
                                color: _brand)),
                        const SizedBox(height: 6),
                        Text(title,
                            style: TextStyle(
                              fontSize: _sMd,
                              fontWeight: FontWeight.w900,
                              color: isDone ? _text3 : _text1,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: () => _toggleComplete(sc),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDone ? _success : _brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16)),
                            ),
                            child: Text(
                              isDone ? '✅  완료됨' : '완료하기',
                              style: const TextStyle(
                                  fontSize: _sSm,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTime(String t) =>
      t.length >= 16 ? t.substring(11, 16) : t;
  String _weekday(int w) =>
      ['월', '화', '수', '목', '금', '토', '일'][w - 1] + '요일';
  String _weekLabel(DateTime now) {
    final ord = ['첫째', '둘째', '셋째', '넷째', '다섯째'];
    return '${now.month}월 ${ord[((now.day - 1) ~/ 7).clamp(0, 4)]} 주';
  }
}

class _SchedItem extends StatelessWidget {
  final Map data;
  final VoidCallback onComplete, onDelete;
  static const _colors = [_brand, _warning, _success, Color(0xFF9B59B6)];

  const _SchedItem(
      {required this.data, required this.onComplete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final timeStr = _fmtTime(data['time']?.toString() ?? '');
    final title   = data['title'] as String? ?? '일정';
    final isDone  = data['status'] == '완료';
    final color   = _colors[title.hashCode.abs() % _colors.length];

    return Dismissible(
      key: ValueKey('${data['id']}_${data['time']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: _danger, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('일정 삭제',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              content: Text('"$title"을(를) 삭제할까요?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('삭제',
                        style: TextStyle(
                            color: _danger,
                            fontWeight: FontWeight.w700))),
              ],
            ),
          ) ??
          false,
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onComplete,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: isDone ? _bg : _surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDone
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8)
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 4, height: 70,
                decoration: BoxDecoration(
                  color: isDone ? _text3 : color,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(timeStr,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _text3)),
                      const SizedBox(height: 3),
                      Text(title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDone ? _text3 : _text1,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                          )),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? _success : Colors.transparent,
                    border: Border.all(
                        color: isDone ? _success : _line, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTime(String t) => t.length >= 16 ? t.substring(11, 16) : t;
}

// ════════════════════════════════════════════════════════════
//  기록 TAB
// ════════════════════════════════════════════════════════════
class _LogTab extends StatefulWidget {
  final bool seniorView;
  const _LogTab({required this.seniorView});

  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  List<Map>  _chats  = [];
  bool       _loading = true;
  bool       _showSearch = false;
  String     _query = '';
  final      _searchCtrl = TextEditingController();
  final      _scrollCtrl = ScrollController();
  Timer?     _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // 5초마다 자동 갱신
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _loadSilently());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final chats = await ApiService.getChatLogs();
    if (mounted) {
      setState(() { _chats = chats; _loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _loadSilently() async {
    final chats = await ApiService.getChatLogs();
    if (!mounted) return;
    if (chats.length != _chats.length) {
      setState(() => _chats = chats);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  List<Map> get _filteredChats {
    if (_query.isEmpty) return _chats;
    return _chats.where((c) =>
        (c['content'] as String? ?? '').toLowerCase().contains(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            color: _surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                  child: Row(
                    children: [
                      const Text('대화 기록',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _text1)),
                      const Spacer(),
                      // 새로고침 버튼
                      GestureDetector(
                        onTap: _load,
                        child: Container(
                          width: 40, height: 40,
                          child: Center(
                            child: Icon(Icons.refresh_rounded,
                                color: _text3, size: 22),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) {
                              _query = '';
                              _searchCtrl.clear();
                            }
                          });
                        },
                        child: Container(
                          width: 40, height: 40,
                          child: Center(
                            child: Icon(Icons.search_rounded,
                                color: _showSearch ? _brand : _text3,
                                size: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 검색 바
                if (_showSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: (v) =>
                          setState(() => _query = v.toLowerCase()),
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '검색어를 입력하세요',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: _text3, size: 18),
                        suffixIcon: _query.isNotEmpty
                            ? GestureDetector(
                                onTap: () => setState(() {
                                  _query = '';
                                  _searchCtrl.clear();
                                }),
                                child: const Icon(Icons.clear_rounded,
                                    color: _text3, size: 18),
                              )
                            : null,
                        filled: true,
                        fillColor: _bg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _brand))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _brand,
                    child: _buildChatList(),
                    displacement: 20,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final list = _filteredChats;
    if (list.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 80),
        Center(
            child: Text('대화 기록이 없어요',
                style: TextStyle(fontSize: 16, color: _text3))),
      ]);
    }
    // getChatLogs에서 이미 오래된순 정렬됨
    final Map<String, List<Map>> grouped = {};
    for (final c in list) {
      final key = _dateKey(c['time'] as String? ?? '');
      grouped.putIfAbsent(key, () => []).add(c);
    }
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: grouped.entries.toList()
          .map((e) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 4),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _line,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _text3)),
                        ),
                      )),
                  ...e.value.map((c) => _ChatBubble(data: c)),
                ],
              ))
          .toList(),
    );
  }

  String _dateKey(String t) {
    try {
      final dt  = DateTime.parse(t.replaceAll(' ', 'T'));
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day)
        return '오늘 · ${now.month}월 ${now.day}일';
      final yd = now.subtract(const Duration(days: 1));
      if (dt.year == yd.year && dt.month == yd.month && dt.day == yd.day)
        return '어제 · ${dt.month}월 ${dt.day}일';
      return '${dt.month}월 ${dt.day}일';
    } catch (_) { return '이전'; }
  }
}

class _ChatBubble extends StatelessWidget {
  final Map data;
  const _ChatBubble({required this.data});

  @override
  Widget build(BuildContext context) {
    final role    = data['role'] as String? ?? '';
    final content = data['content'] as String? ?? '';
    final timeStr = _fmtTime(data['time'] as String? ?? '');
    final maxW    = MediaQuery.of(context).size.width * 0.72;
    final isUser  = role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isUser)
            // ── 사용자 발화 (오른쪽) ──
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: maxW),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: _brand,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(content,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.white, height: 1.4)),
                  ),
                  const SizedBox(height: 4),
                  Text(timeStr,
                      style: const TextStyle(fontSize: 11, color: _text3)),
                ],
              ),
            )
          else
            // ── AI 응답 (왼쪽) ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                      color: _brandSoft,
                      borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: const Text('🤖', style: TextStyle(fontSize: 15)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('오아시스',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _brand)),
                      const SizedBox(height: 4),
                      Container(
                        constraints: BoxConstraints(maxWidth: maxW),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Text(content,
                            style: const TextStyle(
                                fontSize: 15, color: _text2, height: 1.45)),
                      ),
                      const SizedBox(height: 4),
                      Text(timeStr,
                          style: const TextStyle(fontSize: 11, color: _text3)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _fmtTime(String t) {
    try {
      final dt = DateTime.parse(t.replaceAll(' ', 'T'));
      final h  = dt.hour;
      final m  = dt.minute.toString().padLeft(2, '0');
      final ap = h < 12 ? '오전' : '오후';
      final dh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$ap $dh:$m';
    } catch (_) {
      return t.length >= 16 ? t.substring(11, 16) : t;
    }
  }
}

// ════════════════════════════════════════════════════════════
//  홈캠 TAB
// ════════════════════════════════════════════════════════════
class _CamTab extends StatelessWidget {
  const _CamTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            color: _surface,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: const Row(
              children: [
                Text('홈캠',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: _text1)),
              ],
            ),
          ),
          const Expanded(child: CameraPage()),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  설정 TAB
// ════════════════════════════════════════════════════════════
class _SettingsTab extends StatelessWidget {
  final bool seniorView;
  final VoidCallback onToggleView;
  const _SettingsTab(
      {required this.seniorView, required this.onToggleView});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 바
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: const Row(
                children: [
                  Text('설정',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _text1)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 내 정보
            _SettingSection(title: '내 정보', children: [
              _SettingRow(
                icon: Icons.person_rounded,
                iconBg: _brandSoft,
                iconColor: _brand,
                label: AppState.nickname ?? AppState.username ?? '보호자',
                sub: AppState.username ?? '',
              ),
            ]),
            const SizedBox(height: 16),

            // 화면 설정
            _SettingSection(title: '화면 설정', children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: _brandSoft,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.text_fields_rounded,
                          color: _brand, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('어르신 모드',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _text1)),
                          Text('더 크고 간단한 화면',
                              style:
                                  TextStyle(fontSize: 13, color: _text3)),
                        ],
                      ),
                    ),
                    Switch(
                      value: seniorView,
                      onChanged: (_) => onToggleView(),
                      activeColor: _brand,
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // 앱 정보
            _SettingSection(title: '앱 정보', children: [
              _SettingRow(
                icon: Icons.info_outline_rounded,
                iconBg: const Color(0xFFF0F4FF),
                iconColor: const Color(0xFF6B7AFF),
                label: 'OASIS',
                sub: '어르신 안심 케어 서비스  v1.0.0',
              ),
            ]),
            const SizedBox(height: 16),

            // 로그아웃
            _SettingSection(title: '계정', children: [
              GestureDetector(
                onTap: () {
                  AppState.role     = '';
                  AppState.username = null;
                  Navigator.of(context)
                      .popUntil((route) => route.isFirst);
                },
                child: Container(
                  color: _surface,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                            color: _dangerSoft,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.logout_rounded,
                            color: _danger, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text('로그아웃',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _danger)),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SettingSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingSection(
      {required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _text3)),
        ),
        Container(
          color: _surface,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label, sub;
  const _SettingRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _text1)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 13, color: _text3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  공용 위젯
// ════════════════════════════════════════════════════════════
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  const _Field(
      {required this.controller,
      required this.label,
      required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _brand, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── 센서 미니 카드 (홈탭 요약용)
class _SensorMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isAlert;
  const _SensorMiniCard({required this.icon, required this.label, required this.isAlert});

  @override
  Widget build(BuildContext context) {
    final color = isAlert ? _danger : _success;
    final bg    = isAlert ? _dangerSoft : _sucSoft;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _text2)),
          const SizedBox(height: 3),
          Text(isAlert ? '⚠️ 감지' : '정상',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}

class _PickerBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PickerBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, color: _text3, size: 18),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _text1)),
        ],
      ),
    );
  }
}
