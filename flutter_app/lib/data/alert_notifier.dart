import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// 보호자 폰 알림: 낙상·가스·긴급 알림이 새로 생기면 2초 안에 폰 알림(배너+소리)을 띄운다.
///
/// 지금은 앱이 켜져 있거나 잠깐 백그라운드에 있을 때 동작하는 '로컬 알림'이다.
/// 앱을 완전히 끈 상태에서도 받으려면 서버에서 보내는 푸시(Firebase Cloud Messaging + Apple 푸시 인증서)가 필요하다.
class AlertNotifier {
  AlertNotifier._();
  static final AlertNotifier instance = AlertNotifier._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final Set<String> _seen = {};   // 알림 번호 + 생성 시각 (DB가 지운 번호를 다시 쓰는 경우 대비)
  Timer? _timer;
  bool _ready = false;
  bool _first = true;

  static const _titles = {
    '낙상': '🚨 낙상 감지',
    '가스': '🔥 가스 누출 감지',
    '긴급': '🆘 어르신 긴급 호출',
  };

  Future<void> start({String seniorName = '순자'}) async {
    if (_timer != null) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
      debugPrint('[폰 알림] 준비 완료');
    } catch (e) {
      debugPrint('알림 초기화 실패: $e');
    }
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _check(seniorName));
    _check(seniorName);
  }

  Future<void> _check(String seniorName) async {
    final alerts = await ApiService.getAlerts();
    for (final a in alerts) {
      final id = a['id'];
      final type = a['type']?.toString() ?? '';
      if (id is! int || !_titles.containsKey(type) || a['status'] != '처리 중') continue;
      if (!_seen.add('$id|${a['time']}') || _first) continue;     // 앱을 켰을 때 이미 있던 알림은 다시 울리지 않음
      if (!_ready) continue;
      debugPrint('[폰 알림] $type #$id 보냄');
      await _plugin.show(
        id: id,
        title: _titles[type],
        body: type == '낙상'
            ? '$seniorName 어르신 댁에서 낙상이 감지됐어요. 지금 확인해 주세요.'
            : type == '가스'
                ? '$seniorName 어르신 댁에서 가스가 감지됐어요. 바로 확인해 주세요.'
                : '$seniorName 어르신이 도움을 요청하셨어요.',
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive),
          android: AndroidNotificationDetails('oasis_danger', '위험 알림',
              importance: Importance.max, priority: Priority.high),
        ),
      );
    }
    _first = false;
  }
}
