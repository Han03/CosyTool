import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/session/tool_session.dart';
import '../../core/utils/permissions.dart';

/// 一条录音记录。
class RecordingItem {
  RecordingItem(this.path, {this.duration});

  final String path;
  Duration? duration;

  String get name {
    final base = path.split(Platform.pathSeparator).last;
    return base.replaceFirst(RegExp(r'^rec_'), '').replaceAll('.m4a', '');
  }

  String get sizeLabel {
    final f = File(path);
    final bytes = f.existsSync() ? f.lengthSync().toDouble() : 0;
    if (bytes >= 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

/// 录音机会话：录制 / 回放引擎常驻，切页不断。
///
/// 播放进度等高频状态通过 [notifyListeners] 驱动页面刷新。
class RecorderSession extends ToolSession {
  RecorderSession() : super('recorder') {
    _player.onDurationChanged.listen((d) {
      playingDuration = d;
      notifyListeners();
    });
    _player.onPositionChanged.listen((d) {
      if (!_seekTicking) {
        playingPosition = d;
        notifyListeners();
      }
    });
    _player.onPlayerComplete.listen((_) {
      playingPath = null;
      playingPosition = Duration.zero;
      playingDuration = Duration.zero;
      notifyListeners();
    });
  }

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  Timer? _ticker;
  Duration elapsed = Duration.zero;
  bool recording = false;
  bool paused = false;
  double level = 0; // 0..1 归一化电平
  String? currentPath;
  Directory? recordDir;

  final List<RecordingItem> items = [];
  String? playingPath;
  Duration playingDuration = Duration.zero;
  Duration playingPosition = Duration.zero;
  bool _seekTicking = false;

  /// 最近一次操作错误信息（页面据此提示）。
  String? lastError;

  @override
  bool get isRunning => recording;

  @override
  String get statusLabel => '录音';

  @override
  String get statusText => fmt(elapsed);

  /// 初始化录音目录并加载历史文件。
  Future<void> loadItems() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    recordDir = dir;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.m4a'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    items
      ..clear()
      ..addAll(files.map((f) => RecordingItem(f.path)));
    notifyListeners();
  }

  /// 开始录音；返回是否成功（权限 / 启动失败时置 [lastError] 并返回 false）。
  Future<bool> start() async {
    lastError = null;
    if (recording) return true;
    final granted = await Permissions.requestMic();
    if (!granted) {
      lastError = '未获得麦克风权限，无法录音';
      return false;
    }
    if (recordDir == null) return false;
    final path =
        '${recordDir!.path}${Platform.pathSeparator}rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 2,
          autoGain: true,
        ),
        path: path,
      );
      currentPath = path;
      recording = true;
      paused = false;
      elapsed = Duration.zero;
      level = 0;
      _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) async {
        final amp = await _recorder.getAmplitude();
        elapsed = elapsed + const Duration(milliseconds: 120);
        // amp.current 为 dBFS（负值），-60~0 映射到 0..1
        level = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        notifyListeners();
      });
      notifyRunning();
      notifyListeners();
      return true;
    } catch (e) {
      lastError = '录音启动失败：$e';
      return false;
    }
  }

  @override
  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    try {
      final path = await _recorder.stop();
      if (path != null && currentPath != null) {
        items.insert(0, RecordingItem(currentPath!, duration: elapsed));
        recording = false;
        paused = false;
      }
    } catch (e) {
      lastError = '录音结束失败：$e';
    }
    recording = false;
    paused = false;
    notifyRunning();
    notifyListeners();
  }

  Future<void> pauseResume() async {
    if (paused) {
      await _recorder.resume();
      paused = false;
    } else {
      await _recorder.pause();
      paused = true;
    }
    notifyListeners();
  }

  Future<void> cancel() async {
    _ticker?.cancel();
    _ticker = null;
    try {
      await _recorder.cancel();
    } catch (_) {}
    final path = currentPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    recording = false;
    paused = false;
    elapsed = Duration.zero;
    currentPath = null;
    notifyRunning();
    notifyListeners();
  }

  Future<void> togglePlay(RecordingItem item) async {
    if (playingPath == item.path) {
      await _player.stop();
      playingPath = null;
      playingPosition = Duration.zero;
      playingDuration = Duration.zero;
      notifyListeners();
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(item.path));
    playingPath = item.path;
    playingPosition = Duration.zero;
    playingDuration = item.duration ?? Duration.zero;
    notifyListeners();
  }

  Future<void> seek(double seconds) async {
    if (playingPath == null) return;
    final target = Duration(milliseconds: (seconds * 1000).round());
    playingPosition = target;
    _seekTicking = true;
    await _player.seek(target);
    _seekTicking = false;
  }

  Future<void> delete(RecordingItem item) async {
    final f = File(item.path);
    if (await f.exists()) await f.delete();
    if (playingPath == item.path) {
      await _player.stop();
      playingPath = null;
    }
    items.remove(item);
    notifyListeners();
  }

  /// 重命名录音文件；返回是否成功。
  Future<bool> rename(RecordingItem item, String newName) async {
    final dir = File(item.path).parent.path;
    final safe = newName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final target = '$dir${Platform.pathSeparator}$safe.m4a';
    try {
      await File(item.path).rename(target);
      final idx = items.indexOf(item);
      if (idx >= 0) items[idx] = RecordingItem(target, duration: item.duration);
      if (playingPath == item.path) {
        await _player.stop();
        playingPath = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      lastError = '重命名失败：$e';
      return false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  static String fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
