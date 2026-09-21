import 'package:flutter/foundation.dart';

import 'session_registry.dart';

/// 工具会话：引擎常驻的抽象基类。
///
/// 持续型工具（录音 / 计时等）首次打开时创建 Session，持有引擎与状态；
/// 页面只是 Session 的视图。页面销毁不销毁 Session，切走不断、回来恢复。
abstract class ToolSession extends ChangeNotifier {
  ToolSession(this.toolId);

  final String toolId;

  /// 会话是否处于"运行中"（状态条显示依据）。
  bool get isRunning => false;

  /// 状态条摘要文本（如 '02:13'）。
  String get statusText => '';

  /// 状态条标签（如 '秒表'）。
  String get statusLabel => toolId;

  /// 状态条"停止"动作：停止引擎（不重置数据）。
  void stop() {}

  /// 运行状态变化时通知状态条刷新。
  @protected
  void notifyRunning() => SessionRegistry.instance.notifyListeners();
}
