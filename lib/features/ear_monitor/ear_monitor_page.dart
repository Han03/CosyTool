import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';

// ignore_for_file: experimental_member_use

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 耳返工具：基于 miniaudio 原生双工回环（<15ms）的实时监听。
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
  final Recorder _recorder = Recorder.instance;

  bool _on = false;
  bool _initializing = false;
  bool _aec = true;
  int _sampleRate = 48000;
  AndroidInputPreset _preset = AndroidInputPreset.voiceCommunication;

  double _db = -100;
  Float32List _wave = Float32List(256);

  Timer? _meterTimer;
  StreamSubscription<RecorderDeviceNotification>? _deviceSub;
  StreamSubscription<AudioVisualizationData>? _vizSub;
  StreamSubscription<AudioDataContainer>? _streamSub;

  // 延迟测试
  bool _testing = false;
  int? _lastLatencyMs;
  AudioPlayer? _pulsePlayer;
  Stopwatch? _latencySw;
  bool _pulseDetected = false;

  @override
  void dispose() {
    _meterTimer?.cancel();
    _deviceSub?.cancel();
    _vizSub?.cancel();
    _streamSub?.cancel();
    _pulsePlayer?.dispose();
    _teardown();
    super.dispose();
  }

  void _teardown() {
    try {
      if (_recorder.isDeviceInitialized()) {
        if (_recorder.isDeviceStarted()) _recorder.stop();
        _recorder.deinit();
      }
    } catch (_) {
      // 忽略释放期异常
    }
  }

  Future<bool> _ensurePermission() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能使用耳返')),
          );
        }
        return false;
      }
    }
    return true;
  }

  /// 初始化 → 启动 → 开启回环 → 配置 AEC / 可视化。
  Future<void> _applyConfig() async {
    if (!await _ensurePermission()) return;
    setState(() => _initializing = true);
    try {
      if (_recorder.isDeviceInitialized()) _recorder.deinit();
      await _recorder.init(
        format: PCMFormat.f32le,
        sampleRate: _sampleRate,
        channels: RecorderChannels.mono,
        androidInputPreset: _preset,
        iosInputPreset: IosInputPreset.voiceCommunication,
      );
      _recorder.setVisualizationEnabled(
        true,
        windowSize: 256,
        kind: VisualizationKind.waveAndFft,
        channel: VisualizationChannel.merged,
      );
      _recorder.start();
      _vizSub?.cancel();
      _vizSub = _recorder.audioVisualizationEvents.listen((data) {
        if (!mounted || !_on) return;
        final w = data.waveData;
        if (w != null) setState(() => _wave = w);
      });
      // 原生双工回环：麦克风 → 耳机，全程 native，<15ms
      _recorder.setLoopback(enable: true);
      if (_aec) {
        _recorder.filters.echoCancellationFilter.activate();
        _recorder.filters.echoCancellationFilter.filterLengthMs.value = 120;
        _recorder.filters.echoCancellationFilter.denoiseEnabled.value = 1;
        _recorder.filters.echoCancellationFilter.denoiseLevelDb.value = -30;
      }
      _startMeterTimer();
      if (mounted) setState(() => _on = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _stopMonitor() {
    _meterTimer?.cancel();
    _meterTimer = null;
    _vizSub?.cancel();
    _vizSub = null;
    _teardown();
    setState(() {
      _on = false;
      _db = -100;
      _wave = Float32List(256);
    });
  }

  Future<void> _toggle() async {
    if (_on) {
      _stopMonitor();
      return;
    }
    await _applyConfig();
  }

  void _startMeterTimer() {
    _meterTimer?.cancel();
    _meterTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!_on || !mounted) return;
      setState(() => _db = _recorder.getVolumeDb());
    });
  }

  Future<void> _toggleAec(bool enable) async {
    setState(() => _aec = enable);
    if (!_on) return;
    try {
      final aec = _recorder.filters.echoCancellationFilter;
      if (enable) {
        aec.activate();
        aec.filterLengthMs.value = 120;
        aec.denoiseEnabled.value = 1;
        aec.denoiseLevelDb.value = -30;
      } else {
        aec.deactivate();
      }
    } catch (_) {}
  }

  /// 切换采样率 / 输入预置：若正在监听则热重载配置。
  Future<void> _changeConfig() async {
    if (!_on) return;
    await _applyConfig();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已应用新配置'), duration: Duration(seconds: 1)),
      );
    }
  }

  // ---------- 延迟测试：声学脉冲法 ----------

  Uint8List _buildPulseWav({required int sampleRate}) {
    const durationMs = 150;
    const freq = 1000.0;
    final sampleCount = sampleRate * durationMs ~/ 1000;
    final data = Int16List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      final env = math.sin(math.pi * i / sampleCount); // 淡入淡出包络
      data[i] =
          (math.sin(2 * math.pi * freq * i / sampleRate) * 0.95 * env * 32767)
              .round();
    }
    final bytes = ByteData(44 + sampleCount * 2);
    void writeStr(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    bytes.setUint32(4, 36 + sampleCount * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little); // block align
    bytes.setUint16(34, 16, Endian.little); // bits per sample
    writeStr(36, 'data');
    bytes.setUint32(40, sampleCount * 2, Endian.little);
    for (var i = 0; i < sampleCount; i++) {
      bytes.setInt16(44 + i * 2, data[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  /// 查询系统蓝牙音频是否处于连接状态（脉冲会走蓝牙导致测试无效）
Future<bool> _isBluetoothAudioOn() async {
  try {
    final channel = MethodChannel('com.cosytool.cosy_tool/audio');
    final v = await channel.invokeMethod<bool>('isBluetoothAudioOn');
    return v ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> _runLatencyTest() async {
    if (!_on || _testing) return;

    // 蓝牙音频连接时，外放脉冲会走蓝牙而非手机扬声器，测试无意义
    if (_preset != AndroidInputPreset.voiceCommunication) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '延迟测试需要「语音通信」输入预置（该预置走 OpenSL 原生双工路径，'
              '麦克风能量才可用）。请切换到「语音通信」后重试。',
            ),
          ),
        );
      }
      return;
    }

    if (await _isBluetoothAudioOn()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '检测到蓝牙音频连接：脉冲会走蓝牙而非手机扬声器，'
              '测试结果无效。请断开蓝牙后重试。',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _testing = true;
      _lastLatencyMs = null;
      _pulseDetected = false;
    });

    // 1. 播放 1kHz 脉冲（audioplayers 低延迟模式，不阻塞等待播放完成）
    final player = AudioPlayer(playerId: 'ear_monitor_pulse');
    _pulsePlayer = player;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setPlayerMode(PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('pulse player config failed: $e');
    }
    final wavBytes = _buildPulseWav(sampleRate: _sampleRate);
    final wavFile = File(
      '${Directory.systemTemp.path}/ear_pulse_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    try {
      await wavFile.writeAsBytes(wavBytes, flush: true);
    } catch (e) {
      debugPrint('pulse wav write failed: $e');
    }
    _latencySw = Stopwatch()..start();
    unawaited(
      player.play(DeviceFileSource(wavFile.path)).then(
        (_) async {
          debugPrint('pulse play completed');
          try {
            await wavFile.delete();
          } catch (_) {}
        },
        onError: (e) => debugPrint('pulse play error: $e'),
      ),
    );

    // 2. 轮询 getVolumeDb 检测脉冲（复用实时电平路径，规避原生流订阅竞态）
    var maxDb = -100.0;
    var aboveCount = 0;
    final deadline = DateTime.now().add(const Duration(milliseconds: 3000));
    while (!_pulseDetected && DateTime.now().isBefore(deadline)) {
      final db = _recorder.getVolumeDb();
      if (db > maxDb) maxDb = db;
      if (db > -38) {
        aboveCount++;
        if (aboveCount >= 2) {
          _pulseDetected = true;
          final ms = _latencySw!.elapsedMilliseconds;
          debugPrint('latency detected at ${ms}ms (db=$db)');
          if (mounted) setState(() => _lastLatencyMs = ms);
          break;
        }
      } else {
        aboveCount = 0;
      }
      await Future.delayed(const Duration(milliseconds: 15));
    }
    debugPrint('latency test end: detected=$_pulseDetected maxDb=$maxDb');

    // 3. 收尾
    try {
      await player.stop();
    } catch (_) {}
    _latencySw = null;
    if (mounted) {
      setState(() => _testing = false);
      if (!_pulseDetected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              maxDb < -60
                  ? '未检测到脉冲：请调大媒体音量（音量键），并让扬声器靠近麦克风后重试'
                  : '未捕获到明显脉冲：请保持「语音通信」预置并调大媒体音量后重试',
            ),
          ),
        );
      }
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                  _buildMonitorCard(theme, colorScheme),
                  const SizedBox(height: 20),
                  _buildLevelCard(theme),
                  const SizedBox(height: 20),
                  _buildControlCard(theme, isAndroid),
                  const SizedBox(height: 20),
                  _buildLatencyCard(theme, colorScheme),
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

  Widget _buildMonitorCard(ThemeData theme, ColorScheme colorScheme) {
    final accent = _on ? _tool.accent : colorScheme.surfaceContainerHighest;
    final fg = _on ? Colors.white : colorScheme.onSurfaceVariant;
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
                onTap: _initializing ? null : _toggle,
                child: SizedBox(
                  width: 132,
                  height: 132,
                  child: Center(
                    child: _initializing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            _on ? Icons.headphones_rounded : Icons.mic_rounded,
                            size: 52,
                            color: fg,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _initializing
                  ? '正在初始化…'
                  : _on
                      ? '耳返监听中'
                      : '点击开启耳返',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _on ? _tool.accent : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _on ? '原生双工回环 · 端到端约 20-60ms' : '麦克风声音直达耳机，音频不经过 Dart 层',
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

  Widget _buildLevelCard(ThemeData theme) {
    final level = ((_db + 60) / 60).clamp(0.0, 1.0);
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
                  _on ? '${_db.toStringAsFixed(1)} dB' : '-- dB',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: _on ? _tool.accent : null,
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
                color: _db < -40
                    ? const Color(0xFF3AA6C9)
                    : _db < -20
                        ? const Color(0xFF2F9E6E)
                        : const Color(0xFFE85D5D),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: CustomPaint(
                size: Size.infinite,
                painter: _WavePainter(
                  wave: _wave,
                  color: _tool.accent,
                  lineColor: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard(ThemeData theme, bool isAndroid) {
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
              value: _aec,
              onChanged: _toggleAec,
            ),
            const SizedBox(height: 8),
            Text('采样率', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 44100, label: Text('44.1 kHz')),
                ButtonSegment(value: 48000, label: Text('48 kHz')),
              ],
              selected: {_sampleRate},
              onSelectionChanged: (s) {
                setState(() => _sampleRate = s.first);
                _changeConfig();
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
                selected: {_preset},
                onSelectionChanged: (s) {
                  setState(() => _preset = s.first);
                  _changeConfig();
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 8),
              Text(
                _preset == AndroidInputPreset.voiceCommunication
                    ? '语音通信：启用硬件 AEC/AGC/降噪；原生双工回环仅此预置可用（OpenSL 双工路径，端到端约 20-60ms）'
                    : '注意：非「语音通信」预置下原生双工回环不可用（AAudio 双工受限），'
                        '仅实时电平/波形可用，建议仅用于采集分析',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _preset == AndroidInputPreset.voiceCommunication
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

  Widget _buildLatencyCard(ThemeData theme, ColorScheme colorScheme) {
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
                if (_lastLatencyMs != null)
                  Text(
                    '$_lastLatencyMs ms',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _lastLatencyMs! < 80
                          ? const Color(0xFF2F9E6E)
                          : const Color(0xFFE85D5D),
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
              onPressed: _on && !_testing ? _runLatencyTest : null,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.speed_rounded),
              label: Text(_testing ? '测试中…' : '开始延迟测试'),
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
