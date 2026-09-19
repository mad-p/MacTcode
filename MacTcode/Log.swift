//
//  Log.swift
//  MacTcode
//
//  Created by maeda on 2024/06/09.
//

import Cocoa
import os

/// ログ出力
class Log {
    static func i(_ message: String) {
        if UserConfigs.i.system.logEnabled {
            Log.i.logger.info("\(message, privacy: .public)")
        }
    }
    static private var i = Log()
    let logger: Logger
    init() {
        logger = Logger(subsystem: "MacTcode", category: "i")
        logger.info("★Logger created")
    }
}

/// 打鍵可視化用の JSONL ロガー。
/// 有効状態はプロセス内だけで保持し、ログ失敗時は通常の入力を妨げず停止する。
final class InputLogRecorder {
    static let i = InputLogRecorder()

    private let lock = NSLock()
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private var handle: FileHandle?
    private var sessionURL: URL?
    private var sessionStartedAt: Date?
    private var sequence = 0

    var isRecording: Bool {
        lock.lock()
        defer { lock.unlock() }
        return handle != nil
    }

    @discardableResult
    func start(in directory: URL) throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        if let sessionURL {
            return sessionURL
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let startedAt = Date()
        let fileName = "keystrokes-\(fileTimestamp(startedAt)).jsonl"
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let newHandle = try FileHandle(forWritingTo: url)
        handle = newHandle
        sessionURL = url
        sessionStartedAt = startedAt
        sequence = 0
        writeLocked(type: "sessionStarted", fields: [
            "applicationVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        ], at: startedAt)
        return url
    }

    func startDefaultSession() throws -> URL {
        try start(in: UserConfigs.i.macTcodeURL.appendingPathComponent("logs", isDirectory: true))
    }

    func stop(reason: String) {
        lock.lock()
        defer { lock.unlock() }
        guard handle != nil else { return }
        writeLocked(type: "sessionStopped", fields: ["reason": reason], at: Date())
        handle?.synchronizeFile()
        try? handle?.close()
        handle = nil
        sessionURL = nil
        sessionStartedAt = nil
        sequence = 0
    }

    func recordKeyInput(_ input: InputEvent) {
        var fields: [String: Any] = ["keyType": String(describing: input.type)]
        if let text = input.text {
            fields["text"] = text
        }
        if let event = input.event {
            fields["keyCode"] = Int(event.keyCode)
            fields["modifiers"] = modifierNames(event.modifierFlags)
        }
        record(type: "keyInput", fields: fields)
    }

    func recordModeChanged(_ mode: String, transition: String) {
        record(type: "modeChanged", fields: ["mode": mode, "transition": transition])
    }

    func recordPendingChanged(_ pending: [InputEvent]) {
        record(type: "pendingChanged", fields: [
            "keys": pending.compactMap(\.text).joined(),
            "count": pending.count
        ])
    }

    func recordTextCommitted(_ text: String, source: String = "ime") {
        guard !text.isEmpty else { return }
        record(type: "textCommitted", fields: ["text": text, "source": source])
    }

    func recordTextDeleted(_ text: String? = nil, source: String = "backspace") {
        var fields: [String: Any] = ["source": source]
        if let text {
            fields["text"] = text
        }
        record(type: "textDeleted", fields: fields)
    }

    func recordTextReplaced(replacedText: String, text: String, source: String) {
        record(type: "textReplaced", fields: [
            "replacedText": replacedText,
            "text": text,
            "source": source
        ])
    }

    func record(type: String, fields: [String: Any] = [:]) {
        lock.lock()
        defer { lock.unlock() }
        writeLocked(type: type, fields: fields, at: Date())
    }

    private func writeLocked(type: String, fields: [String: Any], at date: Date) {
        guard let handle, let startedAt = sessionStartedAt else { return }
        sequence += 1
        var event = fields
        event["schemaVersion"] = 1
        event["sequence"] = sequence
        event["timestamp"] = dateFormatter.string(from: date)
        event["elapsedMilliseconds"] = max(0, Int((date.timeIntervalSince(startedAt) * 1000).rounded()))
        event["type"] = type
        do {
            let data = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
            handle.write(data)
            handle.write(Data([0x0A]))
        } catch {
            try? handle.close()
            self.handle = nil
            self.sessionURL = nil
            self.sessionStartedAt = nil
            self.sequence = 0
            Log.i("Input logging stopped after write failure: \(error)")
        }
    }

    private func fileTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss.SSSZ"
        return formatter.string(from: date)
    }

    private func modifierNames(_ flags: NSEvent.ModifierFlags) -> [String] {
        var names: [String] = []
        if flags.contains(.command) { names.append("command") }
        if flags.contains(.control) { names.append("control") }
        if flags.contains(.option) { names.append("option") }
        if flags.contains(.shift) { names.append("shift") }
        if flags.contains(.capsLock) { names.append("capsLock") }
        return names
    }
}
