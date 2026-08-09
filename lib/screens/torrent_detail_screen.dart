import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/torrent_item.dart';
import '../providers/torrent_provider.dart';
import '../services/haptic_service.dart';
import '../utils/torrent_format.dart';

/// Live torrent details: stats, per-file priorities, trackers and controls.
class TorrentDetailScreen extends StatelessWidget {
  const TorrentDetailScreen({super.key, required this.infoHash});

  final String infoHash;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TorrentProvider>();
    final torrent = provider.byHash[infoHash];
    final cs = Theme.of(context).colorScheme;

    if (torrent == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Torrent')),
        body: Center(
          child: Text(
            'This torrent is no longer active.',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: _ActionBar(
        torrent: torrent,
        onPause: () => provider.pause(infoHash),
        onResume: () => provider.resume(infoHash),
        onRemove: () => _confirmRemove(context, torrent),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                tooltip: 'Copy info hash',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: torrent.infoHash));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Info hash copied')),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsetsDirectional.only(start: 16, bottom: 16),
              title: Text(
                torrent.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _StatsCard(torrent: torrent),
          ),
          if (torrent.files.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionHeader(title: 'Files (${torrent.files.length})')),
            SliverList.builder(
              itemCount: torrent.files.length,
              itemBuilder: (context, index) =>
                  _FileTile(torrent: torrent, file: torrent.files[index]),
            ),
          ],
          if (torrent.trackers.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionHeader(title: 'Trackers (${torrent.trackers.length})')),
            SliverList.builder(
              itemCount: torrent.trackers.length,
              itemBuilder: (context, index) =>
                  _TrackerTile(tracker: torrent.trackers[index]),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, TorrentItem torrent) {
    HapticService.heavy();
    bool deleteFiles = false;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => CupertinoAlertDialog(
          title: const Text('Remove Torrent?'),
          content: Column(
            children: [
              Text(
                'Remove "${torrent.name}" from the engine?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CupertinoCheckbox(
                    value: deleteFiles,
                    onChanged: (v) =>
                        setState(() => deleteFiles = v ?? false),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text('Delete downloaded files from storage',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                context
                    .read<TorrentProvider>()
                    .remove(torrent.infoHash, deleteFiles: deleteFiles);
                Navigator.pop(context);
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.torrent});

  final TorrentItem torrent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final eta = torrent.etaSeconds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _stateColor(cs).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    torrent.state.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _stateColor(cs),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${torrent.progressPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: torrent.progress.clamp(0.0, 1.0),
                minHeight: 8,
                color: _stateColor(cs),
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            _statRow(cs, 'Size',
                '${formatBytes(torrent.totalDone)} / ${formatBytes(torrent.total)}'),
            _statRow(cs, 'Speed',
                '${formatSpeed(torrent.downloadSpeed)} down \u00b7 ${formatSpeed(torrent.uploadSpeed)} up'),
            if (eta > 0) _statRow(cs, 'ETA', formatDuration(eta)),
            _statRow(cs, 'Peers',
                '${torrent.numberOfSeeds} seeders \u00b7 ${torrent.numberOfPeers} leechers'),
            _statRow(cs, 'Traffic',
                '${formatBytes(torrent.totalDownload)} down \u00b7 ${formatBytes(torrent.totalUpload)} up'),
            _statRow(cs, 'Info hash', torrent.infoHash, selectable: true),
          ],
        ),
      ),
    );
  }

  Color _stateColor(ColorScheme cs) {
    switch (torrent.state) {
      case TorrentState.downloading:
      case TorrentState.downloadingMetadata:
        return cs.primary;
      case TorrentState.paused:
        return Colors.orange;
      case TorrentState.seeding:
      case TorrentState.finished:
        return Colors.green;
      case TorrentState.storageError:
        return cs.error;
      default:
        return cs.onSurfaceVariant;
    }
  }

  Widget _statRow(ColorScheme cs, String label, String value,
      {bool selectable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.torrent, required this.file});

  final TorrentItem torrent;
  final TorrentFileItem file;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fileName = file.path.split('/').last;
    final progress =
        file.size > 0 ? (file.downloaded / file.size).clamp(0.0, 1.0) : 0.0;
    final skip = file.priorityLevel == TorrentFilePriority.skip;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: skip
                          ? cs.onSurface.withValues(alpha: 0.45)
                          : cs.onSurface,
                    ),
                  ),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Priority',
                  initialValue: file.priorityLevel.raw,
                  onSelected: (raw) {
                    HapticService.light();
                    context
                        .read<TorrentProvider>()
                        .setFilePriority(torrent.infoHash, file.index,
                            TorrentFilePriority.fromRaw(raw));
                  },
                  itemBuilder: (_) => [
                    for (final p in TorrentFilePriority.values)
                      PopupMenuItem(
                        value: p.raw,
                        child: Row(
                          children: [
                            Icon(
                              _priorityIcon(p),
                              size: 18,
                              color: _priorityColor(cs, p),
                            ),
                            const SizedBox(width: 10),
                            Text(_priorityLabel(p)),
                          ],
                        ),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _priorityLabel(file.priorityLevel),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _priorityColor(cs, file.priorityLevel),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatBytes(file.downloaded)} / ${formatBytes(file.size)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Text(
                  formatBytes((file.size * progress).round()),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: skip ? 0 : progress,
                minHeight: 4,
                color: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priorityLabel(TorrentFilePriority p) {
    switch (p) {
      case TorrentFilePriority.skip:
        return 'Skip';
      case TorrentFilePriority.low:
        return 'Low';
      case TorrentFilePriority.normal:
        return 'Normal';
      case TorrentFilePriority.high:
        return 'High';
      case TorrentFilePriority.top:
        return 'Top';
    }
  }

  IconData _priorityIcon(TorrentFilePriority p) {
    switch (p) {
      case TorrentFilePriority.skip:
        return Icons.remove_circle_outline;
      case TorrentFilePriority.low:
        return Icons.arrow_downward;
      case TorrentFilePriority.normal:
        return Icons.horizontal_rule;
      case TorrentFilePriority.high:
        return Icons.arrow_upward;
      case TorrentFilePriority.top:
        return Icons.vertical_align_top;
    }
  }

  Color _priorityColor(ColorScheme cs, TorrentFilePriority p) {
    switch (p) {
      case TorrentFilePriority.skip:
        return cs.onSurface.withValues(alpha: 0.4);
      case TorrentFilePriority.low:
        return Colors.blueGrey;
      case TorrentFilePriority.normal:
        return cs.onSurface;
      case TorrentFilePriority.high:
        return Colors.orange;
      case TorrentFilePriority.top:
        return Colors.redAccent;
    }
  }
}

class _TrackerTile extends StatelessWidget {
  const _TrackerTile({required this.tracker});

  final TorrentTrackerItem tracker;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ok = tracker.state == 'working';
    final stateColor =
        ok ? Colors.green : (tracker.state == 'unreachable' || tracker.state == 'trackerError' ? cs.error : cs.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.dns_outlined,
                size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tracker.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tracker.message.isEmpty
                        ? '${tracker.seeds} seeds \u00b7 ${tracker.peers} peers \u00b7 ${tracker.leeches} leeches'
                        : tracker.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              tracker.state,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: stateColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.torrent,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
  });

  final TorrentItem torrent;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: torrent.isPaused ? onResume : onPause,
              icon: Icon(
                torrent.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
              label: Text(torrent.isPaused ? 'Resume' : 'Pause'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: onRemove,
              style: FilledButton.styleFrom(
                backgroundColor: cs.errorContainer,
                foregroundColor: cs.onErrorContainer,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }
}
