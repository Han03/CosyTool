import 'package:flutter/material.dart';

/// 工具元信息。
///
/// 一个工具 = 一个可独立渲染的页面（[builder]）+ 一组展示元数据。
/// 注册在 [ToolRegistry] 中，由首页网格 / 抽屉 / 桌面导航栏统一消费，
/// 新增工具只需在此处增加一个条目。
class ToolInfo {
  const ToolInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accent,
    required this.builder,
    this.mobileOnly = false,
    this.tags = const [],
  });

  /// 唯一标识。
  final String id;

  /// 展示名称。
  final String name;

  /// 一句话描述。
  final String description;

  /// 图标。
  final IconData icon;

  /// 品牌强调色（用于卡片渐变与主题点缀）。
  final Color accent;

  /// 工具页面构造器。
  final WidgetBuilder builder;

  /// 是否仅移动端可用（如相机、手电筒）。
  final bool mobileOnly;

  /// 标签，用于后续搜索 / 分类。
  final List<String> tags;
}
