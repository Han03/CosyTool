import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/app_data.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import 'tts_service.dart';

/// 文本阅读模式。
enum _ReaderMode { input, book }

/// 本地书籍条目（选择器用）。
class _BookEntry {
  const _BookEntry(this.name, this.path, this.isDir);

  final String name;
  final String path;
  final bool isDir;
}

/// 文本阅读：Edge-TTS 语音朗读 + 本地小说阅读。
///
/// - 输入朗读：粘贴文本 → 分句朗读（音色 / 语速 / 音调可调）
/// - 本地小说：从数据文件夹 `text_reader/books/` 选择小说，
///   分页阅读 + 进度自动保存，TTS 语音缓存到 `text_reader/tts_cache/`
class TextReaderPage extends StatefulWidget {
  const TextReaderPage({super.key});

  @override
  State<TextReaderPage> createState() => _TextReaderPageState();
}

class _TextReaderPageState extends State<TextReaderPage> {
  static final ToolInfo _tool = ToolRegistry.of('text_reader');
  static const int _pageChars = 2500; // 每页字符数（runes）

  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _urlCtrl =
      TextEditingController(text: 'https://tts.maxh.ccwu.cc');

  TtsService? _tts;
  String _voice = 'zh-CN-YunxiNeural';
  double _speed = 1.0;
  double _pitch = 0;

  _ReaderMode _mode = _ReaderMode.input;

  // 小说模式状态
  File? _bookFile;
  String _bookTitle = '';
  List<String> _pages = const [];
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    final service = await TtsService.create();
    // TTS 语音缓存到数据文件夹 text_reader/tts_cache/
    service.cacheDir = await AppData.toolSubDir('text_reader', 'tts_cache');
    if (!mounted) return;
    service.onStateChanged = _onStateChanged;
    service.onError = ((String msg) => _showError('$msg，已跳过该句'));
    service.onComplete = (() => _showMessage('朗读完成'));
    setState(() => _tts = service);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tts?.dispose();
    _textCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- 输入模式 ----------------

  Future<void> _pasteInput() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || !mounted) return;
    setState(() => _textCtrl.text = data.text!);
  }

  void _loadSample() {
    setState(() {
      _textCtrl.text = '欢迎使用 CosyTool 文本阅读工具。'
          '本工具基于 Edge-TTS 语音合成，可以朗读长文本。'
          '你可以粘贴文章、讲稿或任何文字内容，选择合适的音色和语速开始朗读。'
          '也支持从本地数据文件夹读取小说，自动记录阅读进度。';
    });
  }

  void _clearInput() {
    _tts?.stop();
    setState(() => _textCtrl.clear());
  }

  bool get _canPlay => _textCtrl.text.trim().isNotEmpty;

  void _applyTtsSettings() {
    final tts = _tts;
    if (tts == null) return;
    tts.serviceUrl = _urlCtrl.text.trim().isEmpty
        ? 'https://tts.maxh.ccwu.cc'
        : _urlCtrl.text.trim();
    tts.voice = _voice;
    tts.speed = _speed;
    tts.pitch = _pitch;
  }

  void _play() {
    final tts = _tts;
    if (tts == null) return;
    if (!_canPlay) return;
    _applyTtsSettings();
    tts.speak(_textCtrl.text);
  }

  void _playCurrentPage() {
    final tts = _tts;
    if (tts == null || _pages.isEmpty) return;
    _applyTtsSettings();
    tts.speak(_pages[_pageIndex]);
  }

  void _togglePlayPause() {
    final tts = _tts;
    if (tts == null) return;
    if (tts.isSpeaking && tts.isPaused) {
      tts.resume();
    } else if (tts.isSpeaking) {
      tts.pause();
    } else if (_mode == _ReaderMode.input) {
      _play();
    } else {
      _playCurrentPage();
    }
  }

  // ---------------- 小说模式 ----------------

  /// 浏览数据文件夹 books/ 下的小说（支持一层子目录）。
  Future<File?> _pickBook() async {
    final booksDir = await AppData.toolSubDir('text_reader', 'books');
    if (!mounted) return null;
    return showDialog<File>(
      context: context,
      builder: (ctx) => _BookPickerDialog(rootDir: booksDir),
    );
  }

  Future<void> _openBook(File file) async {
    try {
      final text = await file.readAsString();
      if (!mounted) return;
      final pages = _paginate(text, _pageChars);
      final title = file.uri.pathSegments.last;
      final saved = await _loadProgress(title);
      if (!mounted) return;
      setState(() {
        _bookFile = file;
        _bookTitle = title;
        _pages = pages;
        _pageIndex = saved == null
            ? 0
            : saved.clamp(0, pages.isEmpty ? 0 : pages.length - 1);
        _mode = _ReaderMode.book;
      });
    } catch (e) {
      _showError('读取小说失败：$e');
    }
  }

  List<String> _paginate(String text, int perPage) {
    final runes = text.runes.toList();
    if (runes.isEmpty) return const [];
    final pages = <String>[];
    for (var i = 0; i < runes.length; i += perPage) {
      final end = (i + perPage) > runes.length ? runes.length : i + perPage;
      pages.add(String.fromCharCodes(runes.sublist(i, end)));
    }
    return pages;
  }

  Future<int?> _loadProgress(String title) async {
    try {
      final dir = await AppData.toolSubDir('text_reader', 'progress');
      final f = File('${dir.path}${Platform.pathSeparator}$title.json');
      if (!await f.exists()) return null;
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return (map['page'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProgress() async {
    if (_bookFile == null || _pages.isEmpty) return;
    try {
      final dir = await AppData.toolSubDir('text_reader', 'progress');
      final f = File('${dir.path}${Platform.pathSeparator}$_bookTitle.json');
      await f.writeAsString(jsonEncode({
        'path': _bookFile!.path,
        'page': _pageIndex,
        'total': _pages.length,
        'updatedAt': DateTime.now().toIso8601String(),
      }));
    } catch (_) {
      // 进度保存失败不影响阅读
    }
  }

  void _goPage(int index) {
    if (_pages.isEmpty) return;
    final target = index.clamp(0, _pages.length - 1);
    if (target == _pageIndex) return;
    setState(() => _pageIndex = target);
    _saveProgress();
  }

  void _closeBook() {
    _saveProgress();
    setState(() {
      _bookFile = null;
      _bookTitle = '';
      _pages = const [];
      _pageIndex = 0;
    });
  }

  Future<void> _clearTtsCache() async {
    final tts = _tts;
    if (tts == null) return;
    final count = await tts.clearDiskCache();
    if (!mounted) return;
    _showMessage('已清理 $count 条语音缓存');
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tts = _tts;

    final actions = <Widget>[
      if (_mode == _ReaderMode.book && _bookFile != null)
        IconButton(
          tooltip: '清空语音缓存',
          icon: const Icon(Icons.cleaning_services_rounded),
          onPressed: _clearTtsCache,
        ),
      if (_mode == _ReaderMode.input)
        IconButton(
          tooltip: '清空',
          icon: const Icon(Icons.delete_sweep_rounded),
          onPressed: _clearInput,
        ),
    ];

    return ToolPageScaffold(
      tool: _tool,
      actions: actions,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _mode == _ReaderMode.book && _bookFile != null
                ? _buildBookView(theme, colorScheme)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<_ReaderMode>(
                          segments: const [
                            ButtonSegment(
                              value: _ReaderMode.input,
                              icon: Icon(Icons.edit_rounded, size: 16),
                              label: Text('输入朗读'),
                            ),
                            ButtonSegment(
                              value: _ReaderMode.book,
                              icon: Icon(Icons.menu_book_rounded, size: 16),
                              label: Text('本地小说'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (s) =>
                              setState(() => _mode = s.first),
                        ),
                        const SizedBox(height: 16),
                        if (_mode == _ReaderMode.input)
                          _buildInputView(theme, colorScheme, tts)
                        else
                          _buildBookPickerView(theme, colorScheme),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputView(ThemeData theme, ColorScheme colorScheme, TtsService? tts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInputCard(theme, colorScheme),
        const SizedBox(height: 16),
        _buildSettingsCard(theme, colorScheme),
        const SizedBox(height: 16),
        if (tts != null && tts.total > 0) ...[
          _buildControlBar(theme, colorScheme),
          const SizedBox(height: 16),
          _buildSentenceList(theme, colorScheme),
        ] else
          _buildIdleHint(theme, colorScheme),
      ],
    );
  }

  Widget _buildInputCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('朗读文本',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadSample,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('示例'),
                ),
                TextButton.icon(
                  onPressed: _pasteInput,
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('粘贴'),
                ),
              ],
            ),
            TextField(
              controller: _textCtrl,
              minLines: 6,
              maxLines: 12,
              style: const TextStyle(fontSize: 14, height: 1.5),
              decoration: const InputDecoration(
                hintText: '输入或粘贴要朗读的文本…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _canPlay ? _play : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始朗读'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('朗读设置',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _voice,
              decoration: const InputDecoration(
                labelText: '音色',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final v in TtsVoice.chinese)
                  DropdownMenuItem(value: v.id, child: Text(v.label)),
              ],
              onChanged: (v) => setState(() => _voice = v ?? _voice),
            ),
            const SizedBox(height: 16),
            _buildSliderRow(
              theme,
              label: '语速',
              valueLabel: '${_speed.toStringAsFixed(1)}x',
              value: _speed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (v) => setState(() => _speed = v),
            ),
            const SizedBox(height: 8),
            _buildSliderRow(
              theme,
              label: '音调',
              valueLabel: '${_pitch.round()}',
              value: _pitch,
              min: -50,
              max: 50,
              divisions: 100,
              onChanged: (v) => setState(() => _pitch = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Edge-TTS 服务地址',
                hintText: 'https://tts.maxh.ccwu.cc',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    ThemeData theme, {
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            valueLabel,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlBar(ThemeData theme, ColorScheme colorScheme) {
    final tts = _tts!;
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: '上一句',
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: () => tts.skipPrevious(),
            ),
            IconButton.filled(
              tooltip: tts.isPaused ? '继续' : '暂停',
              icon: Icon(tts.isPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded),
              onPressed: _togglePlayPause,
            ),
            IconButton(
              tooltip: '下一句',
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: () => tts.skipNext(),
            ),
            IconButton(
              tooltip: '停止',
              icon: const Icon(Icons.stop_rounded),
              onPressed: () => tts.stop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '第 ${tts.currentIndex + 1} / ${tts.total} 句',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    tts.currentText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (tts.isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceList(ThemeData theme, ColorScheme colorScheme) {
    final tts = _tts!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '句子列表（点击跳转播放）',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: tts.total,
            itemBuilder: (context, index) {
              final active = index == tts.currentIndex && tts.isSpeaking;
              return ListTile(
                dense: true,
                selected: active,
                selectedTileColor:
                    colorScheme.primaryContainer.withValues(alpha: 0.6),
                leading: CircleAvatar(
                  radius: 13,
                  backgroundColor: active
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                title: Text(
                  tts.sentences[index],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: active
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                onTap: () => tts.skipTo(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIdleHint(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.record_voice_over_rounded,
                size: 40, color: colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(
              '输入文本后点击「开始朗读」',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookPickerView(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.menu_book_rounded,
                size: 40, color: colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text('从本地数据文件夹读取小说',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '将 .txt 小说放入数据文件夹 text_reader/books/，'
              '或通过设置页从 GitHub 仓库拉取后即可选择。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final file = await _pickBook();
                if (file != null && mounted) await _openBook(file);
              },
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('选择小说'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookView(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: '返回书库',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _closeBook,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '第 ${_pageIndex + 1} / ${_pages.length} 页',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '朗读本页',
                icon: const Icon(Icons.record_voice_over_rounded),
                onPressed: _playCurrentPage,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: SelectableText(
                _pages.isEmpty ? '（空）' : _pages[_pageIndex],
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.9,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: '上一页',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _pageIndex > 0 ? () => _goPage(_pageIndex - 1) : null,
                ),
                Expanded(
                  child: Slider(
                    value: _pageIndex.toDouble(),
                    min: 0,
                    max: _pages.isEmpty
                        ? 0
                        : (_pages.length - 1).toDouble(),
                    divisions: _pages.length > 1 ? _pages.length - 1 : 1,
                    label: '${_pageIndex + 1}/${_pages.length}',
                    onChanged: (v) => _goPage(v.round()),
                  ),
                ),
                IconButton(
                  tooltip: '下一页',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _pageIndex < _pages.length - 1
                      ? () => _goPage(_pageIndex + 1)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 书籍选择对话框：浏览数据文件夹 books/ 下的 .txt 文件（支持一层子目录）。
class _BookPickerDialog extends StatefulWidget {
  const _BookPickerDialog({required this.rootDir});

  final Directory rootDir;

  @override
  State<_BookPickerDialog> createState() => _BookPickerDialogState();
}

class _BookPickerDialogState extends State<_BookPickerDialog> {
  late Directory _currentDir;
  List<_BookEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentDir = widget.rootDir;
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final entries = <_BookEntry>[];
    await for (final e in _currentDir.list()) {
      if (e is Directory) {
        entries.add(_BookEntry(e.uri.pathSegments.last, e.path, true));
      } else if (e is File && e.path.toLowerCase().endsWith('.txt')) {
        entries.add(_BookEntry(e.uri.pathSegments.last, e.path, false));
      }
    }
    entries.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRoot = _currentDir.path == widget.rootDir.path;
    return AlertDialog(
      title: Text(isRoot ? '选择小说' : _currentDir.uri.pathSegments.last),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 380,
        height: 380,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? Center(
                    child: Text(
                      'books/ 目录下没有 .txt 文件\n请先放入小说或从云端拉取',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView(
                    children: [
                      if (!isRoot)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.arrow_upward_rounded),
                          title: const Text('..'),
                          onTap: () {
                            _currentDir = _currentDir.parent;
                            _reload();
                          },
                        ),
                      for (final e in _entries)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            e.isDir
                                ? Icons.folder_rounded
                                : Icons.description_rounded,
                            color: e.isDir
                                ? const Color(0xFFF5B642)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(e.name, maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          onTap: e.isDir
                              ? () {
                                  _currentDir = Directory(e.path);
                                  _reload();
                                }
                              : () => Navigator.of(context).pop(File(e.path)),
                        ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
