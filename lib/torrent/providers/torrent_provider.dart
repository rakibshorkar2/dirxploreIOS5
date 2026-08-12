import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/torrent_model.dart';
import '../models/torrent_file_model.dart';
import '../models/torrent_stats_model.dart';
import '../native/torrent_platform_channel.dart';
import '../services/torrent_event_service.dart';
import '../services/torrent_storage_service.dart';
import '../services/torrent_service.dart';

class TorrentProvider extends ChangeNotifier {
  final TorrentPlatformChannel _platformChannel = TorrentPlatformChannel();
  late final TorrentEventService _eventService;
  late final TorrentStorageService _storageService;
  late final TorrentService _torrentService;

  List<TorrentModel> _torrents = [];
  TorrentStatsModel _stats = TorrentStatsModel.empty();
  Map<String, dynamic> _settings = {};
  bool _isInitialized = false;
  String? _errorMessage;
  Timer? _statsTimer;

  TorrentProvider() {
    _eventService = TorrentEventService(_platformChannel);
    _storageService = TorrentStorageService();
    _torrentService = TorrentService(
      platformChannel: _platformChannel,
      storageService: _storageService,
    );
  }

  List<TorrentModel> get torrents => List.unmodifiable(_torrents);
  TorrentStatsModel get stats => _stats;
  Map<String, dynamic> get settings => Map.unmodifiable(_settings);
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  TorrentService get torrentService => _torrentService;

  int get totalDownloadSpeed => _stats.totalDownloadSpeed;
  int get totalUploadSpeed => _stats.totalUploadSpeed;
  int get activeCount => _torrents.where((t) => t.status == TorrentStatus.downloading || t.status == TorrentStatus.seeding).length;
  int get pausedCount => _torrents.where((t) => t.status == TorrentStatus.paused).length;
  int get completedCount => _torrents.where((t) => t.status == TorrentStatus.completed).length;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _storageService.init();
      _settings = await _storageService.loadSettings();

      final defaultPath = await _storageService.defaultSavePath;
      await _platformChannel.initialize(downloadDirectory: defaultPath);

      _eventService.startListening();
      _eventService.events.listen(_handleEvent);

      // Load saved torrent records
      final saved = await _storageService.loadSavedTorrents();
      _torrents = saved;

      // Sync with native engine
      final nativeTorrents = await _platformChannel.getTorrents();
      _mergeNativeTorrents(nativeTorrents);

      _startStatsTimer();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isInitialized) return;
      try {
        final newStats = await _platformChannel.getSessionStats();
        _stats = newStats;
        notifyListeners();
      } catch (_) {}
    });
  }

  void _handleEvent(TorrentEvent event) {
    if (event is TorrentAddedEvent) {
      final model = TorrentModel.fromJson(event.torrentData);
      _addOrUpdateTorrent(model);
    } else if (event is TorrentUpdatedEvent) {
      final model = TorrentModel.fromJson(event.torrentData);
      _addOrUpdateTorrent(model);
    } else if (event is TorrentRemovedEvent) {
      _torrents.removeWhere((t) => t.infoHash == event.infoHash.toLowerCase());
      _persistTorrents();
      notifyListeners();
    } else if (event is TorrentErrorEvent) {
      final index = _torrents.indexWhere((t) => t.infoHash == event.infoHash.toLowerCase());
      if (index != -1) {
        _torrents[index] = _torrents[index].copyWith(
          status: TorrentStatus.error,
          errorMessage: event.errorMessage,
        );
        notifyListeners();
      }
    } else if (event is TorrentMetadataReceivedEvent) {
      final model = TorrentModel.fromJson(event.torrentData);
      _addOrUpdateTorrent(model);
    } else if (event is TorrentCompletedEvent) {
      final index = _torrents.indexWhere((t) => t.infoHash == event.infoHash.toLowerCase());
      if (index != -1) {
        _torrents[index] = _torrents[index].copyWith(
          status: TorrentStatus.completed,
          progress: 1.0,
        );
        _persistTorrents();
        notifyListeners();
      }
    } else if (event is TorrentStatsUpdatedEvent) {
      _stats = TorrentStatsModel.fromJson(event.statsData);
      notifyListeners();
    }
  }

  void _addOrUpdateTorrent(TorrentModel model) {
    final index = _torrents.indexWhere((t) => t.infoHash == model.infoHash);
    if (index != -1) {
      _torrents[index] = model;
    } else {
      _torrents.add(model);
    }
    _persistTorrents();
    notifyListeners();
  }

  void _mergeNativeTorrents(List<TorrentModel> nativeTorrents) {
    final map = <String, TorrentModel>{for (var t in _torrents) t.infoHash: t};
    for (var nt in nativeTorrents) {
      map[nt.infoHash] = nt;
    }
    _torrents = map.values.toList();
    _persistTorrents();
  }

  Future<void> _persistTorrents() async {
    await _storageService.saveTorrents(_torrents);
  }

  TorrentModel? getTorrentByHash(String infoHash) {
    final target = infoHash.toLowerCase();
    try {
      return _torrents.firstWhere((t) => t.infoHash == target);
    } catch (_) {
      return null;
    }
  }

  bool isDuplicate(String infoHash) {
    return getTorrentByHash(infoHash) != null;
  }

  Future<TorrentModel?> addMagnet(String magnetUri, {String? savePath}) async {
    final extractedHash = _torrentService.extractInfoHashFromMagnet(magnetUri);
    if (extractedHash != null && isDuplicate(extractedHash)) {
      throw Exception('Torrent already exists in session.');
    }

    final path = savePath ?? await _storageService.defaultSavePath;
    final result = await _platformChannel.addMagnet(magnetUri, savePath: path);
    final model = TorrentModel.fromJson(result);
    _addOrUpdateTorrent(model);
    return model;
  }

  Future<TorrentModel?> addTorrentFile(String filePath, {String? savePath}) async {
    final path = savePath ?? await _storageService.defaultSavePath;
    final result = await _platformChannel.addTorrentFile(filePath, savePath: path);
    final model = TorrentModel.fromJson(result);

    if (isDuplicate(model.infoHash)) {
      throw Exception('Torrent already exists in session.');
    }

    _addOrUpdateTorrent(model);
    return model;
  }

  Future<void> pauseTorrent(String infoHash) async {
    await _platformChannel.pauseTorrent(infoHash);
    final index = _torrents.indexWhere((t) => t.infoHash == infoHash.toLowerCase());
    if (index != -1) {
      _torrents[index] = _torrents[index].copyWith(status: TorrentStatus.paused);
      _persistTorrents();
      notifyListeners();
    }
  }

  Future<void> resumeTorrent(String infoHash) async {
    await _platformChannel.resumeTorrent(infoHash);
    final index = _torrents.indexWhere((t) => t.infoHash == infoHash.toLowerCase());
    if (index != -1) {
      _torrents[index] = _torrents[index].copyWith(status: TorrentStatus.downloading);
      _persistTorrents();
      notifyListeners();
    }
  }

  Future<void> forceStartTorrent(String infoHash) async {
    await _platformChannel.forceStartTorrent(infoHash);
    final index = _torrents.indexWhere((t) => t.infoHash == infoHash.toLowerCase());
    if (index != -1) {
      _torrents[index] = _torrents[index].copyWith(status: TorrentStatus.downloading);
      _persistTorrents();
      notifyListeners();
    }
  }

  Future<void> recheckTorrent(String infoHash) async {
    await _platformChannel.recheckTorrent(infoHash);
    final index = _torrents.indexWhere((t) => t.infoHash == infoHash.toLowerCase());
    if (index != -1) {
      _torrents[index] = _torrents[index].copyWith(status: TorrentStatus.checking);
      notifyListeners();
    }
  }

  Future<void> removeTorrent(String infoHash, {bool deleteData = false}) async {
    await _platformChannel.removeTorrent(infoHash, deleteData: deleteData);
    _torrents.removeWhere((t) => t.infoHash == infoHash.toLowerCase());
    await _persistTorrents();
    notifyListeners();
  }

  Future<void> setFilePriority(String infoHash, int fileIndex, FilePriority priority) async {
    await _platformChannel.setFilePriority(infoHash, fileIndex, priority.rawValue);
    final torrentIndex = _torrents.indexWhere((t) => t.infoHash == infoHash.toLowerCase());
    if (torrentIndex != -1) {
      final updatedFiles = List<TorrentFileModel>.from(_torrents[torrentIndex].files);
      final fIndex = updatedFiles.indexWhere((f) => f.index == fileIndex);
      if (fIndex != -1) {
        updatedFiles[fIndex] = updatedFiles[fIndex].copyWith(priority: priority);
        _torrents[torrentIndex] = _torrents[torrentIndex].copyWith(files: updatedFiles);
        notifyListeners();
      }
    }
  }

  Future<void> setSequentialDownload(String infoHash, bool enabled) async {
    await _platformChannel.setSequentialDownload(infoHash, enabled);
    final index = _torrents.indexWhere((t) => t.infoHash == infoHash.toLowerCase());
    if (index != -1) {
      _torrents[index] = _torrents[index].copyWith(isSequential: enabled);
      notifyListeners();
    }
  }

  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    _settings = {..._settings, ...newSettings};
    await _storageService.saveSettings(_settings);

    if (newSettings.containsKey('globalDownloadLimit')) {
      await _platformChannel.setGlobalDownloadLimit(newSettings['globalDownloadLimit'] as int? ?? 0);
    }
    if (newSettings.containsKey('globalUploadLimit')) {
      await _platformChannel.setGlobalUploadLimit(newSettings['globalUploadLimit'] as int? ?? 0);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _eventService.dispose();
    super.dispose();
  }
}
