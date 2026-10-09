import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_service.dart';
import '../main.dart';
import 'senior_main_page.dart';

// ── 어르신 고르기 (넷플릭스 프로필 선택처럼) ─────────────────────
// 친가·외가 어르신을 한 화면에서 고른다. 얼굴 옆 점 색으로 지금 상태를 한눈에 본다.
//   파랑 = 안전, 빨강 = 가스·낙상·긴급 감지, 회색 = 아직 기기 연결 전
// 지금은 순자 어르신(senior_id 4) 댁에만 기기가 연결되어 있다.
// 다른 어르신은 '기기 연결 전'으로 표시만 하고, 목록은 이 폰에 저장한다.

const _bg        = Color(0xFFF2F4F6);
const _surface   = Colors.white;
const _text1     = Color(0xFF191F28);
const _text2     = Color(0xFF4E5968);
const _text3     = Color(0xFF6B7684);
const _text4     = Color(0xFFB0B8C1);
const _brand     = Color(0xFF2F6FEB);
const _brandSoft = Color(0xFFE8F1FF);
const _danger    = Color(0xFFE42939);
const _dangerSoft= Color(0xFFFDEEEF);

const _avatarColors = [
  Color(0xFF2F6FEB), Color(0xFF12A594), Color(0xFFF08C00), Color(0xFF7048E8), Color(0xFFE8590C),
];
const relations = ['친가 할머니', '친가 할아버지', '외가 할머니', '외가 할아버지', '기타'];

class SeniorProfile {
  String id, name, relation, phone;
  int color;
  int? seniorId;                 // 기기가 연결된 어르신만 있음 (서버의 어르신 번호)

  SeniorProfile({required this.id, required this.name, required this.relation,
      this.phone = '', this.color = 0, this.seniorId});

  bool get connected => seniorId != null;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'relation': relation, 'phone': phone, 'color': color, 'seniorId': seniorId};

  factory SeniorProfile.fromJson(Map<String, dynamic> j) => SeniorProfile(
        id: j['id'], name: j['name'], relation: j['relation'] ?? '기타',
        phone: j['phone'] ?? '', color: j['color'] ?? 0, seniorId: j['seniorId']);
}

class ProfileStore {
  static const _key = 'oasis_profiles_v1';

  static List<SeniorProfile> defaults() => [
        SeniorProfile(id: 'p1', name: '순자', relation: '친가 할머니', color: 0, seniorId: 4),
        SeniorProfile(id: 'p2', name: '영자', relation: '외가 할머니', color: 1),
        SeniorProfile(id: 'p3', name: '만수', relation: '외가 할아버지', color: 2),
      ];

  static Future<List<SeniorProfile>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return defaults();
      return (jsonDecode(raw) as List).map((e) => SeniorProfile.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return defaults();
    }
  }

  static Future<void> save(List<SeniorProfile> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(list.map((p) => p.toJson()).toList()));
    } catch (_) {}
  }
}

// 기기가 연결된 어르신의 지금 상태 (선택 화면에 한 줄로 보여 줄 것)
class _LiveStatus {
  final String? danger;           // '가스 누출' 같은 감지 내용 (없으면 안전)
  final int medDone, medTotal;
  final String? lastTalk;         // '2026-10-09 15:41'
  const _LiveStatus({this.danger, this.medDone = 0, this.medTotal = 0, this.lastTalk});
}

class ProfileSelectScreen extends StatefulWidget {
  const ProfileSelectScreen({super.key});
  @override
  State<ProfileSelectScreen> createState() => _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends State<ProfileSelectScreen> {
  List<SeniorProfile> _profiles = [];
  _LiveStatus? _live;
  bool _editing = false;

  Timer? _dangerTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // 위험 알림은 2초마다 확인 → 어르신 카드가 바로 빨갛게
    _dangerTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshDanger());
  }

  @override
  void dispose() {
    _dangerTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshDanger() async {
    final l = _live;
    if (l == null) return;
    final alerts = await ApiService.getAlerts();
    final open = alerts.where((a) => a['status'] == '처리 중').map((a) => a['type']).toSet();
    final danger = [
      if (open.contains('가스')) '가스 누출',
      if (open.contains('낙상')) '낙상',
      if (open.contains('긴급')) '긴급 호출',
    ].join(', ');
    final d = danger.isEmpty ? null : danger;
    if (mounted && d != l.danger) {
      setState(() => _live = _LiveStatus(danger: d, medDone: l.medDone, medTotal: l.medTotal, lastTalk: l.lastTalk));
    }
  }

  Future<void> _load() async {
    final list = await ProfileStore.load();
    if (mounted) setState(() => _profiles = list);
    await _loadLive();
  }

  Future<void> _loadLive() async {
    final alerts = await ApiService.getAlerts();
    final meds = await ApiService.getMedications();
    final open = alerts.where((a) => a['status'] == '처리 중').map((a) => a['type']).toSet();
    final danger = [
      if (open.contains('가스')) '가스 누출',
      if (open.contains('낙상')) '낙상',
      if (open.contains('긴급')) '긴급 호출',
    ].join(', ');
    final live = _LiveStatus(
      danger: danger.isEmpty ? null : danger,
      medDone: meds.where((m) => m['taken'] == true).length,
      medTotal: meds.length,
    );
    if (mounted) setState(() => _live = live);
    final summary = await ApiService.getDailySummary();          // AI 요약이 있어 조금 늦게 온다
    if (mounted && summary != null) {
      setState(() => _live = _LiveStatus(
          danger: live.danger, medDone: live.medDone, medTotal: live.medTotal,
          lastTalk: summary['last_talk_at']?.toString()));
    }
  }

  void _open(SeniorProfile p) {
    if (_editing) {
      _edit(p);
      return;
    }
    if (!p.connected) {
      _notConnected(p);
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SeniorMainPage(seniorName: p.name, profile: p)))
        .then((_) => _loadLive());
  }

  void _notConnected(SeniorProfile p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(profile: p, size: 56, dot: null),
              const SizedBox(height: 16),
              Text('${p.name} 어르신 댁에는\n아직 기기가 없어요',
                  style: const TextStyle(fontSize: 22, height: 1.35, fontWeight: FontWeight.w800, color: _text1)),
              const SizedBox(height: 10),
              const Text('OASIS 기기를 설치하면 이곳에서 복약·대화·안전 상태를 함께 살펴볼 수 있어요.',
                  style: TextStyle(fontSize: 15, height: 1.5, color: _text2)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('확인', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(SeniorProfile? p) async {
    final isNew = p == null;
    final target = p ??
        SeniorProfile(id: 'p${DateTime.now().millisecondsSinceEpoch}', name: '', relation: '외가 할머니',
            color: _profiles.length % _avatarColors.length);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _EditSheet(profile: target, isNew: isNew),
    );
    if (result == null) return;
    setState(() {
      if (result == 'delete') {
        _profiles.removeWhere((x) => x.id == target.id);
      } else if (isNew) {
        _profiles.add(target);
      }
    });
    await ProfileStore.save(_profiles);
  }

  String _statusLine(SeniorProfile p) {
    if (!p.connected) return '기기 연결 전';
    final l = _live;
    if (l == null) return '불러오는 중…';
    if (l.danger != null) return '${l.danger} 감지';
    final parts = <String>[
      if (l.medTotal > 0) '복약 ${l.medDone}/${l.medTotal}',
      if (l.lastTalk != null) _ago(l.lastTalk!),
    ];
    return parts.isEmpty ? '안전해요' : parts.join('\n');
  }

  // '2026-10-09 15:41' → '오늘 오후 3:41 대화' / '어제 대화' / '3일 전 대화'
  String _ago(String s) {
    final t = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (t == null) return '';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
    if (days == 0) {
      final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
      return '${t.hour < 12 ? '오전' : '오후'} $h:${t.minute.toString().padLeft(2, '0')} 대화';
    }
    return days == 1 ? '어제 대화' : '$days일 전 대화';
  }

  @override
  Widget build(BuildContext context) {
    final guardian = AppState.nickname ?? AppState.username ?? '보호자';
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _brand,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              Row(children: [
                const Text('OASIS',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3, color: _text1)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _editing = !_editing),
                  child: Text(_editing ? '완료' : '편집',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _brand)),
                ),
              ]),
              const SizedBox(height: 28),
              Text('$guardian님,', style: const TextStyle(fontSize: 16, color: _text3, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(_editing ? '어르신 정보를 고쳐 주세요' : '누구를 살펴볼까요?',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: _text1)),
              const SizedBox(height: 28),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.74,
                children: [
                  ..._profiles.map((p) => _ProfileTile(
                        profile: p,
                        editing: _editing,
                        status: _statusLine(p),
                        danger: p.connected && _live?.danger != null,
                        onTap: () => _open(p),
                      )),
                  _AddTile(onTap: () => _edit(null)),
                ],
              ),
              const SizedBox(height: 22),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _Legend(color: _brand, text: '안전'),
                SizedBox(width: 16),
                _Legend(color: _danger, text: '확인 필요'),
                SizedBox(width: 16),
                _Legend(color: _text4, text: '기기 연결 전'),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final SeniorProfile profile;
  final bool editing, danger;
  final String status;
  final VoidCallback onTap;
  const _ProfileTile({required this.profile, required this.editing, required this.status,
      required this.danger, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dot = !profile.connected ? _text4 : (danger ? _danger : _brand);
    return Material(
      color: danger ? _dangerSoft : _surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
          child: Column(
            children: [
              Stack(clipBehavior: Clip.none, children: [
                Opacity(opacity: profile.connected ? 1 : 0.55, child: _Avatar(profile: profile, size: 84, dot: dot)),
                if (editing)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(26)),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 30),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              Text('${profile.name} 어르신',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _text1)),
              const SizedBox(height: 4),
              Text(profile.relation, style: const TextStyle(fontSize: 13, color: _text3, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(status,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: danger ? _danger : (profile.connected ? _text2 : _text4))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final SeniorProfile profile;
  final double size;
  final Color? dot;
  const _Avatar({required this.profile, required this.size, required this.dot});

  @override
  Widget build(BuildContext context) {
    final c = _avatarColors[profile.color % _avatarColors.length];
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(size * 0.31)),
        child: Text(profile.name.isEmpty ? '?' : profile.name.characters.first,
            style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      if (dot != null)
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(
                color: dot, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
          ),
        ),
    ]);
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _text4, width: 1.5),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_rounded, size: 40, color: _text3),
            SizedBox(height: 8),
            Text('어르신 추가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text2)),
          ]),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: _text3, fontWeight: FontWeight.w600)),
      ]);
}

// 어르신 추가·수정 (이름, 관계, 연락처)
class _EditSheet extends StatefulWidget {
  final SeniorProfile profile;
  final bool isNew;
  const _EditSheet({required this.profile, required this.isNew});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late String _relation = widget.profile.relation;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해 주세요');
      return;
    }
    widget.profile
      ..name = name
      ..relation = _relation
      ..phone = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    Navigator.pop(context, 'save');
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _text4),
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isNew ? '어르신 추가' : '어르신 정보',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _text1)),
            const SizedBox(height: 20),
            const Text('이름', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text2)),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              maxLength: 8,
              onChanged: (_) => setState(() => _error = null),
              decoration: _deco('예) 영자').copyWith(counterText: '', errorText: _error),
            ),
            const SizedBox(height: 18),
            const Text('관계', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: relations.map((r) {
                final on = r == _relation;
                return ChoiceChip(
                  label: Text(r),
                  selected: on,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _relation = r),
                  labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: on ? _brand : _text2),
                  backgroundColor: _bg,
                  selectedColor: _brandSoft,
                  side: BorderSide(color: on ? _brand : Colors.transparent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            const Text('어르신 연락처 (긴급할 때 바로 전화)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text2)),
            const SizedBox(height: 8),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: _deco('010-0000-0000')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('저장', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
            if (!widget.isNew && !widget.profile.connected)
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  child: const Text('목록에서 빼기', style: TextStyle(color: _danger, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
