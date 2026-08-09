import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../providers/torrent_provider.dart';
import '../services/haptic_service.dart';

/// Bottom sheet to add a torrent: paste a magnet link or pick a
/// .torrent file from the device.
class TorrentAddSheet extends StatefulWidget {
  const TorrentAddSheet({super.key});

  @override
  State<TorrentAddSheet> createState() => _TorrentAddSheetState();
}

class _TorrentAddSheetState extends State<TorrentAddSheet> {
  final TextEditingController _magnetCtrl = TextEditingController();
  String? _errorText;
  bool _isAdding = false;

  @override
  void dispose() {
    _magnetCtrl.dispose();
    super.dispose();
  }

  bool get _magnetValid {
    final text = _magnetCtrl.text.trim().toLowerCase();
    return text.startsWith('magnet:?') && text.contains('xt=urn:btih:');
  }

  Future<void> _addMagnet() async {
    if (!_magnetValid || _isAdding) return;
    HapticService.medium();
    final provider = context.read<TorrentProvider>();
    setState(() {
      _isAdding = true;
      _errorText = null;
    });
    try {
      await provider.addMagnet(_magnetCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdding = false;
          _errorText = e.toString();
        });
      }
    }
  }

  Future<void> _pickTorrentFile() async {
    HapticService.light();
    final provider = context.read<TorrentProvider>();
    setState(() => _errorText = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['torrent'],
        allowMultiple: false,
      );
      final path = result?.files.first.path;
      if (path == null || !mounted) return;

      setState(() => _isAdding = true);
      try {
        await provider.addTorrentFile(path);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          setState(() {
            _isAdding = false;
            _errorText = e.toString();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'File selection failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Add Torrent',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _magnetCtrl,
            autocorrect: false,
            enableSuggestions: false,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'magnet:?xt=urn:btih:...',
              labelText: 'Magnet link',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              errorText: _errorText,
            ),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _magnetValid && !_isAdding ? _addMagnet : null,
            icon: _isAdding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_rounded),
            label: const Text('Add Magnet'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Divider(color: cs.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(child: Divider(color: cs.outlineVariant)),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _isAdding ? null : _pickTorrentFile,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Choose .torrent File'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Downloads go to the torrent download folder. You can change it after adding.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
