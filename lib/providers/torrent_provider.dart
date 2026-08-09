import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../models/torrent_item.dart';
import '../services/torrent_service.dart';

/// State holder for the iOS Torrent subsystem. Mirrors the DownloadProvider
/// pattern: holds the live list, subscribes to native snapshots and exposes
/// typed actions. This provider is only active on iOS.
class TorrentProvider with ChangeNotifier {
  final TorrentService _service = TorrentService();

  List<TorrentItem> _torrents = [];
  Map<String, TorrentItem> _byHash = {};
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _lastError;

  StreamSubscription<List<TorrentItem>>? _updatesSub;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  final bool _isIOS = Platform.isIOS;

  List<TorrentItem> get torrents => _torrents;
  Map<String, TorrentItem> get byHash => _byHash;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  String? get lastError => _lastError;

  int get activeCount =>
      _torrents.where((t) => t.state == TorrentState.downloading).length;
  int get seedCount => _torrents.where((t) => t.state == TorrentState.seeding).length;

  Future<void> init() async {
    if (_isInitializing || _isInitialized) return;
    _isInitializing = true;
    _lastError = null;
    notifyListeners();

    try {
      if (_isIOS) {
        _eventsSub = _service.torrentEvents.listen(_handleTorrentEvent);
        _updatesSub = _service.torrentUpdates.listen(_applySnapshot);

        await _service.initialize();
        _applySnapshot(await _service.getTorrents());
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Torrent init failed: $e');
      _lastError = e.toString();
      await _updatesSub?.cancel();
      await _eventsSub?.cancel();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  void _handleTorrentEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final message = event['message'] as String?;
    if (type == 'error' && message != null) {
      _lastError = message;
      notifyListeners();
    }
  }

  void _applySnapshot(List<TorrentItem> tasks) {
    _torrents = tasks;
    _byHash = {for (final t in tasks) t.infoHash: t};
    notifyListeners();
  }

  Future<String> addMagnet(String magnet) async {
    _lastError = null;
    try {
      return await _service.addMagnet(magnet);
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<String> addTorrentFile(
    String path, {
    List<int>? selectedIndices,
    bool startPaused = false,
  }) async {
    _lastError = null;
    try {
      return await _service.addTorrentFile(
        path,
        selectedIndices: selectedIndices,
        startPaused: startPaused,
      );
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pause(String infoHash) async {
    await _service.pause(infoHash);
  }

  Future<void> resume(String infoHash) async {
    await _service.resume(infoHash);
  }

  Future<void> remove(String infoHash, {bool deleteFiles = false}) async {
    await _service.remove(infoHash, deleteFiles: deleteFiles);
  }

  Future<void> recheck(String infoHash) async {
    await _service.recheck(infoHash);
  }

  Future<void> forceAnnounce(String infoHash) async {
    await _service.forceAnnounce(infoHash);
  }

  Future<void> setFilePriority(
      String infoHash, int index, TorrentFilePriority priority) async {
    await _service.setFilePriority(infoHash, index, priority);
  }

  Future<void> setFilesPriority(
      String infoHash, List<int> indices, TorrentFilePriority priority) async {
    await _service.setFilesPriority(infoHash, indices, priority);
  }

  Future<void> setDownloadLimit(int bytesPerSecond) async {
    await _service.setDownloadLimit(bytesPerSecond);
  }

  Future<void> setUploadLimit(int bytesPerSecond) async {
    await _service.setUploadLimit(bytesPerSecond);
  }

  Future<void> applySettings(Map<String, dynamic> settings) async {
    await _service.applySettings(settings);
  }

  Future<ParsedTorrentInfo?> parseTorrentFile(String path) =>
      _service.parseTorrentFile(path);

  Future<String?> pickDownloadFolder() => _service.pickDownloadFolder();

  Future<void> refresh() async {
    _applySnapshot(await _service.getTorrents());
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }
}
