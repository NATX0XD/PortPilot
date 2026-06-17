import Foundation

/// Stops and restarts detected services.
enum ProcessManager {

    enum ActionResult {
        case success
        case failure(String)
    }

    /// Sends SIGTERM, then SIGKILL after a short grace period if still alive.
    @discardableResult
    static func close(_ service: ServiceInfo) -> ActionResult {
        guard service.pid > 0 else { return .failure("invalid pid") }

        // Guard against PID reuse: the scan data can be up to 5s stale, so confirm this
        // PID is still the one listening on this exact port before we signal it.
        guard stillListening(pid: service.pid, port: service.port) else {
            return .failure("Process changed — please refresh")
        }

        // Try a graceful stop first.
        if kill(service.pid, SIGTERM) != 0 && errno == EPERM {
            return .failure("Permission denied (process owned by \(service.user))")
        }

        // Give it up to ~2s to exit, then force-kill.
        for _ in 0..<20 {
            if kill(service.pid, 0) != 0 { return .success }  // gone
            usleep(100_000)
        }
        // Re-validate before the unconditional SIGKILL — the PID may have been recycled
        // into an unrelated process during the grace window.
        if stillListening(pid: service.pid, port: service.port) {
            kill(service.pid, SIGKILL)
        }
        return .success
    }

    /// True if `pid` is still the process listening on `port` (closes the kill TOCTOU window).
    private static func stillListening(pid: Int32, port: Int) -> Bool {
        let out = Shell.run("/usr/sbin/lsof", ["-t", "-nP", "-iTCP:\(port)", "-sTCP:LISTEN"])
        let pids = out.split(whereSeparator: { $0 == "\n" || $0 == " " }).compactMap { Int32($0) }
        return pids.contains(pid)
    }

    /// Kills the service, then re-runs its original command in its original working dir.
    @discardableResult
    static func restart(_ service: ServiceInfo) -> ActionResult {
        let cwd = service.cwd
        // Capture the TRUE argv (exact args) while the process is still alive.
        let captured = Shell.processArgs(pid: service.pid)
        let fallback = service.command

        let result = close(service)
        if case .failure = result { return result }

        // Small delay so the port is released before re-binding.
        usleep(400_000)

        let launched: Bool
        if let c = captured, !c.exec.isEmpty {
            // No shell: pass argv literally (preserves spaces/quotes/globs).
            launched = Shell.spawnDetached(exec: c.exec,
                                           args: Array(c.argv.dropFirst()),
                                           workingDir: cwd)
        } else if !fallback.isEmpty {
            launched = Shell.spawnDetached(command: fallback, workingDir: cwd)
        } else {
            return .failure("No command captured to restart")
        }

        return launched ? .success : .failure("Killed it, but failed to relaunch")
    }
}
