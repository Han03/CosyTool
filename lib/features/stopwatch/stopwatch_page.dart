import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 秒表工具：计时 + 分段记录。
class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  static final ToolInfo _tool = ToolRegistry.of('stopwatch');

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  final List<Duration> _laps = [];
  Duration _elapsed = Duration.zero;

  bool get _running => _stopwatch.isRunning;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      setState(() => _elapsed = _stopwatch.elapsed);
    });
    setState(() {});
  }

  void _pause() {
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
    setState(() => _elapsed = _stopwatch.elapsed);
  }

  void _reset() {
    _stopwatch
      ..stop()
      ..reset();
    _timer?.cancel();
    _timer = null;
    setState(() {
      _elapsed = Duration.zero;
      _laps.clear();
    });
  }

  void _lap() {
    if (!_running) return;
    setState(() => _laps.insert(0, _stopwatch.elapsed));
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000) ~/ 10;
    return '$h:$m:$s.$ms';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                  const Spacer(),
                  // 主计时
                  Text(
                    _fmt(_elapsed),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _running ? '计时中…' : (_laps.isEmpty ? '点击开始' : '已暂停'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // 控制按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundButton(
                        icon: Icons.refresh_rounded,
                        label: '重置',
                        onPressed: _laps.isEmpty && _elapsed == Duration.zero ? null : _reset,
                      ),
                      const SizedBox(width: 20),
                      _BigRoundButton(
                        icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: _running ? colorScheme.tertiary : colorScheme.primary,
                        onPressed: _running ? _pause : _start,
                      ),
                      const SizedBox(width: 20),
                      _RoundButton(
                        icon: Icons.flag_rounded,
                        label: '分段',
                        onPressed: _running ? _lap : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // 分段列表
                  Expanded(
                    child: _laps.isEmpty
                        ? Center(
                            child: Text(
                              '暂无分段记录',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _laps.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                            itemBuilder: (context, index) {
                              final lap = _laps[index];
                              return ListTile(
                                dense: true,
                                leading: Text(
                                  '分段 ${_laps.length - index}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Text(
                                  _fmt(lap),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 26,
          padding: const EdgeInsets.all(14),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _BigRoundButton extends StatelessWidget {
  const _BigRoundButton({required this.icon, required this.color, required this.onPressed});

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 76,
          height: 76,
          child: Icon(icon, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}
