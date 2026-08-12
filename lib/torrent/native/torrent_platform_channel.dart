import 'dart:async';
import 'package:flutter/services.dart';
import '../models/torrent_model.dart';
import '../models/torrent_stats_model.dart';

class TorrentPlatformChannel {
  static const MethodChannel _methodChannel = MethodChannel('com.dirxplore.torrent');
  static const EventChannel _eventChannel = EventChannel('com.dirxplore.torrent_events');

  Stream<dynamic>? _eventStream;

  Stream<dynamic> get eventStream {
    _eventStream ??= _eventChannel.receiveBroadcastStream();
    return _eventStream!;
  }

  Future<bool> initialize({String? downloadDirectory}) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('initialize', {
        'downloadDirectory': downloadDirectory,
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

  Future<Map<String, dynamic>> addMagnet(String magnetUri, {String? savePath}) async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>('addMagnet', {
        'magnetUri': magnetUri,
        'savePath': savePath,
      });
      return result ?? {};
    } on PlatformException catch (e) {
      throw Exception('Failed to add magnet link: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> addTorrentFile(String filePath, {String? savePath}) async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>('addTorrentFile', {
        'filePath': filePath,
        'savePath': savePath,
      });
      return result ?? {};
    } on PlatformException catch (e) {
      throw Exception('Failed to add torrent file: ${e.message}');
    }
  }

  Future<bool> removeTorrent(String infoHash, {bool deleteData = false}) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('removeTorrent', {
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
      final result = await _methodChannel.invokeMethod<bool>('pauseTorrent', {
        'infoHash': infoHash,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to pause torrent: ${e.message}');
    }
  }

  Future<bool> resumeTorrent(String infoHash) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('resumeTorrent', {
        'infoHash': infoHash,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to resume torrent: ${e.message}');
    }
  }

  Future<bool> forceStartTorrent(String infoHash) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('forceStartTorrent', {
        'infoHash': infoHash,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to force start torrent: ${e.message}');
    }
  }

  Future<bool> recheckTorrent(String infoHash) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('recheckTorrent', {
        'infoHash': infoHash,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to recheck torrent: ${e.message}');
    }
  }

  Future<bool> setFilePriority(String infoHash, int fileIndex, int priority) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setFilePriority', {
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
      final result = await _methodChannel.invokeMethod<bool>('setSequentialDownload', {
        'infoHash': infoHash,
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set sequential download: ${e.message}');
    }
  }

  Future<bool> setGlobalDownloadLimit(int limitBytesPerSec) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setGlobalDownloadLimit', {
        'limit': limitBytesPerSec,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set global download limit: ${e.message}');
    }
  }

  Future<bool> setGlobalUploadLimit(int limitBytesPerSec) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setGlobalUploadLimit', {
        'limit': limitBytesPerSec,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set global upload limit: ${e.message}');
    }
  }

  Future<List<TorrentModel>> getTorrents() async {
    try {
      final result = await _methodChannel.invokeListMethod<Map>('getTorrents');
      if (result == null) return [];
      return result
          .map((item) => TorrentModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to get torrent list: ${e.message}');
    }
  }

  Future<TorrentStatsModel> getSessionStats() async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>('getSessionStats');
      if (result == null) return TorrentStatsModel.empty();
      return TorrentStatsModel.fromJson(result);
    } on PlatformException catch (_) {
      return TorrentStatsModel.empty();
    }
  }
}
