import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session/session_registry.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import 'recorder_session.dart';

/// 录音机工具：录制、回放、管理录音文件（引擎常驻，切页不断）。
class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  static final ToolInfo _tool = ToolRegistry.of('recorder');

  late final RecorderSession _session;

  @override
  void initState() {
    super.initState();
    _session = SessionRegistry.instance.sessionOf('recorder', RecorderSession.new);
    _session.addListener(_onChanged);
    _session.loadItems();
  }

  @override
  void dispose() {
    _session.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _showError(String? msg) {
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _startRecording() async {
    final ok = await _session.start();
    if (!ok) _showError(_session.lastError);
  }

  Future<void> _stopRecording() async {
    await _session.stop();
    _showError(_session.lastError);
  }

  Future<void> _renameRecording(RecordingItem item) async {
    final controller = TextEditingController(text: item.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名录音'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称（不包含扩展名）'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (!mounted || newName == null || newName.isEmpty || newName == item.name) return;
    final ok = await _session.rename(item, newName);
    if (!ok) _showError(_session.lastError);
  }

  Future<void> _copyPath(RecordingItem item) async {
    await Clipboard.setData(ClipboardData(text: item.path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制文件路径')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = _session;
    final recording = session.recording;
    final items = session.items;

    return ToolPageScaffold(
      tool: _tool,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
                            widthFactor: session.level.clamp(0.02, 1.0),
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
                        RecorderSession.fmt(session.elapsed),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w300,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recording
                            ? (session.paused ? '已暂停' : '录制中…')
                            : '点击开始录音',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: recording
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (recording)
                            IconButton.filledTonal(
                              tooltip: session.paused ? '继续' : '暂停',
                              icon: Icon(session.paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded),
                              onPressed: session.pauseResume,
                            ),
                          const SizedBox(width: 16),
                          Material(
                            color: recording ? colorScheme.error : colorScheme.primary,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap:
                                  recording ? _stopRecording : _startRecording,
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: Icon(
                                  recording ? Icons.stop_rounded : Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (recording)
                            IconButton.filledTonal(
                              tooltip: '取消并删除',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: session.cancel,
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
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            '还没有录音，点上面的麦克风开始吧',
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final playing = session.playingPath == item.path;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                                child: Column(
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        playing
                                            ? Icons.graphic_eq_rounded
                                            : Icons.audiotrack_rounded,
                                        color: playing
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
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
                                        '${RecorderSession.fmt(playing ? session.playingPosition : item.duration ?? Duration.zero)}'
                                        '${playing && session.playingDuration > Duration.zero ? ' / ${RecorderSession.fmt(session.playingDuration)}' : ''}'
                                        ' · ${item.sizeLabel}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: playing ? '停止' : '播放',
                                            icon: Icon(
                                              playing
                                                  ? Icons.stop_rounded
                                                  : Icons.play_arrow_rounded,
                                            ),
                                            onPressed: () => session.togglePlay(item),
                                          ),
                                          PopupMenuButton<String>(
                                            tooltip: '更多操作',
                                            onSelected: (v) {
                                              switch (v) {
                                                case 'rename':
                                                  _renameRecording(item);
                                                  break;
                                                case 'copy':
                                                  _copyPath(item);
                                                  break;
                                              }
                                            },
                                            itemBuilder: (ctx) => const [
                                              PopupMenuItem(
                                                value: 'rename',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.drive_file_rename_outline_rounded, size: 20),
                                                    SizedBox(width: 12),
                                                    Text('重命名'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'copy',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.copy_rounded, size: 20),
                                                    SizedBox(width: 12),
                                                    Text('复制路径'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          IconButton(
                                            tooltip: '删除',
                                            icon: const Icon(Icons.delete_outline_rounded),
                                            onPressed: () => session.delete(item),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 播放进度条
                                    if (playing) ...[
                                      const SizedBox(height: 4),
                                      Slider(
                                        value: session.playingDuration.inMilliseconds == 0
                                            ? 0
                                            : (session.playingPosition.inMilliseconds /
                                                    session.playingDuration.inMilliseconds)
                                                .clamp(0.0, 1.0),
                                        onChanged: (v) => session.seek(
                                            v * session.playingDuration.inSeconds.toDouble()),
                                        min: 0,
                                        max: 1,
                                      ),
                                    ],
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
