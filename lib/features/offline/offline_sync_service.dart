import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/supabase_client.dart';

/// Offline-First Sync Engine
/// - Queues mutations when offline
/// - Auto-syncs when connectivity returns
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._();

  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  void start() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
      if (online) {
        syncQueue();
      }
    });
  }

  void stop() {
    _connectivitySub?.cancel();
  }

  /// Add operation to offline queue
  Future<void> enqueue({
    required String table,
    required String action, // insert | update | delete
    required Map<String, dynamic> data,
    String? recordId,
  }) async {
    final box = Hive.box(AppConstants.syncQueueBox);
    await box.add({
      'table': table,
      'action': action,
      'data': data,
      'record_id': recordId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Process all queued operations
  Future<void> syncQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final box = Hive.box(AppConstants.syncQueueBox);
    final keys = box.keys.toList();

    for (final key in keys) {
      final item = Map<String, dynamic>.from(box.get(key));
      try {
        final table = item['table'] as String;
        final action = item['action'] as String;
        final data = Map<String, dynamic>.from(item['data']);
        final recordId = item['record_id'] as String?;

        switch (action) {
          case 'insert':
            await SupabaseService.from(table).insert(data);
            break;
          case 'update':
            if (recordId != null) {
              await SupabaseService.from(table).update(data).eq('id', recordId);
            }
            break;
          case 'delete':
            if (recordId != null) {
              await SupabaseService.from(table).delete().eq('id', recordId);
            }
            break;
        }
        await box.delete(key);
      } catch (_) {
        // Keep in queue for next attempt
      }
    }

    _isSyncing = false;
  }

  /// Cache data locally for offline read
  Future<void> cacheTable(String table, List<Map<String, dynamic>> rows) async {
    final box = Hive.box(AppConstants.offlineBox);
    await box.put(table, rows);
  }

  List<Map<String, dynamic>> getCached(String table) {
    final box = Hive.box(AppConstants.offlineBox);
    final data = box.get(table);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }
}
