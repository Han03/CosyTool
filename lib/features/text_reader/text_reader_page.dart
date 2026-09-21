import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import 'tts_service.dart';

/// 文本阅读：Edge-TTS 语音朗读。
///
/// 输入文本 → 选择音色 / 语速 / 音调 / 服务地址 → 分句朗读，
/// 当前句高亮，支持暂停、上下句跳转、点句重播。
class TextReaderPage extends StatefulWidget {
  const TextReaderPage({super.key});

  @override
  State<TextReaderPage> createState() => _TextReaderPageState();
}

class _TextReaderPageState extends State<TextReaderPage> {
  static final ToolInfo _tool = ToolRegistry.of('text_reader');

  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _urlCtrl =
      TextEditingController(text: 'https://tts.maxh.ccwu.cc');

  TtsService? _tts;
  String _voice = 'zh-CN-YunxiNeural';
  double _speed = 1.0;
  double _pitch = 0;

  @override
  void initState() {
    super.initState();
    TtsService.create().then((service) {
      if (!mounted) return;
      service.onStateChanged = _onStateChanged;
      service.onError = ((String msg) => _showError('$msg，已跳过该句'));
      service.onComplete = (() => _showMessage('朗读完成'));
      setState(() => _tts = service);
    });
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
          '支持暂停、继续、上一句、下一句，点击句子即可从该句重新播放。';
    });
  }

  void _clearInput() {
    _tts?.stop();
    setState(() => _textCtrl.clear());
  }

  bool get _canPlay => _textCtrl.text.trim().isNotEmpty;

  void _play() {
    final tts = _tts;
    if (tts == null) return;
    if (!_canPlay) return;
    tts.serviceUrl = _urlCtrl.text.trim().isEmpty
        ? 'https://tts.maxh.ccwu.cc'
        : _urlCtrl.text.trim();
    tts.voice = _voice;
    tts.speed = _speed;
    tts.pitch = _pitch;
    tts.speak(_textCtrl.text);
  }

  void _togglePlayPause() {
    final tts = _tts;
    if (tts == null) return;
    if (tts.isSpeaking && tts.isPaused) {
      tts.resume();
    } else if (tts.isSpeaking) {
      tts.pause();
    } else {
      _play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tts = _tts;

    return ToolPageScaffold(
      tool: _tool,
      actions: [
        IconButton(
          tooltip: '清空',
          icon: const Icon(Icons.delete_sweep_rounded),
          onPressed: _clearInput,
        ),
      ],
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
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
              ),
            ),
          ),
        ),
      ),
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
}
