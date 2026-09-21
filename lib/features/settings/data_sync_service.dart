import 'dart:io';

import '../../core/data/app_data.dart';
import '../cloud_storage/cloud_storage_service.dart';

/// 拉取结果统计。
class SyncResult {
  const SyncResult({
    required this.files,
    required this.bytes,
    required this.dirs,
    required this.failures,
  });

  final int files;
  final int bytes;
  final int dirs;
  final int failures;

  bool get success => failures == 0;
}

/// 云端 → 本地数据同步。
///
/// 将 GitHub 仓库（CosyToolStorage）中的文件拉取到本地数据文件夹：
/// 仓库顶层目录名 = 工具 id，仓库 `text_reader/books/xx.txt`
/// 即写入本地 `CosyToolData/tools/text_reader/books/xx.txt`。
///
/// 策略：远程为准的增量更新 —— 下载并覆盖远程存在的文件；
/// 不删除本地已有文件（保护本地生成的缓存等产物）。
class DataSyncService {
  DataSyncService(this._storage);

  final CloudStorageService _storage;

  /// 拉取全部仓库文件到各工具数据文件夹。
  Future<SyncResult> pullAll() async {
    final tree = await _storage.fetchTree();
    final blobs = tree
        .where((t) => t.type == 'blob' && t.path.isNotEmpty)
        .toList();

    var files = 0;
    var bytes = 0;
    var failures = 0;
    final dirs = <String>{};

    for (final blob in blobs) {
      final localFile = await _localFileFor(blob.path);
      if (localFile == null) {
        failures += 1; // 顶层目录不是工具 id，跳过并计数
        continue;
      }
      try {
        final data = await _storage.fetchBlob(blob.sha);
        await localFile.create(recursive: true);
        await localFile.writeAsBytes(data, flush: true);
        files += 1;
        bytes += data.length;
        dirs.add(localFile.parent.path);
      } catch (_) {
        failures += 1;
      }
    }
    return SyncResult(files: files, bytes: bytes, dirs: dirs.length, failures: failures);
  }

  /// 仓库路径 → 本地工具数据文件。
  ///
  /// 顶层目录即工具 id（如 `text_reader/books/a.txt` → `tools/text_reader/books/a.txt`），
  /// 目录不存在时自动创建；对含 `..` 等穿越段或空段的路径返回 null 拒绝写入。
  Future<File?> _localFileFor(String repoPath) async {
    final parts = repoPath.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    if (parts.any((p) => p == '..' || p == '.')) return null;
    final toolDir = await AppData.toolDir(parts.first);
    final rel = parts.sublist(1).join(Platform.pathSeparator);
    return File('${toolDir.path}${Platform.pathSeparator}$rel');
  }
}
