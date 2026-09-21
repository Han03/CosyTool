import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cosy_tool/app.dart';
import 'package:cosy_tool/shared/widgets/tool_card.dart';

void main() {
  testWidgets('desktop layout shows home tool grid', (tester) async {
    // 模拟桌面宽屏
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CosyToolApp());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // 侧栏骨架
    expect(find.text('首页'), findsWidgets);
    expect(find.text('设置'), findsWidgets);

    // 首页内容区：应用名大标题
    expect(find.text('CosyTool'), findsWidgets);

    // 工具分组标题应存在
    expect(find.text('音频'), findsOneWidget);
    expect(find.text('计时'), findsOneWidget);
    expect(find.text('文本'), findsOneWidget);

    // 工具卡片应渲染
    expect(find.byType(ToolCard), findsWidgets);

    final exceptions = tester.takeException();
    expect(exceptions, isNull);
  });
}
