import 'package:cosy_tool/features/text_tools/text_tools_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TextToolsPage()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> runOp(
    WidgetTester tester,
    String mode,
    String op,
    String input,
  ) async {
    await tester.tap(find.text(mode));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, input);
    await tester.tap(find.text(op));
    await tester.pumpAndSettle();
  }

  testWidgets('JSON 格式化 / 压缩 / 校验', (tester) async {
    await pump(tester);
    await runOp(tester, 'JSON', '格式化', '{"name":"cosy","n":1}');
    expect(find.textContaining('"name": "cosy"'), findsOneWidget);
    expect(find.textContaining('格式化完成'), findsOneWidget);

    await runOp(tester, 'JSON', '压缩', '{"name":"cosy","n":1}');
    expect(find.textContaining('{"name":"cosy","n":1}'), findsWidgets);

    await runOp(tester, 'JSON', '校验', '{"a":1}');
    expect(find.textContaining('有效 JSON'), findsOneWidget);

    // 非法 JSON
    await runOp(tester, 'JSON', '格式化', '{bad json');
    expect(find.textContaining('处理失败'), findsOneWidget);
  });

  testWidgets('Base64 编码 / 解码', (tester) async {
    await pump(tester);
    await runOp(tester, 'Base64', '编码', '你好 Cosy');
    expect(find.textContaining('5L2g5aW9IENvc3k='), findsOneWidget);

    await runOp(tester, 'Base64', '解码', '5L2g5aW9IENvc3k=');
    expect(find.textContaining('你好 Cosy'), findsOneWidget);
  });

  testWidgets('URL 编码 / 解码', (tester) async {
    await pump(tester);
    await runOp(tester, 'URL', '编码', 'a b&c');
    expect(find.textContaining('a%20b%26c'), findsOneWidget);

    await runOp(tester, 'URL', '解码', 'a%20b%26c');
    expect(find.textContaining('a b&c'), findsOneWidget);
  });

  testWidgets('大小写转换', (tester) async {
    await pump(tester);
    await runOp(tester, '大小写', '全大写', 'hello world');
    expect(find.textContaining('HELLO WORLD'), findsOneWidget);

    await runOp(tester, '大小写', '驼峰', 'hello world foo');
    expect(find.textContaining('helloWorldFoo'), findsOneWidget);

    await runOp(tester, '大小写', '蛇形', 'Hello World Foo');
    expect(find.textContaining('hello_world_foo'), findsOneWidget);

    await runOp(tester, '大小写', '短横线', 'Hello World Foo');
    expect(find.textContaining('hello-world-foo'), findsOneWidget);
  });

  testWidgets('行处理：去重 / 排序 / 加行号', (tester) async {
    await pump(tester);
    await runOp(tester, '行处理', '去重', 'b\na\nb\nc');
    expect(find.textContaining('b\na\nc'), findsOneWidget);

    await runOp(tester, '行处理', '排序↑', 'c\na\nb');
    expect(find.textContaining('a\nb\nc'), findsOneWidget);

    await runOp(tester, '行处理', '加行号', 'a\nb');
    expect(find.textContaining('1. a\n2. b'), findsOneWidget);
  });

  testWidgets('空输入提示', (tester) async {
    await pump(tester);
    await runOp(tester, 'JSON', '格式化', '');
    expect(find.textContaining('请先输入要处理的文本'), findsOneWidget);
  });
}
