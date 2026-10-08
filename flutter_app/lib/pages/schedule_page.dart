import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../data/api_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<Map> _scheds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScheds();
  }

  Future<void> _loadScheds() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getSchedules();
    setState(() {
      _scheds = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';

    final today = _scheds.where((s) {
      final t = s["time"].toString();
      return t.startsWith(todayStr) || (!t.contains('-') && !t.contains('202'));
    }).toList();

    final upcoming = _scheds.where((s) {
      final t = s["time"].toString();
      return t.contains('-') && !t.startsWith(todayStr);
    }).toList();

    final done = _scheds.where((s) => s["status"] == "완료").length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${now.year}년 ${now.month}월 ${now.day}일',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text('오늘 일정 ${today.length}개',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatBadge(label: '예정', count: today.where((s) => s["status"] == "" || s["status"] == "예정").length, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 8),
                    _StatBadge(label: '완료', count: done, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 8),
                    _StatBadge(label: '취소', count: today.where((s) => s["status"] == "취소").length, color: Colors.white.withOpacity(0.2)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF6366F1))))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (today.isNotEmpty) ...[
                    const Text('📅 오늘 일정', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    ...today.map((s) => _SchedCard(
                      sched: s,
                      onStatusChange: (status) async {
                        final i = _scheds.indexOf(s);
                        if (status == "완료" && s["id"] != null) {
                          await ApiService.completeSchedule(s["id"]);
                        } else if (status == "" && s["id"] != null) {
                          await ApiService.uncompleteSchedule(s["id"]);
                        }
                        setState(() => _scheds[i]["status"] = status);
                      },
                      onDelete: () async {
                        if (s["id"] != null) {
                          await ApiService.deleteSchedule(s["id"]);
                          _loadScheds();
                        }
                      },
                    )),
                    const SizedBox(height: 20),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    const Text('🗓 예정 일정', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    ...upcoming.map((s) => _SchedCard(
                      sched: s,
                      onStatusChange: (status) async {
                        final i = _scheds.indexOf(s);
                        if (status == "완료" && s["id"] != null) {
                          await ApiService.completeSchedule(s["id"]);
                        } else if (status == "" && s["id"] != null) {
                          await ApiService.uncompleteSchedule(s["id"]);
                        }
                        setState(() => _scheds[i]["status"] = status);
                      },
                      onDelete: () async {
                        if (s["id"] != null) {
                          await ApiService.deleteSchedule(s["id"]);
                          _loadScheds();
                        }
                      },
                    )),
                    const SizedBox(height: 20),
                  ],
                  const Text('➕ 일정 추가', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),
                  _AddSchedCard(onAdd: (title, time) async {
                    await ApiService.addSchedule(title, time);
                    _loadScheds();
                  }),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_rounded, color: Color(0xFF0EA5E9), size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text('일정 시간이 되면 챗봇이 음성으로 알려드립니다.', style: TextStyle(fontSize: 13, color: Color(0xFF0369A1)))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SchedCard extends StatelessWidget {
  final Map sched;
  final Function(String) onStatusChange;
  final VoidCallback onDelete;

  const _SchedCard({required this.sched, required this.onStatusChange, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status = sched["status"] as String;
    final isDone = status == "완료";
    final isCancelled = status == "취소";

    Color borderColor = const Color(0xFFE2E8F0);
    Color iconBg = const Color(0xFFEFF6FF);
    Color iconColor = const Color(0xFF6366F1);

    if (isDone) {
      borderColor = const Color(0xFFBBF7D0);
      iconBg = const Color(0xFFF0FDF4);
      iconColor = const Color(0xFF10B981);
    } else if (isCancelled) {
      borderColor = const Color(0xFFE2E8F0);
      iconBg = const Color(0xFFF8FAFC);
      iconColor = const Color(0xFF94A3B8);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
            child: Icon(
              isDone ? Icons.check_rounded : isCancelled ? Icons.close_rounded : Icons.calendar_today_rounded,
              color: iconColor, size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sched["title"] as String,
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: isCancelled ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    )),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(sched["time"] as String, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                ]),
              ],
            ),
          ),
          if (!isCancelled)
            GestureDetector(
              onTap: () => onStatusChange(isDone ? "" : "완료"),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFFF0FDF4) : const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isDone ? '완료 ✓' : '완료',
                  style: TextStyle(color: isDone ? const Color(0xFF10B981) : Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (!isDone) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onStatusChange(isCancelled ? "" : "취소"),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isCancelled ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCancelled ? '취소 ✓' : '취소',
                  style: TextStyle(color: isCancelled ? const Color(0xFF6366F1) : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('일정 삭제', style: TextStyle(fontWeight: FontWeight.w700)),
                  content: Text('${sched["title"]}을(를) 삭제할까요?'),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSchedCard extends StatefulWidget {
  final Function(String title, String time) onAdd;
  const _AddSchedCard({required this.onAdd});

  @override
  State<_AddSchedCard> createState() => _AddSchedCardState();
}

class _AddSchedCardState extends State<_AddSchedCard> {
  final _titleController = TextEditingController();
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
        height: 320,
        color: Colors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8))),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('날짜 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                CupertinoButton(
                  child: const Text('확인', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                  onPressed: () {
                    setState(() => _selectedDate = tempDate);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate ?? DateTime.now(),
                minimumDate: DateTime.now().subtract(const Duration(days: 1)),
                maximumDate: DateTime(2030),
                onDateTimeChanged: (dt) => tempDate = dt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTimePicker() async {
    DateTime tempTime = _selectedTime;
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 320,
        color: Colors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8))),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('시간 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                CupertinoButton(
                  child: const Text('확인', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                  onPressed: () {
                    setState(() {
                      _selectedTime = tempTime;
                      _timeSelected = true;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: _selectedTime,
                onDateTimeChanged: (dt) => tempTime = dt,
              ),
            ),
          ],
        ),
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
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.add_rounded, color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('새 일정 추가', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: const Color(0xFF94A3B8)),
                ],
              ),
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
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: '일정명',
                      prefixIcon: const Icon(Icons.event_rounded, color: Color(0xFF6366F1)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _showDatePicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6366F1)),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedDate == null
                                      ? '날짜 선택'
                                      : '${_selectedDate!.year}년 ${_selectedDate!.month}월 ${_selectedDate!.day}일',
                                  style: TextStyle(fontSize: 13, color: _selectedDate == null ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)),
                                ),
                              ],
                            ),
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
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF6366F1)),
                                const SizedBox(width: 8),
                                Text(
                                  _timeSelected
                                      ? '${_selectedTime.hour.toString().padLeft(2, '0')}시 ${_selectedTime.minute.toString().padLeft(2, '0')}분'
                                      : '시간 선택',
                                  style: TextStyle(fontSize: 13, color: _timeSelected ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_titleController.text.isNotEmpty && _timeSelected) {
                          widget.onAdd(_titleController.text, _formatDateTime());
                          _titleController.clear();
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

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text('$label $count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}