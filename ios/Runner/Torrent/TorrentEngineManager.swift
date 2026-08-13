import Foundation
import Flutter

@objc class TorrentEngineManager: NSObject, SessionDelegate {
    static let shared = TorrentEngineManager()

    private var session: Session?
    private var isInitialized = false

    // Throttling state
    private var lastStatsTime: Date = Date.distantPast
    private let statsInterval: TimeInterval = 0.5   // 2 Hz max
    private var lastUpdateTimes: [String: Date] = [:]
    private let updateInterval: TimeInterval = 0.333 // ~3 Hz max per torrent

    // Event transition tracking (fires metadataReceived / torrentCompleted once)
    private var hashesWithMetadata: Set<String> = []
    private var hashesCompleted: Set<String> = []

    // Persistent save-path storage mapping (path -> storage UUID)
    private let storageDefaultsKey = "torrent.storageUUIDs"
    private var storageUUIDsByPath: [String: String] = [:]

    var eventSink: FlutterEventSink? {
        didSet {
            if eventSink != nil {
                replayPendingEvents()
            }
        }
    }
    private var pendingEvents: [[String: Any]] = []

    private override init() {
        super.init()
        if let saved = UserDefaults.standard.dictionary(forKey: storageDefaultsKey) as? [String: String] {
            storageUUIDsByPath = saved
        }
    }

    // MARK: - Initialize

    func initialize(downloadDir: String? = nil, settings settingsDict: [String: Any]? = nil, completion: @escaping (Bool) -> Void) {
        if isInitialized {
            if let settingsDict = settingsDict, let session = session {
                applySettings(settingsDict, to: session)
            }
            completion(true)
            return
        }

        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

        let baseTorrentDir = docs.appendingPathComponent("Torrents", isDirectory: true)
        let downloadPath: URL
        if let dirPath = downloadDir, !dirPath.isEmpty {
            // Sanitise - must remain under Documents
            let resolved = URL(fileURLWithPath: dirPath)
            if resolved.path.hasPrefix(docs.path) {
                downloadPath = resolved
            } else {
                downloadPath = baseTorrentDir.appendingPathComponent("Downloads", isDirectory: true)
            }
        } else {
            downloadPath = baseTorrentDir.appendingPathComponent("Downloads", isDirectory: true)
        }
        let torrentsPath = baseTorrentDir.appendingPathComponent("Torrents", isDirectory: true)
        let fastResumePath = baseTorrentDir.appendingPathComponent("FastResume", isDirectory: true)

        try? fileManager.createDirectory(at: downloadPath, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: torrentsPath, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: fastResumePath, withIntermediateDirectories: true)

        let nativeSettings: Session.Settings
        if let settingsDict = settingsDict {
            nativeSettings = buildSettings(from: settingsDict)
        } else {
            nativeSettings = Session.Settings()
        }

        // Register every persisted custom save path before restoreSession() runs
        // inside Session init, so fast-resume storage UUIDs resolve correctly.
        let storages = buildStorages()

        self.session = Session(
            downloadPath,
            torrentsPath: torrentsPath,
            fastResumePath: fastResumePath,
            settings: nativeSettings,
            storages: storages
        )

        if let session = self.session {
            session.addDelegate(self)
            // restoreSession() is called inside Session init already
            self.isInitialized = true
            completion(true)
        } else {
            completion(false)
        }
    }

    // MARK: - Shutdown

    func shutdown() {
        guard let session = session else { return }
        session.pause()
        session.removeDelegate(self)
        // Stop the alert loop first; the Session must not be deallocated while
        // the alert thread is still using the underlying lt::session.
        session.stop()
        self.session = nil
        self.isInitialized = false
        hashesWithMetadata.removeAll()
        hashesCompleted.removeAll()
        lastUpdateTimes.removeAll()
    }

    // MARK: - Session Settings

    func configureSession(settingsDict: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let session = session else { completion(false); return }
        applySettings(settingsDict, to: session)
        completion(true)
    }

    private func applySettings(_ settingsDict: [String: Any], to session: Session) {
        let newSettings = buildSettings(from: settingsDict)
        session.settings = newSettings

        // Runtime network toggles. settings_pack flags only apply at session
        // creation, so start/stop the services explicitly when the value is
        // provided (absence of a key must not toggle anything).
        if let enabled = settingsDict["enableDht"] as? Bool {
            enabled ? session.startDht() : session.stopDht()
        }
        if let enabled = settingsDict["enableUpnp"] as? Bool {
            enabled ? session.startUpnp() : session.stopUpnp()
        }
        if let enabled = settingsDict["enableNatPmp"] as? Bool {
            enabled ? session.startNatPmp() : session.stopNatPmp()
        }

        // Per-torrent connection limits are per-torrent state, not a session
        // setting. Push the value to every live torrent.
        if let maxPerTorrent = settingsDict["maxConnectionsPerTorrent"] as? Int, maxPerTorrent > 0 {
            for handle in session.torrents {
                handle.setMaxConnections(maxPerTorrent)
            }
        }
    }

    private func buildSettings(from dict: [String: Any]) -> Session.Settings {
        let s = Session.Settings()
        s.isDhtEnabled   = dict["enableDht"] as? Bool ?? true
        s.isUpnpEnabled  = dict["enableUpnp"] as? Bool ?? true
        s.isNatEnabled   = dict["enableNatPmp"] as? Bool ?? true
        s.isLsdEnabled   = dict["enableLsd"] as? Bool ?? true
        s.isUtpEnabled   = dict["enableUtp"] as? Bool ?? true

        if let port = dict["listenPort"] as? Int, port > 0 {
            s.port = port
        }

        if let dlLimit = dict["downloadLimit"] as? Int {
            s.maxDownloadSpeed = UInt(max(0, dlLimit))
        }
        if let ulLimit = dict["uploadLimit"] as? Int {
            s.maxUploadSpeed = UInt(max(0, ulLimit))
        }
        if let maxConn = dict["maxConnections"] as? Int {
            s.maxConnections = maxConn
        }
        if let maxConnPer = dict["maxConnectionsPerTorrent"] as? Int {
            s.maxConnectionsPerTorrent = maxConnPer
        }
        return s
    }

    // MARK: - Persistent save paths

    /// Builds the storages dictionary passed to the Session initializer so
    /// that restoreSession() can resolve persisted storage UUIDs.
    private func buildStorages() -> [UUID: StorageModel] {
        var storages: [UUID: StorageModel] = [:]
        let fileManager = FileManager.default
        for (path, uuidString) in storageUUIDsByPath {
            guard let uuid = UUID(uuidString: uuidString) else { continue }
            if fileManager.fileExists(atPath: path) {
                storages[uuid] = makeStorageModel(path: path, uuid: uuid)
            }
        }
        return storages
    }

    private func makeStorageModel(path: String, uuid: UUID) -> StorageModel {
        let storage = StorageModel()
        storage.uuid = uuid
        storage.name = (path as NSString).lastPathComponent
        // App-internal directories need no security-scoped bookmark. resolved
        // and allowed are set directly (see Session.registerStorageWithPath).
        storage.pathBookmark = Data()
        storage.url = URL(fileURLWithPath: path)
        storage.resolved = true
        storage.allowed = true
        return storage
    }

    private func storageUUID(forPath path: String) -> UUID {
        if let existing = storageUUIDsByPath[path], let uuid = UUID(uuidString: existing) {
            return uuid
        }
        let uuid = UUID()
        storageUUIDsByPath[path] = uuid.uuidString
        UserDefaults.standard.set(storageUUIDsByPath, forKey: storageDefaultsKey)
        return uuid
    }

    /// Resolves a save path into a registered storage UUID. Returns nil for
    /// paths outside the app sandbox or when no path is given (default path).
    private func resolveStorage(for savePath: String?, session: Session) -> UUID? {
        guard let path = savePath, !path.isEmpty else { return nil }
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = URL(fileURLWithPath: path)
        guard url.path.hasPrefix(docs.path) else { return nil }
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        let uuid = storageUUID(forPath: url.path)
        session.registerStorageWithPath(url.path, uuid: uuid)
        return uuid
    }

    // MARK: - Add Torrent

    func addMagnet(magnetUri: String, savePath: String?, completion: @escaping ([String: Any]?) -> Void) {
        guard let session = session, let url = URL(string: magnetUri) else {
            completion(nil)
            return
        }
        guard let magnet = MagnetURI(unsafeWithMagnetURI: url) else {
            completion(nil)
            return
        }

        // Duplicate check by real info hashes (handles v1/v2/hybrid magnets)
        if let existingHandle = findExistingTorrent(with: magnet.infoHashes) {
            existingHandle.updateSnapshot()
            completion(torrentToDictionary(existingHandle))
            return
        }

        let storage = resolveStorage(for: savePath, session: session)
        if let handle = session.addTorrent(magnet, to: storage) {
            handle.updateSnapshot()
            completion(torrentToDictionary(handle))
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
        guard let torrentFile = TorrentFile(unsafeWithFileAtURL: fileURL) else {
            completion(nil)
            return
        }

        // Duplicate check by real info hashes (v1/v2/hybrid aware)
        if let existingHandle = findExistingTorrent(with: torrentFile.infoHashes) {
            existingHandle.updateSnapshot()
            completion(torrentToDictionary(existingHandle))
            return
        }

        let storage = resolveStorage(for: savePath, session: session)
        if let handle = session.addTorrent(torrentFile, to: storage) {
            handle.updateSnapshot()
            completion(torrentToDictionary(handle))
        } else {
            completion(nil)
        }
    }

    private func findExistingTorrent(with hashes: TorrentHashes) -> TorrentHandle? {
        guard let session = session else { return nil }
        for handle in session.torrents {
            if torrentHashesMatch(handle.infoHashes, hashes) {
                return handle
            }
        }
        return nil
    }

    private func torrentHashesMatch(_ a: TorrentHashes, _ b: TorrentHashes) -> Bool {
        if a.hasV1 && b.hasV1 && a.v1 == b.v1 { return true }
        if a.hasV2 && b.hasV2 && a.v2 == b.v2 { return true }
        return false
    }

    // MARK: - Torrent Controls

    func removeTorrent(infoHash: String, deleteData: Bool, completion: @escaping (Bool) -> Void) {
        guard let session = session else { completion(false); return }
        let targetHash = infoHash.lowercased()
        for handle in session.torrents {
            if torrentHashesToString(handle.infoHashes).lowercased() == targetHash {
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

    // MARK: - Queries

    func getTorrents() -> [[String: Any]] {
        guard let session = session else { return [] }
        return session.torrents.map { handle in
            handle.updateSnapshot()
            return torrentToDictionary(handle)
        }
    }

    func getPeers(infoHash: String) -> [[String: Any]] {
        guard let session = session else { return [] }
        let targetHash = infoHash.lowercased()
        for handle in session.torrents {
            if torrentHashesToString(handle.infoHashes).lowercased() == targetHash {
                return handle.getPeerInfo() as? [[String: Any]] ?? []
            }
        }
        return []
    }

    func getTrackers(infoHash: String) -> [[String: Any]] {
        guard let session = session else { return [] }
        let targetHash = infoHash.lowercased()
        for handle in session.torrents {
            if torrentHashesToString(handle.infoHashes).lowercased() == targetHash {
                handle.updateSnapshot()
                return buildTrackersList(from: handle.snapshot.trackers)
            }
        }
        return []
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

    // MARK: - SessionDelegate

    func torrentManager(_ manager: Session, didAddTorrent torrent: TorrentHandle) {
        torrent.updateSnapshot()
        let dict = torrentToDictionary(torrent)
        let hashStr = dict["infoHash"] as? String ?? ""
        if torrent.snapshot.hasMetadata {
            hashesWithMetadata.insert(hashStr)
        }
        sendEvent(["eventType": "torrentAdded", "torrent": dict])
    }

    func torrentManager(_ manager: Session, didRemoveTorrentWithHash hashesData: TorrentHashes) {
        let hashStr = torrentHashesToString(hashesData)
        hashesWithMetadata.remove(hashStr)
        hashesCompleted.remove(hashStr)
        lastUpdateTimes.removeValue(forKey: hashStr)
        sendEvent(["eventType": "torrentRemoved", "infoHash": hashStr])
    }

    func torrentManager(_ manager: Session, didReceiveUpdateForTorrent torrent: TorrentHandle) {
        torrent.updateSnapshot()
        let snap = torrent.snapshot
        let hashStr = torrentHashesToString(snap.infoHashes)

        // Throttle per-torrent update events
        let now = Date()
        if let lastTime = lastUpdateTimes[hashStr], now.timeIntervalSince(lastTime) < updateInterval {
            return
        }
        lastUpdateTimes[hashStr] = now

        let dict = torrentToDictionary(torrent)

        // Metadata just received (magnet turned into a real torrent) - fires once
        if snap.hasMetadata && !hashesWithMetadata.contains(hashStr) {
            hashesWithMetadata.insert(hashStr)
            sendEvent(["eventType": "metadataReceived", "infoHash": hashStr, "torrent": dict])
        }

        // Completion - fires once per torrent
        if (snap.isFinished || snap.isSeed) && !hashesCompleted.contains(hashStr) {
            hashesCompleted.insert(hashStr)
            sendEvent(["eventType": "torrentCompleted", "infoHash": hashStr, "torrent": dict])
        }

        sendEvent(["eventType": "torrentUpdated", "torrent": dict])

        // Global stats throttle
        if now.timeIntervalSince(lastStatsTime) >= statsInterval {
            lastStatsTime = now
            sendEvent(["eventType": "statsUpdated", "stats": getSessionStats()])
        }
    }

    func torrentManager(_ manager: Session, didErrorOccur error: Error) {
        sendEvent(["eventType": "torrentError", "infoHash": "", "error": error.localizedDescription])
    }

    // MARK: - Events

    private func sendEvent(_ event: [String: Any]) {
        DispatchQueue.main.async {
            if let sink = self.eventSink {
                sink(event)
            } else {
                // Keep a bounded buffer of pending events
                if self.pendingEvents.count < 200 {
                    self.pendingEvents.append(event)
                }
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

    // MARK: - Helpers

    private func torrentHashesToString(_ hashes: TorrentHashes) -> String {
        if hashes.hasV1 {
            return hashes.v1.map { String(format: "%02hhx", $0) }.joined()
        }
        if hashes.hasV2 {
            // Return full v2 hash (32 bytes = 64 hex chars), do NOT truncate to 20 bytes
            return hashes.v2.map { String(format: "%02hhx", $0) }.joined()
        }
        return hashes.best.map { String(format: "%02hhx", $0) }.joined()
    }

    private func buildTrackersList(from trackers: [TorrentTracker]) -> [[String: Any]] {
        return trackers.map { tracker in
            let stateStr: String
            switch tracker.state {
            case .working:
                stateStr = "working"
            case .updating:
                stateStr = "updating"
            case .trackerError:
                stateStr = "error"
            case .notWorking:
                stateStr = "error"
            case .unreachable:
                stateStr = "error"
            case .notContacted:
                stateStr = "queued"
            @unknown default:
                stateStr = "unknown"
            }

            return [
                "url": tracker.trackerUrl,
                "status": stateStr,
                "seeds": tracker.seeds >= 0 ? tracker.seeds : NSNull(),
                "peers": tracker.peers >= 0 ? tracker.peers : NSNull(),
                "leeches": tracker.leeches >= 0 ? tracker.leeches : NSNull(),
                "downloaded": tracker.downloaded >= 0 ? tracker.downloaded : NSNull(),
                "message": tracker.message ?? NSNull()
            ]
        }
    }

    private func torrentToDictionary(_ handle: TorrentHandle) -> [String: Any] {
        let snap = handle.snapshot
        let hashStr = torrentHashesToString(snap.infoHashes)

        var statusStr = "queued"
        if snap.isPaused {
            statusStr = "paused"
        } else if snap.isFinished || snap.isSeed {
            statusStr = snap.isSeed ? "seeding" : "completed"
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

        // Use real tracker information (never fabricate)
        let trackersList = buildTrackersList(from: snap.trackers)

        var dict: [String: Any] = [
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
            "downloadPath": snap.downloadPath?.path ?? "",
            "isSequential": snap.isSequential,
            "hasMetadata": snap.hasMetadata,
            "files": filesList,
            "trackers": trackersList,
            "addedDate": snap.addedDate?.timeIntervalSince1970 ?? 0
        ]

        if let torrentFilePath = snap.torrentFilePath {
            dict["torrentFilePath"] = torrentFilePath
        }

        // Include v1/v2 separately for hybrid-torrent support
        if snap.infoHashes.hasV1 {
            dict["v1InfoHash"] = snap.infoHashes.v1.map { String(format: "%02hhx", $0) }.joined()
        }
        if snap.infoHashes.hasV2 {
            dict["v2InfoHash"] = snap.infoHashes.v2.map { String(format: "%02hhx", $0) }.joined()
        }

        return dict
    }
}
