import 'torrent_file_model.dart';
import 'torrent_peer_model.dart';
import 'torrent_tracker_model.dart';

enum TorrentStatus {
  checking,
  downloadingMetadata,
  downloading,
  seeding,
  paused,
  queued,
  completed,
  error;

  String get displayName {
    switch (this) {
      case TorrentStatus.checking:
        return 'Checking';
      case TorrentStatus.downloadingMetadata:
        return 'Downloading Metadata';
      case TorrentStatus.downloading:
        return 'Downloading';
      case TorrentStatus.seeding:
        return 'Seeding';
      case TorrentStatus.paused:
        return 'Paused';
      case TorrentStatus.queued:
        return 'Queued';
      case TorrentStatus.completed:
        return 'Completed';
      case TorrentStatus.error:
        return 'Error';
    }
  }

  static TorrentStatus fromString(String? status) {
    if (status == null) return TorrentStatus.queued;
    switch (status.toLowerCase()) {
      case 'checking':
      case 'checking_files':
      case 'checking_resume_data':
        return TorrentStatus.checking;
      case 'downloadingmetadata':
      case 'downloading_metadata':
        return TorrentStatus.downloadingMetadata;
      case 'downloading':
        return TorrentStatus.downloading;
      case 'seeding':
        return TorrentStatus.seeding;
      case 'paused':
        return TorrentStatus.paused;
      case 'queued':
      case 'allocating':
        return TorrentStatus.queued;
      case 'completed':
      case 'finished':
        return TorrentStatus.completed;
      case 'error':
        return TorrentStatus.error;
      default:
        return TorrentStatus.queued;
    }
  }
}

class TorrentModel {
  final String infoHash;
  final String name;
  final TorrentStatus status;
  final double progress;
  final int downloadSpeed;
  final int uploadSpeed;
  final int totalSize;
  final int downloadedSize;
  final int uploadedSize;
  final int peers;
  final int seeds;
  final int leeches;
  final int etaSeconds;
  final double ratio;
  final String? magnetUri;
  final String? torrentFilePath;
  final String? savePath;
  final DateTime? addedDate;
  final String? errorMessage;
  final bool isSequential;
  final List<TorrentFileModel> files;
  final List<TorrentTrackerModel> trackers;
  final List<TorrentPeerModel> peerList;

  const TorrentModel({
    required this.infoHash,
    required this.name,
    required this.status,
    required this.progress,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.totalSize,
    required this.downloadedSize,
    required this.uploadedSize,
    required this.peers,
    required this.seeds,
    required this.leeches,
    required this.etaSeconds,
    required this.ratio,
    this.magnetUri,
    this.torrentFilePath,
    this.savePath,
    this.addedDate,
    this.errorMessage,
    this.isSequential = false,
    this.files = const [],
    this.trackers = const [],
    this.peerList = const [],
  });

  factory TorrentModel.fromJson(Map<String, dynamic> json) {
    final infoHash = (json['infoHash'] as String? ?? json['hash'] as String? ?? '').toLowerCase();
    final name = json['name'] as String? ?? 'Unnamed Torrent';
    final progress = (json['progress'] as num?)?.toDouble() ?? 0.0;
    final totalSize = json['totalSize'] as int? ?? json['total'] as int? ?? 0;
    final downloadedSize = json['downloadedSize'] as int? ?? json['totalDone'] as int? ?? 0;
    final uploadedSize = json['uploadedSize'] as int? ?? json['totalUpload'] as int? ?? 0;
    final downloadSpeed = json['downloadSpeed'] as int? ?? json['downloadRate'] as int? ?? 0;
    final uploadSpeed = json['uploadSpeed'] as int? ?? json['uploadRate'] as int? ?? 0;

    final ratio = downloadedSize > 0 ? (uploadedSize / downloadedSize) : 0.0;

    int etaSeconds = 0;
    if (downloadSpeed > 0 && totalSize > downloadedSize) {
      etaSeconds = ((totalSize - downloadedSize) / downloadSpeed).ceil();
    }

    final rawFiles = json['files'] as List?;
    final files = rawFiles != null
        ? rawFiles.map((f) => TorrentFileModel.fromJson(Map<String, dynamic>.from(f as Map))).toList()
        : <TorrentFileModel>[];

    final rawTrackers = json['trackers'] as List?;
    final trackers = rawTrackers != null
        ? rawTrackers.map((t) => TorrentTrackerModel.fromJson(Map<String, dynamic>.from(t as Map))).toList()
        : <TorrentTrackerModel>[];

    final rawPeers = json['peersList'] as List?;
    final peerList = rawPeers != null
        ? rawPeers.map((p) => TorrentPeerModel.fromJson(Map<String, dynamic>.from(p as Map))).toList()
        : <TorrentPeerModel>[];

    return TorrentModel(
      infoHash: infoHash,
      name: name,
      status: TorrentStatus.fromString(json['status'] as String?),
      progress: progress.clamp(0.0, 1.0),
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      totalSize: totalSize,
      downloadedSize: downloadedSize,
      uploadedSize: uploadedSize,
      peers: json['peers'] as int? ?? json['numberOfPeers'] as int? ?? 0,
      seeds: json['seeds'] as int? ?? json['numberOfSeeds'] as int? ?? 0,
      leeches: json['leeches'] as int? ?? json['numberOfLeechers'] as int? ?? 0,
      etaSeconds: json['etaSeconds'] as int? ?? etaSeconds,
      ratio: (json['ratio'] as num?)?.toDouble() ?? ratio,
      magnetUri: json['magnetUri'] as String? ?? json['magnetLink'] as String?,
      torrentFilePath: json['torrentFilePath'] as String?,
      savePath: json['savePath'] as String? ?? json['downloadPath'] as String?,
      addedDate: json['addedDate'] != null
          ? DateTime.tryParse(json['addedDate'].toString())
          : DateTime.now(),
      errorMessage: json['errorMessage'] as String?,
      isSequential: json['isSequential'] as bool? ?? false,
      files: files,
      trackers: trackers,
      peerList: peerList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'infoHash': infoHash,
      'name': name,
      'status': status.name,
      'progress': progress,
      'downloadSpeed': downloadSpeed,
      'uploadSpeed': uploadSpeed,
      'totalSize': totalSize,
      'downloadedSize': downloadedSize,
      'uploadedSize': uploadedSize,
      'peers': peers,
      'seeds': seeds,
      'leeches': leeches,
      'etaSeconds': etaSeconds,
      'ratio': ratio,
      'magnetUri': magnetUri,
      'torrentFilePath': torrentFilePath,
      'savePath': savePath,
      'addedDate': addedDate?.toIso8601String(),
      'errorMessage': errorMessage,
      'isSequential': isSequential,
      'files': files.map((f) => f.toJson()).toList(),
      'trackers': trackers.map((t) => t.toJson()).toList(),
      'peerList': peerList.map((p) => p.toJson()).toList(),
    };
  }

  TorrentModel copyWith({
    String? infoHash,
    String? name,
    TorrentStatus? status,
    double? progress,
    int? downloadSpeed,
    int? uploadSpeed,
    int? totalSize,
    int? downloadedSize,
    int? uploadedSize,
    int? peers,
    int? seeds,
    int? leeches,
    int? etaSeconds,
    double? ratio,
    String? magnetUri,
    String? torrentFilePath,
    String? savePath,
    DateTime? addedDate,
    String? errorMessage,
    bool? isSequential,
    List<TorrentFileModel>? files,
    List<TorrentTrackerModel>? trackers,
    List<TorrentPeerModel>? peerList,
  }) {
    return TorrentModel(
      infoHash: infoHash ?? this.infoHash,
      name: name ?? this.name,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      totalSize: totalSize ?? this.totalSize,
      downloadedSize: downloadedSize ?? this.downloadedSize,
      uploadedSize: uploadedSize ?? this.uploadedSize,
      peers: peers ?? this.peers,
      seeds: seeds ?? this.seeds,
      leeches: leeches ?? this.leeches,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      ratio: ratio ?? this.ratio,
      magnetUri: magnetUri ?? this.magnetUri,
      torrentFilePath: torrentFilePath ?? this.torrentFilePath,
      savePath: savePath ?? this.savePath,
      addedDate: addedDate ?? this.addedDate,
      errorMessage: errorMessage ?? this.errorMessage,
      isSequential: isSequential ?? this.isSequential,
      files: files ?? this.files,
      trackers: trackers ?? this.trackers,
      peerList: peerList ?? this.peerList,
    );
  }
}
