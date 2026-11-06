import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'event.dart';
import 'store.dart';
import 'appearance.dart';
import 'editor.dart';
import 'details.dart';
export 'editor.dart' show Editor;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DaysApp());
}

class DaysApp extends StatelessWidget {
  const DaysApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '日子有数',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: appTheme(),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  final EventStore? store;
  final DateTime Function() clock;
  const Home({super.key, this.store, this.clock = DateTime.now});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  late final EventStore store;
  String filter = 'all';
  List<Event> events = [];
  bool loading = true;
  bool busy = false;
  String? loadError;
  Timer? timer;
  late DateTime now;
  @override
  void initState() {
    super.initState();
    store = widget.store ?? EventStore();
    now = widget.clock();
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => now = widget.clock());
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => now = widget.clock());
    }
  }

  Future<void> load() async {
    try {
      final loaded = await store.load();
      if (mounted) {
        setState(() {
          events = loaded;
          loading = false;
          loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = '无法读取本地数据：$e';
        });
      }
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> save(List<Event> next) async {
    if (busy || loadError != null) return;
    setState(() => busy = true);
    try {
      await store.save(next);
      if (mounted) setState(() => events = next);
    } catch (e) {
      message('保存失败，原数据保留：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([Event? event]) async {
    final result = await Navigator.of(context).push<Event>(
      MaterialPageRoute(
        builder: (_) => Editor(event: event, now: now),
      ),
    );
    if (result == null || !mounted) return;
    if (events.any((e) => !identical(e, event) && e.key == result.key)) {
      message('已有相同事件');
      return;
    }
    final next = [...events];
    if (event == null) {
      next.add(result);
    } else {
      next[next.indexOf(event)] = result;
    }
    await save(next);
  }

  Future<void> remove(Event event) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除事件？'),
        content: Text(event.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await save(events.where((e) => !identical(e, event)).toList());
    }
  }

  Future<void> importFile() async {
    try {
      final f = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
      );
      if (f == null || !mounted) return;
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in f.readAsByteStream()) {
        if (buffer.length + chunk.length > 5 * 1024 * 1024) {
          throw const FormatException('文件不能超过 5 MB');
        }
        buffer.add(chunk);
      }
      final bytes = buffer.takeBytes();
      final batch = parseImport(
        utf8.decode(bytes),
        csv: f.extension?.toLowerCase() == 'csv',
      );
      final keys = events.map((e) => e.key).toSet();
      final additions = batch.events.where((e) => keys.add(e.key)).toList();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入预览'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '新增 ${additions.length} 条 · 重复跳过 ${batch.events.length - additions.length} 条',
                  ),
                  const SizedBox(height: 12),
                  ...additions
                      .take(20)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${e.icon} ${e.title}\n${e.displayDate} · ${e.isAnniversary ? '纪念日' : '倒计时'} · ${repeatLabel(e.repeat)}',
                          ),
                        ),
                      ),
                  if (additions.length > 20) const Text('其余事件已通过格式校验，确认后一起导入。'),
                  if (batch.errors.isNotEmpty)
                    Text(
                      '发现 ${batch.errors.length} 条错误，本次不能导入。请修正文件后重试。\n${batch.errors.take(10).join('\n')}',
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: additions.isEmpty || batch.errors.isNotEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('确认合并'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) await save([...events, ...additions]);
    } catch (e) {
      message('导入失败：$e\n请使用 UTF-8 编码的 CSV 或 JSON 文件');
    }
  }

  Future<void> exportFile() async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(encodeEvents(events))),
              mimeType: 'application/json',
              name: 'days-backup.json',
            ),
          ],
          fileNameOverrides: ['days-${dateText(now)}.json'],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      message('导出失败：$e');
    }
  }

  Future<void> details(Event event) async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EventDetails(event: event, now: now),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await edit(event);
    } else if (action == 'delete') {
      await remove(event);
    } else {
      await save(
        events
            .map(
              (e) => identical(e, event)
                  ? (action == 'pin'
                        ? e.copyWith(pinned: !e.pinned)
                        : e.copyWith(archived: !e.archived))
                  : e,
            )
            .toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted =
        events
            .where(
              (e) => filter == 'archived'
                  ? e.archived
                  : !e.archived && (filter == 'all' || e.type == filter),
            )
            .toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return a.days(now).abs().compareTo(b.days(now).abs());
          });
    final disabled = loading || busy || loadError != null;
    final featured = sorted.isEmpty ? null : sorted.first;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 82,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '日子有数',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 25,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'D A Y S   T O   R E M E M B E R',
              style: TextStyle(color: muted, fontSize: 9),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '从电脑文件导入',
            onPressed: disabled ? null : importFile,
            icon: const Icon(Icons.file_upload_outlined, size: 22),
          ),
          PopupMenuButton<String>(
            enabled: !disabled,
            onSelected: (_) => exportFile(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('导出 JSON 备份')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: paper,
            border: Border(top: BorderSide(color: line)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: disabled
                    ? null
                    : () => setState(() => filter = 'all'),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_view_outlined, size: 22),
                    SizedBox(height: 4),
                    Text('我的日子', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              FilledButton(
                onPressed: disabled ? null : () => edit(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.add, semanticLabel: '记个日子'),
              ),
              TextButton(
                onPressed: disabled ? null : importFile,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.file_upload_outlined, size: 22),
                    SizedBox(height: 4),
                    Text('电脑导入', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loadError!),
                    TextButton(onPressed: load, child: const Text('重试读取')),
                  ],
                ),
              ),
            )
          : AbsorbPointer(
              absorbing: busy,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${now.year} 年 ${now.month.toString().padLeft(2, '0')} 月 ${now.day.toString().padLeft(2, '0')} 日 · 星期${['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1]}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 26),
                              RichText(
                                text: TextSpan(
                                  style: serif.copyWith(
                                    fontSize: 27,
                                    height: 1.5,
                                  ),
                                  children: const [
                                    TextSpan(text: '有些日子，\n想一直'),
                                    TextSpan(
                                      text: '记在心里。',
                                      style: TextStyle(color: accent),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 26),
                              if (featured != null)
                                hero(featured)
                              else if (events.isEmpty)
                                emptyHero(),
                              const SizedBox(height: 22),
                              Wrap(
                                spacing: 6,
                                runSpacing: 5,
                                children: [
                                  for (final item in const [
                                    ('all', '全部'),
                                    ('anniversary', '纪念日'),
                                    ('countdown', '倒计时'),
                                    ('archived', '归档'),
                                  ])
                                    ChoiceChip(
                                      key: Key('filter-${item.$1}'),
                                      label: Text(item.$2),
                                      selected: filter == item.$1,
                                      showCheckmark: false,
                                      selectedColor: ink,
                                      labelStyle: TextStyle(
                                        color: filter == item.$1
                                            ? Colors.white
                                            : muted,
                                        fontSize: 12,
                                      ),
                                      side: BorderSide.none,
                                      backgroundColor: paper,
                                      shape: const StadiumBorder(),
                                      onSelected: (_) =>
                                          setState(() => filter = item.$1),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Text(
                                    filter == 'archived'
                                        ? '珍藏在这里的日子'
                                        : '属于你的时光',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${sorted.length} 个日子',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (sorted.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 30,
                                  ),
                                  child: Center(
                                    child: noteText(
                                      filter == 'archived'
                                          ? '还没有归档的日子'
                                          : '还没有这个分类的日子，点 + 记下第一件事。',
                                    ),
                                  ),
                                ),
                              if (busy) const LinearProgressIndicator(),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        sliver: SliverList.builder(
                          itemCount: sorted.length,
                          itemBuilder: (_, i) => eventTile(sorted[i]),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
                          child: Text(
                            '只保存在这台设备 · 记得导出备份',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, color: muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget emptyHero() => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: peach,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('♡', style: TextStyle(fontSize: 40, color: accent)),
        const SizedBox(height: 16),
        Text('给时光，留一个位置。', style: serif.copyWith(fontSize: 25)),
        const SizedBox(height: 10),
        noteText('记下相识的日子，期待下一次生日。'),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => edit(), child: const Text('添加第一个日子')),
      ],
    ),
  );
  Widget hero(Event e) => Semantics(
    button: true,
    label: '${e.title} ${e.direction(now)} ${numberText(e.days(now))} 天，查看详情',
    child: Material(
      color: peach,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => details(e),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: 20,
              child: IgnorePointer(
                child: Container(
                  width: 158,
                  height: 158,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC79B7D)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.favorite_border,
                      size: 65,
                      color: Color(0xFFCC9E81),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.pinned ? 'PINNED / 特别关注' : 'A DAY TO REMEMBER',
                    style: const TextStyle(
                      color: Color(0xFF9B6B51),
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Padding(
                    padding: const EdgeInsets.only(right: 35),
                    child: Text(
                      e.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.direction(now),
                    style: const TextStyle(
                      color: Color(0xFF96735B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${numberText(e.days(now))} 天',
                      style: serif.copyWith(fontSize: 60),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Divider(color: Color(0xFFCBA78D)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${dateText(e.isAnniversary ? e.date : e.target(now))} ${e.isAnniversary ? '起' : '目标日'}',
                          style: const TextStyle(
                            color: Color(0xFF96735B),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Text(
                        '查看这个日子 ↗',
                        style: TextStyle(
                          color: Color(0xFF96735B),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget eventTile(Event e) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => details(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
          child: Row(
            children: [
              eventBadge(e.icon, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.title}${e.pinned ? '  ⌁' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${dateText(e.target(now))} · ${e.isAnniversary
                          ? '纪念日'
                          : e.repeat == 'none'
                          ? '倒计时'
                          : repeatLabel(e.repeat)}${e.isLunar ? ' · 农历' : ''}',
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      e.direction(now),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        color: e.isAnniversary ? muted : accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${numberText(e.days(now))} 天',
                        style: serif.copyWith(fontSize: 27),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
