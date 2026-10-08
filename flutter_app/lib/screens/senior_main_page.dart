import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../main.dart';
import '../pages/camera_page.dart';

// ── DESIGN TOKENS (Toss-style flat system) ─────────────────
// 원칙: 그림자 대신 면 색 차이(흰 카드 / 회색 배경)로 구분하고,
//       강조색은 블루 하나만 쓴다. 빨강은 긴급 상황에만 쓴다.
// 글자색은 배경 대비 4.5:1 이상 (어르신 가독성)
const _bg        = Color(0xFFF2F4F6);
const _surface   = Colors.white;
const _line      = Color(0xFFEDF0F3);
const _text1     = Color(0xFF191F28);
const _text2     = Color(0xFF4E5968);
const _text3     = Color(0xFF6B7684);
const _text4     = Color(0xFFB0B8C1);
const _brand     = Color(0xFF2F6FEB);
const _brandSoft = Color(0xFFE8F1FF);
const _sky       = _brand;
const _skySoft   = _brandSoft;
const _done      = Color(0xFF4E5968);
const _doneSoft  = Color(0xFFF2F4F6);
const _danger    = Color(0xFFE42939);
const _dangerSoft= Color(0xFFFDEEEF);
const _heroGradient = LinearGradient(
  colors: [Color(0xFF2F6FEB), Color(0xFF4A86F2)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

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
        ? [_NI(Icons.home_rounded, '홈', 0, current, onTap, senior: true),
           _NI(Icons.medication_rounded, '복약', 1, current, onTap, senior: true),
           _NI(Icons.calendar_month_rounded, '일정', 2, current, onTap, senior: true)]
        : [_NI(Icons.home_rounded, '홈', 0, current, onTap),
           _NI(Icons.medication_rounded, '복약', 1, current, onTap),
           _NI(Icons.calendar_month_rounded, '일정', 2, current, onTap),
           _NI(Icons.forum_rounded, '기록', 3, current, onTap),
           _NI(Icons.videocam_rounded, '홈캠', 4, current, onTap),
           _NI(Icons.settings_rounded, '설정', 5, current, onTap)];
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: items),
        ),
      ),
    );
  }
}

class _NI extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final void Function(int) onTap;
  final bool senior;
  const _NI(this.icon, this.label, this.index, this.current, this.onTap,
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
              Icon(icon,
                  size: senior ? 30 : 25,
                  color: active ? _text1 : _text4),
              SizedBox(height: senior ? 5 : 3),
              Text(label,
                  style: TextStyle(
                    fontSize: senior ? 14 : 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? _text1 : _text3,
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

    final medDone  = _meds.where((m) => m['taken'] == true).length;
    final medTotal = _meds.length;
    final todayStr = _dateStr(now);
    final todayScheds = _scheds.where((sc) =>
        (sc['time']?.toString() ?? '').startsWith(todayStr)).toList()
      ..sort((a, b) => (a['time']?.toString() ?? '').compareTo(b['time']?.toString() ?? ''));
    final todaySchedDone  = todayScheds.where((sc) => sc['status'] == '완료').length;
    final todaySchedTotal = todayScheds.length;
    final nextSched = todayScheds.cast<Map?>().firstWhere(
        (sc) => sc!['status'] != '완료' && sc['status'] != '취소',
        orElse: () => null);

    // 센서 알림 상태
    // 비활동 감지는 수면·TV 시청 오작동 우려로 사용하지 않음
    final hasGas        = _alerts.any((a) => a['type'] == '가스' && a['status'] == '처리 중');
    final hasFall       = _alerts.any((a) => a['type'] == '낙상' && a['status'] == '처리 중');
    final anyAlert      = hasGas || hasFall;
    final alertText = [
      if (hasGas) '가스 누출',
      if (hasFall) '낙상',
    ].join(', ');

    // 인사말 — 보호자 뷰는 보호자 이름, 어르신 뷰는 어르신 이름
    final greetName = s ? widget.displayName
        : (AppState.nickname ?? AppState.username ?? '보호자');
    final hello = now.hour < 12 ? '좋은 아침이에요' : (now.hour < 18 ? '좋은 오후예요' : '편안한 저녁 되세요');
    final headline = s ? '$greetName님,\n$hello' : '$greetName님,\n오늘도 안심하세요';

    // 복약/일정 요약 문구
    final medSub = medTotal == 0
        ? '등록된 약이 없어요'
        : (medDone == medTotal ? '오늘 약을 모두 드셨어요' : '${medTotal - medDone}개 남았어요');
    final schedSub = todaySchedTotal == 0
        ? '오늘은 일정이 없어요'
        : (nextSched == null
            ? '오늘 일정을 모두 마쳤어요'
            : '다음 ${_fmtTime(nextSched['time']?.toString() ?? '')} ${nextSched['title'] ?? '일정'}');

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: _brand,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ── 상단 바 ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: Row(
                children: [
                  const Text('OASIS',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: _text1)),
                  const Spacer(),
                  _ViewToggle(senior: s, onTap: widget.onToggleView),
                  IconButton(
                    onPressed: widget.onGoSettings,
                    icon: Icon(Icons.settings_outlined, color: _text2, size: s ? 28 : 24),
                  ),
                ],
              ),
            ),

            // ── 인사말 (카드 없이 큰 글씨) ───────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${now.month}월 ${now.day}일 ${_weekday(now.weekday)}',
                      style: TextStyle(
                          fontSize: s ? 18 : 15,
                          color: _text3,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(headline,
                      style: TextStyle(
                          fontSize: s ? 32 : 26,
                          height: 1.35,
                          letterSpacing: -0.6,
                          fontWeight: FontWeight.w800,
                          color: _text1)),
                ],
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _brand)),
              )
            else ...[
              // ── 1. 안심 상태 ───────────────────────────
              _HomeCard(
                onTap: widget.onGoCam,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: s ? 60 : 52, height: s ? 60 : 52,
                          decoration: BoxDecoration(
                            color: anyAlert ? _dangerSoft : _brandSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              anyAlert ? Icons.priority_high_rounded : Icons.check_rounded,
                              color: anyAlert ? _danger : _brand,
                              size: s ? 34 : 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('지금 집 안은',
                                  style: TextStyle(fontSize: s ? 17 : 14, color: _text3, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(anyAlert ? '$alertText 감지' : '모두 안전해요',
                                  style: TextStyle(
                                      fontSize: s ? 24 : 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: anyAlert ? _danger : _text1)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: _text4, size: s ? 30 : 26),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(height: 1, color: _line),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _SensorDot(label: '가스', alert: hasGas, senior: s),
                        _SensorDot(label: '낙상', alert: hasFall, senior: s),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 2. 오늘 챙길 것 ─────────────────────────
              _HomeCard(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('오늘 챙길 것',
                        style: TextStyle(
                            fontSize: s ? 22 : 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: _text1)),
                    const SizedBox(height: 8),
                    _HomeRow(
                      icon: Icons.medication_rounded,
                      title: '복약',
                      sub: medSub,
                      trailing: medTotal == 0 ? null : '$medDone/$medTotal',
                      done: medTotal > 0 && medDone == medTotal,
                      progress: medTotal == 0 ? null : medDone / medTotal,
                      senior: s,
                      onTap: widget.onGoMed,
                    ),
                    Container(height: 1, color: _line, margin: const EdgeInsets.only(left: 60)),
                    _HomeRow(
                      icon: Icons.calendar_today_rounded,
                      title: '일정',
                      sub: schedSub,
                      trailing: todaySchedTotal == 0 ? null : '$todaySchedDone/$todaySchedTotal',
                      done: todaySchedTotal > 0 && todaySchedDone == todaySchedTotal,
                      progress: todaySchedTotal == 0 ? null : todaySchedDone / todaySchedTotal,
                      senior: s,
                      onTap: widget.onGoSched,
                    ),
                  ],
                ),
              ),

              // ── 3. 날씨 ─────────────────────────────────
              if (_weather != null)
                _HomeCard(
                  child: Row(
                    children: [
                      Text(_weatherEmoji(_weather!['main']),
                          style: TextStyle(fontSize: s ? 40 : 34)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('부산 ${_weather!['temp']}°',
                                style: TextStyle(
                                    fontSize: s ? 24 : 20,
                                    fontWeight: FontWeight.w800,
                                    color: _text1)),
                            const SizedBox(height: 2),
                            Text(_weatherTip(_weather!),
                                style: TextStyle(fontSize: s ? 17 : 14, color: _text3, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _weatherTip(Map<String, dynamic> w) {
    final temp = (w['temp'] as num?)?.toInt() ?? 20;
    final main = w['main'] as String? ?? '';
    if (main == 'Rain' || main == 'Drizzle' || main == 'Thunderstorm') return '비 소식이 있어요. 외출 시 우산을 챙기세요';
    if (main == 'Snow') return '눈이 와요. 미끄럼에 조심하세요';
    if (temp >= 30) return '더운 날이에요. 물을 자주 드세요';
    if (temp <= 5) return '쌀쌀해요. 따뜻하게 입으세요';
    return '${w['desc']} · 산책하기 좋은 날씨예요';
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

// ── 홈 공용: 흰 카드 (그림자·테두리 없이 면 색 차이로만 구분)
class _HomeCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const _HomeCard({required this.child, this.onTap, this.padding = const EdgeInsets.all(22)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ── 보호자/어르신 화면 전환 토글
class _ViewToggle extends StatelessWidget {
  final bool senior;
  final VoidCallback onTap;
  const _ViewToggle({required this.senior, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool on) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? _text1 : _text3)),
        );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _line,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [seg('보호자', !senior), seg('어르신', senior)],
        ),
      ),
    );
  }
}

// ── 센서 상태 점 (안심 상태 카드 하단)
class _SensorDot extends StatelessWidget {
  final String label;
  final bool alert, senior;
  const _SensorDot({required this.label, required this.alert, required this.senior});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: alert ? _danger : _brand,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: senior ? 17 : 14, color: _text2, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(alert ? '감지' : '정상',
              style: TextStyle(
                  fontSize: senior ? 17 : 14,
                  fontWeight: FontWeight.w700,
                  color: alert ? _danger : _text3)),
        ],
      ),
    );
  }
}

// ── 리스트 행: 아이콘 원 + 제목/설명 + 오른쪽 진행 상황
class _HomeRow extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final String? trailing;
  final double? progress;
  final bool done, senior;
  final VoidCallback onTap;
  const _HomeRow({
    required this.icon, required this.title, required this.sub,
    this.trailing, this.progress, required this.done,
    required this.senior, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = senior ? 52.0 : 44.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: box, height: box,
              decoration: const BoxDecoration(color: _brandSoft, shape: BoxShape.circle),
              child: Icon(icon, color: _brand, size: box * 0.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: senior ? 21 : 17,
                          fontWeight: FontWeight.w700,
                          color: _text1)),
                  const SizedBox(height: 3),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: senior ? 17 : 14,
                          color: done ? _brand : _text3,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (progress != null) ...[
              SizedBox(
                width: senior ? 50 : 44, height: senior ? 50 : 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        backgroundColor: _line,
                        valueColor: const AlwaysStoppedAnimation(_brand),
                      ),
                    ),
                    done
                        ? Icon(Icons.check_rounded, color: _brand, size: senior ? 24 : 20)
                        : Text(trailing ?? '',
                            style: TextStyle(
                                fontSize: senior ? 13 : 11,
                                fontWeight: FontWeight.w800,
                                color: _text1)),
                  ],
                ),
              ),
            ] else
              Icon(Icons.chevron_right_rounded, color: _text4, size: senior ? 30 : 26),
          ],
        ),
      ),
    );
  }
}

// ── 아이콘 배지: 연한 배경 + 아이콘 (이모지 대신 통일된 아이콘 사용)
class _TitleBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _TitleBadge({required this.icon, required this.color, this.size = 32, bool large = false})
      : _large = large;
  final bool _large;

  @override
  Widget build(BuildContext context) {
    final box = _large && size == 32 ? 40.0 : size;
    return Container(
      width: box, height: box,
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(0.10), Colors.white),
        borderRadius: BorderRadius.circular(box * 0.3),
      ),
      child: Icon(icon, size: box * 0.56, color: color),
    );
  }
}

// ── 빠른 요약 칩 위젯
class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, softColor;
  final VoidCallback onTap;
  const _QuickChip({
    required this.icon, required this.label,
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
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
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
    meds.sort((a, b) => (a['time']?.toString() ?? '').padLeft(5, '0')
        .compareTo((b['time']?.toString() ?? '').padLeft(5, '0')));
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
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
                child: Row(
                  children: [
                    Text(s ? '오늘의 약' : '복약 관리',
                        style: TextStyle(
                            fontSize: s ? _sLg : 26,
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
                    color: _surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('오늘 복약 달성률',
                          style: TextStyle(
                              fontSize: _fSm,
                              fontWeight: FontWeight.w600,
                              color: _text3)),
                      const SizedBox(height: 8),
                      Text('${(pct * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: _text1,
                              letterSpacing: -2,
                              height: 1)),
                      const SizedBox(height: 4),
                      Text(
                        total == 0
                            ? '등록된 복약이 없어요'
                            : (done == total
                                ? '모든 약을 복용했어요'
                                : '$total개 중 $done개 완료 · ${total - done}개 남음'),
                        style: TextStyle(
                            fontSize: _fXs,
                            color: _text3,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: _line,
                          valueColor:
                              const AlwaysStoppedAnimation(_brand),
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
                          const _TitleBadge(icon: Icons.medication_rounded, color: _brand, size: 72),
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
              const _TitleBadge(icon: Icons.medication_rounded, color: _brand, size: 88),
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
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            
            
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TitleBadge(icon: Icons.medication_rounded, color: done ? _text3 : _brand, size: 52),
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
                    backgroundColor: done ? _doneSoft : _brand,
                    foregroundColor: done ? _done : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    done ? '✓  복용 완료' : '복용하기',
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
                  color: done ? _done : Colors.transparent,
                  border: Border.all(
                      color: done ? _done : _line, width: 2),
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
      final h = int.parse(p[0]);
      return '${h % 12 == 0 ? 12 : h % 12}:${p[1].substring(0, 2)}';
    }
    return t;
  }

  String _ampm(String t) {
    if (!RegExp(r'^\d{1,2}:\d{2}').hasMatch(t)) return '';
    return (int.tryParse(t.split(':')[0]) ?? 0) < 12 ? '오전' : '오후';
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
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
                child: Row(
                  children: [
                    const Text('일정',
                        style: TextStyle(
                            fontSize: 26,
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
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                ),
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
                                      ? _brand
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
                padding: const EdgeInsets.fromLTRB(28, 20, 20, 10),
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
                        const _TitleBadge(icon: Icons.calendar_month_rounded, color: _sky, size: 72),
                        const SizedBox(height: 12),
                        const Text('일정이 없어요',
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
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
                child: Row(
                  children: [
                    Text('오늘 일정',
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
                        const _TitleBadge(icon: Icons.calendar_month_rounded, color: _sky, size: 88),
                        const SizedBox(height: 16),
                        const Text('오늘 일정이 없어요',
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
                      color: _surface,
                      borderRadius: BorderRadius.circular(22),
                      
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
                              backgroundColor: isDone ? _doneSoft : _brand,
                              foregroundColor: isDone ? _done : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16)),
                            ),
                            child: Text(
                              isDone ? '✓  완료됨' : '완료하기',
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
  static const _colors = [_brand, _sky, _done, Color(0xFF4F46E5)];

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
                    color: isDone ? _done : Colors.transparent,
                    border: Border.all(
                        color: isDone ? _done : _line, width: 2),
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
//  기록 TAB — 캐릭터 채팅방 스타일
//  어르신(오른쪽)과 오아시스(왼쪽)가 나눈 대화를 메신저처럼 보여준다.
// ════════════════════════════════════════════════════════════
const _oasisAvatar = 'assets/icon/app_icon.png';

class _LogTab extends StatefulWidget {
  final bool seniorView;
  const _LogTab({required this.seniorView});

  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  List<Map> _chats   = [];
  bool      _loading = true;
  String    _query   = '';
  final     _searchCtrl = TextEditingController();
  final     _scrollCtrl = ScrollController();
  Timer?    _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // 5초마다 새 대화 확인
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadSilently());
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

  int get _todayCount {
    final now = DateTime.now();
    return _chats.where((c) {
      final dt = DateTime.tryParse((c['time'] as String? ?? '').replaceAll(' ', 'T'));
      return c['role'] == 'user' && dt != null &&
          dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.seniorView;
    return Container(
      color: _bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _LogHeader(onRefresh: _load, senior: s),
            // 안내 배너
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '오아시스의 답변은 AI가 생성한 내용이에요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: s ? 15 : 12, color: _text3, fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _brand))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _brand,
                      displacement: 20,
                      child: _buildChatList(s),
                    ),
            ),
            _LogSearchBar(
              controller: _searchCtrl,
              senior: s,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              onClear: () => setState(() { _query = ''; _searchCtrl.clear(); }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(bool s) {
    final list = _filteredChats;
    final children = <Widget>[];

    // 검색 중이 아닐 때만 캐릭터 프로필 카드
    if (_query.isEmpty) {
      children.add(_OasisProfileCard(
          todayCount: _todayCount, totalCount: _chats.length, senior: s));
    }

    if (list.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Text(
          _query.isEmpty
              ? '아직 대화가 없어요.\n어르신이 오아시스에게 말을 걸면 여기에 기록돼요.'
              : '"$_query" 에 대한 대화가 없어요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: s ? 17 : 14, color: _text3, height: 1.6),
        ),
      ));
    } else {
      String? lastDate;
      for (final c in list) {
        final key = _dateKey(c['time'] as String? ?? '');
        if (key != lastDate) {
          children.add(_DateDivider(label: key));
          lastDate = key;
        }
        children.add(_ChatBubble(data: c, senior: s));
      }
    }

    return ListView(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: children,
    );
  }

  String _dateKey(String t) {
    try {
      final dt  = DateTime.parse(t.replaceAll(' ', 'T'));
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day)
        return '오늘 · ${dt.month}월 ${dt.day}일';
      final yd = now.subtract(const Duration(days: 1));
      if (dt.year == yd.year && dt.month == yd.month && dt.day == yd.day)
        return '어제 · ${dt.month}월 ${dt.day}일';
      return '${dt.month}월 ${dt.day}일';
    } catch (_) { return '이전 대화'; }
  }
}

// ── 오아시스 원형 아바타
class _OasisAvatar extends StatelessWidget {
  final double size;
  final double border;
  const _OasisAvatar({this.size = 36, this.border = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      padding: EdgeInsets.all(border),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: _brand.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipOval(child: Image.asset(_oasisAvatar, fit: BoxFit.cover)),
    );
  }
}

// ── 상단 헤더: 아바타 + 이름 + 새로고침
class _LogHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool senior;
  const _LogHeader({required this.onRefresh, required this.senior});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Row(
        children: [
          _OasisAvatar(size: senior ? 48 : 42, border: 2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('오아시스',
                    style: TextStyle(
                        fontSize: senior ? 22 : 18,
                        fontWeight: FontWeight.w800,
                        color: _text1)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(color: _brand, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('어르신의 AI 말벗 · 대화 기록',
                        style: TextStyle(fontSize: senior ? 15 : 12, color: _text3, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: _text2, size: 24),
            tooltip: '새로고침',
          ),
        ],
      ),
    );
  }
}

// ── 대화방 맨 위 캐릭터 프로필 카드
class _OasisProfileCard extends StatelessWidget {
  final int todayCount, totalCount;
  final bool senior;
  const _OasisProfileCard({required this.todayCount, required this.totalCount, required this.senior});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
      decoration: BoxDecoration(
        gradient: _heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: _brand.withOpacity(0.22), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          _OasisAvatar(size: senior ? 112 : 96, border: 4),
          const SizedBox(height: 14),
          Text('오아시스',
              style: TextStyle(
                  fontSize: senior ? 26 : 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text('오늘도 어르신 곁에서 이야기를 나눠요',
              style: TextStyle(
                  fontSize: senior ? 17 : 14,
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 18),
          Row(
            children: [
              _ProfileStat(label: '오늘 대화', value: '$todayCount회', senior: senior),
              const SizedBox(width: 10),
              _ProfileStat(label: '전체 기록', value: '$totalCount개', senior: senior),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label, value;
  final bool senior;
  const _ProfileStat({required this.label, required this.value, required this.senior});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: senior ? 22 : 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: senior ? 14 : 12,
                    color: Colors.white.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

// ── 날짜 구분선
class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _text1.withOpacity(0.08),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _text2)),
        ),
      ),
    );
  }
}

// ── 말풍선
class _ChatBubble extends StatelessWidget {
  final Map data;
  final bool senior;
  const _ChatBubble({required this.data, this.senior = false});

  @override
  Widget build(BuildContext context) {
    final role    = data['role'] as String? ?? '';
    final content = data['content'] as String? ?? '';
    final type    = data['type'] as String? ?? '';
    final timeStr = _fmtTime(data['time'] as String? ?? '');
    final maxW    = MediaQuery.of(context).size.width * 0.66;
    final isUser  = role == 'user';
    final fs      = senior ? 19.0 : 15.0;

    final timeText = Text(timeStr,
        style: TextStyle(fontSize: senior ? 13 : 11, color: _text3));

    if (isUser) {
      // ── 어르신 발화 (오른쪽, 블루)
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: Text('어르신',
                  style: TextStyle(fontSize: senior ? 14 : 12, color: _text3, fontWeight: FontWeight.w600)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                timeText,
                const SizedBox(width: 6),
                Container(
                  constraints: BoxConstraints(maxWidth: maxW),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: _brand,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text(content,
                      style: TextStyle(fontSize: fs, color: Colors.white, height: 1.45)),
                ),
              ],
            ),
            if (type.isNotEmpty && type != '생활정보') ...[
              const SizedBox(height: 6),
              _TypeNote(type: type, senior: senior),
            ],
          ],
        ),
      );
    }

    // ── 오아시스 답변 (왼쪽, 흰 말풍선 + 아바타)
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OasisAvatar(size: senior ? 44 : 38, border: 1.5),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text('오아시스',
                      style: TextStyle(fontSize: senior ? 14 : 12, color: _text3, fontWeight: FontWeight.w600)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxW),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: _text1.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Text(content,
                            style: TextStyle(fontSize: fs, color: _text1, height: 1.45)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    timeText,
                  ],
                ),
              ],
            ),
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

// ── AI가 분류한 대화 주제 표시 (서술형 말풍선)
class _TypeNote extends StatelessWidget {
  final String type;
  final bool senior;
  const _TypeNote({required this.type, required this.senior});

  @override
  Widget build(BuildContext context) {
    final isEmergency = type == '긴급';
    final color = isEmergency ? _danger : (type == '일정' ? _sky : _brand);
    final icon = switch (type) {
      '복약' => Icons.medication_rounded,
      '일정' => Icons.calendar_month_rounded,
      '긴급' => Icons.warning_amber_rounded,
      _      => Icons.label_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isEmergency ? _dangerSoft : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: senior ? 16 : 13, color: color),
          const SizedBox(width: 4),
          Text(isEmergency ? '긴급 대화로 분류됐어요' : '$type 관련 대화',
              style: TextStyle(fontSize: senior ? 14 : 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── 하단 검색창 (메신저 입력창 모양)
class _LogSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool senior;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _LogSearchBar({
    required this.controller, required this.senior,
    required this.onChanged, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: senior ? 18 : 15, color: _text1),
              decoration: InputDecoration(
                hintText: '대화 내용 검색',
                hintStyle: TextStyle(color: _text3, fontSize: senior ? 18 : 15),
                prefixIcon: const Icon(Icons.search_rounded, color: _text3, size: 22),
                filled: true,
                fillColor: _bg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) {
              final active = v.text.isNotEmpty;
              if (!active) return const SizedBox.shrink();
              return GestureDetector(
                onTap: active ? onClear : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: active ? _brand : _bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(active ? Icons.close_rounded : Icons.search_rounded,
                      color: active ? Colors.white : _text3, size: 22),
                ),
              );
            },
          ),
        ],
      ),
    );
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
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
            child: const Row(
              children: [
                Text('홈캠',
                    style: TextStyle(
                        fontSize: 26,
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
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
              child: const Row(
                children: [
                  Text('설정',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _text1)),
                ],
              ),
            ),
            const SizedBox(height: 4),

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
            const SizedBox(height: 4),

            // 챗봇 이름 (어르신이 부르는 애칭)
            _SettingSection(title: '챗봇', children: [
              _WakeNameRow(senior: seniorView),
            ]),
            const SizedBox(height: 4),

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
                    Switch.adaptive(
                      value: seniorView,
                      onChanged: (_) => onToggleView(),
                      activeColor: _brand,
                      activeTrackColor: _brand,
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 4),

            // 앱 정보
            _SettingSection(title: '앱 정보', children: [
              _SettingRow(
                icon: Icons.info_outline_rounded,
                iconBg: _brandSoft,
                iconColor: _brand,
                label: 'OASIS',
                sub: '어르신 안심 케어 서비스  v1.0.0',
              ),
            ]),
            const SizedBox(height: 4),

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

// ── 챗봇 이름 설정 행: 어르신이 '○○야' 하고 부르는 애칭
String _callingName(String name) {
  final code = name.codeUnitAt(name.length - 1) - 0xAC00;
  final batchim = code >= 0 && code < 11172 && code % 28 != 0;
  return name + (batchim ? '아' : '야');
}

class _WakeNameRow extends StatefulWidget {
  final bool senior;
  const _WakeNameRow({required this.senior});
  @override
  State<_WakeNameRow> createState() => _WakeNameRowState();
}

class _WakeNameRowState extends State<_WakeNameRow> {
  String? _name;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await ApiService.getWakeName();
    if (mounted) setState(() => _name = n);
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _edit() async {
    final ctrl = TextEditingController(text: _name ?? '');
    String? error;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              const Text('챗봇 이름 정하기',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _text1)),
              const SizedBox(height: 6),
              const Text('어르신이 이 이름으로 부르면 대답해요.\n부르기 쉬운 2~6글자 이름이 좋아요.',
                  style: TextStyle(fontSize: 14, color: _text3, height: 1.5)),
              const SizedBox(height: 18),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 6,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: '예: 복실이, 순이, 오아시스',
                  errorText: error,
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setSheet(() => error = null),
              ),
              if (ctrl.text.trim().length >= 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text("어르신은 '${_callingName(ctrl.text.trim())}' 하고 부르시면 돼요",
                      style: const TextStyle(fontSize: 14, color: _brand, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    final err = await ApiService.setWakeName(ctrl.text.trim());
                    if (err != null) {
                      setSheet(() => error = err);
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                    _toast("이제 '${_callingName(_name ?? '')}' 하고 부르면 대답해요");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('저장', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final ok = await ApiService.resetWakeName();
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                    _toast(ok ? '다음에 말을 걸면 어르신께 이름을 여쭤봐요' : '서버에 연결할 수 없어요');
                  },
                  child: const Text('어르신이 직접 짓도록 처음부터 다시 하기',
                      style: TextStyle(fontSize: 14, color: _text3, fontWeight: FontWeight.w600)),
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
    final s = widget.senior;
    final name = _name;
    return InkWell(
      onTap: _edit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _brandSoft, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.record_voice_over_rounded, color: _brand, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('챗봇 이름',
                      style: TextStyle(fontSize: s ? 19 : 16, fontWeight: FontWeight.w700, color: _text1)),
                  Text(name == null ? '불러오는 중…' : "'${_callingName(name)}' 하고 부르면 대답해요",
                      style: TextStyle(fontSize: s ? 15 : 13, color: _text3)),
                ],
              ),
            ),
            Text(name ?? '',
                style: TextStyle(fontSize: s ? 19 : 16, fontWeight: FontWeight.w700, color: _brand)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: _text4),
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
          padding: const EdgeInsets.fromLTRB(28, 4, 20, 10),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _text3)),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
          ),
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
    final color = isAlert ? _danger : _brand;
    final bg    = isAlert ? _dangerSoft : _brandSoft;
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
