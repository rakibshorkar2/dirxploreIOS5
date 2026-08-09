/// Formatting helpers shared by the Torrent UI screens.
library;

import 'dart:math';

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  final i = (log(bytes) / log(1024)).floor();
  final v = bytes / pow(1024, i);
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${suffixes[i]}';
}

String formatSpeed(double bytesPerSec) {
  if (bytesPerSec <= 0) return '0 B/s';
  return '${formatBytes(bytesPerSec.round())}/s';
}

String formatDuration(int seconds) {
  if (seconds <= 0) return '--';
  final d = Duration(seconds: seconds);
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}
