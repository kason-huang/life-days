import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_days/appearance.dart';
import 'package:life_days/editor.dart';
import 'package:life_days/event.dart';

void main() {
  testWidgets('空标题拦截；新建纪念日保存明确类型和包含当天规则', (tester) async {
    Event? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<Event>(
                  MaterialPageRoute(
                    builder: (_) => Editor(now: DateTime(2026, 11, 6)),
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();
    expect(find.text('请填写事件名称'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('event-title')));
    await tester.enterText(find.byKey(const Key('event-title')), '我们相识的日子');
    await tester.ensureVisible(find.text('起始日算第 1 天'));
    await tester.tap(find.text('起始日算第 1 天'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();
    expect(saved?.type, 'anniversary');
    expect(saved?.inclusive, true);
    expect(saved?.days(DateTime(2026, 11, 6)), 1);
  });
  testWidgets('生日模板保存年度倒计时，默认不显示年龄', (tester) async {
    Event? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<Event>(
                  MaterialPageRoute(
                    builder: (_) => Editor(now: DateTime(2026, 11, 6)),
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🎂 生日模板'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), '妈妈生日');
    expect(find.text('起始日算第 1 天'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();
    expect(saved?.type, 'countdown');
    expect(saved?.repeat, 'yearly');
    expect(saved?.birthday, true);
    expect(saved?.showAge, false);
    expect(saved?.icon, '🎂');
  });
  testWidgets('编辑已有纪念日保留备注、图标和归档状态', (tester) async {
    final e = Event(
      '旧名称',
      DateTime(2020, 3, 20),
      type: 'anniversary',
      icon: '💍',
      notes: '保留备注',
      archived: true,
    );
    Event? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<Event>(
                  MaterialPageRoute(
                    builder: (_) =>
                        Editor(event: e, now: DateTime(2026, 11, 6)),
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), '新名称');
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();
    expect(saved?.notes, '保留备注');
    expect(saved?.icon, '💍');
    expect(saved?.archived, true);
  });
}
