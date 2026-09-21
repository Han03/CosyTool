import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/app_data.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import '../cloud_storage/cloud_storage_service.dart';
import 'data_sync_service.dart';

/// 设置：云端数据同步与数据目录管理。
///
/// - 配置 GitHub Token（复用云端存储的连接配置）
/// - 「拉取数据」：从 GitHub 仓库拉取文件，更新各工具的数据文件夹
/// - 查看 / 打开本地数据目录
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static final ToolInfo _tool = ToolRegistry.of('settings');
  static const String _kPrefToken = 'cloud_storage_token';
  static const String _kPrefOwner = 'cloud_storage_owner';
  static const String _kPrefRepo = 'cloud_storage_repo';

  final TextEditingController _tokenCtrl = TextEditingController();
  final TextEditingController _ownerCtrl = TextEditingController(text: 'Han03');
  final TextEditingController _repoCtrl =
      TextEditingController(text: 'CosyToolStorage');

  bool _busy = false;
  String _rootPath = '';
  List<String> _toolDirs = const [];
  SyncResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _refreshLocal();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _tokenCtrl.text = prefs.getString(_kPrefToken) ?? '';
      _ownerCtrl.text = prefs.getString(_kPrefOwner) ?? 'Han03';
      _repoCtrl.text = prefs.getString(_kPrefRepo) ?? 'CosyToolStorage';
    });
  }

  Future<void> _refreshLocal() async {
    final root = await AppData.root();
    final dirs = await AppData.existingToolDirs();
    if (!mounted) return;
    setState(() {
      _rootPath = root.path;
      _toolDirs = dirs;
    });
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _ownerCtrl.dispose();
    _repoCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pullData() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      _toast('请先输入 GitHub Token（云端存储页已保存过可自动读取）');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefToken, token);
    await prefs.setString(_kPrefOwner, _ownerCtrl.text.trim());
    await prefs.setString(_kPrefRepo, _repoCtrl.text.trim());

    setState(() => _busy = true);
    try {
      final storage = CloudStorageService(
        token: token,
        owner: _ownerCtrl.text.trim(),
        repo: _repoCtrl.text.trim(),
      );
      final result = await DataSyncService(storage).pullAll();
      if (!mounted) return;
      setState(() => _lastResult = result);
      _toast(result.success
          ? '拉取完成：${result.files} 个文件，${_formatSize(result.bytes)}'
          : '拉取完成但 ${result.failures} 个文件失败');
      await _refreshLocal();
    } catch (e) {
      if (mounted) _toast('拉取失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
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
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSyncCard(theme, colorScheme),
                  const SizedBox(height: 16),
                  _buildDataCard(theme, colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('云端数据同步',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '修改 GitHub 仓库（CosyToolStorage）中的文件后，点击拉取即可更新对应工具的数据文件夹。'
              '仓库顶层目录名 = 工具 id，例如 text_reader/books/xxx.txt 会同步到本地 text_reader 数据目录。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenCtrl,
              obscureText: true,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'GitHub Token',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ownerCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: '仓库所有者',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _repoCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: '仓库名',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _pullData,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_rounded, size: 18),
              label: Text(_busy ? '拉取中…' : '拉取数据（GitHub Pull）'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 12),
              _buildResultCard(theme, colorScheme, _lastResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
      ThemeData theme, ColorScheme colorScheme, SyncResult r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (r.success ? colorScheme.primary : colorScheme.error)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            r.success ? Icons.check_circle_rounded : Icons.warning_rounded,
            size: 18,
            color: r.success ? colorScheme.primary : colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '最近拉取：${r.files} 个文件 · ${_formatSize(r.bytes)} · '
              '${r.dirs} 个目录'
              '${r.failures > 0 ? ' · ${r.failures} 个失败' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(ThemeData theme, ColorScheme colorScheme) {
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
                Text('数据文件夹',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed:
                      _rootPath.isEmpty ? null : () => AppData.reveal(_rootPath),
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('打开文件夹'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _rootPath.isEmpty ? '正在定位…' : _rootPath,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            if (_toolDirs.isEmpty)
              Text(
                '暂无工具数据目录。使用工具或拉取数据后自动创建。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in _toolDirs)
                    ActionChip(
                      avatar: const Icon(Icons.folder_rounded, size: 16),
                      label: Text(id),
                      onPressed: () => AppData.reveal(
                          '$_rootPath${Platform.pathSeparator}tools'
                          '${Platform.pathSeparator}$id'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
