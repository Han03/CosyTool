import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cosy_tool/features/home/tab_strip.dart';
import 'package:cosy_tool/models/tool_info.dart';

ToolInfo _tool(String id, String name) => ToolInfo(
      id: id,
      name: name,
      description: '测试',
      icon: Icons.timer_rounded,
      accent: Colors.teal,
      builder: (context) => const SizedBox(),
    );

void main() {
  testWidgets('TabStrip 2 tabs render both items with correct sizes',
      (tester) async {
    final tabs = [_tool('a', '秒表'), _tool('b', '倒计时')];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 800,
            height: 600,
            child: Column(
              children: [
                TabStrip(
                  tabs: tabs,
                  activeIndex: 1,
                  onSelect: (_) {},
                  onClose: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));

    // 两个 Tab 标题都应渲染
    expect(find.text('秒表'), findsOneWidget);
    expect(find.text('倒计时'), findsOneWidget);
    final r1 = tester.getRect(find.text('秒表'));
    final r2 = tester.getRect(find.text('倒计时'));
    debugPrint('STRIP= TAB1= TAB2=');
    expect(r1.overlaps(r2), isFalse);

    // TabStrip 高度 44
    final strip = tester.getSize(find.byType(TabStrip));
    expect(strip.height, 44);

    debugPrint('STRIP WIDTH=${strip.width}');
  });

  testWidgets('update tabs 1->2 keeps both items visible', (tester) async {
    late StateSetter setState;
    var tabs = [_tool('a', '秒表')];
    var active = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 800,
                height: 100,
                child: TabStrip(
                  tabs: tabs,
                  activeIndex: active,
                  onSelect: (_) {},
                  onClose: (_) {},
                ),
              ),
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('秒表'), findsOneWidget);

    // 模拟打开第二个工具（含点击首页后 _activeTab=-1 → 打开新工具）
    setState(() {
      tabs = [...tabs, _tool('b', '倒计时')];
      active = 1;
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('秒表'), findsOneWidget);
    expect(find.text('倒计时'), findsOneWidget);
    final r1 = tester.getRect(find.text('秒表'));
    final r2 = tester.getRect(find.text('倒计时'));
    debugPrint('STRIP= TAB1= TAB2=');
    expect(r1.overlaps(r2), isFalse);
    debugPrint('UPDATE-STRIP OK');
  });


  testWidgets('shared mutable list in-place add does not crash (regression)',
      (tester) async {
    // 模拟 HomeShell 旧实现：就地修改同一个 List 引用（old/new widget 共享引用）
    final tabs = <ToolInfo>[_tool('a', '秒表')];
    var active = -1;
    late StateSetter setState;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 800,
                height: 100,
                child: TabStrip(
                  tabs: tabs,
                  activeIndex: active,
                  onSelect: (_) {},
                  onClose: (_) {},
                ),
              ),
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    setState(() {
      tabs.add(_tool('b', '倒计时'));
      active = 1;
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    // 两个 Tab 都应渲染，无 RangeError
    expect(find.text('秒表'), findsOneWidget);
    expect(find.text('倒计时'), findsOneWidget);
    debugPrint('SHARED-LIST OK');
  });
}