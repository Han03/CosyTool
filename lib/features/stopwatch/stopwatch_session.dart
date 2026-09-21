import 'dart:async';

import '../../core/session/tool_session.dart';

/// 秒表会话：引擎常驻，切页不断。
class StopwatchSession extends ToolSession {
  StopwatchSession() : super('stopwatch');

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  /// 分段记录（最新在前）。
  final List<Duration> laps = [];

  /// 当前计时（UI 数据源）。
  Duration elapsed = Duration.zero;

  @override
  bool get isRunning => _stopwatch.isRunning;

  @override
  String get statusLabel => '秒表';

  @override
  String get statusText => fmt(elapsed);

  void start() {
    if (isRunning) return;
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      elapsed = _stopwatch.elapsed;
      notifyListeners();
    });
    notifyRunning();
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
    elapsed = _stopwatch.elapsed;
    notifyRunning();
    notifyListeners();
  }

  void reset() {
    _stopwatch
      ..stop()
      ..reset();
    _timer?.cancel();
    _timer = null;
    elapsed = Duration.zero;
    laps.clear();
    notifyRunning();
    notifyListeners();
  }

  void lap() {
    if (!isRunning) return;
    laps.insert(0, _stopwatch.elapsed);
    notifyListeners();
  }

  @override
  void stop() => pause();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String fmt(Duration d) {
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final ms = (d.inMilliseconds % 1000) ~/ 10;
    final hms =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.$ms';
    if (days > 0) return '$days 天 $hms';
    return hms;
  }
}
