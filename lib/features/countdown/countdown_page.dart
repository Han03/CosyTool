import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 倒计时工具：预设 + 自定义时长，圆环进度展示。
class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  static final ToolInfo _tool = ToolRegistry.of('countdown');

  static const List<int> _presets = [60, 180, 300, 600, 900, 1800, 3600];

  Duration _total = const Duration(minutes: 5);
  Duration _remaining = const Duration(minutes: 5);
  Timer? _timer;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_remaining <= const Duration(milliseconds: 200)) {
        _finish();
        return;
      }
      setState(() => _remaining -= const Duration(milliseconds: 200));
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    setState(() => _running = false);
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _remaining = Duration.zero;
      _running = false;
    });
    _showFinishedDialog();
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _remaining = _total;
      _running = false;
    });
  }

  void _setTotal(Duration d) {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _total = d;
      _remaining = d;
      _running = false;
    });
  }

  Future<void> _pickCustom() async {
    final controller = TextEditingController();
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义分钟数'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分钟（1 - 480）'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (minutes != null && minutes > 0 && minutes <= 480) {
      _setTotal(Duration(minutes: minutes));
    } else if (minutes != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入 1 - 480 之间的整数分钟')));
    }
  }

  void _showFinishedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.notifications_active_rounded, size: 40, color: Color(0xFFE85D5D)),
        title: const Text('时间到！'),
        content: const Text('倒计时已结束。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : (_total.inMilliseconds - _remaining.inMilliseconds) / _total.inMilliseconds;

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
                  // 圆环进度
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
                            value: _running || _remaining != _total ? progress : 0,
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
                            Text(
                              _running ? '进行中' : '未开始',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 预设时长
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final p in _presets)
                        ChoiceChip(
                          label: Text(_label(p)),
                          selected: _total.inSeconds == p,
                          onSelected: (_) => _setTotal(Duration(seconds: p)),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('自定义'),
                        onPressed: _pickCustom,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 控制按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _remaining == _total ? null : _reset,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重置'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: _running ? _pause : _start,
                        icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(_running ? '暂停' : '开始'),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label(int seconds) {
    if (seconds % 3600 == 0) return '${seconds ~/ 3600} 小时';
    if (seconds % 60 == 0) return '${seconds ~/ 60} 分钟';
    return '$seconds 秒';
  }
}
