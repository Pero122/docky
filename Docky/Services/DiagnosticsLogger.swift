//
//  DiagnosticsLogger.swift
//  Docky
//
//  Lightweight crash + lifecycle diagnostics so launch failures are
//  debuggable without guessing from a .ips crash report.
//
//  - Redirects stderr to ~/Library/Logs/Docky/docky.log, which captures the
//    things the .ips omits: SwiftUI **AttributeGraph "precondition failure"**
//    reasons and Swift `fatalError()` messages.
//  - Installs uncaught-exception + fatal-signal handlers that dump a native
//    backtrace before the process dies.
//  - Emits lifecycle breadcrumbs to both the file and the unified log
//    (subsystem "gt.quintero.Docky"), including the permission state that
//    gates whether any dock windows get built.
//
//  Inspect:
//    tail -f ~/Library/Logs/Docky/docky.log         # current run
//    cat ~/Library/Logs/Docky/docky.log.prev        # previous run (often the crash)
//    log show --last 10m --predicate 'subsystem == "gt.quintero.Docky"'
//

import Foundation
import Darwin
import os.log

enum Diagnostics {
    private static let osLog = OSLog(subsystem: "gt.quintero.Docky", category: "lifecycle")

    static let logDirectory: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Docky", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private static var logURL: URL { logDirectory.appendingPathComponent("docky.log") }
    private static var prevLogURL: URL { logDirectory.appendingPathComponent("docky.log.prev") }

    /// Call once, as the very first thing in `applicationDidFinishLaunching`.
    static func bootstrap() {
        rotate()
        redirectStderr()
        installHandlers()
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        breadcrumb("=== Docky launch — pid \(ProcessInfo.processInfo.processIdentifier), build \(version) ===")
    }

    /// Preserve the previous run's log (frequently the crashing one) as
    /// docky.log.prev so a crash-then-relaunch doesn't clobber the evidence.
    private static func rotate() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: logURL.path) else { return }
        try? fm.removeItem(at: prevLogURL)
        try? fm.moveItem(at: logURL, to: prevLogURL)
    }

    private static func redirectStderr() {
        // After this, fd 2 points at the log file: AttributeGraph
        // "precondition failure: ..." lines and Swift fatalError() messages
        // land here instead of vanishing into a bare "abort() called".
        freopen(logURL.path, "a", stderr)
        setvbuf(stderr, nil, _IONBF, 0) // unbuffered so a crash still flushes
    }

    /// Timestamped lifecycle note → unified log + the stderr log file.
    static func breadcrumb(_ message: String) {
        os_log("%{public}@", log: osLog, type: .info, message)
        let line = "[\(now())] \(message)\n"
        if let data = line.data(using: .utf8) {
            FileHandle.standardError.write(data) // fd 2 → log file
        }
    }

    /// Logs whether the permission gate that builds dock windows is satisfied,
    /// and exactly which permissions are still blocking it.
    static func logPermissionState() {
        let p = PermissionsService.shared
        breadcrumb("PERMISSIONS: setupComplete=\(p.setupComplete)")
        breadcrumb("  missingRequired=\(p.missingRequiredPermissions.map { $0.rawValue })")
        breadcrumb("  setupBlocking=\(p.setupPermissions.map { $0.rawValue })")
    }

    private static func now() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private static func installHandlers() {
        NSSetUncaughtExceptionHandler { exception in
            let frames = exception.callStackSymbols.joined(separator: "\n")
            let msg = "\n*** UNCAUGHT NSException: \(exception.name.rawValue): \(exception.reason ?? "")\n\(frames)\n"
            if let data = msg.data(using: .utf8) { FileHandle.standardError.write(data) }
        }

        // Fatal signals (SIGABRT is what AttributeGraph raises). The handler is
        // a non-capturing C function: only async-signal-safe C calls inside.
        for sig in [SIGABRT, SIGSEGV, SIGILL, SIGBUS, SIGFPE, SIGTRAP] {
            signal(sig) { received in
                let header = "\n*** FATAL SIGNAL \(received) — native backtrace ***\n"
                header.withCString { _ = write(2, $0, strlen($0)) }
                var frames = [UnsafeMutableRawPointer?](repeating: nil, count: 128)
                let count = backtrace(&frames, 128)
                backtrace_symbols_fd(&frames, count, 2)
                signal(received, SIG_DFL)
                raise(received) // let the normal crash reporter run too
            }
        }
    }
}
