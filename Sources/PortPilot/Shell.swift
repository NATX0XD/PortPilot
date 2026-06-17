import Foundation

/// Minimal helper to run command-line tools and capture their output.
enum Shell {
    /// Runs `launchPath` with `args`, returns stdout. Returns "" on failure/timeout.
    /// The timeout is enforced: a process that overruns is terminated, so a hung
    /// lsof/osascript can never wedge the scan loop forever.
    @discardableResult
    static func run(_ launchPath: String, _ args: [String], timeout: TimeInterval = 8) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice  // avoid deadlock on large/unread stderr

        do {
            try process.run()
        } catch {
            return ""
        }

        // Kill the process if it overruns the deadline.
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            if process.isRunning {
                process.terminate()
                kill(process.processIdentifier, SIGKILL)
            }
        }
        timer.resume()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timer.cancel()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Runs `command` with administrator privileges via osascript (shows a GUI auth prompt).
    /// macOS caches the authorization for ~5 minutes, so repeated calls won't re-prompt immediately.
    static func runAdmin(_ command: String) -> String {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return run("/usr/bin/osascript", ["-e", script], timeout: 60)
    }

    /// Reads a process's executable path and true argv array via the KERN_PROCARGS2 sysctl.
    /// This preserves arguments exactly (spaces, quotes), unlike the space-joined `ps` string.
    /// Returns nil for processes we can't introspect (e.g. other users without privileges).
    static func processArgs(pid: Int32) -> (exec: String, argv: [String])? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        if sysctl(&mib, 3, nil, &size, nil, 0) != 0 || size == 0 { return nil }

        var buf = [UInt8](repeating: 0, count: size)
        let ok = buf.withUnsafeMutableBytes { raw in
            sysctl(&mib, 3, raw.baseAddress, &size, nil, 0) == 0
        }
        guard ok, size >= MemoryLayout<Int32>.size else { return nil }

        let argc = buf.withUnsafeBytes { $0.load(as: Int32.self) }
        var i = MemoryLayout<Int32>.size

        func nextCString() -> String? {
            guard i < size else { return nil }
            let start = i
            while i < size && buf[i] != 0 { i += 1 }
            let s = String(decoding: buf[start..<i], as: UTF8.self)
            i += 1  // skip the NUL
            return s
        }

        guard let exec = nextCString(), !exec.isEmpty else { return nil }
        while i < size && buf[i] == 0 { i += 1 }   // skip padding before argv[0]

        var argv: [String] = []
        var n = 0
        while n < Int(argc), i < size {
            guard let s = nextCString() else { break }
            argv.append(s)
            n += 1
        }
        return (exec, argv)
    }

    /// Launches a detached process from an explicit executable + argument array (NO shell),
    /// so arguments are passed literally. Returns true if it launched.
    @discardableResult
    static func spawnDetached(exec: String, args: [String], workingDir: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exec)
        process.arguments = args
        if !workingDir.isEmpty, FileManager.default.fileExists(atPath: workingDir) {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run(); return true } catch { return false }
    }

    /// Launches a detached `/bin/sh -c <command>` in `workingDir`. Used to re-spawn a killed service.
    @discardableResult
    static func spawnDetached(command: String, workingDir: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        if !workingDir.isEmpty, FileManager.default.fileExists(atPath: workingDir) {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }
        // Detach from PortPilot so the child keeps running after we move on.
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run(); return true } catch { return false }
    }
}
