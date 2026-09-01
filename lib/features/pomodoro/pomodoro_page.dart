import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 番茄钟工具：工作 / 短休 / 长休循环。
class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  static final ToolInfo _tool = ToolRegistry.of('pomodoro');

  static const int _workMin = 25;
  static const int _shortBreakMin = 5;
  static const int _longBreakMin = 15;
  static const int _roundsPerLongBreak = 4;

  int _round = 0; // 已完成番茄数
  bool _isBreak = false;
  Duration _remaining = const Duration(minutes: _workMin);
  Timer? _timer;
  bool _running = false;

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

  void _nextPhase() {
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
    if (_isBreak) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('第 $_round 个番茄完成，休息 ${_round % _roundsPerLongBreak == 0 ? _longBreakMin : _shortBreakMin} 分钟')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('休息结束，开始新的专注')),
      );
    }
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
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _round = 0;
      _isBreak = false;
      _remaining = const Duration(minutes: _workMin);
      _running = false;
    });
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
                                ? const Color(0xFFE85D5D)
                                : colorScheme.outlineVariant,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '本轮已完 ${_round % _roundsPerLongBreak} 个番茄 · 累计 $_round 个',
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
                  const SizedBox(height: 16),
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
