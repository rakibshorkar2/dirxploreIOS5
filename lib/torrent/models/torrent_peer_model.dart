class TorrentPeerModel {
  final String ip;
  final int port;
  final String client;
  final int downloadSpeed;
  final int uploadSpeed;
  final double progress;

  const TorrentPeerModel({
    required this.ip,
    required this.port,
    required this.client,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.progress,
  });

  factory TorrentPeerModel.fromJson(Map<String, dynamic> json) {
    return TorrentPeerModel(
      ip: json['ip'] as String? ?? '',
      port: json['port'] as int? ?? 0,
      client: json['client'] as String? ?? 'Unknown',
      downloadSpeed: json['downloadSpeed'] as int? ?? 0,
      uploadSpeed: json['uploadSpeed'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'port': port,
      'client': client,
      'downloadSpeed': downloadSpeed,
      'uploadSpeed': uploadSpeed,
      'progress': progress,
    };
  }
}
