//
//  TorrentEngine.swift
//  DirXplore
//
//  Single, app-lifetime Torrent engine (libtorrent via LibTorrent-Swift).
//  Owns its own native session, download directory and resume data.
//  It must never be confused with DownloadManager (HTTP downloads).
//

import Foundation
import LibTorrent
import UIKit
import UniformTypeIdentifiers

final class TorrentEngine: NSObject {

    static let shared = TorrentEngine()

    weak var delegate: TorrentEngineDelegate?

    private(set) var isInitialized = false

    private let queue = DispatchQueue(label: "com.dirxplore.torrent.engine")
    private var session: Session?
    private var settings = Session.Settings()

    // Directories
    private let defaultDownloadDirName = "Torrents"
    private var downloadDirURL: URL?
    private var torrentsDirURL: URL?
    private var fastResumeDirURL: URL?
    private var bookmarksPlistURL: URL?
    private var customDownloadBookmark: Data?

    // Background handling
    private var pauseOnBackground = true
    private var resumeOnLaunch = true
    private var backgroundPausedHashes = Set<String>()

    // Folder picker
    private var folderPickerDelegate: FolderPickerDelegate?

    // MARK: - Lifecycle

    func initialize(settingsDict: [String: Any], completion: @escaping (Result<Void, TorrentEngineError>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.setupDirectories()
                try self.loadBookmarks()
                self.settings = TorrentEngine.settings(from: settingsDict)
                self.pauseOnBackground = settingsDict["pauseOnBackground"] as? Bool ?? true
                self.resumeOnLaunch = settingsDict["resumeOnLaunch"] as? Bool ?? true

                guard let downloadDir = self.downloadDirURL,
                      let torrentsDir = self.torrentsDirURL,
                      let fastResumeDir = self.fastResumeDirURL else {
                    throw TorrentEngineError.engineFailure("Unable to resolve torrent directories")
                }

                let session = Session(
                    downloadDir,
                    torrentsPath: torrentsDir,
                    fastResumePath: fastResumeDir,
                    settings: self.settings,
                    storages: [:]
                )
                session.add(self)
                self.session = session
                self.isInitialized = true

                self.observeLifecycle()

                if self.resumeOnLaunch {
                    self.resumePausedTorrents()
                }
                self.emitUpdate()
                completion(.success(()))
            } catch let error as TorrentEngineError {
                completion(.failure(error))
            } catch {
                completion(.failure(.engineFailure(error.localizedDescription)))
            }
        }
    }

    func applySettings(_ dict: [String: Any]) {
        queue.async { [weak self] in
            guard let self else { return }
            self.pauseOnBackground = dict["pauseOnBackground"] as? Bool ?? self.pauseOnBackground
            self.resumeOnLaunch = dict["resumeOnLaunch"] as? Bool ?? self.resumeOnLaunch

            // Changing the download directory only affects torrents added
            // afterwards (existing torrents keep their save paths).
            if let newPath = dict["downloadDir"] as? String, !newPath.isEmpty {
                self.downloadDirURL = URL(fileURLWithPath: newPath, isDirectory: true)
                self.session?.downloadPath = newPath
            } else if let fallback = self.defaultDownloadDirURL(), dict["downloadDir"] as? String == "" {
                self.downloadDirURL = fallback
                self.session?.downloadPath = fallback.path
            }

            let newSettings = TorrentEngine.settings(from: dict)
            self.settings = newSettings
            self.session?.settings = newSettings
            self.emitUpdate()
        }
    }

    func shutdown() {
        queue.async { [weak self] in
            guard let self else { return }
            self.session = nil
            self.isInitialized = false
        }
    }

    // MARK: - Torrents

    func addMagnet(_ magnet: String) -> Result<String, TorrentEngineError> {
        queue.sync {
            guard let session = session, isInitialized else { return .failure(.notInitialized) }
            let trimmed = magnet.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("magnet:?"),
                  trimmed.lowercased().contains("xt=urn:btih:") else {
                return .failure(.invalidMagnet)
            }
            guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: encoded) else {
                return .failure(.invalidMagnet)
            }
            let magnetURI = MagnetURI(unsafeWithMagnetURI: url)
            if let existing = handle(for: (magnetURI.infoHashes.best as Data).hex) {
                return .failure(.duplicate)
            }
            guard let handle = session.addTorrent(magnetURI) else {
                return .failure(.engineFailure("The engine could not add this magnet link"))
            }
            let infoHash = (handle.infoHashes.best as Data).hex.lowercased()
            handle.updateSnapshot()
            delegate?.torrentEngine(self, didAddTorrent: infoHash)
            emitUpdate()
            return .success(infoHash)
        }
    }

    func addTorrentFile(at path: String, selectedIndices: [Int]?, startPaused: Bool) -> Result<String, TorrentEngineError> {
        queue.sync {
            guard let session = session, isInitialized else { return .failure(.notInitialized) }
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .failure(.invalidTorrentFile)
            }
            let torrentFile = TorrentFile(unsafeWithFileAtURL: url)
            guard torrentFile.isValid else {
                return .failure(.invalidTorrentFile)
            }

            if let indices = selectedIndices, indices.isEmpty {
                torrentFile.setAllFilesPriority(.dontDownload)
            } else if let indices = selectedIndices {
                let selected = Set(indices)
                for file in torrentFile.files {
                    torrentFile.setFilePriority(
                        selected.contains(Int(file.index)) ? .defaultPriority : .dontDownload,
                        at: NSInteger(file.index)
                    )
                }
            }

            if let existing = handle(for: (torrentFile.infoHashes.best as Data).hex) {
                return .failure(.duplicate)
            }

            guard let handle = session.addTorrent(torrentFile) else {
                return .failure(.engineFailure("The engine could not add this torrent file"))
            }
            if startPaused {
                handle.pause()
            }
            let infoHash = (handle.infoHashes.best as Data).hex.lowercased()
            handle.updateSnapshot()
            delegate?.torrentEngine(self, didAddTorrent: infoHash)
            emitUpdate()
            return .success(infoHash)
        }
    }

    func parseTorrentFile(at path: String) -> Result<[String: Any], TorrentEngineError> {
        queue.sync {
            let url = URL(fileURLWithPath: path)
            let torrentFile = TorrentFile(unsafeWithFileAtURL: url)
            guard torrentFile.isValid else { return .failure(.invalidTorrentFile) }
            var files: [[String: Any]] = []
            for file in torrentFile.files {
                files.append([
                    "index": file.index,
                    "name": file.name,
                    "path": file.path,
                    "size": Int64(file.size),
                ])
            }
            return .success([
                "name": torrentFile.name,
                "files": files,
            ])
        }
    }

    func pause(_ infoHash: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.handle(for: infoHash)?.pause()
            self.emitUpdate()
        }
    }

    func resume(_ infoHash: String) {
        queue.async { [weak self] in
            guard let self else { return }
            if let handle = self.handle(for: infoHash) {
                handle.resume()
                handle.updateSnapshot()
            }
            self.emitUpdate()
        }
    }

    func remove(_ infoHash: String, deleteFiles: Bool) {
        queue.async { [weak self] in
            guard let self, let session = self.session else { return }
            if let handle = self.handle(for: infoHash) {
                session.removeTorrent(handle, deleteFiles: deleteFiles)
                self.delegate?.torrentEngine(self, didRemoveTorrent: infoHash)
            }
            self.emitUpdate()
        }
    }

    func recheck(_ infoHash: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.handle(for: infoHash)?.rehash()
            self.emitUpdate()
        }
    }

    func forceAnnounce(_ infoHash: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.handle(for: infoHash)?.forceReannounce()
            self.emitUpdate()
        }
    }

    func setFilePriority(_ infoHash: String, index: Int, priority: Int) {
        queue.async { [weak self] in
            guard let self, let handle = self.handle(for: infoHash) else { return }
            handle.setFilePriority(self.filePriority(from: priority), at: NSInteger(index))
            handle.updateSnapshot()
            self.emitUpdate()
        }
    }

    func setFilesPriority(_ infoHash: String, indices: [Int], priority: Int) {
        queue.async { [weak self] in
            guard let self, let handle = self.handle(for: infoHash) else { return }
            handle.setFilesPriority(self.filePriority(from: priority), at: indices.map { NSNumber(value: $0) })
            handle.updateSnapshot()
            self.emitUpdate()
        }
    }

    func setDownloadLimit(_ bytesPerSecond: Int64) {
        queue.async { [weak self] in
            guard let self else { return }
            self.settings.maxDownloadSpeed = bytesPerSecond > 0 ? UInt(max(0, bytesPerSecond)) : 0
            self.session?.settings = self.settings
        }
    }

    func setUploadLimit(_ bytesPerSecond: Int64) {
        queue.async { [weak self] in
            guard let self else { return }
            self.settings.maxUploadSpeed = bytesPerSecond > 0 ? UInt(max(0, bytesPerSecond)) : 0
            self.session?.settings = self.settings
        }
    }

    // MARK: - Snapshots

    func torrentTasks() -> [TorrentTaskModel] {
        queue.sync {
            var tasks: [TorrentTaskModel] = []
            for handle in session?.torrents ?? [] {
                handle.updateSnapshot()
                if let task = TorrentTaskSerializer.serialize(handle: handle) {
                    tasks.append(task)
                }
            }
            return tasks
        }
    }

    func torrentTask(infoHash: String) -> TorrentTaskModel? {
        queue.sync {
            guard let handle = handle(for: infoHash) else { return nil }
            handle.updateSnapshot()
            return TorrentTaskSerializer.serialize(handle: handle)
        }
    }

    // MARK: - Download folder

    func defaultDownloadDirURL() -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents.appendingPathComponent(defaultDownloadDirName, isDirectory: true)
    }

    func resolvedDownloadPath() -> String? {
        queue.sync {
            resolveDownloadFolder()?.path
        }
    }

    func pickDownloadFolder(completion: @escaping (String?) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                completion(nil)
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    completion(nil)
                    return
                }
                guard let root = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first?.keyWindow?.rootViewController else {
                    completion(nil)
                    return
                }

                let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
                picker.allowsMultipleSelection = false

                let delegate = FolderPickerDelegate { [weak self] url in
                    guard let self else { return }
                    self.queue.async { [weak self] in
                        guard let self else { return }
                        defer { self.folderPickerDelegate = nil }
                        guard let url = url,
                              let bookmark = try? url.bookmarkData(
                                  options: [.minimalBookmark],
                                  includingResourceValuesForKeys: nil,
                                  relativeTo: nil
                              ) else {
                            completion(nil)
                            return
                        }
                        self.customDownloadBookmark = bookmark
                        self.saveBookmarks()
                        self.downloadDirURL = url
                        self.session?.downloadPath = url.path
                        completion(url.path)
                    }
                }
                folderPickerDelegate = delegate
                picker.delegate = delegate
                root.present(picker, animated: true)
            }
        }
    }

    // MARK: - Session delegate plumbing

    private func emitUpdate() {
        let tasks = torrentTasks()
        delegate?.torrentEngine(self, didUpdateTorrents: tasks)
    }

    // MARK: - Settings mapping

    private static func settings(from dict: [String: Any]) -> Session.Settings {
        let s = Session.Settings()
        s.agentName = "DirXplore/3.0 (libtorrent)"
        s.port = dict["listenPort"] as? Int ?? 6881
        s.maxActiveTorrents = dict["maxActiveTorrents"] as? Int ?? 3
        s.maxDownloadingTorrents = dict["maxDownloadingTorrents"] as? Int ?? 2
        s.maxUploadingTorrents = dict["maxSeedingTorrents"] as? Int ?? 1

        let downloadKBps = dict["downloadSpeedLimit"] as? Int ?? 0
        let uploadKBps = dict["uploadSpeedLimit"] as? Int ?? 0
        s.maxDownloadSpeed = downloadKBps > 0 ? UInt(downloadKBps * 1024) : 0
        s.maxUploadSpeed = uploadKBps > 0 ? UInt(uploadKBps * 1024) : 0

        s.isDhtEnabled = dict["dhtEnabled"] as? Bool ?? true
        s.isLsdEnabled = dict["lsdEnabled"] as? Bool ?? true
        s.isUtpEnabled = dict["utpEnabled"] as? Bool ?? true
        s.isUpnpEnabled = dict["upnpEnabled"] as? Bool ?? true
        s.isNatEnabled = dict["natpmpEnabled"] as? Bool ?? true
        s.encryptionPolicy = (dict["encryptionEnabled"] as? Bool ?? true)
            ? .enabled
            : .disabled
        return s
    }

    private func filePriority(from raw: Int) -> FileEntry.Priority {
        switch raw {
        case 0: return .dontDownload
        case 1: return .lowPriority
        case 7: return .topPriority
        default: return .defaultPriority
        }
    }

    // MARK: - Lookup

    private func handle(for infoHash: String) -> TorrentHandle? {
        let lower = infoHash.lowercased()
        return session?.torrents.first { (($0.infoHashes.best as Data).hex.lowercased()) == lower }
    }

    // MARK: - Directories & bookmarks

    private func setupDirectories() throws {
        let fileManager = FileManager.default

        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
              let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw TorrentEngineError.engineFailure("Cannot access app directories")
        }

        let defaultDir = documents.appendingPathComponent(defaultDownloadDirName, isDirectory: true)
        let torrentsDir = appSupport.appendingPathComponent("Torrent", isDirectory: true)
            .appendingPathComponent("torrents", isDirectory: true)
        let fastResumeDir = appSupport.appendingPathComponent("Torrent", isDirectory: true)
            .appendingPathComponent("resume", isDirectory: true)

        try fileManager.createDirectory(at: defaultDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: torrentsDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: fastResumeDir, withIntermediateDirectories: true)

        downloadDirURL = defaultDir
        torrentsDirURL = torrentsDir
        fastResumeDirURL = fastResumeDir

        let supportDir = appSupport.appendingPathComponent("Torrent", isDirectory: true)
        bookmarksPlistURL = supportDir.appendingPathComponent("bookmarks.plist")
    }

    private func loadBookmarks() {
        guard let url = bookmarksPlistURL,
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Data] else {
            return
        }
        customDownloadBookmark = plist["customDownloadFolder"]
    }

    private func saveBookmarks() {
        guard let url = bookmarksPlistURL else { return }
        var dict: [String: Data] = [:]
        if let bookmark = customDownloadBookmark {
            dict["customDownloadFolder"] = bookmark
        }
        let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        if let data = data {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func resolveDownloadFolder() -> URL? {
        if let bookmark = customDownloadBookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                bookmarkDataIsStale: &isStale
            ) {
                _ = url.startAccessingSecurityScopedResource()
                return url
            }
            if isStale {
                customDownloadBookmark = nil
                saveBookmarks()
            }
        }
        return downloadDirURL ?? defaultDownloadDirURL()
    }

    // MARK: - App lifecycle

    private func observeLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        queue.async { [weak self] in
            guard let self, self.pauseOnBackground else { return }
            self.backgroundPausedHashes.removeAll()
            for handle in self.session?.torrents ?? [] {
                let snapshot = handle.snapshot
                if snapshot.isValid && !snapshot.isPaused && !snapshot.isFinished && !snapshot.isSeed {
                    let hash = (handle.infoHashes.best as Data).hex.lowercased()
                    self.backgroundPausedHashes.insert(hash)
                    handle.pause()
                }
            }
        }
    }

    @objc private func appDidBecomeActive() {
        queue.async { [weak self] in
            guard let self, !self.backgroundPausedHashes.isEmpty else { return }
            let hashes = self.backgroundPausedHashes
            self.backgroundPausedHashes.removeAll()
            for hash in hashes {
                self.handle(for: hash)?.resume()
            }
            self.emitUpdate()
        }
    }

    private func resumePausedTorrents() {
        for handle in session?.torrents ?? [] {
            let snapshot = handle.snapshot
            if snapshot.isValid && snapshot.isPaused && !snapshot.isFinished && !snapshot.isSeed {
                handle.resume()
            }
        }
    }
}

// MARK: - SessionDelegate

extension TorrentEngine: SessionDelegate {
    func torrentManager(_ manager: Session, didAddTorrent torrent: TorrentHandle) {
        let infoHash = (torrent.infoHashes.best as Data).hex.lowercased()
        delegate?.torrentEngine(self, didAddTorrent: infoHash)
        emitUpdate()
    }

    func torrentManager(_ manager: Session, didRemoveTorrentWithHash hashesData: TorrentHashes) {
        let infoHash = (hashesData.best as Data).hex.lowercased()
        delegate?.torrentEngine(self, didRemoveTorrent: infoHash)
        emitUpdate()
    }

    func torrentManager(_ manager: Session, didReceiveUpdateForTorrent torrent: TorrentHandle) {
        // Throttled by TorrentBridge's 1 Hz timer to keep Flutter traffic low.
    }

    func torrentManager(_ manager: Session, didErrorOccur error: Error) {
        delegate?.torrentEngine(self, didFailWith: error)
    }
}

private final class FolderPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion(urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(nil)
    }
}
