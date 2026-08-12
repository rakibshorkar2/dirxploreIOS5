import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/torrent_model.dart';
import '../providers/torrent_provider.dart';
import '../widgets/torrent_card.dart';
import '../widgets/torrent_stats.dart';
import 'add_torrent_screen.dart';
import 'torrent_detail_screen.dart';
import 'torrent_settings_screen.dart';

class TorrentTab extends StatefulWidget {
  const TorrentTab({super.key});

  @override
  State<TorrentTab> createState() => _TorrentTabState();
}

class _TorrentTabState extends State<TorrentTab> {
  int _filterIndex = 0; // 0 = All, 1 = Downloading, 2 = Completed, 3 = Paused
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTorrentSheet(),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TorrentSettingsScreen()),
    );
  }

  List<TorrentModel> _filterTorrents(List<TorrentModel> torrents) {
    var filtered = torrents;

    if (_filterIndex == 1) {
      filtered = filtered
          .where((t) =>
              t.status == TorrentStatus.downloading ||
              t.status == TorrentStatus.downloadingMetadata ||
              t.status == TorrentStatus.checking)
          .toList();
    } else if (_filterIndex == 2) {
      filtered = filtered
          .where((t) =>
              t.status == TorrentStatus.completed ||
              t.status == TorrentStatus.seeding)
          .toList();
    } else if (_filterIndex == 3) {
      filtered = filtered
          .where((t) => t.status == TorrentStatus.paused)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((t) =>
              t.name.toLowerCase().contains(q) ||
              t.infoHash.toLowerCase().contains(q))
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TorrentProvider>();
    final allTorrents = provider.torrents;
    final displayTorrents = _filterTorrents(allTorrents);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Torrent Downloads',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Torrent',
            onPressed: () => _openAddSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Torrent Settings',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          TorrentStatsBar(
            downloadSpeed: provider.totalDownloadSpeed,
            uploadSpeed: provider.totalUploadSpeed,
            activeCount: provider.activeCount,
            completedCount: provider.completedCount,
            totalCount: allTorrents.length,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search torrents...',
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All (${allTorrents.length})', 0),
                const SizedBox(width: 8),
                _buildFilterChip('Downloading (${provider.activeCount})', 1),
                const SizedBox(width: 8),
                _buildFilterChip('Completed (${provider.completedCount})', 2),
                const SizedBox(width: 8),
                _buildFilterChip('Paused (${provider.pausedCount})', 3),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: displayTorrents.isEmpty
                ? _buildEmptyState(context, allTorrents.isEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: displayTorrents.length,
                    itemBuilder: (context, index) {
                      final torrent = displayTorrents[index];
                      return TorrentCard(
                        torrent: torrent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TorrentDetailScreen(
                                infoHash: torrent.infoHash,
                              ),
                            ),
                          );
                        },
                        onPauseResume: () {
                          if (torrent.status == TorrentStatus.paused) {
                            provider.resumeTorrent(torrent.infoHash);
                          } else {
                            provider.pauseTorrent(torrent.infoHash);
                          }
                        },
                        onMore: () {
                          _showOptionsModal(context, torrent, provider);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Add Torrent'),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _filterIndex == index;
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterIndex = index),
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isTotallyEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.downloading_rounded,
            size: 72,
            color: Colors.grey.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            isTotallyEmpty ? 'No Torrents Yet' : 'No Torrents Found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isTotallyEmpty
                ? 'Add magnet links or .torrent files to start downloading.'
                : 'Try adjusting your search query or filter tab.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          if (isTotallyEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openAddSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Your First Torrent'),
            ),
          ],
        ],
      ),
    );
  }

  void _showOptionsModal(
      BuildContext context, TorrentModel torrent, TorrentProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                torrent.status == TorrentStatus.paused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
              title: Text(torrent.status == TorrentStatus.paused
                  ? 'Resume Torrent'
                  : 'Pause Torrent'),
              onTap: () {
                Navigator.pop(context);
                if (torrent.status == TorrentStatus.paused) {
                  provider.resumeTorrent(torrent.infoHash);
                } else {
                  provider.pauseTorrent(torrent.infoHash);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Recheck Force Hash'),
              onTap: () {
                Navigator.pop(context);
                provider.recheckTorrent(torrent.infoHash);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('View Details & Files'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TorrentDetailScreen(infoHash: torrent.infoHash),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              title: const Text('Remove Torrent Only'),
              onTap: () {
                Navigator.pop(context);
                provider.removeTorrent(torrent.infoHash, deleteData: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded,
                  color: Colors.redAccent),
              title: const Text('Remove Torrent + Delete Files',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                provider.removeTorrent(torrent.infoHash, deleteData: true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
