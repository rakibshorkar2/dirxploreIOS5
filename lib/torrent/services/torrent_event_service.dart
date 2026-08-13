import 'dart:async';
import '../native/torrent_platform_channel.dart';

abstract class TorrentEvent {}

class TorrentAddedEvent extends TorrentEvent {
  final Map<String, dynamic> torrentData;
  TorrentAddedEvent(this.torrentData);
}

class TorrentUpdatedEvent extends TorrentEvent {
  final Map<String, dynamic> torrentData;
  TorrentUpdatedEvent(this.torrentData);
}

class TorrentRemovedEvent extends TorrentEvent {
  final String infoHash;
  TorrentRemovedEvent(this.infoHash);
}

class TorrentErrorEvent extends TorrentEvent {
  final String infoHash;
  final String errorMessage;
  TorrentErrorEvent(this.infoHash, this.errorMessage);
}

class TorrentMetadataReceivedEvent extends TorrentEvent {
  final Map<String, dynamic> torrentData;
  TorrentMetadataReceivedEvent(this.torrentData);
}

class TorrentCompletedEvent extends TorrentEvent {
  final String infoHash;
  final String name;
  final Map<String, dynamic> torrentData;
  TorrentCompletedEvent(this.infoHash, this.name, this.torrentData);
}

class TorrentStatsUpdatedEvent extends TorrentEvent {
  final Map<String, dynamic> statsData;
  TorrentStatsUpdatedEvent(this.statsData);
}

class TorrentEventService {
  final TorrentPlatformChannel _platformChannel;
  final StreamController<TorrentEvent> _eventController = StreamController<TorrentEvent>.broadcast();

  StreamSubscription? _nativeSubscription;

  TorrentEventService(this._platformChannel);

  Stream<TorrentEvent> get events => _eventController.stream;

  void startListening() {
    _nativeSubscription?.cancel();
    _nativeSubscription = _platformChannel.eventStream.listen(
      _onNativeEvent,
      onError: (err) {
        // Handle stream error without crashing
      },
    );
  }

  void stopListening() {
    _nativeSubscription?.cancel();
    _nativeSubscription = null;
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;
    final map = Map<String, dynamic>.from(event);
    final eventType = map['eventType'] as String?;

    switch (eventType) {
      case 'torrentAdded':
        if (map['torrent'] is Map) {
          _eventController.add(TorrentAddedEvent(Map<String, dynamic>.from(map['torrent'] as Map)));
        }
        break;
      case 'torrentUpdated':
        if (map['torrent'] is Map) {
          _eventController.add(TorrentUpdatedEvent(Map<String, dynamic>.from(map['torrent'] as Map)));
        }
        break;
      case 'torrentRemoved':
        if (map['infoHash'] is String) {
          _eventController.add(TorrentRemovedEvent(map['infoHash'] as String));
        }
        break;
      case 'torrentError':
        if (map['infoHash'] is String && map['error'] is String) {
          _eventController.add(TorrentErrorEvent(map['infoHash'] as String, map['error'] as String));
        }
        break;
      case 'metadataReceived':
        if (map['torrent'] is Map) {
          _eventController.add(TorrentMetadataReceivedEvent(Map<String, dynamic>.from(map['torrent'] as Map)));
        }
        break;
      case 'torrentCompleted':
        if (map['infoHash'] is String) {
          final torrentRaw = map['torrent'];
          final torrentData = torrentRaw is Map
              ? Map<String, dynamic>.from(torrentRaw)
              : <String, dynamic>{};
          _eventController.add(TorrentCompletedEvent(
            map['infoHash'] as String,
            torrentData['name'] as String? ?? map['name'] as String? ?? 'Torrent',
            torrentData,
          ));
        }
        break;
      case 'statsUpdated':
        if (map['stats'] is Map) {
          _eventController.add(TorrentStatsUpdatedEvent(Map<String, dynamic>.from(map['stats'] as Map)));
        }
        break;
    }
  }

  void dispose() {
    stopListening();
    _eventController.close();
  }
}
