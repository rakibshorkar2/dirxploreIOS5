class TorrentTrackerModel {
  final String url;
  final String status;
  final int peers;
  final String? message;

  const TorrentTrackerModel({
    required this.url,
    required this.status,
    required this.peers,
    this.message,
  });

  factory TorrentTrackerModel.fromJson(Map<String, dynamic> json) {
    return TorrentTrackerModel(
      url: json['url'] as String? ?? '',
      status: json['status'] as String? ?? 'Working',
      peers: json['peers'] as int? ?? 0,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'status': status,
      'peers': peers,
      'message': message,
    };
  }
}
