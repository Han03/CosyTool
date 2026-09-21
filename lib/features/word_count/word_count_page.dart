import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 文本统计结果。
class TextStats {
  const TextStats({
    required this.characters,
    required this.chinese,
    required this.latinLetters,
    required this.words,
    required this.digits,
    required this.punctuation,
    required this.whitespace,
    required this.lines,
    required this.paragraphs,
    required this.bytes,
  });

  /// 用户感知字符数（表情符号等按 1 计）。
  final int characters;
  final int chinese;
  final int latinLetters;
  final int words;
  final int digits;
  final int punctuation;
  final int whitespace;
  final int lines;
  final int paragraphs;
  final int bytes;

  /// 有效内容字符数（不含空白），用于占比图。
  int get contentChars => chinese + latinLetters + digits + punctuation;

  static const TextStats empty = TextStats(
    characters: 0,
    chinese: 0,
    latinLetters: 0,
    words: 0,
    digits: 0,
    punctuation: 0,
    whitespace: 0,
    lines: 0,
    paragraphs: 0,
    bytes: 0,
  );

  /// 对文本做一次完整统计。纯函数，无状态。
  factory TextStats.count(String text) {
    if (text.isEmpty) return empty;
    final chinese =
        RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final latin =
        RegExp(r'[A-Za-z]').allMatches(text).length;
    final words = RegExp(r'[A-Za-z]+').allMatches(text).length;
    final digits = RegExp(r'[0-9]').allMatches(text).length;
    final punct =
        RegExp(r'[\p{P}\p{S}]', unicode: true).allMatches(text).length;
    final ws = RegExp(r'\s').allMatches(text).length;
    final lines = '\n'.allMatches(text).length + 1;
    final trimmed = text.trim();
    final paragraphs = trimmed.isEmpty
        ? 0
        : trimmed
            .split(RegExp(r'\n\s*\n+'))
            .where((p) => p.trim().isNotEmpty)
            .length;
    return TextStats(
      characters: text.characters.length,
      chinese: chinese,
      latinLetters: latin,
      words: words,
      digits: digits,
      punctuation: punct,
      whitespace: ws,
      lines: lines,
      paragraphs: paragraphs,
      bytes: utf8.encode(text).length,
    );
  }
}

/// 字数统计：输入文本实时统计字符 / 中文 / 单词 / 行数 / 字节等。
class WordCountPage extends StatefulWidget {
  const WordCountPage({super.key});

  @override
  State<WordCountPage> createState() => _WordCountPageState();
}

class _WordCountPageState extends State<WordCountPage> {
  static final ToolInfo _tool = ToolRegistry.of('word_count');

  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _targetCtrl = TextEditingController();

  TextStats _stats = TextStats.empty;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _stats = TextStats.count(_inputCtrl.text);
    });
  }

  Future<void> _pasteInput() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null) return;
    _inputCtrl.text = data.text!;
    _onChanged();
  }

  void _clearInput() {
    _inputCtrl.clear();
    _onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final target = int.tryParse(_targetCtrl.text.trim());
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
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _inputCtrl,
                    onChanged: (_) => _onChanged(),
                    minLines: 8,
                    maxLines: 14,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: '输入文本（实时统计）',
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: '粘贴',
                        icon: const Icon(Icons.content_paste_rounded, size: 20),
                        onPressed: _pasteInput,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _targetCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '目标字数（可选）',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTargetCard(theme, colorScheme, target),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildStatGrid(theme, colorScheme),
                  if (_stats.contentChars > 0) ...[
                    const SizedBox(height: 20),
                    _buildCompositionBar(colorScheme),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetCard(ThemeData theme, ColorScheme colorScheme, int? target) {
    final ratio = (target == null || target <= 0)
        ? null
        : (_stats.characters / target).clamp(0.0, 1.0);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ratio == null
          ? Text(
              '当前 ${_stats.characters} 字符',
              style: theme.textTheme.bodyMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_stats.characters} / $target',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ratio >= 1.0 ? colorScheme.primary : null,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatGrid(ThemeData theme, ColorScheme colorScheme) {
    final items = <(String, int)>[
      ('总字符', _stats.characters),
      ('中文字符', _stats.chinese),
      ('英文单词', _stats.words),
      ('数字', _stats.digits),
      ('标点', _stats.punctuation),
      ('空白', _stats.whitespace),
      ('行数', _stats.lines),
      ('段落', _stats.paragraphs),
      ('UTF-8 字节', _stats.bytes),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _formatCount(item.$2),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  String _formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _buildCompositionBar(ColorScheme colorScheme) {
    const segments = <(String, Color)>[
      ('中文', Color(0xFF3D7BF6)),
      ('英文', Color(0xFF2F9E6E)),
      ('数字', Color(0xFFF09B3A)),
      ('标点', Color(0xFFB66AE8)),
      ('空白', Color(0xFF9AA5B1)),
    ];
    final values = <int>[
      _stats.chinese,
      _stats.latinLetters,
      _stats.digits,
      _stats.punctuation,
      _stats.whitespace,
    ];
    final total = values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '字符构成',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (var i = 0; i < segments.length; i++)
                  Expanded(
                    flex: values[i],
                    child: values[i] == 0
                        ? const SizedBox.shrink()
                        : ColoredBox(color: segments[i].$2),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < segments.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: segments[i].$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${segments[i].$1} ${values[i]}'
                    '${total == 0 ? '' : '（${(values[i] * 100 / total).toStringAsFixed(1)}%）'}',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
