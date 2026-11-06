import 'package:lunar/lunar.dart';

/// Negative month numbers identify leap months; all dates use civil days.
class LunarDate {
  final int year, month, day;
  const LunarDate(this.year, this.month, this.day);
  factory LunarDate.fromSolar(DateTime date) {
    final converted = Solar.fromYmd(date.year, date.month, date.day).getLunar();
    return LunarDate(
      converted.getYear(),
      converted.getMonth(),
      converted.getDay(),
    );
  }
  static List<LunarMonth> months(int year) =>
      LunarYear.fromYear(year).getMonthsInYear();
  int get dayCount => LunarMonth.fromYm(year, month)!.getDayCount();
  DateTime get solar {
    final s = Lunar.fromYmd(year, month, day).getSolar();
    return DateTime.utc(s.getYear(), s.getMonth(), s.getDay());
  }

  String get text {
    final l = Lunar.fromYmd(year, month, day);
    return '农历 $year 年${l.getMonthInChinese()}月${l.getDayInChinese()}';
  }

  static String monthText(int month) =>
      '${month < 0 ? '闰' : ''}${const ['正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊'][month.abs() - 1]}月';
  static String dayText(int day) => const [
    '初一',
    '初二',
    '初三',
    '初四',
    '初五',
    '初六',
    '初七',
    '初八',
    '初九',
    '初十',
    '十一',
    '十二',
    '十三',
    '十四',
    '十五',
    '十六',
    '十七',
    '十八',
    '十九',
    '二十',
    '廿一',
    '廿二',
    '廿三',
    '廿四',
    '廿五',
    '廿六',
    '廿七',
    '廿八',
    '廿九',
    '三十',
  ][day - 1];

  DateTime occurrence(int year, String leapPolicy, String shortPolicy) {
    final m = month < 0 && leapPolicy == 'regular'
        ? month.abs()
        : LunarMonth.fromYm(year, month) == null
        ? month.abs()
        : month;
    final count = LunarMonth.fromYm(year, m)!.getDayCount();
    final s = LunarDate(year, m, day > count ? count : day).solar;
    return day > count && shortPolicy == 'next'
        ? s.add(const Duration(days: 1))
        : s;
  }
}
