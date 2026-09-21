import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 番茄钟工具：工作 / 短休 / 长休循环。
///
/// 支持自定义各阶段时长（持久化）、自动进入下一阶段、结束时提醒，以及今日专注统计。
class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  static final ToolInfo _tool = ToolRegistry.of('pomodoro');

  static const int _roundsPerLongBreak = 4;

  int _workMin = 25;
  int _shortBreakMin = 5;
  int _longBreakMin = 15;
  bool _autoNext = true;
  bool _alertEnabled = true;

  int _round = 0; // 已完成番茄数（会话内）
  bool _isBreak = false;
  Duration _remaining = const Duration(minutes: 25);
  Timer? _timer;
  bool _running = false;

  int _todayCount = 0; // 今日完成番茄数（持久化）

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workMin = prefs.getInt('pomo_work_min') ?? 25;
      _shortBreakMin = prefs.getInt('pomo_short_min') ?? 5;
      _longBreakMin = prefs.getInt('pomo_long_min') ?? 15;
      _remaining = Duration(minutes: _workMin);
      // 今日统计
      final today = _todayKey();
      final savedDay = prefs.getString('pomo_today_date');
      if (savedDay == today) {
        _todayCount = prefs.getInt('pomo_today_count') ?? 0;
      } else {
        _todayCount = 0;
        prefs.setString('pomo_today_date', today);
        prefs.setInt('pomo_today_count', 0);
      }
    });
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> _persistDurations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomo_work_min', _workMin);
    await prefs.setInt('pomo_short_min', _shortBreakMin);
    await prefs.setInt('pomo_long_min', _longBreakMin);
  }

  Future<void> _recordCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDay = prefs.getString('pomo_today_date');
    var count = (savedDay == today ? prefs.getInt('pomo_today_count') ?? 0 : 0);
    count++;
    await prefs.setString('pomo_today_date', today);
    await prefs.setInt('pomo_today_count', count);
    if (mounted) setState(() => _todayCount = count);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _totalSeconds =>
      (_isBreak ? (_round % _roundsPerLongBreak == 0 && _round > 0 ? _longBreakMin : _shortBreakMin) : _workMin) *
      60;

  String get _phaseLabel {
    if (!_isBreak) return '专注中';
    return _round % _roundsPerLongBreak == 0 ? '长休息' : '短休息';
  }

  void _start() {
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= const Duration(seconds: 1)) {
        _nextPhase();
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    setState(() => _running = false);
  }

  void _alert() {
    if (!_alertEnabled) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  Future<void> _nextPhase() async {
    _timer?.cancel();
    _timer = null;
    setState(() {
      if (!_isBreak) {
        _round++;
        _isBreak = true;
      } else {
        _isBreak = false;
      }
      _remaining = Duration(seconds: _totalSeconds);
      _running = _autoNext;
    });
    if (!_isBreak) await _recordCompletion();
    if (mounted) _alert();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !_isBreak
              ? '休息结束，开始新的专注'
              : '第 $_round 个番茄完成，休息 ${_round % _roundsPerLongBreak == 0 ? _longBreakMin : _shortBreakMin} 分钟',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    if (_autoNext && _running) _start();
  }

  void _skip() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      if (!_isBreak) {
        _round++;
        _isBreak = true;
      } else {
        _isBreak = false;
      }
      _remaining = Duration(seconds: _totalSeconds);
      _running = false;
    });
    if (!_isBreak) _recordCompletion();
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _round = 0;
      _isBreak = false;
      _remaining = Duration(minutes: _workMin);
      _running = false;
    });
  }

  Future<void> _editSettings() async {
    final wCtrl = TextEditingController(text: '$_workMin');
    final sCtrl = TextEditingController(text: '$_shortBreakMin');
    final lCtrl = TextEditingController(text: '$_longBreakMin');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('番茄钟设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '专注时长（分钟）', prefixIcon: Icon(Icons.work_rounded)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '短休息（分钟）', prefixIcon: Icon(Icons.self_improvement_rounded)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '长休息（分钟）', prefixIcon: Icon(Icons.beach_access_rounded)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final w = int.tryParse(wCtrl.text.trim());
    final s = int.tryParse(sCtrl.text.trim());
    final l = int.tryParse(lCtrl.text.trim());
    if (w == null || s == null || l == null || w <= 0 || s <= 0 || l <= 0 || w > 180 || s > 60 || l > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入合法时长：专注 1-180，短休 1-60，长休 1-60 分钟')),
      );
      return;
    }
    setState(() {
      _workMin = w;
      _shortBreakMin = s;
      _longBreakMin = l;
      if (!_running && !_isBreak && _remaining == Duration(minutes: w)) {
        _remaining = Duration(minutes: w);
      }
    });
    _persistDurations();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = _totalSeconds == 0
        ? 0.0
        : (_totalSeconds - _remaining.inSeconds) / _totalSeconds;

    return ToolPageScaffold(
      tool: _tool,
      actions: [
        IconButton(
          tooltip: '设置',
          icon: const Icon(Icons.settings_rounded),
          onPressed: _editSettings,
        ),
      ],
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 番茄计数
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _roundsPerLongBreak; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            i < _round % _roundsPerLongBreak
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: i < _round % _roundsPerLongBreak
                                ? BrandColors.primary
                                : colorScheme.outlineVariant,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '本轮已完 ${_round % _roundsPerLongBreak} 个 · 今日共 $_todayCount 个',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  // 圆环
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: CircularProgressIndicator(
                            value: _running || _remaining != Duration(seconds: _totalSeconds) ? progress : 0,
                            strokeWidth: 12,
                            strokeCap: StrokeCap.round,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmt(_remaining),
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w300,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(_phaseLabel),
                              labelStyle: theme.textTheme.labelMedium?.copyWith(
                                color: _isBreak ? colorScheme.tertiary : colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide.none,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重置'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _running ? null : _skip,
                        icon: const Icon(Icons.skip_next_rounded),
                        label: Text(_isBreak ? '跳过休息' : '跳过专注'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _running ? _pause : _start,
                        icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(_running ? '暂停' : '开始'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Switch(
                        value: _autoNext,
                        onChanged: (v) => setState(() => _autoNext = v),
                      ),
                      const SizedBox(width: 4),
                      Text('自动下一阶段', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 16),
                      Switch(
                        value: _alertEnabled,
                        onChanged: (v) => setState(() => _alertEnabled = v),
                      ),
                      const SizedBox(width: 4),
                      Text('结束时提醒', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '专注 $_workMin 分 · 短休 $_shortBreakMin 分 · 每 $_roundsPerLongBreak 个番茄长休 $_longBreakMin 分',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
