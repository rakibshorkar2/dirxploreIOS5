/// Torrent subsystem Dart models. Mirrors the native iOS snapshot format
/// produced by TorrentTaskSerializer. All sizes are bytes, rates are
/// bytes per second.
library;

enum TorrentState {
  checkingFiles,
  downloadingMetadata,
  downloading,
  finished,
  seeding,
  checkingResumeData,
  paused,
  storageError,
  unknown;

  static TorrentState fromName(String? name) {
    switch (name) {
      case 'checkingFiles':
        return TorrentState.checkingFiles;
      case 'downloadingMetadata':
        return TorrentState.downloadingMetadata;
      case 'downloading':
        return TorrentState.downloading;
      case 'finished':
        return TorrentState.finished;
      case 'seeding':
        return TorrentState.seeding;
      case 'checkingResumeData':
        return TorrentState.checkingResumeData;
      case 'paused':
        return TorrentState.paused;
      case 'storageError':
        return TorrentState.storageError;
      default:
        return TorrentState.unknown;
    }
  }

  String get label {
    switch (this) {
      case TorrentState.checkingFiles:
        return 'Checking files';
      case TorrentState.downloadingMetadata:
        return 'Fetching metadata';
      case TorrentState.downloading:
        return 'Downloading';
      case TorrentState.finished:
        return 'Finished';
      case TorrentState.seeding:
        return 'Seeding';
      case TorrentState.checkingResumeData:
        return 'Checking resume data';
      case TorrentState.paused:
        return 'Paused';
      case TorrentState.storageError:
        return 'Storage error';
      case TorrentState.unknown:
        return 'Unknown';
    }
  }
}

/// File priority values matching libtorrent's FileEntry.Priority.
enum TorrentFilePriority {
  skip(0),
  low(1),
  normal(4),
  high(6),
  top(7);

  const TorrentFilePriority(this.raw);
  final int raw;

  static TorrentFilePriority fromRaw(int value) {
    switch (value) {
      case 0:
        return TorrentFilePriority.skip;
      case 1:
        return TorrentFilePriority.low;
      case 6:
        return TorrentFilePriority.high;
      case 7:
        return TorrentFilePriority.top;
      default:
        return TorrentFilePriority.normal;
    }
  }
}

class TorrentFileItem {
  final int index;
  final String name;
  final String path;
  final int size;
  final int downloaded;
  final int priority;
  final bool selected;

  const TorrentFileItem({
    required this.index,
    required this.name,
    required this.path,
    required this.size,
    required this.downloaded,
    required this.priority,
    required this.selected,
  });

  TorrentFilePriority get priorityLevel => TorrentFilePriority.fromRaw(priority);

  factory TorrentFileItem.fromMap(Map<String, dynamic> map) => TorrentFileItem(
        index: (map['index'] as num?)?.toInt() ?? 0,
        name: map['name'] as String? ?? '',
        path: map['path'] as String? ?? '',
        size: (map['size'] as num?)?.toInt() ?? 0,
        downloaded: (map['downloaded'] as num?)?.toInt() ?? 0,
        priority: (map['priority'] as num?)?.toInt() ?? 4,
        selected: map['selected'] as bool? ?? true,
      );
}

class TorrentTrackerItem {
  final String url;
  final String state;
  final String message;
  final int seeds;
  final int peers;
  final int leeches;

  const TorrentTrackerItem({
    required this.url,
    required this.state,
    required this.message,
    required this.seeds,
    required this.peers,
    required this.leeches,
  });

  factory TorrentTrackerItem.fromMap(Map<String, dynamic> map) =>
      TorrentTrackerItem(
        url: map['url'] as String? ?? '',
        state: map['state'] as String? ?? '',
        message: map['message'] as String? ?? '',
        seeds: (map['seeds'] as num?)?.toInt() ?? 0,
        peers: (map['peers'] as num?)?.toInt() ?? 0,
        leeches: (map['leeches'] as num?)?.toInt() ?? 0,
      );
}

class TorrentItem {
  final String infoHash;
  final String name;
  final TorrentState state;
  final double progress;
  final double progressWanted;
  final bool hasMetadata;
  final bool isPaused;
  final bool isFinished;
  final bool isSeed;
  final double downloadSpeed;
  final double uploadSpeed;
  final int numberOfPeers;
  final int numberOfSeeds;
  final int numberOfLeechers;
  final int numberOfTotalPeers;
  final int numberOfTotalSeeds;
  final int total;
  final int totalDone;
  final int totalWanted;
  final int totalWantedDone;
  final int totalDownload;
  final int totalUpload;
  final String magnetUri;
  final String torrentFilePath;
  final String downloadPath;
  final DateTime? addedDate;
  final List<TorrentFileItem> files;
  final List<TorrentTrackerItem> trackers;

  const TorrentItem({
    required this.infoHash,
    required this.name,
    required this.state,
    required this.progress,
    required this.progressWanted,
    required this.hasMetadata,
    required this.isPaused,
    required this.isFinished,
    required this.isSeed,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.numberOfPeers,
    required this.numberOfSeeds,
    required this.numberOfLeechers,
    required this.numberOfTotalPeers,
    required this.numberOfTotalSeeds,
    required this.total,
    required this.totalDone,
    required this.totalWanted,
    required this.totalWantedDone,
    required this.totalDownload,
    required this.totalUpload,
    required this.magnetUri,
    required this.torrentFilePath,
    required this.downloadPath,
    required this.addedDate,
    required this.files,
    required this.trackers,
  });

  double get progressPercent => (progress * 100).clamp(0.0, 100.0);

  int get etaSeconds {
    final remaining = total - totalDone;
    if (remaining <= 0 || downloadSpeed <= 0) return 0;
    return (remaining / downloadSpeed).round();
  }

  factory TorrentItem.fromMap(Map<String, dynamic> map) {
    final rawFiles = map['files'] as List<dynamic>? ?? const [];
    final rawTrackers = map['trackers'] as List<dynamic>? ?? const [];
    final addedMs = (map['addedDate'] as num?)?.toDouble() ?? 0;

    return TorrentItem(
      infoHash: map['infoHash'] as String? ?? '',
      name: map['name'] as String? ?? '',
      state: TorrentState.fromName(map['state'] as String?),
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      progressWanted: (map['progressWanted'] as num?)?.toDouble() ?? 0,
      hasMetadata: map['hasMetadata'] as bool? ?? false,
      isPaused: map['isPaused'] as bool? ?? false,
      isFinished: map['isFinished'] as bool? ?? false,
      isSeed: map['isSeed'] as bool? ?? false,
      downloadSpeed: (map['downloadSpeed'] as num?)?.toDouble() ?? 0,
      uploadSpeed: (map['uploadSpeed'] as num?)?.toDouble() ?? 0,
      numberOfPeers: (map['numberOfPeers'] as num?)?.toInt() ?? 0,
      numberOfSeeds: (map['numberOfSeeds'] as num?)?.toInt() ?? 0,
      numberOfLeechers: (map['numberOfLeechers'] as num?)?.toInt() ?? 0,
      numberOfTotalPeers: (map['numberOfTotalPeers'] as num?)?.toInt() ?? 0,
      numberOfTotalSeeds: (map['numberOfTotalSeeds'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      totalDone: (map['totalDone'] as num?)?.toInt() ?? 0,
      totalWanted: (map['totalWanted'] as num?)?.toInt() ?? 0,
      totalWantedDone: (map['totalWantedDone'] as num?)?.toInt() ?? 0,
      totalDownload: (map['totalDownload'] as num?)?.toInt() ?? 0,
      totalUpload: (map['totalUpload'] as num?)?.toInt() ?? 0,
      magnetUri: map['magnetUri'] as String? ?? '',
      torrentFilePath: map['torrentFilePath'] as String? ?? '',
      downloadPath: map['downloadPath'] as String? ?? '',
      addedDate:
          addedMs > 0 ? DateTime.fromMillisecondsSinceEpoch(addedMs.toInt()) : null,
      files: rawFiles
          .whereType<Map>()
          .map((e) => TorrentFileItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      trackers: rawTrackers
          .whereType<Map>()
          .map((e) => TorrentTrackerItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Summary of a parsed .torrent file, used for file-selection UI.
class ParsedTorrentInfo {
  final String name;
  final List<TorrentFileItem> files;

  const ParsedTorrentInfo({required this.name, required this.files});

  factory ParsedTorrentInfo.fromMap(Map<String, dynamic> map) {
    final rawFiles = map['files'] as List<dynamic>? ?? const [];
    return ParsedTorrentInfo(
      name: map['name'] as String? ?? '',
      files: rawFiles
          .whereType<Map>()
          .map((e) => TorrentFileItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
