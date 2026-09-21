import 'package:flutter/material.dart';

import '../../core/session/session_registry.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import 'pomodoro_session.dart';

/// 番茄钟工具：工作 / 短休 / 长休循环（引擎常驻，切页不断）。
class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  static final ToolInfo _tool = ToolRegistry.of('pomodoro');

  late final PomodoroSession _session;

  @override
  void initState() {
    super.initState();
    _session = SessionRegistry.instance.sessionOf('pomodoro', PomodoroSession.new);
    _session.addListener(_onChanged);
    _session.onPhaseChanged = () {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              !_session.isBreak
                  ? '休息结束，开始新的专注'
                  : '第 ${_session.round} 个番茄完成，休息 ${_session.round % PomodoroSession.roundsPerLongBreak == 0 ? _session.longBreakMin : _session.shortBreakMin} 分钟',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    };
    _session.load();
  }

  @override
  void dispose() {
    _session.removeListener(_onChanged);
    _session.onPhaseChanged = null;
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _editSettings() async {
    final wCtrl = TextEditingController(text: '${_session.workMin}');
    final sCtrl = TextEditingController(text: '${_session.shortBreakMin}');
    final lCtrl = TextEditingController(text: '${_session.longBreakMin}');
    final ok = await showAppDialog<bool>(
      context: context,
      icon: Icons.timer_rounded,
      title: '番茄钟设置',
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
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
      ],
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
    _session.applySettings(work: w, shortBreak: s, longBreak: l);
    _session.persistDurations();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = _session;
    final totalSeconds = session.totalSeconds;
    final progress = totalSeconds == 0
        ? 0.0
        : (totalSeconds - session.remaining.inSeconds) / totalSeconds;

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
                      for (var i = 0; i < PomodoroSession.roundsPerLongBreak; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            i < session.round % PomodoroSession.roundsPerLongBreak
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: i < session.round % PomodoroSession.roundsPerLongBreak
                                ? BrandColors.primary
                                : colorScheme.outlineVariant,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '本轮已完 ${session.round % PomodoroSession.roundsPerLongBreak} 个 · 今日共 ${session.todayCount} 个',
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
                            value: session.isRunning || session.remaining != Duration(seconds: totalSeconds)
                                ? progress
                                : 0,
                            strokeWidth: 12,
                            strokeCap: StrokeCap.round,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 大数字平滑翻转
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
                                PomodoroSession.fmt(session.remaining),
                                key: ValueKey(PomodoroSession.fmt(session.remaining)),
                                style: theme.textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w300,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(session.phaseLabel),
                              labelStyle: theme.textTheme.labelMedium?.copyWith(
                                color: session.isBreak ? colorScheme.tertiary : colorScheme.primary,
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
                        onPressed: session.reset,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重置'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: session.isRunning ? null : session.skip,
                        icon: const Icon(Icons.skip_next_rounded),
                        label: Text(session.isBreak ? '跳过休息' : '跳过专注'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: session.isRunning ? session.pause : session.start,
                        icon: Icon(session.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(session.isRunning ? '暂停' : '开始'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Switch(
                        value: session.autoNext,
                        onChanged: (v) => setState(() => session.autoNext = v),
                      ),
                      const SizedBox(width: 4),
                      Text('自动下一阶段', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 16),
                      Switch(
                        value: session.alertEnabled,
                        onChanged: (v) => setState(() => session.alertEnabled = v),
                      ),
                      const SizedBox(width: 4),
                      Text('结束时提醒', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '专注 ${session.workMin} 分 · 短休 ${session.shortBreakMin} 分 · 每 ${PomodoroSession.roundsPerLongBreak} 个番茄长休 ${session.longBreakMin} 分',
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
