class TorrentStatsModel {
  final int totalDownloadSpeed;
  final int totalUploadSpeed;
  final int activeCount;
  final int pausedCount;
  final int completedCount;
  final int totalCount;

  const TorrentStatsModel({
    required this.totalDownloadSpeed,
    required this.totalUploadSpeed,
    required this.activeCount,
    required this.pausedCount,
    required this.completedCount,
    required this.totalCount,
  });

  factory TorrentStatsModel.empty() {
    return const TorrentStatsModel(
      totalDownloadSpeed: 0,
      totalUploadSpeed: 0,
      activeCount: 0,
      pausedCount: 0,
      completedCount: 0,
      totalCount: 0,
    );
  }

  factory TorrentStatsModel.fromJson(Map<String, dynamic> json) {
    return TorrentStatsModel(
      totalDownloadSpeed: json['totalDownloadSpeed'] as int? ?? 0,
      totalUploadSpeed: json['totalUploadSpeed'] as int? ?? 0,
      activeCount: json['activeCount'] as int? ?? 0,
      pausedCount: json['pausedCount'] as int? ?? 0,
      completedCount: json['completedCount'] as int? ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDownloadSpeed': totalDownloadSpeed,
      'totalUploadSpeed': totalUploadSpeed,
      'activeCount': activeCount,
      'pausedCount': pausedCount,
      'completedCount': completedCount,
      'totalCount': totalCount,
    };
  }
}
