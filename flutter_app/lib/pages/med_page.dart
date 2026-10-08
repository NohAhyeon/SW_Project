import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../data/api_service.dart';

class MedPage extends StatefulWidget {
  const MedPage({super.key});

  @override
  State<MedPage> createState() => _MedPageState();
}

class _MedPageState extends State<MedPage> {
  List<Map> _meds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeds();
  }

  Future<void> _loadMeds() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getMedications();
      if (mounted) setState(() { _meds = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final takenList    = _meds.where((m) => m["taken"] == true || m["taken"] == 1).toList();
    final remainingList = _meds.where((m) => m["taken"] == false || m["taken"] == 0).toList();
    final taken  = takenList.length;
    final total  = _meds.length;
    final progress = total > 0 ? taken / total : 0.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 상단 달성률 카드 ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('오늘 복약 달성률',
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text('${(progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('$total개 중 $taken개 완료 · ${total - taken}개 남음',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 복약 전 ─────────────────────────────────────────────
                  if (remainingList.isNotEmpty) ...[
                    const Text('오늘 복용',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    ...remainingList.map((med) => _MedCard(
                      med: med,
                      isTaken: false,
                      onTake: () async {
                        if (med["id"] != null) {
                          await ApiService.takeMedication(med["id"]);
                          await _loadMeds();
                        }
                      },
                      onDelete: () async {
                        if (med["id"] != null) {
                          await ApiService.deleteMedication(med["id"]);
                          await _loadMeds();
                        }
                      },
                      onEdit: (name, time) async {
                        if (med["id"] != null) {
                          await ApiService.updateMedication(med["id"], name, time);
                          await _loadMeds();
                        }
                      },
                    )),
                    const SizedBox(height: 20),
                  ],

                  // ── 복약 완료 ────────────────────────────────────────────
                  if (takenList.isNotEmpty) ...[
                    const Text('복약 완료',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    ...takenList.map((med) => _MedCard(
                      med: med,
                      isTaken: true,
                      onTake: () async {
                        if (med["id"] != null) {
                          await ApiService.untakeMedication(med["id"]);
                          await _loadMeds();
                        }
                      },
                      onDelete: () async {
                        if (med["id"] != null) {
                          await ApiService.deleteMedication(med["id"]);
                          await _loadMeds();
                        }
                      },
                      onEdit: (name, time) async {
                        if (med["id"] != null) {
                          await ApiService.updateMedication(med["id"], name, time);
                          await _loadMeds();
                        }
                      },
                    )),
                    const SizedBox(height: 20),
                  ],

                  // ── 추가 카드 ────────────────────────────────────────────
                  _AddMedCard(onAdd: (name, time) async {
                    await ApiService.addMedication(name, time);
                    await _loadMeds();
                  }),
                  const SizedBox(height: 16),

                  // ── 안내 ─────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_rounded, color: Color(0xFF6366F1), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('복약 시간이 되면 챗봇이 음성으로 알려드립니다.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF3730A3))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── 복약 카드 ──────────────────────────────────────────────────────────────────
class _MedCard extends StatelessWidget {
  final Map med;
  final bool isTaken;
  final VoidCallback onTake;
  final VoidCallback onDelete;
  final Function(String name, String time) onEdit;

  const _MedCard({
    required this.med,
    required this.isTaken,
    required this.onTake,
    required this.onDelete,
    required this.onEdit,
  });

  String _formatTime(dynamic raw) {
    if (raw == null) return '시간 미설정';
    final s = raw.toString();
    try {
      final dt = DateTime.parse(s.replaceAll(' ', 'T'));
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h < 12 ? 'AM' : 'PM';
      final hour = h % 12 == 0 ? 12 : h % 12;
      return '$hour:$m $period';
    } catch (_) {
      return s;
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(med["name"] ?? '',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(_formatTime(med["time"]),
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 20),
            // 수정 버튼
            _OptionButton(
              icon: Icons.edit_rounded,
              label: '복약 수정',
              color: const Color(0xFF6366F1),
              onTap: () {
                Navigator.pop(context);
                _showEditSheet(context);
              },
            ),
            const SizedBox(height: 10),
            // 복용 토글
            _OptionButton(
              icon: isTaken ? Icons.undo_rounded : Icons.check_circle_rounded,
              label: isTaken ? '복용 취소' : '복용 완료로 변경',
              color: isTaken ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
              onTap: () { Navigator.pop(context); onTake(); },
            ),
            const SizedBox(height: 10),
            // 삭제 버튼
            _OptionButton(
              icon: Icons.delete_outline_rounded,
              label: '복약 삭제',
              color: const Color(0xFFEF4444),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('복약 삭제', style: TextStyle(fontWeight: FontWeight.w700)),
                    content: Text('${med["name"]}을(를) 삭제할까요?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8)))),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                          child: const Text('삭제', style: TextStyle(color: Color(0xFFEF4444)))),
                    ],
                  ),
                );
                if (confirm == true) onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditMedSheet(
        initialName: med["name"] ?? '',
        initialTime: med["time"]?.toString() ?? '',
        onSave: onEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = isTaken ? const Color(0xFF10B981) : const Color(0xFF6366F1);

    return GestureDetector(
      onTap: () => _showOptions(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isTaken ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            // 아이콘
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isTaken ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isTaken ? Icons.check_rounded : Icons.medication_rounded,
                color: color, size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // 약 이름 + 시간
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med["name"] ?? "약 이름 없음",
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: isTaken ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                      decoration: isTaken ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.access_time_rounded, size: 12,
                        color: isTaken ? const Color(0xFFBBF7D0) : const Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(_formatTime(med["time"]),
                        style: TextStyle(
                            fontSize: 12,
                            color: isTaken ? const Color(0xFFBBF7D0) : const Color(0xFF94A3B8))),
                  ]),
                ],
              ),
            ),
            // 상태 배지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isTaken ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isTaken ? '완료' : '미복용',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            const SizedBox(width: 8),
            // 더보기 버튼
            const Icon(Icons.more_vert_rounded, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── 옵션 버튼 ──────────────────────────────────────────────────────────────────
class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionButton({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── 수정 바텀시트 ──────────────────────────────────────────────────────────────
class _EditMedSheet extends StatefulWidget {
  final String initialName;
  final String initialTime;
  final Function(String name, String time) onSave;

  const _EditMedSheet({required this.initialName, required this.initialTime, required this.onSave});

  @override
  State<_EditMedSheet> createState() => _EditMedSheetState();
}

class _EditMedSheetState extends State<_EditMedSheet> {
  late TextEditingController _nameCtrl;
  DateTime? _selectedDate;
  late DateTime _selectedTime;
  bool _timeSelected = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    try {
      final dt = DateTime.parse(widget.initialTime.replaceAll(' ', 'T'));
      _selectedDate = dt;
      _selectedTime = dt;
      _timeSelected = true;
    } catch (_) {
      _selectedTime = DateTime.now();
    }
  }

  String _formatDateTime() {
    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    if (_selectedDate != null) {
      final y = _selectedDate!.year;
      final mo = _selectedDate!.month.toString().padLeft(2, '0');
      final d = _selectedDate!.day.toString().padLeft(2, '0');
      return '$y-$mo-$d $h:$m';
    }
    return '$h:$m';
  }

  Future<void> _showDatePicker() async {
    DateTime tempDate = _selectedDate ?? DateTime.now();
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 320, color: Colors.white,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            CupertinoButton(
                child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8))),
                onPressed: () => Navigator.pop(context)),
            const Text('날짜 선택',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            CupertinoButton(
                child: const Text('확인', style: TextStyle(color: Color(0xFF6366F1))),
                onPressed: () { setState(() => _selectedDate = tempDate); Navigator.pop(context); }),
          ]),
          Expanded(child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _selectedDate ?? DateTime.now(),
            onDateTimeChanged: (dt) => tempDate = dt,
          )),
        ]),
      ),
    );
  }

  Future<void> _showTimePicker() async {
    DateTime tempTime = _selectedTime;
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 320, color: Colors.white,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            CupertinoButton(
                child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8))),
                onPressed: () => Navigator.pop(context)),
            const Text('시간 선택',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            CupertinoButton(
                child: const Text('확인', style: TextStyle(color: Color(0xFF6366F1))),
                onPressed: () {
                  setState(() { _selectedTime = tempTime; _timeSelected = true; });
                  Navigator.pop(context);
                }),
          ]),
          Expanded(child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: _selectedTime,
            onDateTimeChanged: (dt) => tempTime = dt,
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('복약 수정',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: '약 이름',
                prefixIcon: const Icon(Icons.medication_rounded, color: Color(0xFF6366F1)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showDatePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDate == null
                            ? '날짜 선택'
                            : '${_selectedDate!.month}/${_selectedDate!.day}',
                        style: TextStyle(fontSize: 13,
                            color: _selectedDate == null
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF1E293B)),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _showTimePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Text(
                        _timeSelected
                            ? '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'
                            : '시간 선택',
                        style: TextStyle(fontSize: 13,
                            color: _timeSelected
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF94A3B8)),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameCtrl.text.isNotEmpty) {
                    widget.onSave(_nameCtrl.text, _formatDateTime());
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('저장하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 추가 카드 ──────────────────────────────────────────────────────────────────
class _AddMedCard extends StatefulWidget {
  final Function(String name, String time) onAdd;
  const _AddMedCard({required this.onAdd});

  @override
  State<_AddMedCard> createState() => _AddMedCardState();
}

class _AddMedCardState extends State<_AddMedCard> {
  final _nameController = TextEditingController();
  bool _expanded = false;
  DateTime? _selectedDate;
  DateTime _selectedTime = DateTime.now();
  bool _timeSelected = false;

  String _formatDateTime() {
    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    if (_selectedDate != null) {
      final y = _selectedDate!.year;
      final mo = _selectedDate!.month.toString().padLeft(2, '0');
      final d = _selectedDate!.day.toString().padLeft(2, '0');
      return '$y-$mo-$d $h:$m';
    }
    return '$h:$m';
  }

  Future<void> _showDatePicker() async {
    DateTime tempDate = _selectedDate ?? DateTime.now();
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 320, color: Colors.white,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            CupertinoButton(child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8))), onPressed: () => Navigator.pop(context)),
            const Text('날짜 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            CupertinoButton(
                child: const Text('확인', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                onPressed: () { setState(() => _selectedDate = tempDate); Navigator.pop(context); }),
          ]),
          Expanded(child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _selectedDate ?? DateTime.now(),
            minimumDate: DateTime.now().subtract(const Duration(days: 1)),
            maximumDate: DateTime(2030),
            onDateTimeChanged: (dt) => tempDate = dt,
          )),
        ]),
      ),
    );
  }

  Future<void> _showTimePicker() async {
    DateTime tempTime = _selectedTime;
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 320, color: Colors.white,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            CupertinoButton(child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8))), onPressed: () => Navigator.pop(context)),
            const Text('시간 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            CupertinoButton(
                child: const Text('확인', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                onPressed: () { setState(() { _selectedTime = tempTime; _timeSelected = true; }); Navigator.pop(context); }),
          ]),
          Expanded(child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: _selectedTime,
            onDateTimeChanged: (dt) => tempTime = dt,
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('새 복약 추가',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
                Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF94A3B8)),
              ]),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '약 이름',
                      prefixIcon: const Icon(Icons.medication_rounded, color: Color(0xFF6366F1)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showDatePicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6366F1)),
                            const SizedBox(width: 8),
                            Flexible(child: Text(
                              _selectedDate == null ? '날짜 선택'
                                  : '${_selectedDate!.month}/${_selectedDate!.day}',
                              style: TextStyle(fontSize: 13,
                                  color: _selectedDate == null ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)),
                            )),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showTimePicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF6366F1)),
                            const SizedBox(width: 8),
                            Text(
                              _timeSelected
                                  ? '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'
                                  : '시간 선택',
                              style: TextStyle(fontSize: 13,
                                  color: _timeSelected ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_nameController.text.isNotEmpty && _timeSelected) {
                          widget.onAdd(_nameController.text, _formatDateTime());
                          _nameController.clear();
                          setState(() {
                            _expanded = false;
                            _selectedDate = null;
                            _selectedTime = DateTime.now();
                            _timeSelected = false;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('추가하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
