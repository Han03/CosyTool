import 'package:flutter/material.dart';

import '../../core/session/session_registry.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import 'decibel_session.dart';

/// 分贝测试工具：实时测量环境音量并绘制趋势曲线（引擎常驻，切页不断）。
///
/// 通过 `record` 的振幅流（dBFS）读取音量，并映射为参考分贝值。
/// 注意：手机麦克风未做设备校准，数值为相对参考，不同设备存在差异；
/// 支持通过「校准偏移」手动微调，校准值会持久化保存。
class DecibelPage extends StatefulWidget {
  const DecibelPage({super.key});

  @override
  State<DecibelPage> createState() => _DecibelPageState();
}

class _DecibelPageState extends State<DecibelPage> {
  static final ToolInfo _tool = ToolRegistry.of('decibel');

  late final DecibelSession _session;

  @override
  void initState() {
    super.initState();
    _session = SessionRegistry.instance.sessionOf('decibel', DecibelSession.new);
    _session.addListener(_onChanged);
    _session.loadCalibration();
  }

  @override
  void dispose() {
    _session.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _exportCsv() async {
    final path = await _session.exportCsv();
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV 已保存到：$path\n概要已复制到剪贴板')),
      );
    } else if (_session.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_session.error!)),
      );
    }
  }

  (String, Color) _levelInfo(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.extension<AppSemanticColors>()!;
    final d = _session.current;
    if (d < 40) return ('非常安静', theme.colorScheme.outline);
    if (d < 50) return ('安静', s.success);
    if (d < 60) return ('正常交谈', s.success);
    if (d < 70) return ('环境较吵', s.warning);
    if (d < 80) return ('吵闹', s.warning);
    if (d < 90) return ('很吵', s.danger);
    return ('震耳欲聋', s.danger);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = _session;
    final (levelText, levelColor) = _levelInfo(context);

    return ToolPageScaffold(
      tool: _tool,
      actions: [
        if (session.history.isNotEmpty)
          IconButton(
            tooltip: '导出 CSV',
            icon: const Icon(Icons.download_rounded),
            onPressed: _exportCsv,
          ),
      ],
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  // 当前分贝值
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        session.running ? session.current.round().toString() : '--',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w200,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: session.running ? levelColor : colorScheme.outline,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(' dB', style: theme.textTheme.titleMedium),
                      ),
                    ],
                  ),
                  Text(
                    session.running ? levelText : '点击开始测量',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: session.running ? levelColor : colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (session.running)
                    Text(
                      '已测量 ${DecibelSession.fmtDuration(session.sessionElapsed)} · 采样 ${session.count} 次',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 24),
                  // 实时柱
                  SizedBox(
                    height: 150,
                    child: CustomPaint(
                      size: const Size(double.infinity, 150),
                      painter: _BarPainter(
                        value: session.running ? (session.current - 20) / 100 : 0,
                        color: levelColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 历史曲线
                  Container(
                    height: 120,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _HistoryPainter(
                        values: session.history,
                        min: 20,
                        max: 120,
                        lineColor: colorScheme.primary,
                        fillColor: colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 统计
                  Row(
                    children: [
                      _StatCard(label: '最低', value: session.count == 0 ? '--' : '${session.min.round()} dB', color: colorScheme.tertiary),
                      const SizedBox(width: 12),
                      _StatCard(label: '平均', value: session.count == 0 ? '--' : '${session.avg.round()} dB', color: colorScheme.primary),
                      const SizedBox(width: 12),
                      _StatCard(label: '峰值', value: session.count == 0 ? '--' : '${session.max.round()} dB', color: colorScheme.error),
                    ],
                  ),
                  const Spacer(),
                  // 校准偏移
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('校准偏移', style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          value: session.calibration,
                          min: -20,
                          max: 20,
                          divisions: 40,
                          label: '${session.calibration.round()} dB',
                          onChanged: (v) => setState(() => session.calibration = v.roundToDouble()),
                          onChangeEnd: (v) => session.saveCalibration(v.roundToDouble()),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${session.calibration > 0 ? '+' : ''}${session.calibration.round()} dB',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: session.toggle,
                    icon: Icon(session.running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(session.running ? '停止测量' : '开始测量'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 48),
                      backgroundColor: session.running ? colorScheme.error : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '参考值未经设备校准，不同设备存在差异；可用校准偏移微调',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                  if (session.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        session.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error, fontSize: 13),
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 实时柱绘制。
class _BarPainter extends CustomPainter {
  _BarPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height * value.clamp(0.0, 1.0);
    if (h <= 0) return;
    final rect = Rect.fromLTWH(size.width / 2 - 18, size.height - h, 36, h);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [color.withValues(alpha: 0.3), color],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.value != value || old.color != color;
}

/// 历史曲线绘制。
class _HistoryPainter extends CustomPainter {
  _HistoryPainter({
    required this.values,
    required this.min,
    required this.max,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> values;
  final double min;
  final double max;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        Paint()
          ..color = lineColor.withValues(alpha: 0.2)
          ..strokeWidth = 1,
      );
      return;
    }
    final step = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y = size.height - ((values[i] - min) / (max - min)).clamp(0.0, 1.0) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter old) =>
      old.values != values || old.lineColor != lineColor;
}
