import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_days/appearance.dart';
import 'package:life_days/editor.dart';
import 'package:life_days/event.dart';
import 'package:life_days/lunar_date.dart';
import 'package:life_days/store.dart';

Event birthday(
  LunarDate l, {
  String leap = 'prefer-leap',
  String short = 'last',
}) => Event(
  '农历生日',
  l.solar,
  repeat: 'yearly',
  birthday: true,
  showAge: true,
  lunarDate: l,
  lunarLeapPolicy: leap,
  lunarShortPolicy: short,
);

void main() {
  test('春节、闰二月及原型生日换算锚点', () {
    expect(const LunarDate(2026, 1, 1).solar, DateTime.utc(2026, 2, 17));
    expect(const LunarDate(2023, -2, 1).solar, DateTime.utc(2023, 3, 22));
    expect(const LunarDate(2026, 10, 15).solar, DateTime.utc(2026, 11, 23));
    expect(LunarDate.fromSolar(DateTime(2023, 3, 22)).month, -2);
    expect(LunarDate.dayText(30), '三十');
  });
  test('农历生日当天、次日自动滚动及年龄', () {
    final e = birthday(const LunarDate(1972, 10, 15));
    expect(e.target(DateTime(2026, 11, 6)), DateTime.utc(2026, 11, 23));
    expect(e.days(DateTime(2026, 11, 6)), 17);
    expect(e.days(DateTime(2026, 11, 23, 23, 59)), 0);
    expect(e.age(DateTime(2026, 11, 23)), 54);
    expect(e.direction(DateTime(2026, 11, 23)), '生日快乐 · 就是今天');
    expect(
      e.target(DateTime(2026, 11, 24)),
      const LunarDate(2027, 10, 15).solar,
    );
    expect(e.age(DateTime(2026, 11, 24)), 55);
  });
  test('春节前按农历上一年寻找腊月生日', () {
    final e = birthday(const LunarDate(2000, 12, 15));
    final target = const LunarDate(2025, 12, 15).solar;
    expect(e.target(DateTime(2026, 1, 1)), target);
    expect(e.age(DateTime(2026, 1, 1)), 25);
  });
  test('闰月优先、无闰月回退及始终普通月', () {
    const l = LunarDate(2023, -2, 1);
    expect(birthday(l).occurrence(2023), DateTime.utc(2023, 3, 22));
    expect(birthday(l).occurrence(2024), const LunarDate(2024, 2, 1).solar);
    expect(
      birthday(l, leap: 'regular').occurrence(2023),
      const LunarDate(2023, 2, 1).solar,
    );
    final normal = birthday(const LunarDate(2000, 2, 1));
    expect(
      normal.target(DateTime(2023, 3, 1)),
      const LunarDate(2024, 2, 1).solar,
    );
  });
  test('三十遇小月及腊月顺延初一保留正确生日年份', () {
    // Find valid big-month origin and small-month destination explicitly.
    final big = List.generate(20, (i) => 2000 + i).firstWhere(
      (y) =>
          const LunarDate(2000, 12, 1).occurrence(y, 'regular', 'last').isUtc &&
          LunarDate(y, 12, 1).dayCount == 30,
    );
    final small = List.generate(
      20,
      (i) => 2020 + i,
    ).firstWhere((y) => LunarDate(y, 12, 1).dayCount == 29);
    final l = LunarDate(big, 12, 30);
    final last = LunarDate(small, 12, 29).solar;
    expect(birthday(l).occurrence(small), last);
    final next = birthday(l, short: 'next');
    expect(next.occurrence(small), last.add(const Duration(days: 1)));
    expect(next.days(last.add(const Duration(days: 1))), 0);
    expect(next.age(last.add(const Duration(days: 1))), small - big);
  });
  test('农历纪念日持续累计且下一周年按农历换算', () {
    const l = LunarDate(2020, 10, 15);
    final e = Event('纪念', l.solar, type: 'anniversary', lunarDate: l);
    final now = DateTime(2026, 11, 6);
    expect(e.days(now), dayOnly(now).difference(l.solar).inDays);
    expect(e.nextAnniversary(now), DateTime.utc(2026, 11, 23));
  });
  test('JSON、CSV 和置顶归档保留农历规则', () {
    final e = birthday(
      const LunarDate(2023, -2, 1),
      leap: 'regular',
      short: 'next',
    );
    final roundtrip = parseImport(encodeEvents([e]), csv: false);
    expect(roundtrip.errors, isEmpty);
    expect(roundtrip.events.single.toJson(), e.toJson());
    expect(e.copyWith(pinned: true, archived: true).lunarDate!.month, -2);
    final batch = parseImport(
      'title,date,type,repeat,calendar,lunar_year,lunar_month,lunar_day,birthday\n闰月生日,2023-03-22,countdown,yearly,lunar,2023,-2,1,true',
      csv: true,
    );
    expect(batch.errors, isEmpty);
    expect(batch.events.single.lunarDate!.month, -2);
    expect(
      batch.events.single.key,
      isNot(Event('闰月生日', e.date, repeat: 'yearly').key),
    );
  });
  test('拦截不存在的闰月、三十、字段类型、周重复和公农历不一致', () {
    final base = birthday(const LunarDate(2023, -2, 1)).toJson();
    for (final fields in [
      {'lunar_year': 2024},
      {'lunar_month': -3},
      {'lunar_day': 31},
      {'lunar_year': '2023'},
      {'lunar_year': 2101},
      {'date': '2023-03-23'},
      {'repeat': 'weekly'},
      {'lunar_leap_policy': 'unknown'},
      {'lunar_short_policy': 'unknown'},
    ]) {
      expect(() => Event.fromJson({...base, ...fields}), throwsFormatException);
    }
    final small = List.generate(
      12,
      (i) => i + 1,
    ).firstWhere((m) => LunarDate(2026, m, 1).dayCount == 29);
    expect(
      () => Event.fromJson({
        ...base,
        'lunar_year': 2026,
        'lunar_month': small,
        'lunar_day': 30,
      }),
      throwsFormatException,
    );
  });
  test('v2 升级前备份，农历保存重启不变', () async {
    final dir = await Directory.systemTemp.createTemp('life-days-lunar-');
    addTearDown(() => dir.delete(recursive: true));
    final raw = jsonEncode({
      'version': 2,
      'events': [Event('旧事件', DateTime(2020), type: 'anniversary').toJson()],
    });
    await File('${dir.path}/events.json').writeAsString(raw);
    final store = EventStore(directory: dir);
    final old = await store.load();
    expect(await File('${dir.path}/events-v2-backup.json').readAsString(), raw);
    expect(old.single.isLunar, false);
    final lunar = birthday(const LunarDate(2023, -2, 1));
    await store.save([...old, lunar]);
    expect((await store.load()).last.toJson(), lunar.toJson());
  });
  test('交付的农历 JSON 和 CSV 示例均能被手机导入', () {
    for (final ext in ['json', 'csv']) {
      final batch = parseImport(
        File('examples/lunar-birthdays.$ext').readAsStringSync(),
        csv: ext == 'csv',
      );
      expect(batch.errors, isEmpty);
      expect(batch.events.length, 2);
      expect(
        batch.events.first.target(DateTime(2026, 11, 6)),
        DateTime.utc(2026, 11, 23),
      );
      expect(batch.events.last.lunarDate!.month, -2);
    }
  });
  testWidgets('新建生日切换农历后保存双历一致的数据', (tester) async {
    Event? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('打开'),
              onPressed: () async {
                saved = await Navigator.push<Event>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Editor(now: DateTime(2026, 11, 6)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🎂 生日模板'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), '新建农历生日');
    await tester.ensureVisible(find.text('农历'));
    await tester.tap(find.text('农历'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();
    expect(saved!.isLunar, true);
    expect(saved!.repeat, 'yearly');
    expect(saved!.birthday, true);
    expect(saved!.lunarDate!.solar, saved!.date);
    expect(Event.fromJson(saved!.toJson()).isLunar, true);
    expect(tester.takeException(), isNull);
  });
  testWidgets('农历表单小屏保存且重开保留历法、闰月和规则', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final e = birthday(
      const LunarDate(2023, -2, 1),
      leap: 'regular',
      short: 'next',
    );
    Event? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('打开'),
              onPressed: () async {
                saved = await Navigator.push<Event>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        Editor(event: saved ?? e, now: DateTime(2026, 11, 6)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('闰月生日规则'));
    expect(find.text('每年只过普通月'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();
    expect(saved!.toJson(), e.toJson());
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('闰月生日规则'));
    expect(find.text('每年只过普通月'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
