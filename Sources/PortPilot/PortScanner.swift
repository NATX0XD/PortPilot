import Foundation

/// Scans the machine for listening TCP services using `lsof`.
enum PortScanner {

    /// Returns all currently listening services, sorted by port.
    /// When `admin` is true the scan runs with elevated privileges so it can see
    /// root- and other-user-owned listeners (otherwise lsof only shows your own).
    static func scan(admin: Bool = false) -> [ServiceInfo] {
        // Field output: p=pid, c=command, L=login/user, P=protocol, n=name(addr:port)
        let raw: String
        if admin {
            raw = Shell.runAdmin("/usr/sbin/lsof -nP -iTCP -sTCP:LISTEN -FpcLPn")
        } else {
            raw = Shell.run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcLPn"])
        }
        guard !raw.isEmpty else { return [] }

        var services: [ServiceInfo] = []
        var seen = Set<String>()

        var pid: Int32 = 0
        var cmd = ""
        var user = ""
        var proto = "TCP"

        // Lazy caches so we only resolve the heavy fields once per pid.
        var cmdLineCache: [Int32: String] = [:]
        var uptimeCache: [Int32: String] = [:]
        var cwdCache: [Int32: String] = [:]

        for line in raw.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())

            switch tag {
            case "p":
                pid = Int32(value) ?? 0
            case "c":
                cmd = value
            case "L":
                user = value
            case "P":
                proto = value
            case "n":
                guard let port = parsePort(from: value), pid > 0 else { continue }
                let key = "\(pid):\(port)"
                if seen.contains(key) { continue }
                seen.insert(key)

                if cmdLineCache[pid] == nil {
                    let (et, c) = elapsedAndCommand(pid: pid)
                    cmdLineCache[pid] = c
                    uptimeCache[pid] = et
                }
                let fullCmd = cmdLineCache[pid] ?? ""
                let uptime = uptimeCache[pid] ?? ""
                let cwd = cwdCache[pid] ?? {
                    let w = workingDir(pid: pid); cwdCache[pid] = w; return w
                }()

                services.append(ServiceInfo(
                    id: key, pid: pid, port: port, proto: proto,
                    processName: cmd,
                    command: fullCmd.isEmpty ? cmd : fullCmd,
                    cwd: cwd, user: user, uptime: uptime
                ))
            default:
                break
            }
        }

        return services.sorted { $0.port < $1.port }
    }

    /// Extracts the port from an lsof name like `*:3000`, `127.0.0.1:8080`, `[::1]:5000`.
    private static func parsePort(from name: String) -> Int? {
        guard let colon = name.lastIndex(of: ":") else { return nil }
        let portStr = name[name.index(after: colon)...]
        return Int(portStr)
    }

    /// Elapsed run time + full command line for a pid in one `ps` call.
    /// `etime` has no spaces (e.g. "01:23:45" / "2-04:10:00"); the rest is the command.
    private static func elapsedAndCommand(pid: Int32) -> (uptime: String, command: String) {
        let out = Shell.run("/bin/ps", ["-p", "\(pid)", "-o", "etime=,command="])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let space = out.firstIndex(of: " ") else { return ("", out) }
        let etime = String(out[..<space])
        let command = out[out.index(after: space)...].trimmingCharacters(in: .whitespaces)
        return (etime, command)
    }

    /// Current working directory of a pid, used as the spawn directory on restart.
    private static func workingDir(pid: Int32) -> String {
        let raw = Shell.run("/usr/sbin/lsof", ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"])
        for line in raw.split(separator: "\n") where line.first == "n" {
            return String(line.dropFirst())
        }
        return ""
    }
}
