import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/session/tool_session.dart';

/// 倒计时会话：引擎常驻，切页不断；结束时震动 + 提示音（不依赖页面）。
class CountdownSession extends ToolSession {
  CountdownSession() : super('countdown');

  Duration total = const Duration(minutes: 5);
  Duration remaining = const Duration(minutes: 5);
  bool alertEnabled = true;
  bool finished = false;

  Timer? _timer;
  bool _running = false;

  @override
  bool get isRunning => _running;

  @override
  String get statusLabel => '倒计时';

  @override
  String get statusText => fmt(remaining);

  void start() {
    if (_running) return;
    if (remaining == Duration.zero) remaining = total;
    finished = false;
    _running = true;
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (remaining <= const Duration(milliseconds: 200)) {
        _finish();
        return;
      }
      remaining -= const Duration(milliseconds: 200);
      notifyListeners();
    });
    notifyRunning();
    notifyListeners();
  }

  void pause() {
    if (!_running) return;
    _timer?.cancel();
    _timer = null;
    _running = false;
    notifyRunning();
    notifyListeners();
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    remaining = Duration.zero;
    _running = false;
    finished = true;
    if (alertEnabled) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
    notifyRunning();
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    remaining = total;
    _running = false;
    finished = false;
    notifyRunning();
    notifyListeners();
  }

  void setTotal(Duration d) {
    _timer?.cancel();
    _timer = null;
    total = d;
    remaining = d;
    _running = false;
    finished = false;
    notifyRunning();
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
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
