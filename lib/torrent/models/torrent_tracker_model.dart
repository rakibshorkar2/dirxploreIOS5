/// Represents real tracker state as reported by libtorrent.
/// All numeric fields are nullable — a value of null means "not yet known"
/// (do NOT substitute fake zero/working defaults).
class TorrentTrackerModel {
  final String url;
  /// Possible values: 'queued' | 'updating' | 'working' | 'error' | 'unknown'
  final String status;
  final int? seeds;
  final int? peers;
  final int? leeches;
  final int? downloaded;
  final String? message;

  const TorrentTrackerModel({
    required this.url,
    required this.status,
    this.seeds,
    this.peers,
    this.leeches,
    this.downloaded,
    this.message,
  });

  factory TorrentTrackerModel.fromJson(Map<String, dynamic> json) {
    return TorrentTrackerModel(
      url: json['url'] as String? ?? '',
      // Accept only the states the native engine actually emits
      status: _normalizeStatus(json['status'] as String?),
      seeds: _nullableInt(json['seeds']),
      peers: _nullableInt(json['peers']),
      leeches: _nullableInt(json['leeches']),
      downloaded: _nullableInt(json['downloaded']),
      message: (json['message'] is String && (json['message'] as String).isNotEmpty)
          ? json['message'] as String
          : null,
    );
  }

  static String _normalizeStatus(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'working':
        return 'working';
      case 'updating':
        return 'updating';
      case 'error':
        return 'error';
      case 'queued':
        return 'queued';
      case 'disabled':
        return 'disabled';
      default:
        return 'unknown';
    }
  }

  /// Returns null if the native value indicates "unknown" (-1 in ObjC).
  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    final i = (value as num).toInt();
    return i < 0 ? null : i;
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'status': status,
      if (seeds != null) 'seeds': seeds,
      if (peers != null) 'peers': peers,
      if (leeches != null) 'leeches': leeches,
      if (downloaded != null) 'downloaded': downloaded,
      if (message != null) 'message': message,
    };
  }
}
