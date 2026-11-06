import 'package:flutter/material.dart';
import 'appearance.dart';
import 'event.dart';

class EventDetails extends StatelessWidget {
  final Event event;
  final DateTime now;
  const EventDetails({super.key, required this.event, required this.now});
  @override
  Widget build(BuildContext context) {
    final e = event;
    final age = e.age(now);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text('这个日子', style: serif.copyWith(fontSize: 24))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(26),
            children: [
              const SizedBox(height: 20),
              Center(child: eventBadge(e.icon, size: 42)),
              const SizedBox(height: 24),
              Text(
                e.title,
                textAlign: TextAlign.center,
                style: serif.copyWith(fontSize: 28, height: 1.4),
              ),
              const SizedBox(height: 20),
              Text(
                e.direction(now),
                textAlign: TextAlign.center,
                style: const TextStyle(color: accent),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${numberText(e.days(now))} 天',
                    style: serif.copyWith(fontSize: 64),
                  ),
                ),
              ),
              if (age != null && age >= 0)
                Text(
                  e.days(now) == 0 ? '今天满 $age 岁，生日快乐！' : '即将迎来 $age 岁生日',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: accent),
                ),
              const SizedBox(height: 26),
              const Divider(),
              row(
                '事件类型',
                e.isAnniversary
                    ? '纪念日'
                    : e.birthday
                    ? '生日倒计时'
                    : '倒计时',
              ),
              row(e.isAnniversary ? '起始日期' : '设置日期', e.displayDate),
              if (e.isAnniversary) ...[
                row(
                  '下一个周年',
                  '${dateText(e.nextAnniversary(now))} · 还有 ${e.nextAnniversary(now).difference(dayOnly(now)).inDays} 天',
                ),
                row('计数方式', e.inclusive ? '起始日算第 1 天' : '按日期差计算'),
              ] else ...[
                row('本次目标', dateText(e.target(now))),
                row('重复规则', repeatLabel(e.repeat)),
                if (!e.isLunar &&
                    e.repeat == 'yearly' &&
                    e.date.month == 2 &&
                    e.date.day == 29)
                  row('非闰年计算', e.leapPolicy == 'mar1' ? '3 月 1 日' : '2 月 28 日'),
              ],
              if (e.isLunar) ...[
                row('原始公历日期', dateText(e.date)),
                if (e.lunarDate!.month < 0 && e.repeat == 'yearly')
                  row(
                    '闰月规则',
                    e.lunarLeapPolicy == 'regular'
                        ? '每年只过普通月'
                        : '有闰月过闰月，否则过普通月',
                  ),
                if (e.repeat == 'yearly')
                  row('三十遇小月', e.lunarShortPolicy == 'next' ? '下月初一' : '本月廿九'),
              ],
              if (e.notes.isNotEmpty) ...[
                const Divider(),
                noteText('留给这个日子的话'),
                const SizedBox(height: 12),
                Text(e.notes, style: const TextStyle(height: 1.8)),
                const SizedBox(height: 16),
              ],
              const Divider(),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'edit'),
                child: const Text('编辑日子'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'pin'),
                icon: Icon(e.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                label: Text(e.pinned ? '取消置顶' : '置顶关注'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context, 'archive'),
                child: Text(e.archived ? '恢复到我的日子' : '归档这个日子'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                child: const Text(
                  '删除这个日子',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
