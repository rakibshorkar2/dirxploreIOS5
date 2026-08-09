//
//  TorrentTask.swift
//  DirXplore
//
//  Torrent subsystem native model. This file belongs exclusively to the
//  Torrent feature and must not be shared with the HTTP download system.
//

import Foundation
import LibTorrent

/// Serializable snapshot of a single torrent as reported to the Flutter
/// layer. All numeric sizes are bytes, rates are bytes per second.
struct TorrentTaskModel {
    let infoHash: String
    let name: String
    let state: String
    let progress: Double
    let progressWanted: Double
    let hasMetadata: Bool
    let isPaused: Bool
    let isFinished: Bool
    let isSeed: Bool
    let downloadSpeed: Double
    let uploadSpeed: Double
    let numberOfPeers: Int
    let numberOfSeeds: Int
    let numberOfLeechers: Int
    let numberOfTotalPeers: Int
    let numberOfTotalSeeds: Int
    let total: Int64
    let totalDone: Int64
    let totalWanted: Int64
    let totalWantedDone: Int64
    let totalDownload: Int64
    let totalUpload: Int64
    let magnetUri: String?
    let torrentFilePath: String?
    let downloadPath: String?
    let addedDate: Double
    let files: [[String: Any]]
    let trackers: [[String: Any]]

    func toDictionary() -> [String: Any] {
        [
            "infoHash": infoHash,
            "name": name,
            "state": state,
            "progress": progress,
            "progressWanted": progressWanted,
            "hasMetadata": hasMetadata,
            "isPaused": isPaused,
            "isFinished": isFinished,
            "isSeed": isSeed,
            "downloadSpeed": downloadSpeed,
            "uploadSpeed": uploadSpeed,
            "numberOfPeers": numberOfPeers,
            "numberOfSeeds": numberOfSeeds,
            "numberOfLeechers": numberOfLeechers,
            "numberOfTotalPeers": numberOfTotalPeers,
            "numberOfTotalSeeds": numberOfTotalSeeds,
            "total": total,
            "totalDone": totalDone,
            "totalWanted": totalWanted,
            "totalWantedDone": totalWantedDone,
            "totalDownload": totalDownload,
            "totalUpload": totalUpload,
            "magnetUri": magnetUri ?? "",
            "torrentFilePath": torrentFilePath ?? "",
            "downloadPath": downloadPath ?? "",
            "addedDate": addedDate,
            "files": files,
            "trackers": trackers,
        ]
    }
}

/// Maps a LibTorrent handle snapshot to the serializable model.
enum TorrentTaskSerializer {
    static func serialize(handle: TorrentHandle) -> TorrentTaskModel? {
        let snapshot = handle.snapshot
        guard snapshot.isValid else { return nil }

        let infoHash = (handle.infoHashes.best as Data).hex.lowercased()

        var files: [[String: Any]] = []
        if snapshot.hasMetadata {
            for file in snapshot.files {
                files.append([
                    "index": file.index,
                    "name": file.name,
                    "path": file.path,
                    "size": Int64(file.size),
                    "downloaded": Int64(file.downloaded),
                    "priority": Int(file.priority.rawValue),
                    "selected": file.priority.rawValue != FileEntry.Priority.dontDownload.rawValue,
                ])
            }
        }

        var trackers: [[String: Any]] = []
        for tracker in snapshot.trackers {
            trackers.append([
                "url": tracker.trackerUrl,
                "state": TorrentTaskSerializer.trackerState(tracker.state),
                "message": tracker.message ?? "",
                "seeds": tracker.seeds,
                "peers": tracker.peers,
                "leeches": tracker.leeches,
            ])
        }

        let addedInterval = snapshot.addedDate?.timeIntervalSince1970 ?? 0

        return TorrentTaskModel(
            infoHash: infoHash,
            name: snapshot.name,
            state: TorrentTaskSerializer.state(snapshot.state),
            progress: snapshot.progress,
            progressWanted: snapshot.progressWanted,
            hasMetadata: snapshot.hasMetadata,
            isPaused: snapshot.isPaused,
            isFinished: snapshot.isFinished,
            isSeed: snapshot.isSeed,
            downloadSpeed: Double(snapshot.downloadRate),
            uploadSpeed: Double(snapshot.uploadRate),
            numberOfPeers: Int(snapshot.numberOfPeers),
            numberOfSeeds: Int(snapshot.numberOfSeeds),
            numberOfLeechers: Int(snapshot.numberOfLeechers),
            numberOfTotalPeers: Int(snapshot.numberOfTotalPeers),
            numberOfTotalSeeds: Int(snapshot.numberOfTotalSeeds),
            total: Int64(snapshot.total),
            totalDone: Int64(snapshot.totalDone),
            totalWanted: Int64(snapshot.totalWanted),
            totalWantedDone: Int64(snapshot.totalWantedDone),
            totalDownload: Int64(snapshot.totalDownload),
            totalUpload: Int64(snapshot.totalUpload),
            magnetUri: snapshot.magnetLink.isEmpty ? nil : snapshot.magnetLink,
            torrentFilePath: snapshot.torrentFilePath,
            downloadPath: snapshot.downloadPath?.path,
            addedDate: addedInterval * 1000,
            files: files,
            trackers: trackers
        )
    }

    private static func state(_ state: TorrentHandle.State) -> String {
        switch state {
        case .checkingFiles: return "checkingFiles"
        case .downloadingMetadata: return "downloadingMetadata"
        case .downloading: return "downloading"
        case .finished: return "finished"
        case .seeding: return "seeding"
        case .checkingResumeData: return "checkingResumeData"
        case .paused: return "paused"
        case .storageError: return "storageError"
        @unknown default: return "unknown"
        }
    }

    private static func trackerState(_ state: TorrentTracker.State) -> String {
        switch state {
        case .notContacted: return "notContacted"
        case .working: return "working"
        case .updating: return "updating"
        case .notWorking: return "notWorking"
        case .trackerError: return "trackerError"
        case .unreachable: return "unreachable"
        @unknown default: return "unknown"
        }
    }
}
