import 'package:file_picker/file_picker.dart';
import '../native/torrent_platform_channel.dart';
import 'torrent_storage_service.dart';

class TorrentService {
  final TorrentPlatformChannel? platformChannel;
  final TorrentStorageService? storageService;

  TorrentService({
    this.platformChannel,
    this.storageService,
  });

  Future<String?> pickTorrentFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['torrent'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      return result.files.first.path;
    }
    return null;
  }

  bool isValidMagnet(String uri) {
    final trimmed = uri.trim();
    return trimmed.toLowerCase().startsWith('magnet:?xt=urn:btih:');
  }

  String? extractInfoHashFromMagnet(String uri) {
    if (!isValidMagnet(uri)) return null;
    final reg = RegExp(
      r'urn:btih:([a-fA-F0-9]{64}|[a-zA-Z2-7]{52}|[a-fA-F0-9]{40}|[a-zA-Z2-7]{32})',
      caseSensitive: false,
    );
    final match = reg.firstMatch(uri);
    return match?.group(1)?.toLowerCase();
  }
}
