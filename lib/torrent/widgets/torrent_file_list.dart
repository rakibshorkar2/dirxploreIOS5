import 'package:flutter/material.dart';
import '../models/torrent_file_model.dart';
import 'torrent_progress.dart';

class TorrentFileList extends StatelessWidget {
  final List<TorrentFileModel> files;
  final Function(int index, FilePriority priority) onPriorityChanged;

  const TorrentFileList({
    super.key,
    required this.files,
    required this.onPriorityChanged,
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

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(
        child: Text('No file metadata available yet.'),
      );
    }

    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: files.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final file = files[index];
        final percentage = (file.progress * 100).toStringAsFixed(0);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    file.priority == FilePriority.doNotDownload
                        ? Icons.block_rounded
                        : Icons.insert_drive_file_outlined,
                    size: 20,
                    color: file.priority == FilePriority.doNotDownload
                        ? Colors.redAccent
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: file.priority == FilePriority.doNotDownload
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatBytes(file.downloaded)} / ${_formatBytes(file.size)} ($percentage%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<FilePriority>(
                    initialValue: file.priority,
                    onSelected: (p) => onPriorityChanged(file.index, p),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: FilePriority.normal,
                        child: Text('Normal Priority'),
                      ),
                      const PopupMenuItem(
                        value: FilePriority.high,
                        child: Text('High Priority'),
                      ),
                      const PopupMenuItem(
                        value: FilePriority.doNotDownload,
                        child: Text('Don\'t Download'),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            file.priority == FilePriority.doNotDownload
                                ? 'Skip'
                                : file.priority == FilePriority.high
                                    ? 'High'
                                    : 'Normal',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TorrentProgressBar(
                progress: file.progress,
                height: 4,
              ),
            ],
          ),
        );
      },
    );
  }
}
