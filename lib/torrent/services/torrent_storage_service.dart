import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/torrent_model.dart';

class TorrentStorageService {
  Directory? _torrentDir;
  File? _dbFile;
  File? _settingsFile;

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _torrentDir = Directory(p.join(docs.path, 'Torrents'));
    if (!await _torrentDir!.exists()) {
      await _torrentDir!.create(recursive: true);
    }

    _dbFile = File(p.join(_torrentDir!.path, 'torrent_db.json'));
    _settingsFile = File(p.join(_torrentDir!.path, 'torrent_settings.json'));
  }

  Future<String> get defaultSavePath async {
    if (_torrentDir == null) await init();
    final downloadsDir = Directory(p.join(_torrentDir!.path, 'Downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir.path;
  }

  Future<String> get torrentsMetaPath async {
    if (_torrentDir == null) await init();
    final metaDir = Directory(p.join(_torrentDir!.path, 'Meta'));
    if (!await metaDir.exists()) {
      await metaDir.create(recursive: true);
    }
    return metaDir.path;
  }

  Future<List<TorrentModel>> loadSavedTorrents() async {
    if (_dbFile == null) await init();
    if (!await _dbFile!.exists()) return [];

    try {
      final content = await _dbFile!.readAsString();
      if (content.trim().isEmpty) return [];
      final List<dynamic> list = jsonDecode(content);
      return list
          .map((item) => TorrentModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveTorrents(List<TorrentModel> torrents) async {
    if (_dbFile == null) await init();
    try {
      final data = torrents.map((t) => t.toJson()).toList();
      await _dbFile!.writeAsString(jsonEncode(data));
    } catch (e) {
      // Log error silently
    }
  }

  Future<Map<String, dynamic>> loadSettings() async {
    if (_settingsFile == null) await init();
    if (!await _settingsFile!.exists()) return _defaultSettings();

    try {
      final content = await _settingsFile!.readAsString();
      if (content.trim().isEmpty) return _defaultSettings();
      return Map<String, dynamic>.from(jsonDecode(content) as Map);
    } catch (e) {
      return _defaultSettings();
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    if (_settingsFile == null) await init();
    try {
      await _settingsFile!.writeAsString(jsonEncode(settings));
    } catch (e) {
      // Log error silently
    }
  }

  Map<String, dynamic> _defaultSettings() {
    return {
      'globalDownloadLimit': 0, // 0 = unlimited
      'globalUploadLimit': 0, // 0 = unlimited
      'listenPort': 6881,
      'randomizePort': true,
      'enableDht': true,
      'enableUpnp': true,
      'maxConnections': 200,
      'maxConnectionsPerTorrent': 50,
      'maxActiveDownloads': 3,
      'maxActiveSeeds': 3,
      'sequentialDownload': false,
    };
  }
}
