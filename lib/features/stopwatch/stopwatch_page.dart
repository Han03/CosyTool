import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session/session_registry.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import 'stopwatch_session.dart';

/// 秒表工具：计时 + 分段记录（引擎常驻，切页不断）。
class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  static final ToolInfo _tool = ToolRegistry.of('stopwatch');

  late final StopwatchSession _session;

  @override
  void initState() {
    super.initState();
    _session = SessionRegistry.instance.sessionOf('stopwatch', StopwatchSession.new);
    _session.addListener(_onChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _copyLaps() async {
    final laps = _session.laps;
    if (laps.isEmpty) return;
    final sb = StringBuffer(
      '秒表分段记录（共 ${laps.length} 段，总 ${StopwatchSession.fmt(_session.elapsed)}）\n',
    );
    for (var i = 0; i < laps.length; i++) {
      final lap = laps[i];
      final prev = i + 1 < laps.length ? laps[i + 1] : Duration.zero;
      final delta = lap - prev;
      sb.writeln('第 ${laps.length - i} 段  ${StopwatchSession.fmt(lap)}  (分段 ${StopwatchSession.fmt(delta)})');
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分段记录已复制到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final running = _session.isRunning;
    final laps = _session.laps;

    return ToolPageScaffold(
      tool: _tool,
      actions: [
        if (laps.isNotEmpty)
          IconButton(
            tooltip: '复制分段记录',
            icon: const Icon(Icons.copy_rounded),
            onPressed: _copyLaps,
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
                  const Spacer(),
                  // 主计时
                  Text(
                    StopwatchSession.fmt(_session.elapsed),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    running ? '计时中…' : (laps.isEmpty ? '点击开始' : '已暂停'),
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
                        onPressed:
                            laps.isEmpty && _session.elapsed == Duration.zero
                                ? null
                                : _session.reset,
                      ),
                      const SizedBox(width: 20),
                      _BigRoundButton(
                        icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: running ? colorScheme.tertiary : colorScheme.primary,
                        onPressed: running ? _session.pause : _session.start,
                      ),
                      const SizedBox(width: 20),
                      _RoundButton(
                        icon: Icons.flag_rounded,
                        label: '分段',
                        onPressed: running ? _session.lap : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // 分段列表
                  Expanded(
                    child: laps.isEmpty
                        ? Center(
                            child: Text(
                              '暂无分段记录',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: laps.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                            itemBuilder: (context, index) {
                              final lap = laps[index];
                              final prev = index + 1 < laps.length ? laps[index + 1] : Duration.zero;
                              final delta = lap - prev;
                              final best = _isBestLap(index);
                              return ListTile(
                                dense: true,
                                leading: Text(
                                  '分段 ${laps.length - index}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                title: Text(
                                  '本段 ${StopwatchSession.fmt(delta)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: best ? colorScheme.tertiary : colorScheme.outline,
                                    fontWeight: best ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                                trailing: Text(
                                  StopwatchSession.fmt(lap),
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

  bool _isBestLap(int index) {
    final laps = _session.laps;
    final delta = laps[index] - (index + 1 < laps.length ? laps[index + 1] : Duration.zero);
    for (var i = 0; i < laps.length; i++) {
      final d = laps[i] - (i + 1 < laps.length ? laps[i + 1] : Duration.zero);
      if (d < delta) return false;
    }
    return true;
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
