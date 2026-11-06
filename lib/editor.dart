import 'package:flutter/material.dart';
import 'appearance.dart';
import 'event.dart';
import 'lunar_date.dart';

class Editor extends StatefulWidget {
  final Event? event;
  final DateTime? now;
  const Editor({super.key, this.event, this.now});
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late final TextEditingController title, notes;
  late DateTime date;
  late String type, repeat, icon, leapPolicy;
  late bool pinned, inclusive, birthday, showAge;
  LunarDate? lunarDate;
  late String lunarLeapPolicy, lunarShortPolicy;
  final form = GlobalKey<FormState>();
  DateTime get today => dayOnly(widget.now ?? DateTime.now());
  bool get anniversary => type == 'anniversary';
  @override
  void initState() {
    super.initState();
    final e = widget.event;
    title = TextEditingController(text: e?.title);
    notes = TextEditingController(text: e?.notes);
    date = dayOnly(e?.date ?? today);
    type = e?.type ?? 'anniversary';
    repeat = e?.repeat ?? 'none';
    icon = e?.icon ?? '♡';
    leapPolicy = e?.leapPolicy ?? 'feb28';
    pinned = e?.pinned ?? false;
    inclusive = e?.inclusive ?? false;
    birthday = e?.birthday ?? false;
    showAge = e?.showAge ?? false;
    lunarDate = e?.lunarDate;
    lunarLeapPolicy = e?.lunarLeapPolicy ?? 'prefer-leap';
    lunarShortPolicy = e?.lunarShortPolicy ?? 'last';
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  void changeType(String value) => setState(() {
    type = value;
    if (anniversary) {
      birthday = false;
      showAge = false;
      repeat = 'none';
      icon = '♡';
    } else {
      inclusive = false;
      icon = '◷';
    }
  });
  void birthdayTemplate() => setState(() {
    type = 'countdown';
    repeat = 'yearly';
    birthday = true;
    inclusive = false;
    icon = '🎂';
  });
  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(date.year, date.month, date.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: birthday && showAge
          ? '选择出生日期（包含出生年份）'
          : anniversary
          ? '选择起始日期'
          : '选择目标日期',
    );
    if (selected != null && mounted) setState(() => date = dayOnly(selected));
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    if (anniversary && date.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('纪念日的起始日期不能晚于今天，请选择倒计时记录未来事件')),
      );
      return;
    }
    if (birthday && showAge && date.isAfter(today)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('出生日期不能晚于今天')));
      return;
    }
    Navigator.pop(
      context,
      Event(
        title.text.trim(),
        date,
        type: type,
        repeat: anniversary ? 'none' : repeat,
        pinned: pinned,
        inclusive: anniversary && inclusive,
        birthday: birthday,
        showAge: birthday && showAge,
        icon: icon,
        notes: notes.text.trim(),
        leapPolicy: leapPolicy,
        archived: widget.event?.archived ?? false,
        lunarDate: lunarDate,
        lunarLeapPolicy: lunarLeapPolicy,
        lunarShortPolicy: lunarShortPolicy,
      ),
    );
  }

  void updateLunar({int? year, int? month, int? day}) => setState(() {
    final previous = lunarDate!;
    final y = year ?? previous.year;
    final months = LunarDate.months(y);
    var m = month ?? previous.month;
    if (!months.any((v) => v.getMonth() == m)) m = m.abs();
    final count = months.firstWhere((v) => v.getMonth() == m).getDayCount();
    final d = (day ?? previous.day).clamp(1, count);
    lunarDate = LunarDate(y, m, d);
    date = lunarDate!.solar;
  });

  List<Widget> calendarFields() {
    final l = lunarDate;
    return [
      SegmentedButton<String>(
        key: const Key('calendar-switch'),
        segments: const [
          ButtonSegment(value: 'solar', label: Text('公历')),
          ButtonSegment(value: 'lunar', label: Text('农历')),
        ],
        selected: {l == null ? 'solar' : 'lunar'},
        onSelectionChanged: (s) {
          if (s.first == 'solar') {
            setState(() => lunarDate = null);
          } else {
            final converted = LunarDate.fromSolar(date);
            if (converted.year < 1900 || converted.year > 2100) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('农历年份支持 1900–2100，请先选择范围内的公历日期')),
              );
              return;
            }
            setState(() {
              lunarDate = converted;
              if (repeat == 'weekly') repeat = 'yearly';
            });
          }
        },
      ),
      if (l != null) ...[
        const SizedBox(height: 12),
        noteText('按农历记住日子，自动换算公历。无需年龄时，年份只用于选定有效农历日期。'),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey('lunar-year-${l.year}'),
          initialValue: l.year,
          decoration: const InputDecoration(labelText: '农历年份'),
          items: List.generate(
            201,
            (i) =>
                DropdownMenuItem(value: 1900 + i, child: Text('${1900 + i} 年')),
          ),
          onChanged: (v) => updateLunar(year: v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('lunar-month-${l.year}-${l.month}'),
                initialValue: l.month,
                decoration: const InputDecoration(labelText: '农历月份'),
                items: LunarDate.months(l.year)
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.getMonth(),
                        child: Text(LunarDate.monthText(m.getMonth())),
                      ),
                    )
                    .toList(),
                onChanged: (v) => updateLunar(month: v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('lunar-day-${l.year}-${l.month}-${l.day}'),
                initialValue: l.day,
                decoration: const InputDecoration(labelText: '农历日期'),
                items: List.generate(
                  l.dayCount,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(LunarDate.dayText(i + 1)),
                  ),
                ),
                onChanged: (v) => updateLunar(day: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        noteText('所选日期对应公历 ${dateText(date)}。更换年份或月份时，自动调整无效的闰月或三十。'),
        if (repeat == 'yearly' && !anniversary) ...[
          const SizedBox(height: 14),
          if (l.month < 0) ...[
            DropdownButtonFormField<String>(
              initialValue: lunarLeapPolicy,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '闰月生日规则'),
              items: const [
                DropdownMenuItem(
                  value: 'prefer-leap',
                  child: Text('有闰月过闰月，否则过普通月'),
                ),
                DropdownMenuItem(value: 'regular', child: Text('每年只过普通月')),
              ],
              onChanged: (v) => setState(() => lunarLeapPolicy = v!),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            initialValue: lunarShortPolicy,
            decoration: const InputDecoration(labelText: '三十遇到小月（只有廿九）'),
            items: const [
              DropdownMenuItem(value: 'last', child: Text('按本月最后一天（廿九）')),
              DropdownMenuItem(value: 'next', child: Text('按下个月初一')),
            ],
            onChanged: (v) => setState(() => lunarShortPolicy = v!),
          ),
        ],
        const SizedBox(height: 14),
        Builder(
          builder: (_) {
            final preview = Event(
              '预览',
              date,
              type: type,
              repeat: anniversary ? 'none' : repeat,
              lunarDate: l,
              lunarLeapPolicy: lunarLeapPolicy,
              lunarShortPolicy: lunarShortPolicy,
            );
            final target = preview.target(today);
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1E4D1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${anniversary ? '起始公历日期' : '本次公历日期'} ${dateText(target)}\n'
                '${LunarDate.fromSolar(target).text} · ${preview.direction(today)} ${preview.days(today).abs()} 天',
                style: const TextStyle(height: 1.8),
              ),
            );
          },
        ),
      ],
      const SizedBox(height: 12),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.event == null ? '记个日子' : '编辑日子',
        style: serif.copyWith(fontSize: 24),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'anniversary',
                      label: Text('纪念日'),
                      icon: Icon(Icons.favorite_border),
                    ),
                    ButtonSegment(
                      value: 'countdown',
                      label: Text('倒计时'),
                      icon: Icon(Icons.timelapse),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => changeType(s.first),
                ),
                const SizedBox(height: 14),
                noteText(
                  anniversary ? '记录已经走过的时光，累计天数一直增长。' : '给期待一个日期，生日可以每年自动重复。',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('🎂 生日模板'),
                      onPressed: birthdayTemplate,
                    ),
                    ActionChip(
                      label: const Text('♡ 相识纪念'),
                      onPressed: () {
                        changeType('anniversary');
                        if (title.text.isEmpty) title.text = '我们相识的日子';
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('event-title'),
                  controller: title,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: '事件名称',
                    hintText: '例如：妈妈的生日、我们相识的日子',
                  ),
                  validator: (s) =>
                      s == null || s.trim().isEmpty ? '请填写事件名称' : null,
                ),
                const SizedBox(height: 10),
                noteText('选择一个图标'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: ['♡', '🎂', '💍', '✈️', '🌱', '🏡', '🎓', '◷']
                      .map(
                        (s) => ChoiceChip(
                          label: Text(s, style: const TextStyle(fontSize: 20)),
                          selected: icon == s,
                          onSelected: (_) => setState(() => icon = s),
                          showCheckmark: false,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                ...calendarFields(),
                ListTile(
                  key: const Key('event-date'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_month_outlined,
                    color: accent,
                  ),
                  title: Text(
                    anniversary
                        ? '起始日期'
                        : birthday
                        ? (showAge ? '出生日期（包含年份）' : '生日日期（忽略年龄）')
                        : '目标日期',
                  ),
                  subtitle: Text(lunarDate?.text ?? dateText(date)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: lunarDate == null ? pickDate : null,
                ),
                if (!anniversary) ...[
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('这是生日'),
                    subtitle: const Text('每年重复，可选择显示年龄'),
                    value: birthday,
                    onChanged: (v) => setState(() {
                      birthday = v;
                      if (v) {
                        repeat = 'yearly';
                        icon = '🎂';
                      } else {
                        showAge = false;
                      }
                    }),
                  ),
                  if (birthday)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('填写出生年份并显示年龄'),
                      subtitle: const Text('关闭时只计算下一次生日，不显示岁数'),
                      value: showAge,
                      onChanged: (v) => setState(() => showAge = v),
                    ),
                  if (!birthday)
                    DropdownButtonFormField<String>(
                      key: ValueKey('repeat-$repeat'),
                      initialValue: repeat,
                      decoration: const InputDecoration(labelText: '重复规则'),
                      items: ['none', if (lunarDate == null) 'weekly', 'yearly']
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(repeatLabel(v)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => repeat = v!),
                    ),
                ],
                if (anniversary)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('起始日算第 1 天'),
                    subtitle: const Text('默认当天为 0 天，第二天为 1 天'),
                    value: inclusive,
                    onChanged: (v) => setState(() => inclusive = v),
                  ),
                if (!anniversary &&
                    repeat == 'yearly' &&
                    lunarDate == null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: leapPolicy,
                    decoration: const InputDecoration(
                      labelText: '2 月 29 日在非闰年按哪天计算',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'feb28', child: Text('2 月 28 日')),
                      DropdownMenuItem(value: 'mar1', child: Text('3 月 1 日')),
                    ],
                    onChanged: (v) => setState(() => leapPolicy = v!),
                  ),
                  const SizedBox(height: 8),
                  noteText('当天显示“就是今天”，次日自动计算下一次。'),
                ],
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('置顶关注这个日子'),
                  value: pinned,
                  onChanged: (v) => setState(() => pinned = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notes,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    hintText: '留下一句话，记住当时的心情',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('save-event'),
                  onPressed: submit,
                  child: const Text('保存日子'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
