import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/session/tool_session.dart';

/// 番茄钟会话：工作 / 短休 / 长休循环，引擎常驻。
///
/// 阶段结束时的震动 / 提示音在 Session 内触发（不依赖页面）；
/// 页面通过 [onPhaseChanged] 感知阶段切换（页面销毁后置空）。
class PomodoroSession extends ToolSession {
  PomodoroSession() : super('pomodoro');

  static const int roundsPerLongBreak = 4;

  int workMin = 25;
  int shortBreakMin = 5;
  int longBreakMin = 15;
  bool autoNext = true;
  bool alertEnabled = true;

  int round = 0; // 已完成番茄数（会话内）
  bool isBreak = false;
  Duration remaining = const Duration(minutes: 25);
  int todayCount = 0; // 今日完成番茄数（持久化）

  Timer? _timer;
  bool _running = false;

  /// 阶段切换回调（页面注册，用于 SnackBar 提示）。
  void Function()? onPhaseChanged;

  @override
  bool get isRunning => _running;

  @override
  bool get canPause => true;

  @override
  void togglePause() {
    if (_running) {
      pause();
    } else {
      start();
    }
  }

  @override
  String get statusLabel => '番茄钟';

  @override
  String get statusText => fmt(remaining);

  int get totalSeconds =>
      (isBreak
              ? (round % roundsPerLongBreak == 0 && round > 0
                  ? longBreakMin
                  : shortBreakMin)
              : workMin) *
      60;

  String get phaseLabel {
    if (!isBreak) return '专注中';
    return round % roundsPerLongBreak == 0 ? '长休息' : '短休息';
  }

  /// 载入持久化设置与今日统计。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    workMin = prefs.getInt('pomo_work_min') ?? 25;
    shortBreakMin = prefs.getInt('pomo_short_min') ?? 5;
    longBreakMin = prefs.getInt('pomo_long_min') ?? 15;
    remaining = Duration(minutes: workMin);
    final today = _todayKey();
    final savedDay = prefs.getString('pomo_today_date');
    if (savedDay == today) {
      todayCount = prefs.getInt('pomo_today_count') ?? 0;
    } else {
      todayCount = 0;
      prefs.setString('pomo_today_date', today);
      prefs.setInt('pomo_today_count', 0);
    }
    notifyListeners();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> persistDurations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomo_work_min', workMin);
    await prefs.setInt('pomo_short_min', shortBreakMin);
    await prefs.setInt('pomo_long_min', longBreakMin);
  }

  Future<void> _recordCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDay = prefs.getString('pomo_today_date');
    var count = (savedDay == today ? prefs.getInt('pomo_today_count') ?? 0 : 0);
    count++;
    await prefs.setString('pomo_today_date', today);
    await prefs.setInt('pomo_today_count', count);
    todayCount = count;
    notifyListeners();
  }

  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining <= const Duration(seconds: 1)) {
        nextPhase();
        return;
      }
      remaining -= const Duration(seconds: 1);
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

  void _alert() {
    if (!alertEnabled) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  Future<void> nextPhase() async {
    _timer?.cancel();
    _timer = null;
    if (!isBreak) {
      round++;
      isBreak = true;
    } else {
      isBreak = false;
    }
    remaining = Duration(seconds: totalSeconds);
    _running = autoNext;
    if (!isBreak) await _recordCompletion();
    _alert();
    onPhaseChanged?.call();
    if (_running) start();
    notifyRunning();
    notifyListeners();
  }

  void skip() {
    _timer?.cancel();
    _timer = null;
    if (!isBreak) {
      round++;
      isBreak = true;
    } else {
      isBreak = false;
    }
    remaining = Duration(seconds: totalSeconds);
    _running = false;
    if (!isBreak) _recordCompletion();
    notifyRunning();
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    round = 0;
    isBreak = false;
    remaining = Duration(minutes: workMin);
    _running = false;
    notifyRunning();
    notifyListeners();
  }

  /// 应用设置（调用方已校验合法）。
  void applySettings({
    required int work,
    required int shortBreak,
    required int longBreak,
  }) {
    workMin = work;
    shortBreakMin = shortBreak;
    longBreakMin = longBreak;
    if (!_running && !isBreak && remaining == Duration(minutes: work)) {
      remaining = Duration(minutes: work);
    }
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
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
