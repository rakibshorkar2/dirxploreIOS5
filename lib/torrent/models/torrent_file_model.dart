enum FilePriority {
  doNotDownload(0),
  normal(4),
  high(7);

  final int rawValue;
  const FilePriority(this.rawValue);

  static FilePriority fromRawValue(int value) {
    if (value <= 0) return FilePriority.doNotDownload;
    if (value >= 7) return FilePriority.high;
    return FilePriority.normal;
  }
}

class TorrentFileModel {
  final int index;
  final String path;
  final String name;
  final int size;
  final int downloaded;
  final FilePriority priority;
  final double progress;

  const TorrentFileModel({
    required this.index,
    required this.path,
    required this.name,
    required this.size,
    required this.downloaded,
    required this.priority,
    required this.progress,
  });

  factory TorrentFileModel.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as int? ?? 0;
    final downloaded = json['downloaded'] as int? ?? 0;
    final progress = size > 0 ? (downloaded / size).clamp(0.0, 1.0) : 0.0;

    return TorrentFileModel(
      index: json['index'] as int? ?? 0,
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? (json['path'] as String? ?? '').split('/').last,
      size: size,
      downloaded: downloaded,
      priority: FilePriority.fromRawValue(json['priority'] as int? ?? 1),
      progress: (json['progress'] as num?)?.toDouble() ?? progress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'path': path,
      'name': name,
      'size': size,
      'downloaded': downloaded,
      'priority': priority.rawValue,
      'progress': progress,
    };
  }

  TorrentFileModel copyWith({
    int? index,
    String? path,
    String? name,
    int? size,
    int? downloaded,
    FilePriority? priority,
    double? progress,
  }) {
    return TorrentFileModel(
      index: index ?? this.index,
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      downloaded: downloaded ?? this.downloaded,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
    );
  }
}
