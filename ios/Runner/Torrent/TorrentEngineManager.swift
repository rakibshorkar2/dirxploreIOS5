import Foundation
import Flutter

@objc class TorrentEngineManager: NSObject, SessionDelegate {
    static let shared = TorrentEngineManager()

    private var session: Session?
    private var isInitialized = false

    var eventSink: FlutterEventSink? {
        didSet {
            if eventSink != nil {
                replayPendingEvents()
            }
        }
    }
    private var pendingEvents: [[String: Any]] = []
    private var lastStatsUpdate: Date = Date.distantPast

    private override init() {
        super.init()
    }

    func initialize(downloadDir: String? = nil, completion: @escaping (Bool) -> Void) {
        if isInitialized {
            completion(true)
            return
        }

        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

        let baseTorrentDir = docs.appendingPathComponent("Torrents", isDirectory: true)
        let downloadPath: URL
        if let dirPath = downloadDir, !dirPath.isEmpty {
            downloadPath = URL(fileURLWithPath: dirPath)
        } else {
            downloadPath = baseTorrentDir.appendingPathComponent("Downloads", isDirectory: true)
        }
        let torrentsPath = baseTorrentDir.appendingPathComponent("Torrents", isDirectory: true)
        let fastResumePath = baseTorrentDir.appendingPathComponent("FastResume", isDirectory: true)

        try? fileManager.createDirectory(at: downloadPath, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: torrentsPath, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: fastResumePath, withIntermediateDirectories: true)

        let settings = Session.Settings()

        self.session = Session(
            downloadPath,
            torrentsPath: torrentsPath,
            fastResumePath: fastResumePath,
            settings: settings,
            storages: [:]
        )

        if let session = self.session {
            session.addDelegate(self)
            session.restoreSession()
            self.isInitialized = true
            completion(true)
        } else {
            completion(false)
        }
    }

    func shutdown() {
        guard let session = session else { return }
        session.pause()
        session.removeDelegate(self)
        self.session = nil
        self.isInitialized = false
    }

    func addMagnet(magnetUri: String, savePath: String?, completion: @escaping ([String: Any]?) -> Void) {
        guard let session = session, let url = URL(string: magnetUri) else {
            completion(nil)
            return
        }

        let magnet = MagnetURI(unsafeWithMagnetURI: url)
        if let handle = session.addTorrent(magnet) {
            handle.updateSnapshot()
            let dict = torrentToDictionary(handle)
            completion(dict)
        } else {
            completion(nil)
        }
    }

    func addTorrentFile(filePath: String, savePath: String?, completion: @escaping ([String: Any]?) -> Void) {
        guard let session = session else {
            completion(nil)
            return
        }

        let fileURL = URL(fileURLWithPath: filePath)
        let torrentFile = TorrentFile(unsafeWithFileAtURL: fileURL)
        if let handle = session.addTorrent(torrentFile) {
            handle.updateSnapshot()
            let dict = torrentToDictionary(handle)
            completion(dict)
        } else {
            completion(nil)
        }
    }

    func removeTorrent(infoHash: String, deleteData: Bool, completion: @escaping (Bool) -> Void) {
        guard let session = session else {
            completion(false)
            return
        }

        let targetHash = infoHash.lowercased()
        for handle in session.torrents {
            let hashStr = torrentHashesToString(handle.infoHashes)
            if hashStr.lowercased() == targetHash {
                session.removeTorrent(handle, deleteFiles: deleteData)
                completion(true)
                return
            }
        }
        completion(false)
    }

    func pauseTorrent(infoHash: String, completion: @escaping (Bool) -> Void) {
        guard let session = session else { completion(false); return }
        let targetHash = infoHash.lowercased()
        for handle in session.torrents {
            if torrentHashesToString(handle.infoHashes).lowercased() == targetHash {
                handle.pause()
                completion(true)
                return
            }
        }
        completion(false)
    }

    func resumeTorrent(infoHash: String, completion: @escaping (Bool) -> Void) {
        guard let session = session else { completion(false); return }
        let targetHash = infoHash.lowercased()
        for handle in session.torrents {
            if torrentHashesToString(handle.infoHashes).lowercased() == targetHash {
                handle.resume()
                completion(true)
                return
            }
        }
        completion(false)
    }

    func forceStartTorrent(infoHash: String, completion: @escaping (Bool) -> Void) {
        resumeTorrent(infoHash: infoHash, completion: completion)
    }

    func recheckTorrent(infoHash: String, completion: @escaping (Bool) -> Void) {
        guard let session = session else { completion(false); return }
        let targetHash = infoHash.lowercased()
        for handle in session.torrents {
            if torrentHashesToString(handle.infoHashes).lowercased() == targetHash {
                handle.rehash()
                completion(true)
                return
            }
        }
        completion(false)
    }

    func setFilePriority(infoHash: String, fileIndex: Int, priority: Int, completion: @escaping (Bool) -> Void) {
        guard let session = session else { completion(false); return }
        let targetHash = infoHash.lowercased()
        for handle in session.torrents {
            if torrentHashesToString(handle.infoHashes).lowercased() == targetHash {
                let filePriority = FileEntry.Priority(rawValue: UInt8(clamping: priority)) ?? .defaultPriority
                handle.setFilePriority(filePriority, at: fileIndex)
                completion(true)
                return
            }
        }
        completion(false)
    }

    func setSequentialDownload(infoHash: String, enabled: Bool, completion: @escaping (Bool) -> Void) {
        guard let session = session else { completion(false); return }
        let targetHash = infoHash.lowercased()
        for handle in session.torrents {
            if torrentHashesToString(handle.infoHashes).lowercased() == targetHash {
                handle.setSequentialDownload(enabled)
                completion(true)
                return
            }
        }
        completion(false)
    }

    func getTorrents() -> [[String: Any]] {
        guard let session = session else { return [] }
        return session.torrents.map { handle in
            handle.updateSnapshot()
            return torrentToDictionary(handle)
        }
    }

    func getSessionStats() -> [String: Any] {
        guard let session = session else {
            return [
                "totalDownloadSpeed": 0,
                "totalUploadSpeed": 0,
                "activeCount": 0,
                "pausedCount": 0,
                "completedCount": 0,
                "totalCount": 0
            ]
        }

        var totalDl: UInt64 = 0
        var totalUl: UInt64 = 0
        var active = 0
        var paused = 0
        var completed = 0

        for handle in session.torrents {
            let snap = handle.snapshot
            totalDl += snap.downloadRate
            totalUl += snap.uploadRate

            if snap.isPaused {
                paused += 1
            } else if snap.isFinished || snap.isSeed {
                completed += 1
            } else {
                active += 1
            }
        }

        return [
            "totalDownloadSpeed": totalDl,
            "totalUploadSpeed": totalUl,
            "activeCount": active,
            "pausedCount": paused,
            "completedCount": completed,
            "totalCount": session.torrents.count
        ]
    }

    // MARK: - SessionDelegate Protocol

    func torrentManager(_ manager: Session, didAddTorrent torrent: TorrentHandle) {
        torrent.updateSnapshot()
        let dict = torrentToDictionary(torrent)
        sendEvent(["eventType": "torrentAdded", "torrent": dict])
    }

    func torrentManager(_ manager: Session, didRemoveTorrentWithHash hashesData: TorrentHashes) {
        let hashStr = torrentHashesToString(hashesData)
        sendEvent(["eventType": "torrentRemoved", "infoHash": hashStr])
    }

    func torrentManager(_ manager: Session, didReceiveUpdateForTorrent torrent: TorrentHandle) {
        torrent.updateSnapshot()
        let dict = torrentToDictionary(torrent)
        sendEvent(["eventType": "torrentUpdated", "torrent": dict])
    }

    func torrentManager(_ manager: Session, didErrorOccur error: Error) {
        sendEvent(["eventType": "torrentError", "infoHash": "", "error": error.localizedDescription])
    }

    // MARK: - Helpers

    private func sendEvent(_ event: [String: Any]) {
        DispatchQueue.main.async {
            if let sink = self.eventSink {
                sink(event)
            } else {
                self.pendingEvents.append(event)
            }
        }
    }

    private func replayPendingEvents() {
        guard let sink = eventSink else { return }
        for event in pendingEvents {
            sink(event)
        }
        pendingEvents.removeAll()
    }

    private func torrentHashesToString(_ hashes: TorrentHashes) -> String {
        if hashes.hasV1 {
            return hashes.v1.map { String(format: "%02hhx", $0) }.joined()
        }
        if hashes.hasV2 {
            return hashes.v2.prefix(20).map { String(format: "%02hhx", $0) }.joined()
        }
        return hashes.best.prefix(20).map { String(format: "%02hhx", $0) }.joined()
    }

    private func torrentToDictionary(_ handle: TorrentHandle) -> [String: Any] {
        let snap = handle.snapshot
        let hashStr = torrentHashesToString(snap.infoHashes)

        var statusStr = "queued"
        if snap.isPaused {
            statusStr = "paused"
        } else if snap.isFinished || snap.isSeed {
            statusStr = "completed"
        } else {
            switch snap.state {
            case .checkingFiles, .checkingResumeData:
                statusStr = "checking"
            case .downloadingMetadata:
                statusStr = "downloading_metadata"
            case .downloading:
                statusStr = "downloading"
            case .seeding:
                statusStr = "seeding"
            default:
                statusStr = "queued"
            }
        }

        var filesList: [[String: Any]] = []
        for (idx, file) in snap.files.enumerated() {
            filesList.append([
                "index": idx,
                "path": file.path,
                "name": (file.path as NSString).lastPathComponent,
                "size": file.size,
                "downloaded": file.downloaded,
                "priority": file.priority.rawValue
            ])
        }

        var trackersList: [[String: Any]] = []
        for tracker in snap.trackers {
            trackersList.append([
                "url": tracker.trackerUrl,
                "status": "working",
                "peers": 0,
                "message": ""
            ])
        }

        return [
            "infoHash": hashStr,
            "name": snap.name,
            "status": statusStr,
            "progress": snap.progress,
            "downloadSpeed": snap.downloadRate,
            "uploadSpeed": snap.uploadRate,
            "totalSize": snap.total,
            "downloadedSize": snap.totalDone,
            "uploadedSize": snap.totalUpload,
            "numberOfPeers": snap.numberOfPeers,
            "numberOfSeeds": snap.numberOfSeeds,
            "numberOfLeechers": snap.numberOfLeechers,
            "magnetUri": snap.magnetLink,
            "torrentFilePath": snap.torrentFilePath ?? "",
            "downloadPath": snap.downloadPath?.path ?? "",
            "isSequential": snap.isSequential,
            "files": filesList,
            "trackers": trackersList
        ]
    }
}
