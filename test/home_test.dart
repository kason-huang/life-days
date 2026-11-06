import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_days/appearance.dart';
import 'package:life_days/main.dart';
import 'package:life_days/event.dart';
import 'package:life_days/store.dart';

class MemoryStore extends EventStore {
  List<Event> events;
  MemoryStore(this.events);
  @override
  Future<List<Event>> load() async => events;
  @override
  Future<void> save(List<Event> next) async {
    events = next;
  }
}

void main() {
  testWidgets('小屏首页可筛选；详情可置顶且所有事件字段保留', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore([
      Event('我们相识', DateTime(2021, 3, 20), type: 'anniversary', pinned: true),
      Event(
        '妈妈生日',
        DateTime(1972, 11, 23),
        birthday: true,
        showAge: true,
        repeat: 'yearly',
        notes: '带上蛋糕',
        icon: '🎂',
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Home(store: store, clock: () => DateTime(2026, 11, 6)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('filter-countdown')));
    await tester.tap(find.byKey(const Key('filter-countdown')));
    await tester.pumpAndSettle();
    expect(find.text('我们相识'), findsNothing);
    await tester.tap(find.text('妈妈生日').first);
    await tester.pumpAndSettle();
    expect(find.text('即将迎来 54 岁生日'), findsOneWidget);
    expect(find.text('带上蛋糕'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('置顶关注'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('置顶关注'));
    await tester.pumpAndSettle();
    final e = store.events.last;
    expect(e.pinned, true);
    expect(e.birthday, true);
    expect(e.notes, '带上蛋糕');
    expect(e.showAge, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('归档可恢复，不删除本地事件', (tester) async {
    final store = MemoryStore([
      Event('旧旅程', DateTime(2026, 1, 1), archived: true),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Home(store: store, clock: () => DateTime(2026, 11, 6)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('filter-archived')));
    await tester.tap(find.byKey(const Key('filter-archived')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('旧旅程').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('恢复到我的日子'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复到我的日子'));
    await tester.pumpAndSettle();
    expect(store.events.length, 1);
    expect(store.events.single.archived, false);
    await tester.pumpWidget(const SizedBox());
  });
}
