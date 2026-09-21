import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_recorder/flutter_recorder.dart';

// ignore_for_file: experimental_member_use

import '../../core/session/session_registry.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import 'ear_monitor_session.dart';

/// 耳返工具：基于 miniaudio 原生双工回环（<15ms）的实时监听（引擎常驻，切页不断）。
///
/// 设计文档：docs/ear_monitor_design.md
/// - 原生回环：麦克风 PCM 在 native C++ 内直接送耳机，音频不经过 Dart 层
/// - AEC：SpeexDSP 声学回声消除，以回环信号为远端参考，防止啸叫
/// - 实时指标：getVolumeDb / getWave（需 f32le 格式）
/// - 延迟测试：声学脉冲法实测系统往返延迟
class EarMonitorPage extends StatefulWidget {
  const EarMonitorPage({super.key});

  @override
  State<EarMonitorPage> createState() => _EarMonitorPageState();
}

class _EarMonitorPageState extends State<EarMonitorPage> {
  static final ToolInfo _tool = ToolRegistry.of('ear_monitor');

  late final EarMonitorSession _session;

  @override
  void initState() {
    super.initState();
    _session = SessionRegistry.instance.sessionOf('ear_monitor', EarMonitorSession.new);
    _session.addListener(_onChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final msg = _session.lastMessage;
    if (msg != null) {
      _session.lastMessage = null;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 3),
          ),
        );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = _session;
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return ToolPageScaffold(
      tool: _tool,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMonitorCard(theme, colorScheme, session),
                  const SizedBox(height: 20),
                  _buildLevelCard(theme, session),
                  const SizedBox(height: 20),
                  _buildControlCard(theme, session, isAndroid),
                  const SizedBox(height: 20),
                  _buildLatencyCard(theme, colorScheme, session),
                  const SizedBox(height: 20),
                  _buildTipsCard(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonitorCard(
    ThemeData theme,
    ColorScheme colorScheme,
    EarMonitorSession session,
  ) {
    final accent = session.on ? BrandColors.primary : colorScheme.surfaceContainerHighest;
    final fg = session.on ? Colors.white : colorScheme.onSurfaceVariant;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Material(
              color: accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: session.initializing ? null : session.toggle,
                child: SizedBox(
                  width: 132,
                  height: 132,
                  child: Center(
                    child: session.initializing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            session.on ? Icons.headphones_rounded : Icons.mic_rounded,
                            size: 52,
                            color: fg,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              session.initializing
                  ? '正在初始化…'
                  : session.on
                      ? '耳返监听中'
                      : '点击开启耳返',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: session.on ? BrandColors.primary : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session.on ? '原生双工回环 · 端到端约 20-60ms' : '麦克风声音直达耳机，音频不经过 Dart 层',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(ThemeData theme, EarMonitorSession session) {
    final level = ((session.db + 60) / 60).clamp(0.0, 1.0);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('实时电平', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  session.on ? '${session.db.toStringAsFixed(1)} dB' : '-- dB',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: session.on ? BrandColors.primary : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: level,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: session.db < -40
                    ? theme.extension<AppSemanticColors>()!.info
                    : session.db < -20
                        ? theme.extension<AppSemanticColors>()!.success
                        : theme.extension<AppSemanticColors>()!.danger,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: CustomPaint(
                size: Size.infinite,
                painter: _WavePainter(
                  wave: session.wave,
                  color: session.on ? BrandColors.primary : theme.colorScheme.outlineVariant,
                  lineColor: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard(
    ThemeData theme,
    EarMonitorSession session,
    bool isAndroid,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('音频设置', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AEC 防啸叫'),
              subtitle: const Text('声学回声消除，外放时防止尖锐啸叫'),
              value: session.aec,
              onChanged: session.toggleAec,
            ),
            const SizedBox(height: 8),
            Text('采样率', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 44100, label: Text('44.1 kHz')),
                ButtonSegment(value: 48000, label: Text('48 kHz')),
              ],
              selected: {session.sampleRate},
              onSelectionChanged: (s) {
                setState(() => session.sampleRate = s.first);
                session.changeConfig();
              },
            ),
            if (isAndroid) ...[
              const SizedBox(height: 16),
              Text('输入预置（硬件 DSP）', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              SegmentedButton<AndroidInputPreset>(
                segments: const [
                  ButtonSegment(
                    value: AndroidInputPreset.voiceCommunication,
                    label: Text('语音通信'),
                  ),
                  ButtonSegment(
                    value: AndroidInputPreset.unprocessed,
                    label: Text('原始'),
                  ),
                  ButtonSegment(
                    value: AndroidInputPreset.voiceRecognition,
                    label: Text('语音识别'),
                  ),
                ],
                selected: {session.preset},
                onSelectionChanged: (s) {
                  setState(() => session.preset = s.first);
                  session.changeConfig();
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 8),
              Text(
                session.preset == AndroidInputPreset.voiceCommunication
                    ? '语音通信：启用硬件 AEC/AGC/降噪；原生双工回环仅此预置可用（OpenSL 双工路径，端到端约 20-60ms）'
                    : '注意：非「语音通信」预置下原生双工回环不可用（AAudio 双工受限），'
                        '仅实时电平/波形可用，建议仅用于采集分析',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: session.preset == AndroidInputPreset.voiceCommunication
                      ? theme.colorScheme.outline
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLatencyCard(
    ThemeData theme,
    ColorScheme colorScheme,
    EarMonitorSession session,
  ) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('延迟测试', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (session.lastLatencyMs != null)
                  Text(
                    '${session.lastLatencyMs} ms',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: session.lastLatencyMs! < 80
                          ? theme.extension<AppSemanticColors>()!.success
                          : theme.extension<AppSemanticColors>()!.danger,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '外放 1kHz 脉冲 → 麦克风检测到达时刻，实测系统往返延迟。\n原生回环约 20-60ms（受 1024 帧采集周期约束），不受该媒体通路延迟影响。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: session.on && !session.testing ? session.runLatencyTest : null,
              icon: session.testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.speed_rounded),
              label: Text(session.testing ? '测试中…' : '开始延迟测试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('使用提示', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            _tip(theme, Icons.headphones_rounded, '监听请使用有线耳机，体验最佳'),
            _tip(theme, Icons.bluetooth_rounded, '蓝牙耳机延迟 100-300ms，会听到回声，不建议监听'),
            _tip(theme, Icons.volume_up_rounded, '外放时请保持开启 AEC，避免啸叫'),
          ],
        ),
      ),
    );
  }

  Widget _tip(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// 波形绘制：256 点 f32 数据 [-1,1] 映射为折线。
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.wave,
    required this.color,
    required this.lineColor,
  });

  final Float32List wave;
  final Color color;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(8),
      ),
      border,
    );
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final n = wave.length;
    if (n == 0) return;
    final midY = size.height / 2;
    for (var i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      final y = midY - wave[i].clamp(-1.0, 1.0) * (size.height / 2 - 4);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.wave != wave || oldDelegate.color != color;
}
