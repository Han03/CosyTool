import 'package:flutter/foundation.dart';

import 'tool_session.dart';

/// 全局工具会话注册表：按工具 id 管理常驻 Session。
///
/// 页面首次打开工具时通过 [sessionOf] 获取（不存在则创建），
/// 之后任何视图都能拿到同一 Session 实例。
class SessionRegistry extends ChangeNotifier {
  SessionRegistry._();

  static final SessionRegistry instance = SessionRegistry._();

  final Map<String, ToolSession> _sessions = {};

  /// 获取或创建指定工具 id 的会话。
  T sessionOf<T extends ToolSession>(String toolId, T Function() create) {
    return _sessions.putIfAbsent(toolId, create) as T;
  }

  ToolSession? get(String toolId) => _sessions[toolId];

  /// 当前所有运行中的会话（状态条数据源）。
  List<ToolSession> get running =>
      _sessions.values.where((s) => s.isRunning).toList(growable: false);
}
