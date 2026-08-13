import Flutter
import UIKit

class TorrentPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()

        let methodChannel = FlutterMethodChannel(name: "com.dirxplore.torrent", binaryMessenger: messenger)
        let instance = TorrentPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(name: "com.dirxplore.torrent_events", binaryMessenger: messenger)
        eventChannel.setStreamHandler(instance)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let manager = TorrentEngineManager.shared

        switch call.method {

        // MARK: - Lifecycle
        case "initialize":
            let args = call.arguments as? [String: Any]
            let downloadDir = args?["downloadDirectory"] as? String
            let settingsDict = args?["settings"] as? [String: Any]
            manager.initialize(downloadDir: downloadDir, settings: settingsDict) { success in
                result(success)
            }

        case "shutdown":
            manager.shutdown()
            result(true)

        // MARK: - Add Torrents
        case "addMagnet":
            guard let args = call.arguments as? [String: Any],
                  let magnetUri = args["magnetUri"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing magnetUri parameter", details: nil))
                return
            }
            let savePath = args["savePath"] as? String
            manager.addMagnet(magnetUri: magnetUri, savePath: savePath) { dict in
                if let dict = dict {
                    result(dict)
                } else {
                    result(FlutterError(code: "ADD_FAILED", message: "Failed to add magnet link", details: nil))
                }
            }

        case "addTorrentFile":
            guard let args = call.arguments as? [String: Any],
                  let filePath = args["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing filePath parameter", details: nil))
                return
            }
            let savePath = args["savePath"] as? String
            manager.addTorrentFile(filePath: filePath, savePath: savePath) { dict in
                if let dict = dict {
                    result(dict)
                } else {
                    result(FlutterError(code: "ADD_FAILED", message: "Failed to add torrent file", details: nil))
                }
            }

        // MARK: - Remove
        case "removeTorrent":
            guard let args = call.arguments as? [String: Any],
                  let infoHash = args["infoHash"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash parameter", details: nil))
                return
            }
            let deleteData = args["deleteData"] as? Bool ?? false
            manager.removeTorrent(infoHash: infoHash, deleteData: deleteData) { success in
                result(success)
            }

        // MARK: - Pause / Resume
        case "pauseTorrent":
            guard let args = call.arguments as? [String: Any],
                  let infoHash = args["infoHash"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash parameter", details: nil))
                return
            }
            manager.pauseTorrent(infoHash: infoHash) { success in result(success) }

        case "resumeTorrent":
            guard let args = call.arguments as? [String: Any],
                  let infoHash = args["infoHash"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash parameter", details: nil))
                return
            }
            manager.resumeTorrent(infoHash: infoHash) { success in result(success) }

        case "forceStartTorrent":
            guard let args = call.arguments as? [String: Any],
                  let infoHash = args["infoHash"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash parameter", details: nil))
                return
            }
            manager.forceStartTorrent(infoHash: infoHash) { success in result(success) }

        case "recheckTorrent":
            guard let args = call.arguments as? [String: Any],
                  let infoHash = args["infoHash"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash parameter", details: nil))
                return
            }
            manager.recheckTorrent(infoHash: infoHash) { success in result(success) }

        // MARK: - File Priority / Sequential
        case "setFilePriority":
            guard let args = call.arguments as? [String: Any],
                  let infoHash = args["infoHash"] as? String,
                  let fileIndex = args["fileIndex"] as? Int,
                  let priority = args["priority"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing file priority parameters", details: nil))
                return
            }
            manager.setFilePriority(infoHash: infoHash, fileIndex: fileIndex, priority: priority) { success in
                result(success)
            }

        case "setSequentialDownload":
            guard let args = call.arguments as? [String: Any],
                  let infoHash = args["infoHash"] as? String,
                  let enabled = args["enabled"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing parameters", details: nil))
                return
            }
            manager.setSequentialDownload(infoHash: infoHash, enabled: enabled) { success in result(success) }

        // MARK: - Session Settings
        case "configureSession":
            let settingsDict = (call.arguments as? [String: Any]) ?? [:]
            manager.configureSession(settingsDict: settingsDict) { success in result(success) }

        case "setGlobalDownloadLimit":
            let args = call.arguments as? [String: Any]
            let limit = args?["limit"] as? Int ?? 0
            manager.configureSession(settingsDict: ["downloadLimit": limit]) { success in result(success) }

        case "setGlobalUploadLimit":
            let args = call.arguments as? [String: Any]
            let limit = args?["limit"] as? Int ?? 0
            manager.configureSession(settingsDict: ["uploadLimit": limit]) { success in result(success) }

        case "setDHTEnabled":
            let args = call.arguments as? [String: Any]
            let enabled = args?["enabled"] as? Bool ?? true
            manager.configureSession(settingsDict: ["enableDht": enabled]) { success in result(success) }

        case "setUPnPEnabled":
            let args = call.arguments as? [String: Any]
            let enabled = args?["enabled"] as? Bool ?? true
            manager.configureSession(settingsDict: ["enableUpnp": enabled]) { success in result(success) }

        case "setNATPMPEnabled":
            let args = call.arguments as? [String: Any]
            let enabled = args?["enabled"] as? Bool ?? true
            manager.configureSession(settingsDict: ["enableNatPmp": enabled]) { success in result(success) }

        case "setListeningPort":
            let args = call.arguments as? [String: Any]
            let port = args?["port"] as? Int ?? 0
            manager.configureSession(settingsDict: ["listenPort": port]) { success in result(success) }

        case "setMaxConnections":
            let args = call.arguments as? [String: Any]
            let maxConn = args?["maxConnections"] as? Int ?? 0
            manager.configureSession(settingsDict: ["maxConnections": maxConn]) { success in result(success) }

        case "setMaxConnectionsPerTorrent":
            let args = call.arguments as? [String: Any]
            let maxConn = args?["maxConnectionsPerTorrent"] as? Int ?? 0
            manager.configureSession(settingsDict: ["maxConnectionsPerTorrent": maxConn]) { success in result(success) }

        // MARK: - Queries
        case "getTorrents":
            result(manager.getTorrents())

        case "getSessionStats":
            result(manager.getSessionStats())

        case "getPeers":
            let args = call.arguments as? [String: Any]
            let infoHash = args?["infoHash"] as? String ?? ""
            result(manager.getPeers(infoHash: infoHash))

        case "getTrackers":
            let args = call.arguments as? [String: Any]
            let infoHash = args?["infoHash"] as? String ?? ""
            result(manager.getTrackers(infoHash: infoHash))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler Protocol

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        TorrentEngineManager.shared.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        TorrentEngineManager.shared.eventSink = nil
        return nil
    }
}
