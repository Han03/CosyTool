import 'package:cosy_tool/app.dart';
import 'package:cosy_tool/data/tools_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CosyTool 应用可启动并展示工具', (tester) async {
    await tester.pumpWidget(const CosyToolApp());
    await tester.pumpAndSettle();

    // 应用标题与导航
    expect(find.text('CosyTool'), findsWidgets);
    expect(find.text('首页'), findsWidgets);

    // 首页首屏（侧边栏/网格首行）应展示前几个工具
    expect(find.text('录音机'), findsWidgets);
    expect(find.text('分贝测试'), findsWidgets);
    expect(find.text('秒表'), findsWidgets);
  });

  testWidgets('工具注册表包含核心工具', (tester) async {
    // 不需要渲染，直接校验注册表内容
    final tools = ToolRegistry.tools;
    expect(tools.length, greaterThanOrEqualTo(8));
    final ids = tools.map((t) => t.id).toSet();
    expect(ids, containsAll(['recorder', 'decibel', 'stopwatch', 'converter']));
  });
}
