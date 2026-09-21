import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/session/tool_session.dart';
import '../../core/utils/permissions.dart';

/// 分贝测试会话：实时测量引擎常驻，切页不断。
///
/// 振幅流高频刷新通过 [notifyListeners] 驱动页面；校准值持久化。
class DecibelSession extends ToolSession {
  DecibelSession() : super('decibel');

  static const int historySize = 180;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _sub;
  String? _tempPath;
  Timer? _ticker;

  bool running = false;
  String? error;

  double calibration = 0; // 校准偏移（dB），持久化
  DateTime? _sessionStart;
  Duration sessionElapsed = Duration.zero;

  double current = 0;
  double min = 0;
  double max = 0;
  double sum = 0;
  int count = 0;
  final List<double> history = [];

  @override
  bool get isRunning => running;

  @override
  String get statusLabel => '分贝';

  @override
  String get statusText => current.round().toString();

  Future<void> loadCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    calibration = prefs.getDouble('decibel_calibration') ?? 0;
    notifyListeners();
  }

  Future<void> saveCalibration(double v) async {
    calibration = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('decibel_calibration', v);
    notifyListeners();
  }

  /// 开始 / 停止测量。
  Future<void> toggle() async {
    if (running) {
      await stop();
      notifyListeners();
      return;
    }
    final granted = await Permissions.requestMic();
    if (!granted) {
      error = '未获得麦克风权限，无法测量';
      notifyListeners();
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
        sessionElapsed = DateTime.now().difference(_sessionStart!);
        notifyListeners();
      });
      running = true;
      error = null;
      min = 0;
      max = 0;
      sum = 0;
      count = 0;
      current = 0;
      sessionElapsed = Duration.zero;
      history.clear();
      notifyRunning();
      notifyListeners();
    } catch (e) {
      error = '无法启动测量：$e';
      notifyListeners();
    }
  }

  void _onAmplitude(Amplitude amp) {
    final db = toReferenceDb(amp.current);
    current = db;
    if (count == 0) {
      min = db;
      max = db;
    } else {
      if (db < min) min = db;
      if (db > max) max = db;
    }
    sum += db;
    count++;
    history.add(db);
    if (history.length > historySize) history.removeAt(0);
    notifyListeners();
  }

  @override
  Future<void> stop() async {
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
    running = false;
    notifyRunning();
    notifyListeners();
  }

  double toReferenceDb(double dbfs) {
    if (!dbfs.isFinite) dbfs = -60;
    return (dbfs + 100 + calibration).clamp(20.0, 120.0);
  }

  double get avg => count == 0 ? 0 : sum / count;

  /// 导出 CSV（返回文件路径）；失败时置 [error]。
  Future<String?> exportCsv() async {
    if (history.isEmpty) return null;
    final sb = StringBuffer('时间,分贝(dB)\n');
    for (var i = 0; i < history.length; i++) {
      sb.writeln('${(i * 0.12).toStringAsFixed(2)},${history[i].toStringAsFixed(1)}');
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(
        '${docs.path}${Platform.pathSeparator}decibel_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(sb.toString());
      // 同时复制概要到剪贴板
      final summary = '分贝测量概要\n时长: ${fmtDuration(sessionElapsed)}\n'
          '最低: ${min.round()} dB\n平均: ${avg.round()} dB\n峰值: ${max.round()} dB\n';
      await Clipboard.setData(ClipboardData(text: summary));
      return file.path;
    } catch (e) {
      error = '导出失败：$e';
      return null;
    }
  }

  static String fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
