import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 二维码工具：文本 / 网址 / WiFi / 邮箱生成可保存的二维码，支持颜色、尺寸与纠错等级定制。
class QrCodePage extends StatefulWidget {
  const QrCodePage({super.key});

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

enum _Template { text, url, wifi, email }

class _QrCodePageState extends State<QrCodePage> {
  static final ToolInfo _tool = ToolRegistry.of('qrcode');

  final GlobalKey _repaintKey = GlobalKey();
  bool _saving = false;

  _Template _template = _Template.url;

  // 各模板的输入控制器
  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController(
    text: 'https://github.com/Han03/CosyTool',
  );
  final TextEditingController _wifiSsid = TextEditingController();
  final TextEditingController _wifiPass = TextEditingController();
  String _wifiSecurity = 'WPA';
  final TextEditingController _emailAddr = TextEditingController();
  final TextEditingController _emailSubject = TextEditingController();

  // 样式
  Color _foreground = const Color(0xFF1B1F24);
  Color _background = Colors.white;
  double _size = 240;
  int _ecc = QrErrorCorrectLevel.M;

  static const List<Color> _fgOptions = [
    Color(0xFF1B1F24),
    Color(0xFF0E9F8F),
    Color(0xFF3D7BF6),
    Color(0xFFE85D5D),
    Color(0xFFB66AE8),
  ];
  static const List<Color> _bgOptions = [
    Colors.white,
    Color(0xFFFFF8E1),
    Color(0xFFE8F5F0),
    Color(0xFFF0F4FF),
    Color(0xFFFFF0F2),
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    _urlCtrl.dispose();
    _wifiSsid.dispose();
    _wifiPass.dispose();
    _emailAddr.dispose();
    _emailSubject.dispose();
    super.dispose();
  }

  String get _data {
    switch (_template) {
      case _Template.text:
        return _textCtrl.text.trim();
      case _Template.url:
        final u = _urlCtrl.text.trim();
        if (u.isEmpty) return '';
        return u.startsWith(RegExp(r'^https?://', caseSensitive: false)) ? u : 'https://$u';
      case _Template.wifi:
        final ssid = _wifiSsid.text.trim();
        if (ssid.isEmpty) return '';
        final pass = _wifiPass.text.trim();
        String esc(String s) => s
            .replaceAll('\\', '\\\\')
            .replaceAll(';', '\\;')
            .replaceAll(':', '\\:')
            .replaceAll(',', '\\,');
        if (_wifiSecurity == '无') return 'WIFI:T:nopass;S:${esc(ssid)};;';
        return 'WIFI:T:$_wifiSecurity;S:${esc(ssid)};P:${esc(pass)};;';
      case _Template.email:
        final addr = _emailAddr.text.trim();
        if (addr.isEmpty) return '';
        final subject = _emailSubject.text.trim();
        return subject.isEmpty ? 'mailto:$addr' : 'mailto:$addr?subject=${Uri.encodeComponent(subject)}';
    }
  }

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

  Future<void> _copyContent() async {
    if (_data.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _data));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('二维码内容已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ToolPageScaffold(
      tool: _tool,
      actions: [
        if (_data.isNotEmpty)
          IconButton(
            tooltip: '复制内容',
            icon: const Icon(Icons.copy_rounded),
            onPressed: _copyContent,
          ),
      ],
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 模板选择
                  SegmentedButton<_Template>(
                    segments: const [
                      ButtonSegment(value: _Template.text, label: Text('文本'), icon: Icon(Icons.notes_rounded, size: 18)),
                      ButtonSegment(value: _Template.url, label: Text('网址'), icon: Icon(Icons.link_rounded, size: 18)),
                      ButtonSegment(value: _Template.wifi, label: Text('WiFi'), icon: Icon(Icons.wifi_rounded, size: 18)),
                      ButtonSegment(value: _Template.email, label: Text('邮箱'), icon: Icon(Icons.mail_rounded, size: 18)),
                    ],
                    selected: {_template},
                    onSelectionChanged: (s) => setState(() => _template = s.first),
                  ),
                  const SizedBox(height: 16),
                  ..._buildInputs(theme),
                  const SizedBox(height: 24),
                  // 二维码
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: QrImageView(
                          data: _data.isEmpty ? ' ' : _data,
                          version: QrVersions.auto,
                          size: _size,
                          backgroundColor: _background,
                          errorCorrectionLevel: _ecc,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: _foreground,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: _foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _data.isEmpty ? '请输入内容' : '共 ${_data.length} 个字符 · 纠错 $_eccLabel',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 样式设置
                  _StyleRow(
                    label: '前景色',
                    colors: _fgOptions,
                    selected: _foreground,
                    onSelect: (c) => setState(() => _foreground = c),
                  ),
                  const SizedBox(height: 8),
                  _StyleRow(
                    label: '背景色',
                    colors: _bgOptions,
                    selected: _background,
                    onSelect: (c) => setState(() => _background = c),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final sizeSeg = SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: 180, label: Text('小')),
                          ButtonSegment(value: 240, label: Text('中')),
                          ButtonSegment(value: 320, label: Text('大')),
                        ],
                        selected: {_size},
                        onSelectionChanged: (s) => setState(() => _size = s.first),
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      );
                      final eccSeg = SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: QrErrorCorrectLevel.L, label: Text('L')),
                          ButtonSegment(value: QrErrorCorrectLevel.M, label: Text('M')),
                          ButtonSegment(value: QrErrorCorrectLevel.Q, label: Text('Q')),
                          ButtonSegment(value: QrErrorCorrectLevel.H, label: Text('H')),
                        ],
                        selected: {_ecc},
                        onSelectionChanged: (s) => setState(() => _ecc = s.first),
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      );
                      final sizeGroup = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('尺寸', style: theme.textTheme.bodyMedium),
                          const SizedBox(width: 12),
                          sizeSeg,
                        ],
                      );
                      final eccGroup = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('纠错', style: theme.textTheme.bodyMedium),
                          const SizedBox(width: 12),
                          eccSeg,
                        ],
                      );
                      if (constraints.maxWidth < 520) {
                        return Wrap(
                          spacing: 16,
                          runSpacing: 10,
                          children: [sizeGroup, eccGroup],
                        );
                      }
                      return Row(children: [sizeGroup, const Spacer(), eccGroup]);
                    },
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

  String get _eccLabel {
    if (_ecc == QrErrorCorrectLevel.L) return 'L';
    if (_ecc == QrErrorCorrectLevel.Q) return 'Q';
    if (_ecc == QrErrorCorrectLevel.H) return 'H';
    return 'M';
  }

  List<Widget> _buildInputs(ThemeData theme) {
    switch (_template) {
      case _Template.text:
        return [
          TextField(
            controller: _textCtrl,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: '文本内容',
              hintText: '输入任意文本…',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ];
      case _Template.url:
        return [
          TextField(
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '网址',
              hintText: 'https://example.com',
              prefixIcon: Icon(Icons.link_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ];
      case _Template.wifi:
        return [
          TextField(
            controller: _wifiSsid,
            decoration: const InputDecoration(
              labelText: 'WiFi 名称（SSID）',
              prefixIcon: Icon(Icons.wifi_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _wifiPass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _wifiSecurity,
                  decoration: const InputDecoration(labelText: '加密'),
                  items: const [
                    DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2')),
                    DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                    DropdownMenuItem(value: '无', child: Text('无密码')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _wifiSecurity = v);
                  },
                ),
              ),
            ],
          ),
        ];
      case _Template.email:
        return [
          TextField(
            controller: _emailAddr,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '邮箱地址',
              prefixIcon: Icon(Icons.mail_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailSubject,
            decoration: const InputDecoration(labelText: '主题（可选）'),
            onChanged: (_) => setState(() {}),
          ),
        ];
    }
  }
}

class _StyleRow extends StatelessWidget {
  const _StyleRow({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final c in colors)
                InkWell(
                  onTap: () => onSelect(c),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c.computeLuminance() > 0.7 ? Colors.black26 : Colors.white70,
                        width: 2,
                      ),
                    ),
                    child: c == selected
                        ? const Icon(Icons.check_rounded, size: 18, color: Colors.black87)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
