import 'package:flutter_test/flutter_test.dart';
import 'package:dirxplore/torrent/models/torrent_model.dart';
import 'package:dirxplore/torrent/models/torrent_file_model.dart';
import 'package:dirxplore/torrent/services/torrent_service.dart';

void main() {
  group('Torrent Model & Parsing Tests', () {
    test('TorrentModel.fromJson parses JSON correctly', () {
      final json = {
        'infoHash': '0123456789abcdef0123456789abcdef01234567',
        'name': 'Ubuntu ISO',
        'status': 'downloading',
        'progress': 0.45,
        'downloadSpeed': 1048576,
        'uploadSpeed': 51200,
        'totalSize': 2147483648,
        'downloadedSize': 966367641,
        'uploadedSize': 10485760,
        'peers': 15,
        'seeds': 42,
        'leeches': 5,
        'magnetUri': 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=Ubuntu',
        'files': [
          {
            'index': 0,
            'path': 'ubuntu-22.04.iso',
            'size': 2147483648,
            'downloaded': 966367641,
            'priority': 1,
          }
        ],
      };

      final model = TorrentModel.fromJson(json);

      expect(model.infoHash, '0123456789abcdef0123456789abcdef01234567');
      expect(model.name, 'Ubuntu ISO');
      expect(model.status, TorrentStatus.downloading);
      expect(model.progress, 0.45);
      expect(model.downloadSpeed, 1048576);
      expect(model.totalSize, 2147483648);
      expect(model.files.length, 1);
      expect(model.files.first.name, 'ubuntu-22.04.iso');
      expect(model.files.first.priority, FilePriority.normal);
    });

    test('TorrentStatus handles all status strings cleanly', () {
      expect(TorrentStatus.fromString('downloading'), TorrentStatus.downloading);
      expect(TorrentStatus.fromString('checking_files'), TorrentStatus.checking);
      expect(TorrentStatus.fromString('downloading_metadata'), TorrentStatus.downloadingMetadata);
      expect(TorrentStatus.fromString('seeding'), TorrentStatus.seeding);
      expect(TorrentStatus.fromString('paused'), TorrentStatus.paused);
      expect(TorrentStatus.fromString('finished'), TorrentStatus.completed);
      expect(TorrentStatus.fromString('error'), TorrentStatus.error);
    });
  });

  group('TorrentService Helper Tests', () {
    test('Magnet validation and infoHash extraction', () {
      final service = TorrentService(
        platformChannel: null as dynamic,
        storageService: null as dynamic,
      );

      const validMagnet = 'magnet:?xt=urn:btih:da39a3ee5e6b4b0d3255bfef95601890afd80709&dn=test';
      expect(service.isValidMagnet(validMagnet), true);
      expect(service.extractInfoHashFromMagnet(validMagnet), 'da39a3ee5e6b4b0d3255bfef95601890afd80709');

      const invalidMagnet = 'https://example.com/file.torrent';
      expect(service.isValidMagnet(invalidMagnet), false);
      expect(service.extractInfoHashFromMagnet(invalidMagnet), null);
    });
  });
}
