import 'package:flutter_test/flutter_test.dart';
import 'package:life_days/event.dart';

void main() {
  test('日历天数不受当天时刻影响', () {
    expect(
      Event('周六', DateTime(2026, 11, 7)).days(DateTime(2026, 11, 6, 23, 59)),
      1,
    );
    expect(Event('过去', DateTime(2026, 11, 5)).days(DateTime(2026, 11, 6)), -1);
  });
  test('每周重复：当天为零，过期滚到下个星期', () {
    final e = Event('周六', DateTime(2026, 11, 7), repeat: 'weekly');
    expect(e.days(DateTime(2026, 11, 7)), 0);
    expect(e.days(DateTime(2026, 11, 8)), 6);
  });
  test('年度重复跨年及闰日策略', () {
    expect(
      Event(
        '元旦',
        DateTime(2020, 1, 1),
        repeat: 'yearly',
      ).days(DateTime(2026, 12, 31)),
      1,
    );
    final leap = Event('生日', DateTime(2024, 2, 29), repeat: 'yearly');
    expect(leap.target(DateTime(2027, 2, 1)), DateTime.utc(2027, 2, 28));
    expect(leap.target(DateTime(2028, 2, 1)), DateTime.utc(2028, 2, 29));
  });
  test('拒绝不存在的日期', () {
    expect(
      () => Event.fromJson({'title': '坏日期', 'date': '2026-02-30'}),
      throwsFormatException,
    );
  });
  test('CSV 支持 BOM、CRLF、逗号、换行和转义引号', () {
    final batch = parseImport(
      '\uFEFFtitle,date,repeat,pinned\r\n"旅行,\n""出发""",2026-11-07,weekly,true\r\n',
      csv: true,
    );
    expect(batch.errors, isEmpty);
    expect(batch.events.single.title, '旅行,\n"出发"');
    expect(batch.events.single.pinned, isTrue);
  });
  test('错误记录可定位；无效布尔值和列数均不静默通过', () {
    final batch = parseImport(
      'title,date,pinned\n测试,2026-11-07,yes\n缺列,2026-11-07',
      csv: true,
    );
    expect(batch.errors.length, 2);
    expect(batch.events, isEmpty);
  });
  test('JSON 导出格式可重导入，事件键用于去重', () {
    final batch = parseImport(
      '{"version":1,"events":[{"title":"测试","date":"2026-11-07","type":"countdown"}]}',
      csv: false,
    );
    expect(batch.events.single.key, '测试|2026-11-07|countdown|none|solar');
    expect(batch.errors, isEmpty);
  });
  test('CSV 拒绝未闭合引号和重复表头', () {
    expect(
      () => parseImport('title,date\n"abc,2026-11-07', csv: true),
      throwsFormatException,
    );
    expect(
      () => parseImport('title,date,title\na,2026-11-07,b', csv: true),
      throwsFormatException,
    );
  });
  test('纪念日跨周年不归零；可包含起始日', () {
    final e = Event('相识', DateTime(2020, 1, 1), type: 'anniversary');
    expect(e.days(DateTime(2021, 1, 1)), 366);
    expect(e.days(DateTime(2021, 1, 2)), 367);
    expect(
      Event(
        '起点',
        DateTime(2026, 11, 6),
        type: 'anniversary',
        inclusive: true,
      ).days(DateTime(2026, 11, 6)),
      1,
    );
    expect(e.nextAnniversary(DateTime(2026, 12, 31)), DateTime.utc(2027, 1, 1));
  });
  test('生日当天为零，次日滚到下一年，年龄随本次目标计算', () {
    final e = Event(
      '生日',
      DateTime(1998, 11, 6),
      repeat: 'yearly',
      birthday: true,
      showAge: true,
    );
    expect(e.days(DateTime(2026, 11, 6)), 0);
    expect(e.age(DateTime(2026, 11, 6)), 28);
    expect(e.target(DateTime(2026, 11, 7)), DateTime.utc(2027, 11, 6));
    expect(e.age(DateTime(2026, 11, 7)), 29);
    expect(
      Event(
        '未知年份生日',
        DateTime(2026, 11, 6),
        birthday: true,
        repeat: 'yearly',
      ).age(DateTime(2026, 11, 6)),
      isNull,
    );
  });
  test('2 月 29 日的两种规则在非闰年和闰年分别计算', () {
    final e = Event(
      '生日',
      DateTime(2000, 2, 29),
      repeat: 'yearly',
      leapPolicy: 'mar1',
    );
    expect(e.target(DateTime(2027, 2, 28)), DateTime.utc(2027, 3, 1));
    expect(e.days(DateTime(2027, 3, 1)), 0);
    expect(e.target(DateTime(2028, 2, 1)), DateTime.utc(2028, 2, 29));
  });
  test('非重复倒计时到期后保留倒计时类型', () {
    final e = Event('旅行', DateTime(2026, 11, 5));
    expect(e.direction(DateTime(2026, 11, 6)), '已结束 · 过去');
    expect(e.type, 'countdown');
  });
  test('CSV 显式类型与新字段均可校验导入', () {
    final batch = parseImport(
      'title,date,type,repeat,inclusive,birthday,show_age,leap_policy,icon,notes\n相识,2020-01-01,anniversary,none,true,false,false,feb28,♡,记住\n生日,2000-02-29,countdown,yearly,false,true,true,mar1,🎂,祝福',
      csv: true,
    );
    expect(batch.errors, isEmpty);
    expect(batch.events.first.inclusive, true);
    expect(batch.events.last.age(DateTime(2027, 2, 28)), 27);
  });
  test('错误类型和互相冲突的日期规则被拦截', () {
    for (final fields in [
      {'type': 'invalid'},
      {'type': 'anniversary', 'repeat': 'yearly'},
      {'birthday': true},
      {'show_age': true},
      {'type': 'countdown', 'inclusive': true},
      {'leap_policy': 'invalid'},
    ]) {
      expect(
        () => Event.fromJson({'title': '测试', 'date': '2026-11-07', ...fields}),
        throwsFormatException,
      );
    }
  });
}
