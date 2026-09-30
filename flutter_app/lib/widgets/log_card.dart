import 'package:flutter/material.dart';
import '../models/log_item.dart';

class LogCard extends StatelessWidget {
  final LogItem log;
  const LogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    // 상태가 '완료'인지 확인
    final bool isCompleted = log.status == "완료";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(log.time, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text("일정", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ),
              const Spacer(),
              Text(
                log.status,
                style: TextStyle(
                  fontSize: 11, 
                  color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // [핵심 수정] 헷갈리는 체크 아이콘 대신 상태에 따른 변화
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white) // 완료 시 체크
                    : Center(child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle))), // 미완료 시 점(•)
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  log.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                    decoration: isCompleted ? TextDecoration.lineThrough : null, // 완료 시 취소선
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}