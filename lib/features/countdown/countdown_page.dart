import 'package:flutter/material.dart';

import '../../core/session/session_registry.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import 'countdown_session.dart';

/// 倒计时工具：预设 + 自定义时长，圆环进度展示（引擎常驻，切页不断）。
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

  late final CountdownSession _session;

  /// 结束弹窗只弹一次；切回页面时若已结束则补弹。
  bool _finishedHandled = false;

  @override
  void initState() {
    super.initState();
    _session = SessionRegistry.instance.sessionOf('countdown', CountdownSession.new);
    _session.addListener(_onChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    if (_session.finished && !_finishedHandled) {
      _finishedHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _session.finished) _showFinishedDialog();
      });
    }
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
    _finishedHandled = false;
    _session.setTotal(Duration(seconds: seconds));
  }

  void _showFinishedDialog() {
    showAppDialog<void>(
      context: context,
      icon: Icons.notifications_active_rounded,
      iconColor: Theme.of(context).extension<AppSemanticColors>()!.danger,
      title: '时间到！',
      content: const Text('倒计时已结束。'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('好的'),
        ),
      ],
    );
  }

  void _toggleAlert() {
    setState(() => _session.alertEnabled = !_session.alertEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = _session.total;
    final remaining = _session.remaining;
    final running = _session.isRunning;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (total.inMilliseconds - remaining.inMilliseconds) / total.inMilliseconds;

    return ToolPageScaffold(
      tool: _tool,
      actions: [
        IconButton(
          tooltip: _session.alertEnabled ? '结束时提醒（开）' : '结束时提醒（关）',
          icon: Icon(
            _session.alertEnabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
          ),
          onPressed: _toggleAlert,
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
                            value: running || remaining != total ? progress : 0,
                            strokeWidth: 12,
                            strokeCap: StrokeCap.round,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 大数字平滑翻转（每秒变化一次，150ms 淡入+微滑）
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.18),
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: child,
                                ),
                              ),
                              child: Text(
                                CountdownSession.fmt(remaining),
                                key: ValueKey(CountdownSession.fmt(remaining)),
                                style: theme.textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w300,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              running
                                  ? '进行中'
                                  : (remaining == Duration.zero ? '已结束' : '未开始'),
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
                          selected: total.inSeconds == p,
                          onSelected: (_) {
                            _finishedHandled = false;
                            _session.setTotal(Duration(seconds: p));
                          },
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
                        onPressed: remaining == total
                            ? null
                            : () {
                                _finishedHandled = false;
                                _session.reset();
                              },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重置'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: running
                            ? _session.pause
                            : () {
                                _finishedHandled = false;
                                _session.start();
                              },
                        icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(running ? '暂停' : '开始'),
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
