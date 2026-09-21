import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/app_data.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import '../cloud_storage/cloud_storage_service.dart';
import 'data_sync_service.dart';

/// 设置：云端存储（上传 / 下载 / 拉取）与数据目录管理。
///
/// - 统一 GitHub 连接配置（Token / 所有者 / 仓库），token 默认已填入
/// - 「连接云端」：浏览 / 读取 / 编辑 / 上传 / 删除仓库文件
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

  // 默认仓库配置（token 不写死在代码中，从本机机密文件读取后自动填入）
  static const String _defaultOwner = 'Han03';
  static const String _defaultRepo = 'CosyToolStorage';

  final TextEditingController _tokenCtrl = TextEditingController();
  final TextEditingController _ownerCtrl =
      TextEditingController(text: _defaultOwner);
  final TextEditingController _repoCtrl =
      TextEditingController(text: _defaultRepo);
  final TextEditingController _fileNameCtrl = TextEditingController();
  final TextEditingController _fileBodyCtrl = TextEditingController();

  // 拉取状态
  bool _pullBusy = false;
  SyncResult? _lastResult;

  // 云端文件状态
  CloudStorageService? _service;
  bool _connected = false;
  bool _fileBusy = false;
  List<String> _crumbs = const []; // 当前目录面包屑（不含根）
  List<StorageEntry> _entries = const [];
  StorageEntry? _currentFile; // 正在查看/编辑的文件
  String? _currentFileSha;

  // 本地数据目录
  String _rootPath = '';
  List<String> _toolDirs = const [];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _refreshLocal();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(_kPrefToken) ?? '';
    if (token.isEmpty) token = await AppData.readSecretsToken();
    if (!mounted) return;
    setState(() {
      _tokenCtrl.text = token;
      _ownerCtrl.text = prefs.getString(_kPrefOwner) ?? _defaultOwner;
      _repoCtrl.text = prefs.getString(_kPrefRepo) ?? _defaultRepo;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefToken, _tokenCtrl.text.trim());
    await prefs.setString(_kPrefOwner, _ownerCtrl.text.trim());
    await prefs.setString(_kPrefRepo, _repoCtrl.text.trim());
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
    _fileNameCtrl.dispose();
    _fileBodyCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  CloudStorageService _newService() {
    return CloudStorageService(
      token: _tokenCtrl.text.trim(),
      owner: _ownerCtrl.text.trim(),
      repo: _repoCtrl.text.trim(),
    );
  }

  // ---------------- 拉取数据 ----------------

  Future<void> _pullData() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      _toast('请先输入 GitHub Token');
      return;
    }
    await _savePrefs();
    setState(() => _pullBusy = true);
    try {
      final result = await DataSyncService(_newService()).pullAll();
      if (!mounted) return;
      setState(() => _lastResult = result);
      _toast(result.success
          ? '拉取完成：${result.files} 个文件，${_formatSize(result.bytes)}'
          : '拉取完成但 ${result.failures} 个文件失败');
      await _refreshLocal();
    } catch (e) {
      if (mounted) _toast('拉取失败：$e');
    } finally {
      if (mounted) setState(() => _pullBusy = false);
    }
  }

  // ---------------- 云端文件（浏览 / 编辑 / 上传 / 删除） ----------------

  Future<void> _connect() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      _toast('请先输入 GitHub Token');
      return;
    }
    setState(() => _fileBusy = true);
    await _savePrefs();
    final service = _newService();
    try {
      await service.validate();
      if (!mounted) return;
      setState(() {
        _service = service;
        _connected = true;
        _crumbs = const [];
        _currentFile = null;
      });
      await _refreshDir();
      _toast('连接成功');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _service = null;
        _connected = false;
      });
      _toast('连接失败：$e');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  void _disconnect() {
    setState(() {
      _connected = false;
      _service = null;
      _crumbs = const [];
      _entries = const [];
      _currentFile = null;
      _fileBodyCtrl.clear();
      _fileNameCtrl.clear();
    });
  }

  Future<void> _refreshDir() async {
    final service = _service;
    if (service == null) return;
    setState(() => _fileBusy = true);
    try {
      final entries = await service.listDir(_currentPath);
      if (!mounted) return;
      entries.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      setState(() => _entries = entries);
    } catch (e) {
      if (mounted) _toast('加载目录失败：$e');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  String get _currentPath => _crumbs.join('/');

  void _enterDir(StorageEntry entry) {
    setState(() {
      _crumbs = [..._crumbs, entry.name];
      _currentFile = null;
    });
    _refreshDir();
  }

  void _goCrumb(int index) {
    setState(() {
      _crumbs = _crumbs.sublist(0, index + 1);
      _currentFile = null;
    });
    _refreshDir();
  }

  Future<void> _openFile(StorageEntry entry) async {
    final service = _service;
    if (service == null) return;
    setState(() => _fileBusy = true);
    try {
      final content = await service.readFile(entry.path);
      if (!mounted) return;
      setState(() {
        _currentFile = entry;
        _currentFileSha = entry.sha;
        _fileBodyCtrl.text = content;
        _fileNameCtrl.text = entry.name;
      });
    } catch (e) {
      if (mounted) _toast('读取文件失败：$e');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  void _backToList() {
    setState(() {
      _currentFile = null;
      _fileBodyCtrl.clear();
      _fileNameCtrl.clear();
    });
  }

  Future<void> _saveCurrentFile() async {
    final service = _service;
    final file = _currentFile;
    if (service == null || file == null) return;
    setState(() => _fileBusy = true);
    try {
      await service.writeFile(
        file.path,
        _fileBodyCtrl.text,
        sha: _currentFileSha,
      );
      if (!mounted) return;
      _toast('已保存 ${file.path}');
      _backToList();
      await _refreshDir();
    } catch (e) {
      if (mounted) _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _createFile() async {
    final service = _service;
    if (service == null) return;
    final name = _fileNameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('请输入文件名');
      return;
    }
    final path = _currentPath.isEmpty ? name : '$_currentPath/$name';
    setState(() => _fileBusy = true);
    try {
      await service.writeFile(path, _fileBodyCtrl.text);
      if (!mounted) return;
      _toast('已上传 $path');
      _fileNameCtrl.clear();
      _fileBodyCtrl.clear();
      await _refreshDir();
    } catch (e) {
      if (mounted) _toast('上传失败：$e');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _deleteFile(StorageEntry entry) async {
    final service = _service;
    if (service == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定删除 ${entry.path} 吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _fileBusy = true);
    try {
      await service.deleteFile(entry.path, sha: entry.sha);
      if (!mounted) return;
      _toast('已删除 ${entry.path}');
      await _refreshDir();
    } catch (e) {
      if (mounted) _toast('删除失败：$e');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  // ---------------- UI ----------------

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
                  _buildConfigCard(theme, colorScheme),
                  const SizedBox(height: 16),
                  _buildCloudCard(theme, colorScheme),
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

  Widget _buildConfigCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('GitHub 连接配置',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '上传、下载、拉取共用同一仓库连接。修改仓库文件后点击「拉取数据」，'
              '即可更新各工具的数据文件夹（仓库顶层目录名 = 工具 id）。',
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
              onPressed: _pullBusy ? null : _pullData,
              icon: _pullBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_rounded, size: 18),
              label: Text(_pullBusy ? '拉取中…' : '拉取数据（GitHub Pull）'),
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

  Widget _buildCloudCard(ThemeData theme, ColorScheme colorScheme) {
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
                Text('云端文件',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (_connected)
                  OutlinedButton.icon(
                    onPressed: _fileBusy ? null : _disconnect,
                    icon: const Icon(Icons.link_off_rounded, size: 16),
                    label: const Text('断开'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: _fileBusy ? null : _connect,
                    icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                    label: const Text('连接云端'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _connected
                  ? '已连接 $_defaultOwner/$_defaultRepo，可浏览 / 编辑 / 上传 / 删除仓库文件'
                  : '连接后可浏览、编辑、上传、删除仓库中的文件（如向 text_reader/books/ 上传小说）。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            if (_connected) ...[
              const SizedBox(height: 12),
              if (_currentFile != null)
                _buildFileEditor(theme)
              else
                _buildDirBrowser(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDirBrowser(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('文件浏览',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_fileBusy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildBreadcrumb(theme),
        const SizedBox(height: 8),
        if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                _fileBusy ? '加载中…' : '仓库为空，可在下方新建文件',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ..._entries.map((e) => _buildEntryTile(theme, e)),
        const Divider(height: 24),
        Text('新建文件',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_currentPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '$_currentPath/',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            Expanded(
              child: TextField(
                controller: _fileNameCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: '文件名（如 text_reader/books/x.txt）',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _fileBodyCtrl,
          minLines: 3,
          maxLines: 8,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            height: 1.4,
          ),
          decoration: const InputDecoration(
            labelText: '文件内容',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _fileBusy ? null : _createFile,
          icon: const Icon(Icons.upload_rounded, size: 18),
          label: const Text('上传到云端'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb(ThemeData theme) {
    final parts = <Widget>[
      _crumbChip(theme, 'root', 0, isRoot: true),
    ];
    for (var i = 0; i < _crumbs.length; i++) {
      parts.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('/'),
      ));
      parts.add(_crumbChip(theme, _crumbs[i], i));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts,
    );
  }

  Widget _crumbChip(ThemeData theme, String label, int index,
      {bool isRoot = false}) {
    return ActionChip(
      label: Text(isRoot ? '仓库根目录' : label,
          style: theme.textTheme.labelSmall),
      visualDensity: VisualDensity.compact,
      onPressed: () => _goCrumb(index),
    );
  }

  Widget _buildEntryTile(ThemeData theme, StorageEntry e) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        e.isDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
        color: e.isDir
            ? const Color(0xFFF5B642)
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(e.name,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: e.isDir
          ? const Icon(Icons.chevron_right_rounded, size: 18)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatSize(e.size),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                IconButton(
                  tooltip: '删除',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: _fileBusy ? null : () => _deleteFile(e),
                ),
              ],
            ),
      onTap: e.isDir ? () => _enterDir(e) : () => _openFile(e),
    );
  }

  Widget _buildFileEditor(ThemeData theme) {
    final file = _currentFile!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '返回列表',
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: _fileBusy ? null : _backToList,
            ),
            Expanded(
              child: Text(
                file.path,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_fileBusy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _fileBodyCtrl,
          minLines: 10,
          maxLines: 24,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            height: 1.4,
          ),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _fileBusy ? null : _saveCurrentFile,
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: const Text('保存到云端'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
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
