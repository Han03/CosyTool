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

  /// 会话是否支持暂停 / 继续（小窗显示播放/暂停按钮依据）。
  bool get canPause => false;

  /// 暂停 / 继续切换（小窗共用）。
  void togglePause() {}

  /// 桌面端小窗化标记：true 时该会话从状态条移入悬浮小窗。
  bool pinned = false;

  /// 小窗化 / 恢复主区（触发状态条与小窗层刷新）。
  void setPinned(bool value) {
    if (pinned == value) return;
    pinned = value;
    notifyRunning();
  }

  /// 运行状态变化时通知状态条刷新。
  @protected
  void notifyRunning() => SessionRegistry.instance.notifyListeners();
}
