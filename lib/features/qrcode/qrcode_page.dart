import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 二维码工具：文本内容生成可保存的二维码图片。
class QrCodePage extends StatefulWidget {
  const QrCodePage({super.key});

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  static final ToolInfo _tool = ToolRegistry.of('qrcode');

  final TextEditingController _input = TextEditingController(
    text: 'https://github.com/Han03/CosyTool',
  );
  final GlobalKey _repaintKey = GlobalKey();
  bool _saving = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String get _data => _input.text.trim();

  Future<void> _save() async {
    if (_data.isEmpty) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('二维码尚未渲染');
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('图片编码失败');
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}cosytool_qr_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存到：${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _input,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: '内容',
                      hintText: '输入文本或网址…',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: QrImageView(
                          data: _data.isEmpty ? ' ' : _data,
                          version: QrVersions.auto,
                          size: 240,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _data.isEmpty ? '请输入内容' : '共 ${_data.length} 个字符',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _data.isEmpty || _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt_rounded),
                    label: Text(_saving ? '保存中…' : '保存为图片'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
