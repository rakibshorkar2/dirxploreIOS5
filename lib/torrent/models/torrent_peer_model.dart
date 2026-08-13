/// Represents real peer information returned by libtorrent get_peer_info.
class TorrentPeerModel {
  final String ip;
  final int port;
  final String client;
  final String? country;
  final int downloadSpeed;
  final int uploadSpeed;
  final double progress;
  final String? connectionType;
  final bool isSeed;

  const TorrentPeerModel({
    required this.ip,
    required this.port,
    required this.client,
    this.country,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.progress,
    this.connectionType,
    this.isSeed = false,
  });

  factory TorrentPeerModel.fromJson(Map<String, dynamic> json) {
    return TorrentPeerModel(
      ip: json['ip'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
      client: (json['client'] as String? ?? '').isNotEmpty
          ? json['client'] as String
          : 'Unknown',
      country: (json['country'] as String? ?? '').isNotEmpty
          ? json['country'] as String
          : null,
      downloadSpeed: (json['downloadSpeed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (json['uploadSpeed'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      connectionType: json['connectionType'] as String?,
      isSeed: json['isSeed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'port': port,
      'client': client,
      if (country != null) 'country': country,
      'downloadSpeed': downloadSpeed,
      'uploadSpeed': uploadSpeed,
      'progress': progress,
      if (connectionType != null) 'connectionType': connectionType,
      'isSeed': isSeed,
    };
  }
}
