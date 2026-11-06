import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'event.dart';

class EventStore {
  final Directory? directory;
  EventStore({this.directory});
  Future<File> get file async => File(
    '${(directory ?? await getApplicationDocumentsDirectory()).path}/events.json',
  );
  Future<List<Event>> load() async {
    final f = await file;
    if (!await f.exists()) return [];
    final batch = parseImport(await f.readAsString(), csv: false);
    if (batch.errors.isNotEmpty) throw const FormatException('本地数据损坏，请从备份恢复');
    final decoded = jsonDecode(await f.readAsString());
    if (decoded is! Map || decoded['version'] != 3) await save(batch.events);
    return batch.events;
  }

  Future<void> save(List<Event> events) async {
    final f = await file;
    if (await f.exists()) {
      final original = jsonDecode(await f.readAsString());
      final version = original is Map && original['version'] == 2 ? 2 : 1;
      final backup = File('${f.parent.path}/events-v$version-backup.json');
      if ((original is! Map || original['version'] != 3) &&
          !await backup.exists()) {
        await f.copy(backup.path);
      }
    }
    final temp = File('${f.path}.tmp');
    await temp.writeAsString(encodeEvents(events), flush: true);
    await temp.rename(f.path);
  }
}

String encodeEvents(List<Event> events) => const JsonEncoder.withIndent(
  '  ',
).convert({'version': 3, 'events': events.map((e) => e.toJson()).toList()});
