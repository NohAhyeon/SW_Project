class LogItem {
  final String title;  // type 대신 title 사용 (서버 필드명과 일치)
  final String time;
  final String status; // '예정', '완료' 등의 상태

  const LogItem({
    required this.title,
    required this.time,
    this.status = '예정',
  });

  factory LogItem.fromJson(Map<String, dynamic> json) {
    return LogItem(
      // 서버에서 title이 없으면 type을 찾고, 그것도 없으면 '기타'라고 표시
      title: (json['title'] ?? json['type'] ?? '기타').toString(),
      time: json['time']?.toString() ?? '',
      status: json['status']?.toString() ?? '예정',
    );
  }
}