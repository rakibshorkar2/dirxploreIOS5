//
//  TorrentEngineDelegate.swift
//  DirXplore
//
//  Delegate contract for the isolated Torrent subsystem. All callbacks are
//  delivered on the engine's serial queue. Do not use these to drive the
//  HTTP download system.
//

import Foundation

enum TorrentEngineError: LocalizedError {
    case notInitialized
    case invalidMagnet
    case invalidTorrentFile
    case duplicate
    case notFound
    case engineFailure(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Torrent engine is not initialized"
        case .invalidMagnet:
            return "Invalid magnet link"
        case .invalidTorrentFile:
            return "Invalid or corrupted torrent file"
        case .duplicate:
            return "This torrent was already added"
        case .notFound:
            return "Torrent not found"
        case .engineFailure(let message):
            return message
        }
    }
}

protocol TorrentEngineDelegate: AnyObject {
    func torrentEngine(_ engine: TorrentEngine, didAddTorrent infoHash: String)
    func torrentEngine(_ engine: TorrentEngine, didRemoveTorrent infoHash: String)
    func torrentEngine(_ engine: TorrentEngine, didUpdateTorrents tasks: [TorrentTaskModel])
    func torrentEngine(_ engine: TorrentEngine, didFailWith error: Error)
}
