import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/torrent_model.dart';
import '../providers/torrent_provider.dart';
import '../widgets/torrent_file_list.dart';
import '../widgets/torrent_progress.dart';

class TorrentDetailScreen extends StatefulWidget {
  final String infoHash;

  const TorrentDetailScreen({
    super.key,
    required this.infoHash,
  });

  @override
  State<TorrentDetailScreen> createState() => _TorrentDetailScreenState();
}

class _TorrentDetailScreenState extends State<TorrentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  void _confirmDelete(BuildContext context, TorrentModel torrent) {
    final provider = context.read<TorrentProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Torrent'),
        content: Text('Remove "${torrent.name}" from your torrent downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.removeTorrent(torrent.infoHash, deleteData: false);
              Navigator.pop(this.context);
            },
            child: const Text('Remove Only'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              provider.removeTorrent(torrent.infoHash, deleteData: true);
              Navigator.pop(this.context);
            },
            child: const Text('Remove + Delete Files', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TorrentProvider>();
    final torrent = provider.getTorrentByHash(widget.infoHash);

    if (torrent == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Torrent Details')),
        body: const Center(child: Text('Torrent not found or removed.')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          torrent.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Files'),
            Tab(text: 'Trackers'),
            Tab(text: 'Peers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context, torrent, provider),
          TorrentFileList(
            files: torrent.files,
            onPriorityChanged: (index, priority) {
              provider.setFilePriority(torrent.infoHash, index, priority);
            },
          ),
          _buildTrackersTab(context, torrent),
          _buildPeersTab(context, torrent),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                if (torrent.status == TorrentStatus.paused) {
                  provider.resumeTorrent(torrent.infoHash);
                } else {
                  provider.pauseTorrent(torrent.infoHash);
                }
              },
              icon: Icon(
                torrent.status == TorrentStatus.paused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
              label: Text(torrent.status == TorrentStatus.paused ? 'Resume' : 'Pause'),
            ),
            OutlinedButton.icon(
              onPressed: () => provider.recheckTorrent(torrent.infoHash),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Recheck'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              onPressed: () => _confirmDelete(context, torrent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, TorrentModel torrent, TorrentProvider provider) {
    final percentage = (torrent.progress * 100).toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          torrent.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TorrentProgressBar(progress: torrent.progress, height: 10),
        const SizedBox(height: 16),
        _buildDetailRow('Status', torrent.status.displayName),
        _buildDetailRow('Progress', '$percentage%'),
        _buildDetailRow('Downloaded', '${_formatBytes(torrent.downloadedSize)} / ${_formatBytes(torrent.totalSize)}'),
        _buildDetailRow('Uploaded', _formatBytes(torrent.uploadedSize)),
        _buildDetailRow('Download Speed', _formatSpeed(torrent.downloadSpeed)),
        _buildDetailRow('Upload Speed', _formatSpeed(torrent.uploadSpeed)),
        _buildDetailRow('Ratio', torrent.ratio.toStringAsFixed(2)),
        _buildDetailRow('Peers / Seeds', '${torrent.peers} peers (${torrent.seeds} seeds)'),
        _buildDetailRow('Info Hash', torrent.infoHash),
        _buildDetailRow('Save Directory', torrent.savePath ?? 'Default'),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Sequential Download'),
          subtitle: const Text('Download pieces in order from start to end'),
          value: torrent.isSequential,
          onChanged: (val) {
            provider.setSequentialDownload(torrent.infoHash, val);
          },
        ),
        if (torrent.magnetUri != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: torrent.magnetUri!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Magnet URI copied to clipboard.')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy Magnet URI'),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackersTab(BuildContext context, TorrentModel torrent) {
    if (torrent.trackers.isEmpty) {
      return const Center(child: Text('No trackers announced.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: torrent.trackers.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final tracker = torrent.trackers[index];
        return ListTile(
          leading: const Icon(Icons.dns_rounded),
          title: Text(tracker.url, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('Status: ${tracker.status} | Peers: ${tracker.peers}'),
        );
      },
    );
  }

  Widget _buildPeersTab(BuildContext context, TorrentModel torrent) {
    if (torrent.peerList.isEmpty) {
      return const Center(child: Text('No active peer connections.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: torrent.peerList.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final peer = torrent.peerList[index];
        return ListTile(
          leading: const Icon(Icons.connect_without_contact_rounded),
          title: Text('${peer.ip}:${peer.port}'),
          subtitle: Text('Client: ${peer.client} | Down: ${_formatSpeed(peer.downloadSpeed)} | Up: ${_formatSpeed(peer.uploadSpeed)}'),
        );
      },
    );
  }
}
