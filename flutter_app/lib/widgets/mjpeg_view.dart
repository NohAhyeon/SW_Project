import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// 홈캠 실시간 영상 (MJPEG).
/// 파이의 /video 에 연결 하나를 열어 두고, 들어오는 JPEG 를 한 장씩 꺼내 바로 보여 준다.
/// (사진을 한 장씩 요청하면 핫스팟에서 한 장에 0.3초씩 걸려 초당 3장 정도밖에 안 나왔다)
/// 3초 동안 새 화면이 없으면 연결을 다시 연다.
class MjpegView extends StatefulWidget {
  final String url;
  final ValueChanged<bool>? onStatus;     // 영상이 들어오면 true, 끊기면 false
  final BoxFit fit;
  const MjpegView({super.key, required this.url, this.onStatus, this.fit = BoxFit.cover});

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  Uint8List? _frame;
  HttpClient? _client;
  StreamSubscription<List<int>>? _sub;
  Timer? _watch;
  DateTime _last = DateTime.now();
  bool? _ok;
  final List<int> _buf = [];

  @override
  void initState() {
    super.initState();
    _connect();
    _watch = Timer.periodic(const Duration(seconds: 1), (_) {
      final idle = DateTime.now().difference(_last);
      if (idle > const Duration(seconds: 3)) {
        _status(false);
        _last = DateTime.now();
        _connect();                      // 새 화면이 3초 없으면 다시 연결
      }
    });
  }

  @override
  void didUpdateWidget(MjpegView old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _connect();
  }

  @override
  void dispose() {
    _watch?.cancel();
    _close();
    super.dispose();
  }

  void _status(bool ok) {
    if (_ok == ok) return;
    _ok = ok;
    widget.onStatus?.call(ok);
  }

  void _close() {
    _sub?.cancel();
    _sub = null;
    _client?.close(force: true);
    _client = null;
    _buf.clear();
  }

  Future<void> _connect() async {
    _close();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    _client = client;
    try {
      final res = await (await client.getUrl(Uri.parse(widget.url))).close();
      if (_client != client) return;
      _sub = res.listen(_onData, onError: (_) => _status(false), cancelOnError: true);
    } catch (_) {
      _status(false);
    }
  }

  static int _find(List<int> b, int x, int y, int from) {
    for (var i = from; i < b.length - 1; i++) {
      if (b[i] == x && b[i + 1] == y) return i;
    }
    return -1;
  }

  void _onData(List<int> chunk) {
    _buf.addAll(chunk);
    Uint8List? latest;
    while (true) {
      final s = _find(_buf, 0xFF, 0xD8, 0);
      if (s < 0) { _buf.clear(); break; }
      final e = _find(_buf, 0xFF, 0xD9, s + 2);
      if (e < 0) { if (s > 0) _buf.removeRange(0, s); break; }
      latest = Uint8List.fromList(_buf.sublist(s, e + 2));
      _buf.removeRange(0, e + 2);
    }
    if (_buf.length > 3000000) _buf.clear();   // 깨진 데이터가 쌓이지 않게
    if (latest != null && mounted) {
      _last = DateTime.now();
      _status(true);
      setState(() => _frame = latest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _frame;
    if (f == null) return const ColoredBox(color: Color(0xFF191F28));
    return Image.memory(f, gaplessPlayback: true, fit: widget.fit, width: double.infinity, height: double.infinity);
  }
}
