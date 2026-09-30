import '../utils/json_helper.dart';

class DeviceStatus {
  final String mic;
  final String speaker;
  final String network;

  const DeviceStatus({
    required this.mic,
    required this.speaker,
    required this.network,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      mic: JsonHelper.str(json, 'mic', fallback: '정상'),
      speaker: JsonHelper.str(json, 'speaker', fallback: '정상'),
      network: JsonHelper.str(json, 'network', fallback: '정상'),
    );
  }

  Map<String, dynamic> toJson() => {
        'mic': mic,
        'speaker': speaker,
        'network': network,
      };
}