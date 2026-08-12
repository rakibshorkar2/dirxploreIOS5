import 'package:flutter/material.dart';
import '../models/torrent_model.dart';
import 'torrent_progress.dart';

class TorrentCard extends StatelessWidget {
  final TorrentModel torrent;
  final VoidCallback onTap;
  final VoidCallback onPauseResume;
  final VoidCallback onMore;

  const TorrentCard({
    super.key,
    required this.torrent,
    required this.onTap,
    required this.onPauseResume,
    required this.onMore,
  });

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var i = 0;
    double speed = bytesPerSec.toDouble();
    while (speed >= 1024 && i < suffixes.length - 1) {
      speed /= 1024;
      i++;
    }
    return '${speed.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatEta(int seconds) {
    if (seconds <= 0) return '∞';
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).floor()}m ${(seconds % 60)}s';
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    return '${h}h ${m}m';
  }

  Color _getStatusColor(TorrentStatus status, ThemeData theme) {
    switch (status) {
      case TorrentStatus.downloading:
        return Colors.blueAccent;
      case TorrentStatus.downloadingMetadata:
        return Colors.purpleAccent;
      case TorrentStatus.seeding:
      case TorrentStatus.completed:
        return Colors.greenAccent;
      case TorrentStatus.paused:
        return Colors.orangeAccent;
      case TorrentStatus.error:
        return Colors.redAccent;
      case TorrentStatus.checking:
      case TorrentStatus.queued:
        return Colors.amberAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(torrent.status, theme);
    final percentage = (torrent.progress * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      torrent.status == TorrentStatus.paused
                          ? Icons.pause_rounded
                          : torrent.status == TorrentStatus.completed ||
                                  torrent.status == TorrentStatus.seeding
                              ? Icons.check_circle_outline_rounded
                              : Icons.downloading_rounded,
                      size: 20,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          torrent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              torrent.status.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•  ${_formatBytes(torrent.downloadedSize)} / ${_formatBytes(torrent.totalSize)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      torrent.status == TorrentStatus.paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: onPauseResume,
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: onMore,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TorrentProgressBar(
                progress: torrent.progress,
                color: statusColor,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  if (torrent.status == TorrentStatus.downloading) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                        Text(
                          _formatSpeed(torrent.downloadSpeed),
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_upward_rounded,
                          size: 12,
                          color: Colors.green,
                        ),
                        Text(
                          _formatSpeed(torrent.uploadSpeed),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    Text(
                      'ETA: ${_formatEta(torrent.etaSeconds)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Peers: ${torrent.peers} | Ratio: ${torrent.ratio.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
