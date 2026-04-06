import 'dart:convert';
import 'dart:io';

import 'offline_queue_storage.dart';
import 'pending_offline_request.dart';

OfflineQueueStorage createOfflineFileQueueStorageImpl(String absolutePath) =>
    FileJsonOfflineQueueStorage(absolutePath);

/// JSON file backing store — one array of request objects per line-free file.
class FileJsonOfflineQueueStorage implements OfflineQueueStorage {
  FileJsonOfflineQueueStorage(this._path);

  final String _path;

  File get _file => File(_path);

  @override
  Future<List<PendingOfflineRequest>> loadAll() async {
    if (!await _file.exists()) return [];
    final text = await _file.readAsString();
    if (text.trim().isEmpty) return [];
    final decoded = jsonDecode(text);
    if (decoded is! List) return [];
    return decoded
        .map((e) => PendingOfflineRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> saveAll(List<PendingOfflineRequest> items) async {
    final dir = _file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final encoded =
        const JsonEncoder.withIndent('  ').convert(items.map((e) => e.toJson()).toList());
    await _file.writeAsString(encoded);
  }
}
