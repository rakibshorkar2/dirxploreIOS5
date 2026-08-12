import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/torrent_provider.dart';

class AddTorrentSheet extends StatefulWidget {
  const AddTorrentSheet({super.key});

  @override
  State<AddTorrentSheet> createState() => _AddTorrentSheetState();
}

class _AddTorrentSheetState extends State<AddTorrentSheet> {
  final TextEditingController _magnetController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _magnetController.dispose();
    super.dispose();
  }

  Future<void> _addMagnet() async {
    final uri = _magnetController.text.trim();
    final provider = context.read<TorrentProvider>();

    if (uri.isEmpty) {
      setState(() => _errorText = 'Please enter a magnet URI.');
      return;
    }

    if (!provider.torrentService.isValidMagnet(uri)) {
      setState(() => _errorText = 'Invalid magnet link format (magnet:?xt=urn:btih:...).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await provider.addMagnet(uri);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Magnet link added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _pickTorrentFile() async {
    final provider = context.read<TorrentProvider>();
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final filePath = await provider.torrentService.pickTorrentFile();
      if (filePath == null) {
        setState(() => _isLoading = false);
        return;
      }

      await provider.addTorrentFile(filePath);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Torrent file added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Torrent',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _magnetController,
            decoration: InputDecoration(
              hintText: 'magnet:?xt=urn:btih:...',
              labelText: 'Magnet Link / URI',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.link),
              errorText: _errorText,
            ),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _addMagnet,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_link),
            label: const Text('Add Magnet Link'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _pickTorrentFile,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Import .torrent File'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
