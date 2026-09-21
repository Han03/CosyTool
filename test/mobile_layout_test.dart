import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cosy_tool/core/theme/app_theme.dart';
import 'package:cosy_tool/data/tools_registry.dart';
import 'package:cosy_tool/app.dart';
import 'package:cosy_tool/core/theme/theme_controller.dart';

/// 手机端布局冒烟测试：
/// 用常见手机尺寸（390×844 / 375×667）渲染所有工具页 + 应用外壳，
/// 捕获 RenderFlex 溢出等布局异常。平台插件异常（MissingPluginException）
/// 在测试环境属预期噪音，忽略；只关注布局溢出。
void main() {
  const sizes = <(String, Size)>[
    ('iPhone14', Size(390, 844)),
    ('iPhoneSE', Size(375, 667)),
  ];

  for (final (label, size) in sizes) {
    group('mobile $label ${size.width.toInt()}x${size.height.toInt()}', () {
      for (final tool in ToolRegistry.tools) {
        testWidgets('tool page: ${tool.id}', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_wrapBuilder(tool.builder));
          await tester.pump(const Duration(milliseconds: 300));

          _expectNoOverflow(tester, tool.id);
        });
      }

      testWidgets('shell home', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrapApp());
        await tester.pump(const Duration(milliseconds: 300));
        _expectNoOverflow(tester, 'home');
      });

      testWidgets('shell drawer settings', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrapApp());
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('设置'));
        await tester.pump(const Duration(milliseconds: 400));
        _expectNoOverflow(tester, 'settings');
      });
    });
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: Scaffold(body: child),
  );
}

/// 用 Builder 在真实树内调用 builder，获得有效 context。
Widget _wrapBuilder(WidgetBuilder builder) {
  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: Scaffold(body: Builder(builder: (ctx) => builder(ctx))),
  );
}

Widget _wrapApp() {
  return CosyToolApp(themeController: ThemeController());
}

void _expectNoOverflow(WidgetTester tester, String label) {
  final exception = tester.takeException();
  if (exception == null) return;
  final text = exception.toString();
  if (text.contains('overflowed') || text.contains('Overflow')) {
    String detail;
    try {
      detail = (exception as FlutterError).toStringDeep();
    } catch (_) {
      detail = text;
    }
    fail('[$label] RenderFlex overflow:\n$detail');
  }
  // 其余异常（平台通道缺失等）为测试环境预期噪音，忽略
}
