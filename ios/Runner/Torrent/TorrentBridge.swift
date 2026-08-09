//
//  TorrentBridge.swift
//  DirXplore
//
//  Flutter-facing facade for the isolated Torrent subsystem. Exposes
//  "com.dirxplore/ios_torrent" (methods) and "com.dirxplore/ios_torrent_events"
//  (1 Hz task snapshots). It must never be confused with DownloadPlugin.
//

import Flutter
import Foundation

final class TorrentBridge: NSObject, FlutterStreamHandler {

    static let shared = TorrentBridge()

    private let engine = TorrentEngine.shared
    private var eventSink: FlutterEventSink?
    private var updateTimer: Timer?

    private override init() {
        super.init()
        engine.delegate = self
    }

    // MARK: - Registration

    static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()

        let channel = FlutterMethodChannel(name: "com.dirxplore/ios_torrent", binaryMessenger: messenger)
        registrar.addMethodCallDelegate(TorrentBridge.shared, channel: channel)

        let eventChannel = FlutterEventChannel(name: "com.dirxplore/ios_torrent_events", binaryMessenger: messenger)
        eventChannel.setStreamHandler(TorrentBridge.shared)
    }

    // MARK: - Method channel

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "initialize":
            engine.initialize(settingsDict: args) { [weak self] outcome in
                self?.finish(result, outcome: outcome)
            }

        case "applySettings":
            engine.applySettings(args)
            main { result(true) }

        case "shutdown":
            engine.shutdown()
            main { result(true) }

        case "isInitialized":
            main { result(engine.isInitialized) }

        case "addMagnet":
            guard let magnet = args["magnet"] as? String else {
                main { result(FlutterError(code: "INVALID_ARGS", message: "Missing magnet", details: nil)) }
                return
            }
            main { [engine] in
                switch engine.addMagnet(magnet) {
                case .success(let infoHash): result(infoHash)
                case .failure(let error): result(FlutterError(code: "TORRENT_ERROR", message: error.localizedDescription, details: nil))
                }
            }

        case "addTorrentFile":
            guard let path = args["path"] as? String else {
                main { result(FlutterError(code: "INVALID_ARGS", message: "Missing path", details: nil)) }
                return
            }
            let indices = (args["selectedIndices"] as? [Int]).map { $0.map { Int($0) } }
            let startPaused = args["startPaused"] as? Bool ?? false
            main { [engine] in
                switch engine.addTorrentFile(at: path, selectedIndices: indices, startPaused: startPaused) {
                case .success(let infoHash): result(infoHash)
                case .failure(let error): result(FlutterError(code: "TORRENT_ERROR", message: error.localizedDescription, details: nil))
                }
            }

        case "parseTorrentFile":
            guard let path = args["path"] as? String else {
                main { result(FlutterError(code: "INVALID_ARGS", message: "Missing path", details: nil)) }
                return
            }
            main { [engine] in
                switch engine.parseTorrentFile(at: path) {
                case .success(let info): result(info)
                case .failure(let error): result(FlutterError(code: "TORRENT_ERROR", message: error.localizedDescription, details: nil))
                }
            }

        case "pause":
            if let infoHash = args["infoHash"] as? String {
                engine.pause(infoHash)
            }
            main { result(true) }

        case "resume":
            if let infoHash = args["infoHash"] as? String {
                engine.resume(infoHash)
            }
            main { result(true) }

        case "remove":
            if let infoHash = args["infoHash"] as? String {
                let deleteFiles = args["deleteFiles"] as? Bool ?? false
                engine.remove(infoHash, deleteFiles: deleteFiles)
            }
            main { result(true) }

        case "recheck":
            if let infoHash = args["infoHash"] as? String {
                engine.recheck(infoHash)
            }
            main { result(true) }

        case "forceAnnounce":
            if let infoHash = args["infoHash"] as? String {
                engine.forceAnnounce(infoHash)
            }
            main { result(true) }

        case "setFilePriority":
            if let infoHash = args["infoHash"] as? String,
               let index = args["index"] as? Int,
               let priority = args["priority"] as? Int {
                engine.setFilePriority(infoHash, index: index, priority: priority)
            }
            main { result(true) }

        case "setFilesPriority":
            if let infoHash = args["infoHash"] as? String,
               let indices = args["indices"] as? [Int],
               let priority = args["priority"] as? Int {
                engine.setFilesPriority(infoHash, indices: indices.map { Int($0) }, priority: priority)
            }
            main { result(true) }

        case "setDownloadLimit":
            let bytes = args["bytesPerSecond"] as? Int64 ?? 0
            engine.setDownloadLimit(bytes)
            main { result(true) }

        case "setUploadLimit":
            let bytes = args["bytesPerSecond"] as? Int64 ?? 0
            engine.setUploadLimit(bytes)
            main { result(true) }

        case "getTorrents":
            main { [engine] in
                result(engine.torrentTasks().map { $0.toDictionary() })
            }

        case "getTorrent":
            guard let infoHash = args["infoHash"] as? String else {
                main { result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash", details: nil)) }
                return
            }
            main { [engine] in
                result(engine.torrentTask(infoHash: infoHash)?.toDictionary())
            }

        case "getDownloadPath":
            main { [engine] in
                result(engine.resolvedDownloadPath())
            }

        case "pickDownloadFolder":
            engine.pickDownloadFolder { [weak self] path in
                self?.finish(path, outcome: .success(path ?? ""))
            }

        default:
            main { result(FlutterMethodNotImplemented) }
        }
    }

    // MARK: - Event channel

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        startTimer()
        emitSnapshot()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopTimer()
        eventSink = nil
        return nil
    }

    // MARK: - Timed updates

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.emitSnapshot()
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        updateTimer = timer
    }

    private func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func emitSnapshot() {
        let tasks = engine.torrentTasks().map { $0.toDictionary() }
        main { [weak self] in
            self?.eventSink?(["type": "torrents", "torrents": tasks])
        }
    }

    // MARK: - Helpers

    private func finish(_ result: @escaping FlutterResult, outcome: Result<Void, TorrentEngineError>) {
        main {
            switch outcome {
            case .success:
                result(true)
            case .failure(let error):
                result(FlutterError(code: "TORRENT_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func finish(_ result: @escaping FlutterResult, outcome: Result<String, TorrentEngineError>) {
        main {
            switch outcome {
            case .success(let value):
                result(value)
            case .failure(let error):
                result(FlutterError(code: "TORRENT_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func main(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}

// MARK: - TorrentEngineDelegate

extension TorrentBridge: TorrentEngineDelegate {
    func torrentEngine(_ engine: TorrentEngine, didAddTorrent infoHash: String) {
        main { [weak self] in
            self?.eventSink?(["type": "added", "infoHash": infoHash])
        }
    }

    func torrentEngine(_ engine: TorrentEngine, didRemoveTorrent infoHash: String) {
        main { [weak self] in
            self?.eventSink?(["type": "removed", "infoHash": infoHash])
        }
    }

    func torrentEngine(_ engine: TorrentEngine, didUpdateTorrents tasks: [TorrentTaskModel]) {
        let payload = tasks.map { $0.toDictionary() }
        main { [weak self] in
            self?.eventSink?(["type": "torrents", "torrents": payload])
        }
    }

    func torrentEngine(_ engine: TorrentEngine, didFailWith error: Error) {
        main { [weak self] in
            self?.eventSink?(["type": "error", "message": error.localizedDescription])
        }
    }
}
