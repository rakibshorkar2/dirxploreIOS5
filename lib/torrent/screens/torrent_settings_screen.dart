import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/torrent_provider.dart';

class TorrentSettingsScreen extends StatefulWidget {
  const TorrentSettingsScreen({super.key});

  @override
  State<TorrentSettingsScreen> createState() => _TorrentSettingsScreenState();
}

class _TorrentSettingsScreenState extends State<TorrentSettingsScreen> {
  late TextEditingController _downLimitController;
  late TextEditingController _upLimitController;
  late TextEditingController _portController;
  late TextEditingController _maxConnController;

  bool _enableDht = true;
  bool _enableUpnp = true;
  bool _randomizePort = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<TorrentProvider>().settings;

    _downLimitController = TextEditingController(text: '${(settings['globalDownloadLimit'] as int? ?? 0) ~/ 1024}');
    _upLimitController = TextEditingController(text: '${(settings['globalUploadLimit'] as int? ?? 0) ~/ 1024}');
    _portController = TextEditingController(text: '${settings['listenPort'] as int? ?? 6881}');
    _maxConnController = TextEditingController(text: '${settings['maxConnections'] as int? ?? 200}');

    _enableDht = settings['enableDht'] as bool? ?? true;
    _enableUpnp = settings['enableUpnp'] as bool? ?? true;
    _randomizePort = settings['randomizePort'] as bool? ?? true;
  }

  @override
  void dispose() {
    _downLimitController.dispose();
    _upLimitController.dispose();
    _portController.dispose();
    _maxConnController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final downLimitKb = int.tryParse(_downLimitController.text) ?? 0;
    final upLimitKb = int.tryParse(_upLimitController.text) ?? 0;
    final port = int.tryParse(_portController.text) ?? 6881;
    final maxConn = int.tryParse(_maxConnController.text) ?? 200;

    final provider = context.read<TorrentProvider>();
    provider.updateSettings({
      'globalDownloadLimit': downLimitKb * 1024,
      'globalUploadLimit': upLimitKb * 1024,
      'listenPort': port,
      'maxConnections': maxConn,
      'enableDht': _enableDht,
      'enableUpnp': _enableUpnp,
      'randomizePort': _randomizePort,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Torrent settings updated.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Torrent Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Speed Limits'),
          TextField(
            controller: _downLimitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Global Download Limit (KB/s)',
              hintText: '0 = Unlimited',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _upLimitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Global Upload Limit (KB/s)',
              hintText: '0 = Unlimited',
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Network & Port Settings'),
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Incoming Listening Port',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Randomize Port on Startup'),
            value: _randomizePort,
            onChanged: (val) => setState(() => _randomizePort = val),
          ),
          SwitchListTile(
            title: const Text('Enable UPnP / NAT-PMP Port Forwarding'),
            value: _enableUpnp,
            onChanged: (val) => setState(() => _enableUpnp = val),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Peer Connections & DHT'),
          SwitchListTile(
            title: const Text('Enable DHT (Distributed Hash Table)'),
            value: _enableDht,
            onChanged: (val) => setState(() => _enableDht = val),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxConnController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Maximum Peer Connections',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
