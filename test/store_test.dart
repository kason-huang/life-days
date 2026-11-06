import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_days/event.dart';
import 'package:life_days/store.dart';

void main() {
  test('v1 数据迁移先保留原文件，类型固定后重启保持一致', () async {
    final dir = await Directory.systemTemp.createTemp('life-days-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final raw = jsonEncode({
      'version': 1,
      'events': [
        {'title': '过去的日子', 'date': '2020-01-01'},
        {'title': '未来旅行', 'date': '2199-01-01'},
        {'title': '生日', 'date': '1972-11-23', 'repeat': 'yearly'},
      ],
    });
    await File('${dir.path}/events.json').writeAsString(raw);
    final store = EventStore(directory: dir);
    final events = await store.load();
    expect(events.map((e) => e.type), [
      'anniversary',
      'countdown',
      'countdown',
    ]);
    expect(await File('${dir.path}/events-v1-backup.json').readAsString(), raw);
    final saved = jsonDecode(
      await File('${dir.path}/events.json').readAsString(),
    );
    expect(saved['version'], 3);
    expect((await store.load()).map((e) => e.type), events.map((e) => e.type));
  });
  test('v2 备份重导入保留年龄、计数、备注、闰日规则和归档', () {
    final e = Event(
      '生日',
      DateTime(2000, 2, 29),
      repeat: 'yearly',
      birthday: true,
      showAge: true,
      leapPolicy: 'mar1',
      notes: '保留祝福',
      archived: true,
      icon: '🎂',
    );
    final roundtrip = parseImport(encodeEvents([e]), csv: false).events.single;
    expect(roundtrip.toJson(), e.toJson());
  });
  test('损坏数据报错且不会被覆盖', () async {
    final dir = await Directory.systemTemp.createTemp('life-days-corrupt-');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/events.json');
    await f.writeAsString('{broken');
    await expectLater(EventStore(directory: dir).load(), throwsFormatException);
    expect(await f.readAsString(), '{broken');
  });
}
