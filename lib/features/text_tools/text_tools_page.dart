import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 文本工具：JSON / Base64 / URL / 大小写 / 文本清理 / 行处理。
///
/// 全部基于 dart:convert 与字符串处理，无平台依赖，手机与桌面端一致可用。
class TextToolsPage extends StatefulWidget {
  const TextToolsPage({super.key});

  @override
  State<TextToolsPage> createState() => _TextToolsPageState();
}

enum _Mode { json, base64, url, textCase, clean, lines }

class _TextToolsPageState extends State<TextToolsPage> {
  static final ToolInfo _tool = ToolRegistry.of('text_tools');

  _Mode _mode = _Mode.json;

  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  String _output = '';
  String? _error;
  String _status = '';

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ---------- 核心转换 ----------

  void _run(String op) {
    final input = _inputCtrl.text;
    if (input.trim().isEmpty && op != 'validate') {
      setState(() {
        _error = '请先输入要处理的文本';
        _output = '';
        _status = '';
      });
      return;
    }
    try {
      switch (_mode) {
        case _Mode.json:
          _runJson(op, input);
        case _Mode.base64:
          _runBase64(op, input);
        case _Mode.url:
          _runUrl(op, input);
        case _Mode.textCase:
          _runCase(op, input);
        case _Mode.clean:
          _runClean(op, input);
        case _Mode.lines:
          _runLines(op, input);
      }
    } catch (e) {
      setState(() {
        _error = '处理失败：$e';
        _output = '';
      });
    }
  }

  void _runJson(String op, String input) {
    final decoded = jsonDecode(input); // 非法 JSON 会抛 FormatException
    switch (op) {
      case 'format':
        setState(() {
          _output = const JsonEncoder.withIndent('  ').convert(decoded);
          _error = null;
          _status = '格式化完成';
        });
      case 'minify':
        setState(() {
          _output = jsonEncode(decoded);
          _error = null;
          _status = '压缩完成';
        });
      case 'validate':
        setState(() {
          final type = _jsonTypeName(decoded);
          _output = '✔ 有效 JSON（顶层类型：$type）\n\n'
              '${const JsonEncoder.withIndent('  ').convert(decoded)}';
          _error = null;
          _status = '校验通过';
        });
    }
  }

  String _jsonTypeName(Object? v) {
    if (v is Map) return '对象 {}';
    if (v is List) return '数组 []';
    if (v is String) return '字符串';
    if (v is num) return '数字';
    if (v is bool) return '布尔值';
    return 'null';
  }

  void _runBase64(String op, String input) {
    final bytes = utf8.encode(input);
    if (op == 'encode') {
      setState(() {
        _output = base64Encode(bytes);
        _error = null;
        _status = '已按 UTF-8 编码，共 ${bytes.length} 字节';
      });
      return;
    }
    // 解码：先 base64 -> 字节，再尝试 UTF-8
    final decoded = base64Decode(input.trim()); // 非法字符抛 FormatException
    String text;
    try {
      text = utf8.decode(decoded);
    } on FormatException {
      text = latin1.decode(decoded); // 非 UTF-8 文本时保留原始字节
      setState(() {
        _output = text;
        _error = null;
        _status = '已解码（${decoded.length} 字节，非 UTF-8 文本，按原始字节展示）';
      });
      return;
    }
    setState(() {
      _output = text;
      _error = null;
      _status = '已解码，共 ${decoded.length} 字节';
    });
  }

  void _runUrl(String op, String input) {
    if (op == 'encode') {
      setState(() {
        _output = Uri.encodeComponent(input);
        _error = null;
        _status = '已按组件模式编码（空格→%20）';
      });
      return;
    }
    setState(() {
      _output = Uri.decodeComponent(input.trim()); // 非法 % 序列抛 ArgumentError
      _error = null;
      _status = '已解码';
    });
  }

  void _runCase(String op, String input) {
    switch (op) {
      case 'upper':
        _setOut(input.toUpperCase(), '已转为大写');
      case 'lower':
        _setOut(input.toLowerCase(), '已转为小写');
      case 'title':
        _setOut(
          input
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
              .join(' '),
          '每个单词首字母大写',
        );
      case 'camel':
        final words = input
            .split(RegExp(r'[^A-Za-z0-9\u4e00-\u9fff]+'))
            .where((w) => w.isNotEmpty)
            .toList();
        if (words.isEmpty) {
          _setOut('', '无可转换的单词');
          return;
        }
        _setOut(
          words.first.toLowerCase() +
              words
                  .skip(1)
                  .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
                  .join(),
          '已转为小驼峰 camelCase',
        );
      case 'snake':
        _setOut(
          input
              .split(RegExp(r'[^A-Za-z0-9\u4e00-\u9fff]+'))
              .where((w) => w.isNotEmpty)
              .map((w) => w.toLowerCase())
              .join('_'),
          '已转为蛇形 snake_case',
        );
      case 'kebab':
        _setOut(
          input
              .split(RegExp(r'[^A-Za-z0-9\u4e00-\u9fff]+'))
              .where((w) => w.isNotEmpty)
              .map((w) => w.toLowerCase())
              .join('-'),
          '已转为短横线 kebab-case',
        );
    }
  }

  void _runClean(String op, String input) {
    switch (op) {
      case 'spaces':
        _setOut(input.trim().replaceAll(RegExp(r'[ \t]+'), ' '), '已合并多余空格');
      case 'blank':
        _setOut(input.replaceAll(RegExp(r'\n\s*\n+'), '\n\n').trim(), '已合并连续空行');
      case 'trimline':
        _setOut(
          input.split('\n').map((l) => l.trim()).join('\n').trim(),
          '已去除每行首尾空格',
        );
      case 'trimall':
        _setOut(input.trim(), '已去除首尾空白');
    }
  }

  void _runLines(String op, String input) {
    var lines = input.split('\n');
    if (op == 'dedupe') {
      final seen = <String>{};
      lines = lines.where((l) => seen.add(l)).toList();
      _setOut(lines.join('\n'), '已去重（保留首次出现顺序），${lines.length} 行');
      return;
    }
    if (op == 'sort') {
      lines = [...lines]..sort();
      _setOut(lines.join('\n'), '已升序排序');
      return;
    }
    if (op == 'sortdesc') {
      lines = [...lines]..sort((a, b) => b.compareTo(a));
      _setOut(lines.join('\n'), '已降序排序');
      return;
    }
    if (op == 'reverse') {
      _setOut(lines.reversed.join('\n'), '已倒序');
      return;
    }
    if (op == 'number') {
      final buf = StringBuffer();
      for (var i = 0; i < lines.length; i++) {
        buf.writeln('${i + 1}. ${lines[i]}');
      }
      _setOut(buf.toString().trimRight(), '已加行号，共 ${lines.length} 行');
    }
  }

  void _setOut(String text, String status) {
    setState(() {
      _output = text;
      _error = null;
      _status = status;
    });
  }

  void _pasteInput() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null) return;
    _inputCtrl.text = data.text!;
    if (mounted) setState(() {});
  }

  void _clearInput() {
    _inputCtrl.clear();
    setState(() {
      _error = null;
      _output = '';
      _status = '';
    });
  }

  Future<void> _copyOutput() async {
    if (_output.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _output));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ToolPageScaffold(
      tool: _tool,
      actions: [
        IconButton(
          tooltip: '清空',
          icon: const Icon(Icons.delete_sweep_rounded),
          onPressed: _clearInput,
        ),
        if (_output.isNotEmpty)
          IconButton(
            tooltip: '复制结果',
            icon: const Icon(Icons.copy_rounded),
            onPressed: _copyOutput,
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _modeChip(_Mode.json, 'JSON', Icons.data_object_rounded),
                      _modeChip(_Mode.base64, 'Base64', Icons.lock_rounded),
                      _modeChip(_Mode.url, 'URL', Icons.link_rounded),
                      _modeChip(_Mode.textCase, '大小写', Icons.text_fields_rounded),
                      _modeChip(_Mode.clean, '文本清理', Icons.cleaning_services_rounded),
                      _modeChip(_Mode.lines, '行处理', Icons.format_list_numbered_rounded),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _inputCtrl,
                    focusNode: _inputFocus,
                    minLines: 6,
                    maxLines: 10,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: '输入文本',
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
                  _buildActions(colorScheme),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 15, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _status,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                        Text(
                          '输入 ${_inputCtrl.text.length} 字符',
                          style: TextStyle(fontSize: 11, color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 18, color: colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_output.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '结果',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: '复制结果',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                onPressed: _copyOutput,
                              ),
                            ],
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _output,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeChip(_Mode mode, String label, IconData icon) {
    return ChoiceChip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      selected: _mode == mode,
      onSelected: (_) => setState(() {
        _mode = mode;
        _error = null;
        _output = '';
        _status = '';
      }),
    );
  }

  Widget _buildActions(ColorScheme colorScheme) {
    final opDefs = _opDefs();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opDefs.map((op) {
        return FilledButton.tonalIcon(
          onPressed: () => _run(op.id),
          icon: Icon(op.icon, size: 17),
          label: Text(op.label),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        );
      }).toList(),
    );
  }

  List<_OpDef> _opDefs() {
    switch (_mode) {
      case _Mode.json:
        return const [
          _OpDef('format', '格式化', Icons.format_align_left_rounded),
          _OpDef('minify', '压缩', Icons.compress_rounded),
          _OpDef('validate', '校验', Icons.verified_rounded),
        ];
      case _Mode.base64:
        return const [
          _OpDef('encode', '编码', Icons.lock_outline_rounded),
          _OpDef('decode', '解码', Icons.lock_open_rounded),
        ];
      case _Mode.url:
        return const [
          _OpDef('encode', '编码', Icons.link_rounded),
          _OpDef('decode', '解码', Icons.link_off_rounded),
        ];
      case _Mode.textCase:
        return const [
          _OpDef('upper', '全大写', Icons.format_underlined_rounded),
          _OpDef('lower', '全小写', Icons.text_rotate_vertical_rounded),
          _OpDef('title', '首字母大写', Icons.title_rounded),
          _OpDef('camel', '驼峰', Icons.arrow_downward_rounded),
          _OpDef('snake', '蛇形', Icons.horizontal_rule_rounded),
          _OpDef('kebab', '短横线', Icons.minimize_rounded),
        ];
      case _Mode.clean:
        return const [
          _OpDef('spaces', '合并空格', Icons.space_bar_rounded),
          _OpDef('blank', '合并空行', Icons.vertical_align_center_rounded),
          _OpDef('trimline', '去行首尾空格', Icons.format_indent_decrease_rounded),
          _OpDef('trimall', '去首尾空白', Icons.vertical_align_top_rounded),
        ];
      case _Mode.lines:
        return const [
          _OpDef('dedupe', '去重', Icons.filter_alt_off_rounded),
          _OpDef('sort', '排序↑', Icons.sort_rounded),
          _OpDef('sortdesc', '排序↓', Icons.sort_by_alpha_rounded),
          _OpDef('reverse', '倒序', Icons.swap_vert_rounded),
          _OpDef('number', '加行号', Icons.format_list_numbered_rounded),
        ];
    }
  }
}

class _OpDef {
  const _OpDef(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}
