import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/session/tool_session.dart';

// ignore_for_file: experimental_member_use

/// 耳返会话：原生双工回环引擎常驻，切页不断。
///
/// 设计文档：docs/ear_monitor_design.md
/// - 原生回环：麦克风 PCM 在 native C++ 内直接送耳机，音频不经过 Dart 层
/// - AEC：SpeexDSP 声学回声消除，以回环信号为远端参考，防止啸叫
/// - 实时指标：getVolumeDb / getWave（需 f32le 格式）
/// - 延迟测试：声学脉冲法实测系统往返延迟
class EarMonitorSession extends ToolSession {
  EarMonitorSession() : super('ear_monitor');

  final Recorder _recorder = Recorder.instance;

  bool on = false;
  bool initializing = false;
  bool aec = true;
  int sampleRate = 48000;
  AndroidInputPreset preset = AndroidInputPreset.voiceCommunication;

  double db = -100;
  Float32List wave = Float32List(256);

  Timer? _meterTimer;
  StreamSubscription<RecorderDeviceNotification>? _deviceSub;
  StreamSubscription<AudioVisualizationData>? _vizSub;

  // 延迟测试
  bool testing = false;
  int? lastLatencyMs;
  AudioPlayer? _pulsePlayer;
  Stopwatch? _latencySw;
  bool _pulseDetected = false;

  /// 最近一次需要页面提示的信息（错误 / 测试结果）。
  String? lastMessage;

  @override
  bool get isRunning => on;

  @override
  String get statusLabel => '耳返';

  @override
  String get statusText => on ? '监听中' : '';

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
        lastMessage = '需要麦克风权限才能使用耳返';
        return false;
      }
    }
    return true;
  }

  /// 初始化 → 启动 → 开启回环 → 配置 AEC / 可视化。
  Future<void> applyConfig() async {
    if (!await _ensurePermission()) {
      notifyListeners();
      return;
    }
    initializing = true;
    notifyListeners();
    try {
      if (_recorder.isDeviceInitialized()) _recorder.deinit();
      await _recorder.init(
        format: PCMFormat.f32le,
        sampleRate: sampleRate,
        channels: RecorderChannels.mono,
        androidInputPreset: preset,
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
        if (!on) return;
        final w = data.waveData;
        if (w != null) {
          wave = w;
          notifyListeners();
        }
      });
      // 原生双工回环：麦克风 → 耳机，全程 native，<15ms
      _recorder.setLoopback(enable: true);
      if (aec) {
        _recorder.filters.echoCancellationFilter.activate();
        _recorder.filters.echoCancellationFilter.filterLengthMs.value = 120;
        _recorder.filters.echoCancellationFilter.denoiseEnabled.value = 1;
        _recorder.filters.echoCancellationFilter.denoiseLevelDb.value = -30;
      }
      _startMeterTimer();
      on = true;
      notifyRunning();
      notifyListeners();
    } catch (e) {
      lastMessage = '初始化失败：$e';
      notifyListeners();
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  void stopMonitor() {
    _meterTimer?.cancel();
    _meterTimer = null;
    _vizSub?.cancel();
    _vizSub = null;
    _teardown();
    on = false;
    db = -100;
    wave = Float32List(256);
    notifyRunning();
    notifyListeners();
  }

  Future<void> toggle() async {
    if (on) {
      stopMonitor();
      return;
    }
    await applyConfig();
  }

  void _startMeterTimer() {
    _meterTimer?.cancel();
    _meterTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!on) return;
      db = _recorder.getVolumeDb();
      notifyListeners();
    });
  }

  Future<void> toggleAec(bool enable) async {
    aec = enable;
    notifyListeners();
    if (!on) return;
    try {
      final aecFilter = _recorder.filters.echoCancellationFilter;
      if (enable) {
        aecFilter.activate();
        aecFilter.filterLengthMs.value = 120;
        aecFilter.denoiseEnabled.value = 1;
        aecFilter.denoiseLevelDb.value = -30;
      } else {
        aecFilter.deactivate();
      }
    } catch (_) {}
  }

  /// 切换采样率 / 输入预置：若正在监听则热重载配置。
  Future<void> changeConfig() async {
    if (!on) return;
    await applyConfig();
    lastMessage = '已应用新配置';
    notifyListeners();
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

  /// 查询系统蓝牙音频是否处于连接状态（脉冲会走蓝牙导致测试无效）。
  Future<bool> _isBluetoothAudioOn() async {
    try {
      final channel = MethodChannel('com.cosytool.cosy_tool/audio');
      final v = await channel.invokeMethod<bool>('isBluetoothAudioOn');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> runLatencyTest() async {
    if (!on || testing) return;

    // 蓝牙音频连接时，外放脉冲会走蓝牙而非手机扬声器，测试无意义
    if (preset != AndroidInputPreset.voiceCommunication) {
      lastMessage = '延迟测试需要「语音通信」输入预置（该预置走 OpenSL 原生双工路径，'
          '麦克风能量才可用）。请切换到「语音通信」后重试。';
      notifyListeners();
      return;
    }

    if (await _isBluetoothAudioOn()) {
      lastMessage = '检测到蓝牙音频连接：脉冲会走蓝牙而非手机扬声器，'
          '测试结果无效。请断开蓝牙后重试。';
      notifyListeners();
      return;
    }

    testing = true;
    lastLatencyMs = null;
    _pulseDetected = false;
    notifyListeners();

    // 1. 播放 1kHz 脉冲（audioplayers 低延迟模式，不阻塞等待播放完成）
    final player = AudioPlayer(playerId: 'ear_monitor_pulse');
    _pulsePlayer = player;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setPlayerMode(PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('pulse player config failed: $e');
    }
    final wavBytes = _buildPulseWav(sampleRate: sampleRate);
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
          lastLatencyMs = ms;
          notifyListeners();
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
    testing = false;
    if (!_pulseDetected) {
      lastMessage = maxDb < -60
          ? '未检测到脉冲：请调大媒体音量（音量键），并让扬声器靠近麦克风后重试'
          : '未捕获到明显脉冲：请保持「语音通信」预置并调大媒体音量后重试';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _meterTimer?.cancel();
    _deviceSub?.cancel();
    _vizSub?.cancel();
    _pulsePlayer?.dispose();
    _teardown();
    super.dispose();
  }
}
