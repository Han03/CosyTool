import 'package:flutter/material.dart';

import '../features/about/about_page.dart';
import '../features/camera_timer/camera_timer_page.dart';
import '../features/converter/converter_page.dart';
import '../features/countdown/countdown_page.dart';
import '../features/decibel/decibel_page.dart';
import '../features/dice/dice_page.dart';
import '../features/ear_monitor/ear_monitor_page.dart';
import '../features/flashlight/flashlight_page.dart';
import '../features/pomodoro/pomodoro_page.dart';
import '../features/qrcode/qrcode_page.dart';
import '../features/random_tool/random_number_page.dart';
import '../features/recorder/recorder_page.dart';
import '../features/stopwatch/stopwatch_page.dart';
import '../features/text_tools/text_tools_page.dart';
import '../features/word_count/word_count_page.dart';
import '../models/tool_info.dart';

/// 工具注册表。
///
/// 所有工具的集中登记处，是首页 / 导航的唯一数据来源。
/// 新增工具：在 `features/` 下新建页面，并在此追加一条 [ToolInfo]。
class ToolRegistry {
  ToolRegistry._();

  static final List<ToolInfo> tools = <ToolInfo>[
    ToolInfo(
      id: 'recorder',
      name: '录音机',
      description: '高清录音，随时回放',
      icon: Icons.mic_rounded,
      accent: const Color(0xFFE85D75),
      builder: (_) => const RecorderPage(),
      tags: const ['audio', 'record'],
    ),
    ToolInfo(
      id: 'decibel',
      name: '分贝测试',
      description: '实时测量环境音量',
      icon: Icons.graphic_eq_rounded,
      accent: const Color(0xFF2F9E6E),
      builder: (_) => const DecibelPage(),
      tags: const ['audio', 'meter'],
    ),
    ToolInfo(
      id: 'camera_timer',
      name: '延迟拍照',
      description: '倒计时后自动拍摄',
      icon: Icons.camera_alt_rounded,
      accent: const Color(0xFF3D7BF6),
      builder: (_) => const CameraTimerPage(),
      mobileOnly: true,
      tags: const ['camera', 'timer'],
    ),
    ToolInfo(
      id: 'stopwatch',
      name: '秒表',
      description: '计时与分段记录',
      icon: Icons.timer_rounded,
      accent: const Color(0xFFB66AE8),
      builder: (_) => const StopwatchPage(),
      tags: const ['time', 'timer'],
    ),
    ToolInfo(
      id: 'countdown',
      name: '倒计时',
      description: '自定义时长精确倒计时',
      icon: Icons.hourglass_bottom_rounded,
      accent: const Color(0xFFF09B3A),
      builder: (_) => const CountdownPage(),
      tags: const ['time', 'timer'],
    ),
    ToolInfo(
      id: 'pomodoro',
      name: '番茄钟',
      description: '专注 25 分钟高效工作',
      icon: Icons.av_timer_rounded,
      accent: const Color(0xFFE85D5D),
      builder: (_) => const PomodoroPage(),
      tags: const ['time', 'focus'],
    ),
    ToolInfo(
      id: 'dice',
      name: '骰子',
      description: '摇一摇随机点数',
      icon: Icons.casino_rounded,
      accent: const Color(0xFFE8663A),
      builder: (_) => const DicePage(),
      tags: const ['random', 'game'],
    ),
    ToolInfo(
      id: 'random',
      name: '随机数',
      description: '区间内随机生成',
      icon: Icons.shuffle_rounded,
      accent: const Color(0xFF3DB3C9),
      builder: (_) => const RandomNumberPage(),
      tags: const ['random'],
    ),
    ToolInfo(
      id: 'converter',
      name: '单位换算',
      description: '长度 / 重量 / 温度等',
      icon: Icons.swap_horiz_rounded,
      accent: const Color(0xFF6C7CF0),
      builder: (_) => const UnitConverterPage(),
      tags: const ['unit', 'convert'],
    ),
    ToolInfo(
      id: 'flashlight',
      name: '手电筒',
      description: '一键开启强光照明',
      icon: Icons.flashlight_on_rounded,
      accent: const Color(0xFFF5C542),
      builder: (_) => const FlashlightPage(),
      mobileOnly: true,
      tags: const ['light'],
    ),
    ToolInfo(
      id: 'ear_monitor',
      name: '耳返',
      description: '极低延迟实时监听',
      icon: Icons.headphones_rounded,
      accent: const Color(0xFF4C7DF0),
      builder: (_) => const EarMonitorPage(),
      tags: const ['audio', 'monitor'],
    ),
    ToolInfo(
      id: 'qrcode',
      name: '二维码',
      description: '文本内容生成二维码',
      icon: Icons.qr_code_2_rounded,
      accent: const Color(0xFF3A9B6E),
      builder: (_) => const QrCodePage(),
      tags: const ['qr', 'encode'],
    ),
    ToolInfo(
      id: 'text_tools',
      name: '文本工具',
      description: 'JSON / Base64 / 大小写 / 行处理',
      icon: Icons.text_fields_rounded,
      accent: const Color(0xFF8E5CF0),
      builder: (_) => const TextToolsPage(),
      tags: const ['text', 'json', 'format'],
    ),
    ToolInfo(
      id: 'word_count',
      name: '字数统计',
      description: '实时统计字符 / 单词 / 段落',
      icon: Icons.numbers_rounded,
      accent: const Color(0xFF607D8B),
      builder: (_) => const WordCountPage(),
      tags: const ['text', 'count', 'word'],
    ),
  ];

  static final List<ToolInfo> aboutTools = <ToolInfo>[
    ToolInfo(
      id: 'about',
      name: '关于 CosyTool',
      description: '版本信息与项目说明',
      icon: Icons.info_rounded,
      accent: const Color(0xFF7A8AA0),
      builder: (_) => const AboutPage(),
      tags: const ['about'],
    ),
  ];

  /// 根据 id 获取工具元信息（供工具页面自身取用标题 / 图标）。
  static ToolInfo of(String id) {
    for (final t in tools) {
      if (t.id == id) return t;
    }
    return aboutTools.first;
  }
}
