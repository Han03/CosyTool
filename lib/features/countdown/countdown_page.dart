import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 倒计时工具：预设 + 自定义时长，圆环进度展示，结束时震动 + 提示音。
class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  static final ToolInfo _tool = ToolRegistry.of('countdown');

  static const List<int> _presets = [
    10, 30, 45, 60, 120, 180, 300, 600, 900, 1500, 1800, 2700, 3600, 5400, 7200,
  ];

  Duration _total = const Duration(minutes: 5);
  Duration _remaining = const Duration(minutes: 5);
  Timer? _timer;
  bool _running = false;
  bool _alertEnabled = true;

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
    if (_alertEnabled) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
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
    final mCtrl = TextEditingController();
    final sCtrl = TextEditingController();
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义时长'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: mCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: '分钟'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(':'),
            ),
            Expanded(
              child: TextField(
                controller: sCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '秒'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final m = int.tryParse(mCtrl.text.trim()) ?? 0;
              final s = int.tryParse(sCtrl.text.trim()) ?? 0;
              Navigator.pop(ctx, (m, s));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    final seconds = result.$1 * 60 + result.$2;
    if (seconds <= 0 || seconds > 24 * 3600) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 1 秒 ~ 24 小时之间的时长')),
      );
      return;
    }
    _setTotal(Duration(seconds: seconds));
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
      actions: [
        IconButton(
          tooltip: _alertEnabled ? '结束时提醒（开）' : '结束时提醒（关）',
          icon: Icon(
            _alertEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
          ),
          onPressed: () => setState(() => _alertEnabled = !_alertEnabled),
        ),
      ],
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
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
                              _running ? '进行中' : (_remaining == Duration.zero ? '已结束' : '未开始'),
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
                  const SizedBox(height: 16),
                  Text(
                    '结束时会震动并播放提示音（可点右上角开关）',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label(int seconds) {
    if (seconds >= 3600 && seconds % 3600 == 0) return '${seconds ~/ 3600} 小时';
    if (seconds >= 60 && seconds % 60 == 0) return '${seconds ~/ 60} 分钟';
    return '$seconds 秒';
  }
}
