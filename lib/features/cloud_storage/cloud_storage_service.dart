import 'dart:convert';

import 'package:http/http.dart' as http;

/// GitHub Contents API 存储条目。
class StorageEntry {
  const StorageEntry({
    required this.name,
    required this.path,
    required this.isDir,
    required this.size,
    required this.sha,
  });

  final String name;
  final String path;
  final bool isDir;
  final int size;
  final String? sha;
}

/// Git Trees API 条目（拉取数据用）。
class GitTreeItem {
  const GitTreeItem({
    required this.path,
    required this.type,
    required this.sha,
    required this.size,
  });

  final String path;
  final String type; // 'blob' | 'tree'
  final String sha;
  final int size;
}

/// 云端存储服务：基于 GitHub Contents API 的文件读写。
///
/// 端点：
/// - 列出目录 / 读文件：GET  /repos/{owner}/{repo}/contents/{path}
/// - 写入 / 更新文件：PUT  /repos/{owner}/{repo}/contents/{path}
/// - 删除文件：       DELETE /repos/{owner}/{repo}/contents/{path}
///
/// 文件内容以 base64 传输；更新已存在文件必须携带其 sha。
class CloudStorageService {
  CloudStorageService({
    required this.token,
    this.owner = 'Han03',
    this.repo = 'CosyToolStorage',
  });

  final String token;
  String owner;
  String repo;

  static const String _apiBase = 'https://api.github.com';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  String _apiUrl(String path) {
    final p = path.replaceAll(RegExp(r'^/+|/+$'), '');
    final suffix = p.isEmpty ? '' : '/${Uri.encodeComponent(p)}';
    return '$_apiBase/repos/$owner/$repo/contents$suffix';
  }

  /// 校验凭据是否可用（GET 仓库信息）。
  Future<void> validate() async {
    final resp = await http.get(
      Uri.parse('$_apiBase/repos/$owner/$repo'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) return;
    throw CloudStorageException(_statusMessage(resp.statusCode));
  }

  /// 列出目录内容；path 为空表示仓库根目录。
  Future<List<StorageEntry>> listDir(String path) async {
    final resp = await http
        .get(Uri.parse(_apiUrl(path)), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 404 && path.isEmpty) {
      // 空仓库无根内容
      return const [];
    }
    if (resp.statusCode != 200) {
      throw CloudStorageException(_statusMessage(resp.statusCode));
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    if (data is! List) {
      // 路径指向单个文件时返回对象，这里按目录调用处理
      throw CloudStorageException('该路径不是目录');
    }
    return data.map((e) {
      final map = e as Map<String, dynamic>;
      return StorageEntry(
        name: map['name'] as String? ?? '',
        path: map['path'] as String? ?? '',
        isDir: map['type'] == 'dir',
        size: (map['size'] as num?)?.toInt() ?? 0,
        sha: map['sha'] as String?,
      );
    }).toList();
  }

  /// 读取文件内容（UTF-8）。
  Future<String> readFile(String path) async {
    final resp = await http
        .get(Uri.parse(_apiUrl(path)), headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw CloudStorageException(_statusMessage(resp.statusCode));
    }
    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final content = map['content'] as String? ?? '';
    if (content.isEmpty) return '';
    final normalized = content.replaceAll(RegExp(r'\s'), '');
    return utf8.decode(base64Decode(normalized));
  }

  /// 写入 / 更新文件。
  /// [path] 为仓库内路径（如 "config/app.json"）；自动创建父目录对应的文件。
  Future<void> writeFile(String path, String content,
      {String? sha, String message = 'CosyTool 云端存储更新'}) async {
    final body = <String, dynamic>{
      'message': message,
      'content': base64Encode(utf8.encode(content)),
      'branch': 'main',
      'sha': ?sha,
    };
    final resp = await http
        .put(
          Uri.parse(_apiUrl(path)),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw CloudStorageException(_statusMessage(resp.statusCode));
    }
  }

  /// 删除文件。
  Future<void> deleteFile(String path, {String? sha}) async {
    final body = <String, dynamic>{
      'message': 'CosyTool 云端存储删除',
      'branch': 'main',
      'sha': ?sha,
    };
    final resp = await http
        .delete(
          Uri.parse(_apiUrl(path)),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw CloudStorageException(_statusMessage(resp.statusCode));
    }
  }

  /// 获取仓库完整文件树（recursive）。
  Future<List<GitTreeItem>> fetchTree({String branch = 'main'}) async {
    final resp = await http.get(
      Uri.parse('$_apiBase/repos/$owner/$repo/git/trees/$branch?recursive=1'),
      headers: _headers,
    ).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw CloudStorageException(_statusMessage(resp.statusCode));
    }
    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final items = map['tree'] as List<dynamic>? ?? const [];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return GitTreeItem(
        path: m['path'] as String? ?? '',
        type: m['type'] as String? ?? 'blob',
        sha: m['sha'] as String? ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  /// 按 blob sha 获取文件二进制内容。
  Future<List<int>> fetchBlob(String sha) async {
    final resp = await http
        .get(Uri.parse('$_apiBase/repos/$owner/$repo/git/blobs/$sha'),
            headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw CloudStorageException(_statusMessage(resp.statusCode));
    }
    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final encoding = map['encoding'] as String? ?? 'base64';
    if (encoding != 'base64') {
      throw CloudStorageException('不支持的编码：$encoding');
    }
    final content = (map['content'] as String? ?? '').replaceAll(RegExp(r'\s'), '');
    return base64Decode(content);
  }

  String _statusMessage(int code) {
    switch (code) {
      case 401:
        return 'Token 无效或已过期（401）';
      case 403:
        return '无权限访问该仓库（403），请检查 Token 权限';
      case 404:
        return '路径或仓库不存在（404）';
      case 409:
        return '文件冲突（409），可能刚被修改，请刷新后重试';
      default:
        return '请求失败（HTTP $code）';
    }
  }
}

class CloudStorageException implements Exception {
  CloudStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
