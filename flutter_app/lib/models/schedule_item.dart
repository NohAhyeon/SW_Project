import '../utils/json_helper.dart';

class ScheduleItem {
  final int id;
  final String title;
  final String time;
  final String status;

  const ScheduleItem({
    required this.id,
    required this.title,
    required this.time,
    required this.status,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: JsonHelper.intVal(json, 'id'),
      title: JsonHelper.str(json, 'title', fallback: '제목 없음'),
      time: JsonHelper.str(json, 'time', fallback: ''),
      status: JsonHelper.str(json, 'status', fallback: '예정'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time': time,
        'status': status,
      };
}