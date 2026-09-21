import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 应用数据目录管理。
///
/// 目录结构：
/// ```
/// <Documents>/CosyToolData/
///   tools/
///     <toolId>/            # 每个工具独立的数据文件夹
///       ...                # 工具自有文件（小说、缓存、进度等）
/// ```
/// 云端仓库（CosyToolStorage）与 `tools/` 下的结构一一对应：
/// 修改仓库文件后拉取，即可更新对应工具的数据文件夹。
class AppData {
  AppData._();

  static const String rootDirName = 'CosyToolData';

  static Directory? _root;

  /// 数据根目录（Documents/CosyToolData），首次调用时创建。
  static Future<Directory> root() async {
    final cached = _root;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$rootDirName');
    await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  /// 工具数据根（.../CosyToolData/tools）。
  static Future<Directory> toolsRoot() async {
    final rootDir = await root();
    final dir = Directory('${rootDir.path}${Platform.pathSeparator}tools');
    await dir.create(recursive: true);
    return dir;
  }

  /// 指定工具的数据文件夹，不存在则创建。
  static Future<Directory> toolDir(String toolId) async {
    final tools = await toolsRoot();
    final dir = Directory('${tools.path}${Platform.pathSeparator}$toolId');
    await dir.create(recursive: true);
    return dir;
  }

  /// 工具数据文件夹内的子目录。
  static Future<Directory> toolSubDir(String toolId, String sub) async {
    final tool = await toolDir(toolId);
    final dir = Directory('${tool.path}${Platform.pathSeparator}$sub');
    await dir.create(recursive: true);
    return dir;
  }

  /// 已存在的工具数据文件夹（按名称，不含 tools 根自身）。
  static Future<List<String>> existingToolDirs() async {
    final tools = await toolsRoot();
    final list = <String>[];
    await for (final entity in tools.list()) {
      if (entity is Directory) list.add(entity.uri.pathSegments.last);
    }
    return list..sort();
  }

  /// 工具数据目录的路径字符串。
  static Future<String> toolPath(String toolId) async =>
      (await toolDir(toolId)).path;

  /// 本机机密文件（不入仓库）：CosyToolData/secrets/token.txt。
  /// 用于存放 GitHub Token 等本机私有凭据，设置页默认自动读取填入。
  static Future<File> secretsTokenFile() async {
    final rootDir = await root();
    final dir =
        Directory('${rootDir.path}${Platform.pathSeparator}secrets');
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}token.txt');
  }

  /// 读取本机已保存的 GitHub Token；不存在则返回空字符串。
  static Future<String> readSecretsToken() async {
    try {
      final file = await secretsTokenFile();
      if (await file.exists()) return (await file.readAsString()).trim();
    } catch (_) {
      // 读取失败按未配置处理
    }
    return '';
  }

  /// 在系统文件管理器中打开目录（桌面端；移动端忽略）。
  static Future<void> reveal(String path) async {
    try {
      if (kIsWeb) return;
      if (Platform.isWindows) {
        await Process.start('explorer', [path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [path]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [path]);
      }
    } catch (_) {
      // 打开失败静默忽略（如移动端无文件管理器）
    }
  }
}
