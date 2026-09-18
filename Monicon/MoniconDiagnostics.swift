import Foundation

enum MoniconDiagnostics {
    private static let lock = NSLock()
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        NSSetUncaughtExceptionHandler { exception in
            write("CRASH.exception", """
            name=\(exception.name.rawValue)
            reason=\(exception.reason ?? "unknown")
            stack=\(exception.callStackSymbols.joined(separator: " | "))
            """)
        }
        write("diagnostics", "uncaught exception handler installed")
    }

    static func write(_ section: String, _ message: String) {
        let line = "[Monicon][error][\(section)] \(message)"
        print(line)
        lock.lock()
        defer { lock.unlock() }
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documents.appendingPathComponent("monicon.log")
            let data = (line + "\n").data(using: .utf8) ?? Data()
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            print("[Monicon][error][diagnostics.file] \(error.localizedDescription)")
        }
    }
}
