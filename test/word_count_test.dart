import 'dart:convert';

import 'package:cosy_tool/features/word_count/word_count_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextStats.count', () {
    test('空文本全为 0', () {
      final s = TextStats.count('');
      expect(s.characters, 0);
      expect(s.lines, 0);
      expect(s.paragraphs, 0);
      expect(s.bytes, 0);
    });

    test('中英文混合统计', () {
      final s = TextStats.count('你好 hello world 123!');
      // 你好(2) + 空格 + hello(5) + 空格 + world(5) + 空格 + 123(3) + !(1) = 19
      expect(s.characters, 19);
      expect(s.chinese, 2);
      expect(s.words, 2);
      expect(s.latinLetters, 10);
      expect(s.digits, 3);
      expect(s.punctuation, 1);
      expect(s.whitespace, 3);
      expect(s.lines, 1);
      expect(s.paragraphs, 1);
      expect(s.bytes, utf8.encode('你好 hello world 123!').length);
    });

    test('多行与多段落', () {
      final s = TextStats.count('a\n\nb\nc');
      expect(s.lines, 4);
      expect(s.paragraphs, 2);
    });

    test('表情符号按一个字符计', () {
      final s = TextStats.count('🎉🎉');
      expect(s.characters, 2);
      expect(s.bytes, utf8.encode('🎉🎉').length);
    });
  });

  group('WordCountPage', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: WordCountPage()));
      await tester.pumpAndSettle();
    }

    testWidgets('输入后实时更新统计', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField).first, '你好世界 hello');
      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget); // 总字符 4+1+5
      expect(find.text('4'), findsOneWidget); // 中文字符
      expect(find.text('1'), findsWidgets); // 英文单词 / 行数 / 段落
      expect(find.text('18'), findsOneWidget); // UTF-8 字节 12+1+5
    });

    testWidgets('清空按钮归零', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('清空'));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsWidgets);
    });
  });
}
