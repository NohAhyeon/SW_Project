import '../utils/json_helper.dart';

class AlertItem {
  final int id;
  final String content;
  final String time;
  final String status;

  const AlertItem({
    required this.id,
    required this.content,
    required this.time,
    required this.status,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: JsonHelper.intVal(json, 'id'),
      content: JsonHelper.str(json, 'content', fallback: ''),
      time: JsonHelper.str(json, 'time', fallback: ''),
      status: JsonHelper.str(json, 'status', fallback: '처리 중'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'time': time,
        'status': status,
      };
}