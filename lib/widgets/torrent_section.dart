import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/torrent_item.dart';
import '../providers/torrent_provider.dart';
import '../screens/torrent_add_sheet.dart';
import '../screens/torrent_detail_screen.dart';
import '../services/haptic_service.dart';
import '../utils/torrent_format.dart';

/// Torrent section embedded in the Downloads tab (iOS only).
class TorrentSection extends StatelessWidget {
  const TorrentSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TorrentProvider>();
    final cs = Theme.of(context).colorScheme;
    final torrents = provider.torrents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Torrents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              if (torrents.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${torrents.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              IconButton.filledTonal(
                tooltip: 'Add torrent',
                onPressed: () {
                  HapticService.light();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const TorrentAddSheet(),
                  );
                },
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (torrents.isEmpty)
          _EmptyTorrentCard(
            onAdd: () {
              HapticService.light();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const TorrentAddSheet(),
              );
            },
          )
        else
          ...torrents.map((t) => _TorrentCard(torrent: t)),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _EmptyTorrentCard extends StatelessWidget {
  const _EmptyTorrentCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.downloading_rounded,
                color: cs.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No torrents yet. Add a magnet link or a .torrent file.',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            TextButton(
              onPressed: onAdd,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TorrentCard extends StatelessWidget {
  const _TorrentCard({required this.torrent});

  final TorrentItem torrent;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stateColor = _stateColor(cs);
    final active = torrent.state == TorrentState.downloading ||
        torrent.state == TorrentState.downloadingMetadata;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: cs.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticService.light();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TorrentDetailScreen(infoHash: torrent.infoHash),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        torrent.isSeed
                            ? Icons.upload_rounded
                            : torrent.isPaused
                                ? Icons.pause_rounded
                                : Icons.downloading_rounded,
                        color: stateColor,
                        size: 22,
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                torrent.state.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: stateColor,
                                ),
                              ),
                              if (active) ...[
                                const SizedBox(width: 10),
                                Text(
                                  '${formatSpeed(torrent.downloadSpeed)} down',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${formatSpeed(torrent.uploadSpeed)} up',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Torrent options',
                      icon: Icon(Icons.more_vert,
                          color: cs.onSurface.withValues(alpha: 0.7),
                          size: 20),
                      onPressed: () => _showOptions(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: torrent.progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    color: stateColor,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${formatBytes(torrent.totalDone)} / ${formatBytes(torrent.total)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    if (!torrent.hasMetadata)
                      Text(
                        'Metadata pending',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      )
                    else ...[
                      Icon(Icons.group_outlined,
                          size: 13,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '${torrent.numberOfSeeds} seed / ${torrent.numberOfPeers} peer',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    HapticService.light();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(torrent.name,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          if (!torrent.isPaused)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<TorrentProvider>().pause(torrent.infoHash);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause_circle,
                      color: CupertinoColors.systemOrange, size: 22),
                  SizedBox(width: 12),
                  Text('Pause'),
                ],
              ),
            )
          else
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<TorrentProvider>().resume(torrent.infoHash);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle,
                      color: CupertinoColors.activeGreen, size: 22),
                  SizedBox(width: 12),
                  Text('Resume'),
                ],
              ),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TorrentProvider>().recheck(torrent.infoHash);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_outlined,
                    color: CupertinoColors.activeBlue, size: 22),
                SizedBox(width: 12),
                Text('Recheck Files'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TorrentProvider>().forceAnnounce(torrent.infoHash);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sync, color: CupertinoColors.activeBlue, size: 22),
                SizedBox(width: 12),
                Text('Force Re-announce'),
              ],
            ),
          ),
          if (torrent.magnetUri.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: torrent.magnetUri));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Magnet link copied')),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link, color: CupertinoColors.activeBlue, size: 22),
                  SizedBox(width: 12),
                  Text('Copy Magnet'),
                ],
              ),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmRemove(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline,
                    color: CupertinoColors.destructiveRed, size: 22),
                SizedBox(width: 12),
                Text('Remove'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
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
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }
}
