import 'dart:convert';
import 'lunar_date.dart';

String dateText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime dayOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

class Event {
  final String title;
  final DateTime date;
  final String type, repeat, icon, notes, leapPolicy;
  final bool pinned, inclusive, birthday, showAge, archived;
  final LunarDate? lunarDate;
  final String lunarLeapPolicy, lunarShortPolicy;
  bool get isLunar => lunarDate != null;
  String get displayDate => lunarDate?.text ?? dateText(date);
  const Event(
    this.title,
    this.date, {
    this.type = 'countdown',
    this.repeat = 'none',
    this.pinned = false,
    this.inclusive = false,
    this.icon = '◷',
    this.notes = '',
    this.leapPolicy = 'feb28',
    this.birthday = false,
    this.showAge = false,
    this.archived = false,
    this.lunarDate,
    this.lunarLeapPolicy = 'prefer-leap',
    this.lunarShortPolicy = 'last',
  });
  bool get isAnniversary => type == 'anniversary';
  factory Event.fromJson(Map<String, dynamic> map, {DateTime? now}) {
    final title = map['title'];
    final raw = map['date'];
    if (title is! String || title.trim().isEmpty || title.length > 100) {
      throw const FormatException('标题不能为空，且最多 100 个字符');
    }
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      throw const FormatException('日期必须为 YYYY-MM-DD');
    }
    final date = DateTime.tryParse(raw);
    if (date == null ||
        dateText(date) != raw ||
        date.year < 1900 ||
        date.year > 2200) {
      throw const FormatException('日期无效（支持 1900–2200 年）');
    }
    final repeat = map['repeat'] ?? 'none';
    if (!['none', 'weekly', 'yearly'].contains(repeat)) {
      throw const FormatException('repeat 仅支持 none、weekly、yearly');
    }
    // 旧版仅按日期自动切换。迁移时固定类型，之后不会随日期变化。
    final type =
        map['type'] ??
        (repeat == 'none' &&
                dayOnly(date).isBefore(dayOnly(now ?? DateTime.now()))
            ? 'anniversary'
            : 'countdown');
    if (!['anniversary', 'countdown'].contains(type)) {
      throw const FormatException('type 仅支持 anniversary 或 countdown');
    }
    if (type == 'anniversary' && repeat != 'none') {
      throw const FormatException('纪念日持续累计，repeat 应为 none');
    }
    bool flag(String key) {
      final value = map[key] ?? false;
      if (value is! bool) throw FormatException('$key 必须为 true 或 false');
      return value;
    }

    final calendar = map['calendar'] ?? 'solar';
    if (!['solar', 'lunar'].contains(calendar)) {
      throw const FormatException('calendar 应为 solar 或 lunar');
    }
    final lunarLeap = map['lunar_leap_policy'] ?? 'prefer-leap';
    final lunarShort = map['lunar_short_policy'] ?? 'last';
    if (!['prefer-leap', 'regular'].contains(lunarLeap) ||
        !['last', 'next'].contains(lunarShort)) {
      throw const FormatException('农历闰月或小月规则无效');
    }
    LunarDate? lunar;
    if (calendar == 'lunar') {
      final y = map['lunar_year'], m = map['lunar_month'], d = map['lunar_day'];
      if (y is! int ||
          m is! int ||
          d is! int ||
          y < 1900 ||
          y > 2100 ||
          m == 0 ||
          m.abs() > 12 ||
          d < 1 ||
          d > 30) {
        throw const FormatException('请填写有效农历年月日（1900–2100 年，闰月用负月份）');
      }
      lunar = LunarDate(y, m, d);
      try {
        if (dateText(lunar.solar) != raw) {
          throw const FormatException('date 与农历年月日对应的公历日期不一致');
        }
      } on FormatException {
        rethrow;
      } catch (_) {
        throw const FormatException('农历日期不存在，请检查闰月和大小月');
      }
      if (repeat == 'weekly') throw const FormatException('农历不支持每周重复');
    }
    final birthday = flag('birthday');
    final showAge = flag('show_age');
    final inclusive = flag('inclusive');
    if (birthday && (type != 'countdown' || repeat != 'yearly')) {
      throw const FormatException('生日应设为 countdown，且每年重复');
    }
    if (showAge && !birthday) throw const FormatException('显示年龄需要开启 birthday');
    if (inclusive && type != 'anniversary') {
      throw const FormatException('起始日计为第 1 天仅适用于纪念日');
    }
    final leap = map['leap_policy'] ?? 'feb28';
    if (!['feb28', 'mar1'].contains(leap)) {
      throw const FormatException('leap_policy 应为 feb28 或 mar1');
    }
    final icon =
        map['icon'] ??
        (birthday
            ? '🎂'
            : type == 'anniversary'
            ? '♡'
            : '◷');
    final notes = map['notes'] ?? '';
    if (icon is! String ||
        icon.length > 16 ||
        notes is! String ||
        notes.length > 2000) {
      throw const FormatException('图标最多 16 个字符，备注最多 2000 个字符');
    }
    return Event(
      title.trim(),
      date,
      type: type,
      repeat: repeat,
      pinned: flag('pinned'),
      inclusive: inclusive,
      birthday: birthday,
      showAge: showAge,
      archived: flag('archived'),
      leapPolicy: leap,
      icon: icon.isEmpty ? '◷' : icon,
      notes: notes,
      lunarDate: lunar,
      lunarLeapPolicy: lunarLeap,
      lunarShortPolicy: lunarShort,
    );
  }
  Map<String, dynamic> toJson() => {
    'title': title,
    'date': dateText(date),
    'type': type,
    'repeat': repeat,
    'pinned': pinned,
    'inclusive': inclusive,
    'birthday': birthday,
    'show_age': showAge,
    'leap_policy': leapPolicy,
    'icon': icon,
    'notes': notes,
    'archived': archived,
    'calendar': isLunar ? 'lunar' : 'solar',
    if (isLunar) ...{
      'lunar_year': lunarDate!.year,
      'lunar_month': lunarDate!.month,
      'lunar_day': lunarDate!.day,
      'lunar_leap_policy': lunarLeapPolicy,
      'lunar_short_policy': lunarShortPolicy,
    },
  };
  String get key =>
      '$title|${dateText(date)}|$type|$repeat|${isLunar ? 'lunar' : 'solar'}';
  Event copyWith({bool? pinned, bool? archived}) => Event(
    title,
    date,
    type: type,
    repeat: repeat,
    pinned: pinned ?? this.pinned,
    archived: archived ?? this.archived,
    inclusive: inclusive,
    birthday: birthday,
    showAge: showAge,
    leapPolicy: leapPolicy,
    icon: icon,
    notes: notes,
    lunarDate: lunarDate,
    lunarLeapPolicy: lunarLeapPolicy,
    lunarShortPolicy: lunarShortPolicy,
  );
  DateTime occurrence(int year) {
    if (isLunar) {
      return lunarDate!.occurrence(year, lunarLeapPolicy, lunarShortPolicy);
    }
    final last = DateTime.utc(year, date.month + 1, 0).day;
    if (date.day > last && leapPolicy == 'mar1') {
      return DateTime.utc(year, 3, 1);
    }
    return DateTime.utc(year, date.month, date.day > last ? last : date.day);
  }

  DateTime nextAnniversary(DateTime now) {
    final today = dayOnly(now);
    if (isLunar) return occurrence(_nextLunarYear(today));
    var next = occurrence(today.year < date.year ? date.year : today.year);
    if (next.isBefore(today)) next = occurrence(today.year + 1);
    return next;
  }

  DateTime target(DateTime now) {
    final today = dayOnly(now), original = dayOnly(date);
    if (isLunar && !isAnniversary && repeat == 'yearly') {
      return nextAnniversary(now);
    }
    if (isAnniversary || repeat == 'none' || !original.isBefore(today)) {
      return original;
    }
    if (repeat == 'weekly') {
      final delta = today.difference(original).inDays;
      return original.add(Duration(days: ((delta + 6) ~/ 7) * 7));
    }
    return nextAnniversary(now);
  }

  int days(DateTime now) => isAnniversary
      ? dayOnly(now).difference(dayOnly(date)).inDays + (inclusive ? 1 : 0)
      : target(now).difference(dayOnly(now)).inDays;
  String direction(DateTime now) {
    final n = days(now);
    if (isAnniversary) return n < 0 ? '尚未开始 · 还有' : '已经';
    return n < 0
        ? '已结束 · 过去'
        : n == 0
        ? (birthday ? '生日快乐 · 就是今天' : '就是今天')
        : '还有';
  }

  int _nextLunarYear(DateTime now) {
    final today = dayOnly(now);
    final current = LunarDate.fromSolar(today).year;
    var year = current - 1 < lunarDate!.year ? lunarDate!.year : current - 1;
    while (occurrence(year).isBefore(today) ||
        occurrence(year).isBefore(dayOnly(date))) {
      year++;
    }
    return year;
  }

  int? age(DateTime now) => birthday && showAge
      ? (isLunar
            ? _nextLunarYear(now) - lunarDate!.year
            : target(now).year - date.year)
      : null;
}

class ImportBatch {
  final List<Event> events;
  final List<String> errors;
  const ImportBatch(this.events, this.errors);
}

ImportBatch parseImport(String source, {required bool csv}) {
  source = source.replaceFirst(RegExp('^\uFEFF'), '');
  final errors = <String>[];
  final events = <Event>[];
  List<dynamic> records;
  if (csv) {
    final rows = parseCsv(source);
    if (rows.isEmpty) throw const FormatException('文件为空');
    final header = rows.first.map((s) => s.trim()).toList();
    if (!header.contains('title') ||
        !header.contains('date') ||
        header.toSet().length != header.length) {
      throw const FormatException('CSV 表头需包含 title,date，且不能重复');
    }
    records = rows.skip(1).where((r) => r.any((v) => v.trim().isNotEmpty)).map((
      row,
    ) {
      if (row.length != header.length) return null;
      final map = <String, dynamic>{};
      for (var i = 0; i < header.length; i++) {
        map[header[i]] = row[i].trim();
      }
      if (map.containsKey('repeat') && map['repeat'] == '') {
        map.remove('repeat');
      }
      for (final key in [
        'type',
        'icon',
        'leap_policy',
        'calendar',
        'lunar_leap_policy',
        'lunar_short_policy',
      ]) {
        if (map[key] == '') map.remove(key);
      }
      for (final key in ['lunar_year', 'lunar_month', 'lunar_day']) {
        if (map[key] == '') map.remove(key);
        if (map[key] is String) map[key] = int.tryParse(map[key]) ?? map[key];
      }
      for (final key in [
        'pinned',
        'inclusive',
        'birthday',
        'show_age',
        'archived',
      ]) {
        if (!map.containsKey(key)) continue;
        final value = map[key];
        map[key] = value == 'true' || value == '1'
            ? true
            : value == 'false' || value == '0' || value == ''
            ? false
            : value;
      }
      return map;
    }).toList();
  } else {
    final decoded = jsonDecode(source);
    final list = decoded is Map ? decoded['events'] : decoded;
    if (list is! List) throw const FormatException('JSON 应为事件数组或包含 events 的对象');
    records = list;
  }
  if (records.length > 5000) throw const FormatException('单次最多导入 5000 条');
  for (var i = 0; i < records.length; i++) {
    try {
      final row = records[i];
      if (row is! Map) throw const FormatException('事件格式或列数不正确');
      events.add(Event.fromJson(Map<String, dynamic>.from(row)));
    } catch (e) {
      errors.add('第 ${i + 1} 条：$e');
    }
  }
  return ImportBatch(events, errors);
}

List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  var closed = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.write(c);
      }
    } else if (c == ',') {
      row.add(field.toString());
      field = StringBuffer();
      closed = false;
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      rows.add(row);
      row = [];
      field = StringBuffer();
      closed = false;
    } else if (c == '"' && field.isEmpty && !closed) {
      quoted = true;
    } else {
      if (closed || c == '"') throw const FormatException('CSV 引号格式不正确');
      field.write(c);
    }
  }
  if (quoted) throw const FormatException('CSV 引号未闭合');
  if (field.isNotEmpty || row.isNotEmpty || closed) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
