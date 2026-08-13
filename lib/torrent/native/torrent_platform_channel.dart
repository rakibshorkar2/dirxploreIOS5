import 'dart:async';
import 'package:flutter/services.dart';
import '../models/torrent_model.dart';
import '../models/torrent_stats_model.dart';
import '../models/torrent_peer_model.dart';
import '../models/torrent_tracker_model.dart';

/// MethodChannel contract for the Torrent engine.
///
/// Channels:
///   com.dirxplore.torrent        - method channel
///   com.dirxplore.torrent_events - event channel
///
/// This class is a thin wrapper around the iOS MethodChannel/EventChannel
/// used by the Torrent engine.
class TorrentPlatformChannel {
  static const MethodChannel _methodChannel =
      MethodChannel('com.dirxplore.torrent');
  static const EventChannel _eventChannel =
      EventChannel('com.dirxplore.torrent_events');

  Stream<dynamic>? _eventStream;

  Stream<dynamic> get eventStream {
    _eventStream ??= _eventChannel.receiveBroadcastStream();
    return _eventStream!;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<bool> initialize({
    String? downloadDirectory,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('initialize', {
        'downloadDirectory': downloadDirectory,
        if (settings != null) 'settings': settings,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to initialize Torrent engine: ${e.message}');
    }
  }

  Future<bool> shutdown() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('shutdown');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to shutdown Torrent engine: ${e.message}');
    }
  }

  // ── Add Torrents ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> addMagnet(String magnetUri,
      {String? savePath}) async {
    try {
      final result =
          await _methodChannel.invokeMapMethod<String, dynamic>('addMagnet', {
        'magnetUri': magnetUri,
        'savePath': savePath,
      });
      return result ?? {};
    } on PlatformException catch (e) {
      throw Exception('Failed to add magnet link: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> addTorrentFile(String filePath,
      {String? savePath}) async {
    try {
      final result = await _methodChannel
          .invokeMapMethod<String, dynamic>('addTorrentFile', {
        'filePath': filePath,
        'savePath': savePath,
      });
      return result ?? {};
    } on PlatformException catch (e) {
      throw Exception('Failed to add torrent file: ${e.message}');
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Future<bool> removeTorrent(String infoHash, {bool deleteData = false}) async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('removeTorrent', {
        'infoHash': infoHash,
        'deleteData': deleteData,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to remove torrent: ${e.message}');
    }
  }

  Future<bool> pauseTorrent(String infoHash) async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('pauseTorrent', {'infoHash': infoHash});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to pause torrent: ${e.message}');
    }
  }

  Future<bool> resumeTorrent(String infoHash) async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('resumeTorrent', {'infoHash': infoHash});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to resume torrent: ${e.message}');
    }
  }

  Future<bool> forceStartTorrent(String infoHash) async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('forceStartTorrent', {'infoHash': infoHash});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to force start torrent: ${e.message}');
    }
  }

  Future<bool> recheckTorrent(String infoHash) async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('recheckTorrent', {'infoHash': infoHash});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to recheck torrent: ${e.message}');
    }
  }

  // ── File Priority / Sequential ─────────────────────────────────────────────

  Future<bool> setFilePriority(
      String infoHash, int fileIndex, int priority) async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('setFilePriority', {
        'infoHash': infoHash,
        'fileIndex': fileIndex,
        'priority': priority,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set file priority: ${e.message}');
    }
  }

  Future<bool> setSequentialDownload(String infoHash, bool enabled) async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('setSequentialDownload', {
        'infoHash': infoHash,
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set sequential download: ${e.message}');
    }
  }

  // ── Session Settings ────────────────────────────────────────────────────────

  /// Send a full settings dictionary to the native engine.
  /// The engine applies everything in one pass.
  Future<bool> configureSession(Map<String, dynamic> settings) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
          'configureSession', settings);
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to configure session: ${e.message}');
    }
  }

  Future<bool> setGlobalDownloadLimit(int limitBytesPerSec) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
          'setGlobalDownloadLimit', {'limit': limitBytesPerSec});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set global download limit: ${e.message}');
    }
  }

  Future<bool> setGlobalUploadLimit(int limitBytesPerSec) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
          'setGlobalUploadLimit', {'limit': limitBytesPerSec});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set global upload limit: ${e.message}');
    }
  }

  Future<bool> setDHTEnabled(bool enabled) async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('setDHTEnabled', {'enabled': enabled});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set DHT: ${e.message}');
    }
  }

  Future<bool> setUPnPEnabled(bool enabled) async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('setUPnPEnabled', {'enabled': enabled});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set UPnP: ${e.message}');
    }
  }

  Future<bool> setNATPMPEnabled(bool enabled) async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('setNATPMPEnabled', {'enabled': enabled});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set NAT-PMP: ${e.message}');
    }
  }

  Future<bool> setListeningPort(int port) async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('setListeningPort', {'port': port});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set listening port: ${e.message}');
    }
  }

  Future<bool> setMaxConnections(int maxConn) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
          'setMaxConnections', {'maxConnections': maxConn});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set max connections: ${e.message}');
    }
  }

  Future<bool> setMaxConnectionsPerTorrent(int maxConn) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
          'setMaxConnectionsPerTorrent',
          {'maxConnectionsPerTorrent': maxConn});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception(
          'Failed to set max connections per torrent: ${e.message}');
    }
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  Future<List<TorrentModel>> getTorrents() async {
    try {
      final result =
          await _methodChannel.invokeListMethod<Map>('getTorrents');
      if (result == null) return [];
      return result
          .map((item) =>
              TorrentModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to get torrent list: ${e.message}');
    }
  }

  Future<TorrentStatsModel> getSessionStats() async {
    try {
      final result =
          await _methodChannel.invokeMapMethod<String, dynamic>('getSessionStats');
      if (result == null) return TorrentStatsModel.empty();
      return TorrentStatsModel.fromJson(result);
    } on PlatformException catch (_) {
      return TorrentStatsModel.empty();
    }
  }

  /// Fetch real peer list for a specific torrent from libtorrent.
  Future<List<TorrentPeerModel>> getPeers(String infoHash) async {
    try {
      final result = await _methodChannel
          .invokeListMethod<Map>('getPeers', {'infoHash': infoHash});
      if (result == null) return [];
      return result
          .map((item) =>
              TorrentPeerModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on PlatformException catch (_) {
      return [];
    }
  }

  /// Fetch real tracker list for a specific torrent from libtorrent.
  Future<List<TorrentTrackerModel>> getTrackers(String infoHash) async {
    try {
      final result = await _methodChannel
          .invokeListMethod<Map>('getTrackers', {'infoHash': infoHash});
      if (result == null) return [];
      return result
          .map((item) =>
              TorrentTrackerModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on PlatformException catch (_) {
      return [];
    }
  }
}
