import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api_service.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadLogs(showLoading: false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);
    try {
      final data = await ApiService.getChatLogs();
      final List<Map<String, dynamic>> parsedLogs =
          data.map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _logs = parsedLogs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // 날짜별로 그룹핑
  Map<String, List<Map<String, dynamic>>> _groupByDate(List<Map<String, dynamic>> logs) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final log in logs) {
      final time = (log["time"] ?? '').toString();
      String dateKey = '날짜 없음';
      if (time.length >= 10) {
        final date = DateTime.tryParse(time);
        if (date != null) {
          dateKey = '${date.year}년 ${date.month}월 ${date.day}일';
        } else {
          dateKey = time.substring(0, 10);
        }
      }
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _logs.where((l) {
      final userText = (l["user"] ?? '').toString();
      final botText = (l["bot"] ?? '').toString();
      return _keyword.isEmpty || userText.contains(_keyword) || botText.contains(_keyword);
    }).toList();

    final grouped = _groupByDate(filtered);
    final dateKeys = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: () => _loadLogs(showLoading: false),
      color: const Color(0xFF6366F1),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
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
                  const Text('대화 내용', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '총 ${_logs.length}개의 대화',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async => await _loadLogs(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                          ),
                          child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
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
                  // 검색창
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _keyword = v),
                    decoration: InputDecoration(
                      hintText: '대화 내용 검색...',
                      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                      suffixIcon: _keyword.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _keyword = '');
                              },
                              child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF6366F1))))
                  else if (filtered.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFCBD5E1), size: 48),
                            SizedBox(height: 12),
                            Text('대화 내용이 없어요', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...dateKeys.map((dateKey) {
                      final dayLogs = grouped[dateKey]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 날짜 헤더
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    dateKey,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${dayLogs.length}개', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          ...dayLogs.map((l) => _ChatBubbleCard(log: l)),
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubbleCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _ChatBubbleCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final type = (log["type"] ?? '').toString();
    final time = (log["time"] ?? '').toString();
    final user = (log["user"] ?? '').toString();
    final bot = (log["bot"] ?? '').toString();

    final colors = {
      "생활정보": const Color(0xFF3B82F6),
      "복약": const Color(0xFF10B981),
      "일정": const Color(0xFF8B5CF6),
      "긴급": const Color(0xFFEF4444),
    };
    final bgColors = {
      "생활정보": const Color(0xFFEFF6FF),
      "복약": const Color(0xFFF0FDF4),
      "일정": const Color(0xFFF5F3FF),
      "긴급": const Color(0xFFFEF2F2),
    };

    final c = colors[type] ?? const Color(0xFF94A3B8);
    final bg = bgColors[type] ?? const Color(0xFFF8FAFC);
    final isEmergency = type == "긴급";

    // 시간만 추출 (HH:mm)
    String timeStr = time;
    if (time.length >= 19) {
      final dt = DateTime.tryParse(time);
      if (dt != null) {
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isEmergency ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                ),
                const Spacer(),
                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(timeStr, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('👴', style: TextStyle(fontSize: 14))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.only(topRight: Radius.circular(12), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                    ),
                    child: Text(user, style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('🤖', style: TextStyle(fontSize: 14))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isEmergency ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                    ),
                    child: Text(bot, style: TextStyle(fontSize: 14, color: isEmergency ? const Color(0xFFDC2626) : const Color(0xFF1E293B))),
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