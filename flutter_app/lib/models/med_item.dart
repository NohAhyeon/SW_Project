import '../utils/json_helper.dart';

class MedItem {
  final int id;
  final String name;
  final String time;
  final bool taken;

  const MedItem({
    required this.id,
    required this.name,
    required this.time,
    required this.taken,
  });

  factory MedItem.fromJson(Map<String, dynamic> json) {
    return MedItem(
      id: JsonHelper.intVal(json, 'id'),
      name: JsonHelper.str(json, 'name', fallback: '복약 정보 없음'),
      time: JsonHelper.str(json, 'time', fallback: ''),
      taken: JsonHelper.boolVal(json, 'taken'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'time': time,
        'taken': taken,
      };
}