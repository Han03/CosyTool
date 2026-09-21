import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import 'cloud_storage_service.dart';

/// 云端存储：基于 GitHub 仓库的文件读写。
///
/// 用于保存配置、备份数据或读取文件。输入 Token 后即可浏览仓库目录、
/// 读取 / 编辑文件、上传新文件。
class CloudStoragePage extends StatefulWidget {
  const CloudStoragePage({super.key});

  @override
  State<CloudStoragePage> createState() => _CloudStoragePageState();
}

class _CloudStoragePageState extends State<CloudStoragePage> {
  static final ToolInfo _tool = ToolRegistry.of('cloud_storage');
  static const String _kPrefToken = 'cloud_storage_token';
  static const String _kPrefOwner = 'cloud_storage_owner';
  static const String _kPrefRepo = 'cloud_storage_repo';

  final TextEditingController _tokenCtrl = TextEditingController();
  final TextEditingController _ownerCtrl = TextEditingController(text: 'Han03');
  final TextEditingController _repoCtrl =
      TextEditingController(text: 'CosyToolStorage');
  final TextEditingController _fileNameCtrl = TextEditingController();
  final TextEditingController _fileBodyCtrl = TextEditingController();

  CloudStorageService? _service;
  bool _connected = false;
  bool _busy = false;

  List<String> _crumbs = const []; // 当前目录面包屑（不含根）
  List<StorageEntry> _entries = const [];
  StorageEntry? _currentFile; // 正在查看/编辑的文件
  String? _currentFileSha;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
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

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefToken, _tokenCtrl.text.trim());
    await prefs.setString(_kPrefOwner, _ownerCtrl.text.trim());
    await prefs.setString(_kPrefRepo, _repoCtrl.text.trim());
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

  String get _currentPath => _crumbs.join('/');

  Future<void> _connect() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      _toast('请先输入 GitHub Token');
      return;
    }
    setState(() => _busy = true);
    await _savePrefs();
    final service = CloudStorageService(
      token: token,
      owner: _ownerCtrl.text.trim(),
      repo: _repoCtrl.text.trim(),
    );
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshDir() async {
    final service = _service;
    if (service == null) return;
    setState(() => _busy = true);
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
      if (mounted) setState(() => _busy = false);
    }
  }

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
    setState(() => _busy = true);
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
      if (mounted) setState(() => _busy = false);
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
    setState(() => _busy = true);
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
      if (mounted) setState(() => _busy = false);
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
    setState(() => _busy = true);
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
      if (mounted) setState(() => _busy = false);
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
    setState(() => _busy = true);
    try {
      await service.deleteFile(entry.path, sha: entry.sha);
      if (!mounted) return;
      _toast('已删除 ${entry.path}');
      await _refreshDir();
    } catch (e) {
      if (mounted) _toast('删除失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ToolPageScaffold(
      tool: _tool,
      actions: [
        if (_connected)
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshDir,
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
                  _buildConnectCard(theme, colorScheme),
                  if (_connected) ...[
                    const SizedBox(height: 16),
                    _buildBrowserCard(theme, colorScheme),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('连接设置',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenCtrl,
              obscureText: true,
              enabled: !_connected,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'GitHub Token',
                hintText: '粘贴 Personal Access Token（保存在本机）',
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
                    enabled: !_connected,
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
                    enabled: !_connected,
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
              onPressed: _busy ? null : (_connected ? _disconnect : _connect),
              icon: Icon(_connected
                  ? Icons.link_off_rounded
                  : Icons.cloud_sync_rounded),
              label: Text(_connected ? '断开连接' : '连接云端'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildBrowserCard(ThemeData theme, ColorScheme colorScheme) {
    final file = _currentFile;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: file != null ? _buildFileEditor(theme) : _buildDirBrowser(theme),
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
            if (_busy)
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
                _busy ? '加载中…' : '仓库为空，可在下方新建文件',
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
                  labelText: '文件名（如 config.json）',
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
          onPressed: _busy ? null : _createFile,
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
                  onPressed: _busy ? null : () => _deleteFile(e),
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
              onPressed: _busy ? null : _backToList,
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
            if (_busy)
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
          onPressed: _busy ? null : _saveCurrentFile,
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: const Text('保存到云端'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
