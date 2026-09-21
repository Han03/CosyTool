import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/permissions.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 分贝测试工具：实时测量环境音量并绘制趋势曲线。
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

  static const int _historySize = 180;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _sub;
  String? _tempPath;
  Timer? _ticker;

  bool _running = false;
  String? _error;

  double _calibration = 0; // 校准偏移（dB），持久化
  DateTime? _sessionStart;
  Duration _sessionElapsed = Duration.zero;

  double _current = 0;
  double _min = 0;
  double _max = 0;
  double _sum = 0;
  int _count = 0;
  final List<double> _history = [];

  @override
  void initState() {
    super.initState();
    _loadCalibration();
  }

  Future<void> _loadCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble('decibel_calibration') ?? 0;
    if (mounted) setState(() => _calibration = v);
  }

  Future<void> _saveCalibration(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('decibel_calibration', v);
  }

  @override
  void dispose() {
    _stop();
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_running) {
      await _stop();
      if (mounted) setState(() {});
      return;
    }
    final granted = await Permissions.requestMic();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未获得麦克风权限，无法测量')),
      );
      return;
    }
    try {
      // 先起一个极小的临时录制，为振幅流提供会话
      final tmp = await getTemporaryDirectory();
      _tempPath =
          '${tmp.path}${Platform.pathSeparator}cosytool_decibel_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
        ),
        path: _tempPath!,
      );
      _sub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen(_onAmplitude);
      _sessionStart = DateTime.now();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _sessionElapsed = DateTime.now().difference(_sessionStart!);
          });
        }
      });
      if (!mounted) return;
      setState(() {
        _running = true;
        _error = null;
        _min = 0;
        _max = 0;
        _sum = 0;
        _count = 0;
        _current = 0;
        _sessionElapsed = Duration.zero;
        _history.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '无法启动测量：$e');
    }
  }

  void _onAmplitude(Amplitude amp) {
    final db = _toReferenceDb(amp.current);
    if (!mounted) return;
    setState(() {
      _current = db;
      if (_count == 0) {
        _min = db;
        _max = db;
      } else {
        if (db < _min) _min = db;
        if (db > _max) _max = db;
      }
      _sum += db;
      _count++;
      _history.add(db);
      if (_history.length > _historySize) _history.removeAt(0);
    });
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    _ticker = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    final path = _tempPath;
    _tempPath = null;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    _running = false;
  }

  double _toReferenceDb(double dbfs) {
    if (!dbfs.isFinite) dbfs = -60;
    return (dbfs + 100 + _calibration).clamp(20.0, 120.0);
  }

  double get _avg => _count == 0 ? 0 : _sum / _count;

  (String, Color) _levelInfo(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.extension<AppSemanticColors>()!;
    final d = _current;
    if (d < 40) return ('非常安静', theme.colorScheme.outline);
    if (d < 50) return ('安静', s.success);
    if (d < 60) return ('正常交谈', s.success);
    if (d < 70) return ('环境较吵', s.warning);
    if (d < 80) return ('吵闹', s.warning);
    if (d < 90) return ('很吵', s.danger);
    return ('震耳欲聋', s.danger);
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _exportCsv() async {
    if (_history.isEmpty) return;
    final sb = StringBuffer('时间,分贝(dB)\n');
    for (var i = 0; i < _history.length; i++) {
      sb.writeln('${(i * 0.12).toStringAsFixed(2)},${_history[i].toStringAsFixed(1)}');
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(
        '${docs.path}${Platform.pathSeparator}decibel_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(sb.toString());
      // 同时复制概要到剪贴板
      final summary = '分贝测量概要\n时长: ${_fmtDur(_sessionElapsed)}\n'
          '最低: ${_min.round()} dB\n平均: ${_avg.round()} dB\n峰值: ${_max.round()} dB\n';
      await Clipboard.setData(ClipboardData(text: summary));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV 已保存到：${file.path}\n概要已复制到剪贴板')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (levelText, levelColor) = _levelInfo(context);

    return ToolPageScaffold(
      tool: _tool,
      actions: [
        if (_history.isNotEmpty)
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
                        _running ? _current.round().toString() : '--',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w200,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: _running ? levelColor : colorScheme.outline,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(' dB', style: theme.textTheme.titleMedium),
                      ),
                    ],
                  ),
                  Text(
                    _running ? levelText : '点击开始测量',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _running ? levelColor : colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_running)
                    Text(
                      '已测量 ${_fmtDur(_sessionElapsed)} · 采样 $_count 次',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 24),
                  // 实时柱
                  SizedBox(
                    height: 150,
                    child: CustomPaint(
                      size: const Size(double.infinity, 150),
                      painter: _BarPainter(
                        value: _running ? (_current - 20) / 100 : 0,
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
                        values: _history,
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
                      _StatCard(label: '最低', value: _count == 0 ? '--' : '${_min.round()} dB', color: colorScheme.tertiary),
                      const SizedBox(width: 12),
                      _StatCard(label: '平均', value: _count == 0 ? '--' : '${_avg.round()} dB', color: colorScheme.primary),
                      const SizedBox(width: 12),
                      _StatCard(label: '峰值', value: _count == 0 ? '--' : '${_max.round()} dB', color: colorScheme.error),
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
                          value: _calibration,
                          min: -20,
                          max: 20,
                          divisions: 40,
                          label: '${_calibration.round()} dB',
                          onChanged: (v) {
                            setState(() => _calibration = v.roundToDouble());
                          },
                          onChangeEnd: (v) => _saveCalibration(v.roundToDouble()),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${_calibration > 0 ? '+' : ''}${_calibration.round()} dB',
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
                    onPressed: _toggle,
                    icon: Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(_running ? '停止测量' : '开始测量'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 48),
                      backgroundColor: _running ? colorScheme.error : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '参考值未经设备校准，不同设备存在差异；可用校准偏移微调',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
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
