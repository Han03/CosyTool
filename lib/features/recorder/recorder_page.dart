import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/utils/permissions.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 录音机工具：录制、回放、管理录音文件。
///
/// 使用 `record` 插件录制（aacLc / m4a），`audioplayers` 回放，
/// 文件保存在应用文档目录的 recordings/ 下。
class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  static final ToolInfo _tool = ToolRegistry.of('recorder');

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _paused = false;
  double _level = 0; // 0..1 归一化电平
  String? _currentPath;
  Directory? _recordDir;

  final List<_RecordingItem> _items = [];
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    _recordDir = dir;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.m4a'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(files.map((f) => _RecordingItem(f.path)));
    });
  }

  Future<void> _startRecording() async {
    final granted = await Permissions.requestMic();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未获得麦克风权限，无法录音')),
      );
      return;
    }
    if (_recordDir == null) return;
    final path =
        '${_recordDir!.path}${Platform.pathSeparator}rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
      _currentPath = path;
      setState(() {
        _recording = true;
        _paused = false;
        _elapsed = Duration.zero;
        _level = 0;
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) async {
        final amp = await _recorder.getAmplitude();
        if (!mounted) return;
        setState(() {
          _elapsed = _elapsed + const Duration(milliseconds: 120);
          // amp.current 为 dBFS（负值），-60~0 映射到 0..1
          _level = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('录音启动失败：$e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _ticker = null;
    try {
      final path = await _recorder.stop();
      if (path != null && _currentPath != null) {
        setState(() {
          _items.insert(0, _RecordingItem(_currentPath!));
          _recording = false;
          _paused = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('录音结束失败：$e')),
      );
    }
    setState(() {
      _recording = false;
      _paused = false;
    });
  }

  Future<void> _pauseRecording() async {
    if (_paused) {
      await _recorder.resume();
      setState(() => _paused = false);
    } else {
      await _recorder.pause();
      setState(() => _paused = true);
    }
  }

  Future<void> _cancelRecording() async {
    _ticker?.cancel();
    _ticker = null;
    try {
      await _recorder.cancel();
    } catch (_) {}
    final path = _currentPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    setState(() {
      _recording = false;
      _paused = false;
      _elapsed = Duration.zero;
      _currentPath = null;
    });
  }

  Future<void> _togglePlay(String path) async {
    if (_playingPath == path) {
      await _player.stop();
      setState(() => _playingPath = null);
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    setState(() => _playingPath = path);
    _player.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _playingPath = null);
    });
  }

  Future<void> _deleteRecording(_RecordingItem item) async {
    final f = File(item.path);
    if (await f.exists()) await f.delete();
    if (_playingPath == item.path) {
      await _player.stop();
      _playingPath = null;
    }
    setState(() => _items.remove(item));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ToolPageScaffold(
      tool: _tool,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                // 录制控制区
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    children: [
                      // 电平条
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          height: 10,
                          color: colorScheme.surfaceContainerHighest,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _level.clamp(0.02, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.primary.withValues(alpha: 0.6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _fmt(_elapsed),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w300,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _recording
                            ? (_paused ? '已暂停' : '录制中…')
                            : '点击开始录音',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _recording
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_recording)
                            IconButton.filledTonal(
                              tooltip: _paused ? '继续' : '暂停',
                              icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                              onPressed: _pauseRecording,
                            ),
                          const SizedBox(width: 16),
                          Material(
                            color: _recording ? colorScheme.error : colorScheme.primary,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _recording ? _stopRecording : _startRecording,
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: Icon(
                                  _recording ? Icons.stop_rounded : Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (_recording)
                            IconButton.filledTonal(
                              tooltip: '取消并删除',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: _cancelRecording,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                // 录音列表
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Text(
                            '还没有录音，点上面的麦克风开始吧',
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final playing = _playingPath == item.path;
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  playing ? Icons.graphic_eq_rounded : Icons.audiotrack_rounded,
                                  color: playing ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                ),
                                title: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${_fmt(item.duration)} · ${item.sizeLabel}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: playing ? '停止' : '播放',
                                      icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                                      onPressed: () => _togglePlay(item.path),
                                    ),
                                    IconButton(
                                      tooltip: '删除',
                                      icon: const Icon(Icons.delete_outline_rounded),
                                      onPressed: () => _deleteRecording(item),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 一条录音记录。
class _RecordingItem {
  _RecordingItem(this.path);

  final String path;

  String get name {
    final base = path.split(Platform.pathSeparator).last;
    return base.replaceFirst(RegExp(r'^rec_'), '').replaceAll('.m4a', '');
  }

  Duration get duration {
    final f = File(path);
    // m4a 无轻量时长解析，此处以文件大小估算展示（约 16KB/s @128kbps）
    final bytes = f.existsSync() ? f.lengthSync() : 0;
    return Duration(milliseconds: (bytes * 8 / 128000 * 1000).round());
  }

  String get sizeLabel {
    final f = File(path);
    final bytes = f.existsSync() ? f.lengthSync().toDouble() : 0;
    if (bytes >= 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
