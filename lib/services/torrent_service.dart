import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../models/torrent_item.dart';

/// Flutter facade over the native iOS Torrent engine.
///
/// Talks to TorrentBridge on `com.dirxplore/ios_torrent` and listens on
/// `com.dirxplore/ios_torrent_events` for 1 Hz task snapshots. The engine
/// is iOS-only; on other platforms every method becomes a no-op.
class TorrentService {
  static final TorrentService _instance = TorrentService._internal();
  factory TorrentService() => _instance;

  static const MethodChannel _channel =
      MethodChannel('com.dirxplore/ios_torrent');
  static const EventChannel _events =
      EventChannel('com.dirxplore/ios_torrent_events');

  final bool _isIOS = Platform.isIOS;

  StreamSubscription? _eventSub;

  /// Full torrent snapshots, emitted every second while a listener exists.
  late final Stream<List<TorrentItem>> torrentUpdates;

  /// Info-hash events: `added` / `removed` / `error`.
  late final Stream<Map<String, dynamic>> torrentEvents;

  /// Settings passed to the native engine on initialize().
  Map<String, dynamic> settings = {
    'listenPort': 6881,
    'maxActiveTorrents': 3,
    'maxDownloadingTorrents': 2,
    'maxSeedingTorrents': 1,
    'downloadSpeedLimit': 0,
    'uploadSpeedLimit': 0,
    'dhtEnabled': true,
    'lsdEnabled': true,
    'utpEnabled': true,
    'upnpEnabled': true,
    'natpmpEnabled': true,
    'encryptionEnabled': true,
    'pauseOnBackground': true,
    'resumeOnLaunch': true,
  };

  TorrentService._internal() {
    torrentEvents = _events
        .receiveBroadcastStream()
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .asBroadcastStream();
    torrentUpdates = torrentEvents
        .where((event) => event['type'] == 'torrents')
        .map((event) {
      final raw = event['torrents'] as List<dynamic>? ?? const [];
      return raw
          .whereType<Map>()
          .map((e) => TorrentItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    });
    _eventSub = torrentEvents.listen((event) {
      // Reserved for future use; the provider consumes torrentUpdates.
    });
  }

  Future<void> initialize({Map<String, dynamic>? settings}) async {
    if (!_isIOS) return;
    final merged = {...this.settings, ...?settings};
    this.settings = merged;
    try {
      await _channel.invokeMethod<bool>('initialize', merged);
    } on PlatformException catch (e) {
      throw TorrentServiceException(e.message ?? 'Torrent engine failed to start');
    }
  }

  Future<bool> get isInitialized async {
    if (!_isIOS) return false;
    return await _channel.invokeMethod<bool>('isInitialized') ?? false;
  }

  Future<void> applySettings(Map<String, dynamic> settings) async {
    if (!_isIOS) return;
    this.settings = {...this.settings, ...settings};
    await _channel.invokeMethod('applySettings', this.settings);
  }

  Future<void> shutdown() async {
    if (!_isIOS) return;
    await _channel.invokeMethod('shutdown');
  }

  Future<String> addMagnet(String magnet) async {
    if (!_isIOS) return '';
    try {
      final hash = await _channel.invokeMethod<String>('addMagnet', {
        'magnet': magnet,
      });
      return hash ?? '';
    } on PlatformException catch (e) {
      throw TorrentServiceException(e.message ?? 'Failed to add magnet');
    }
  }

  Future<String> addTorrentFile(
    String path, {
    List<int>? selectedIndices,
    bool startPaused = false,
  }) async {
    if (!_isIOS) return '';
    try {
      final hash = await _channel.invokeMethod<String>('addTorrentFile', {
        'path': path,
        if (selectedIndices != null) 'selectedIndices': selectedIndices,
        'startPaused': startPaused,
      });
      return hash ?? '';
    } on PlatformException catch (e) {
      throw TorrentServiceException(e.message ?? 'Failed to add torrent file');
    }
  }

  Future<ParsedTorrentInfo?> parseTorrentFile(String path) async {
    if (!_isIOS) return null;
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'parseTorrentFile', {'path': path});
      if (map == null) return null;
      return ParsedTorrentInfo.fromMap(Map<String, dynamic>.from(map));
    } on PlatformException catch (e) {
      throw TorrentServiceException(e.message ?? 'Failed to parse torrent file');
    }
  }

  Future<void> pause(String infoHash) async {
    if (!_isIOS) return;
    await _channel.invokeMethod('pause', {'infoHash': infoHash});
  }

  Future<void> resume(String infoHash) async {
    if (!_isIOS) return;
    await _channel.invokeMethod('resume', {'infoHash': infoHash});
  }

  Future<void> remove(String infoHash, {bool deleteFiles = false}) async {
    if (!_isIOS) return;
    await _channel.invokeMethod('remove', {
      'infoHash': infoHash,
      'deleteFiles': deleteFiles,
    });
  }

  Future<void> recheck(String infoHash) async {
    if (!_isIOS) return;
    await _channel.invokeMethod('recheck', {'infoHash': infoHash});
  }

  Future<void> forceAnnounce(String infoHash) async {
    if (!_isIOS) return;
    await _channel.invokeMethod('forceAnnounce', {'infoHash': infoHash});
  }

  Future<void> setFilePriority(
      String infoHash, int index, TorrentFilePriority priority) async {
    if (!_isIOS) return;
    await _channel.invokeMethod('setFilePriority', {
      'infoHash': infoHash,
      'index': index,
      'priority': priority.raw,
    });
  }

  Future<void> setFilesPriority(
      String infoHash, List<int> indices, TorrentFilePriority priority) async {
    if (!_isIOS) return;
    await _channel.invokeMethod('setFilesPriority', {
      'infoHash': infoHash,
      'indices': indices,
      'priority': priority.raw,
    });
  }

  Future<void> setDownloadLimit(int bytesPerSecond) async {
    if (!_isIOS) return;
    await _channel.invokeMethod('setDownloadLimit', {
      'bytesPerSecond': bytesPerSecond,
    });
  }

  Future<void> setUploadLimit(int bytesPerSecond) async {
    if (!_isIOS) return;
    await _channel.invokeMethod('setUploadLimit', {
      'bytesPerSecond': bytesPerSecond,
    });
  }

  Future<List<TorrentItem>> getTorrents() async {
    if (!_isIOS) return [];
    final raw = await _channel.invokeMethod<List<dynamic>>('getTorrents');
    return (raw ?? [])
        .whereType<Map>()
        .map((e) => TorrentItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<TorrentItem?> getTorrent(String infoHash) async {
    if (!_isIOS) return null;
    final map = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('getTorrent', {'infoHash': infoHash});
    if (map == null) return null;
    return TorrentItem.fromMap(Map<String, dynamic>.from(map));
  }

  Future<String?> getDownloadPath() async {
    if (!_isIOS) return null;
    return await _channel.invokeMethod<String>('getDownloadPath');
  }

  Future<String?> pickDownloadFolder() async {
    if (!_isIOS) return null;
    return await _channel.invokeMethod<String>('pickDownloadFolder');
  }

  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
  }
}

class TorrentServiceException implements Exception {
  const TorrentServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
