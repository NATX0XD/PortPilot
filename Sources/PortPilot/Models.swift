import Foundation

/// A single listening service detected on the machine.
struct ServiceInfo: Identifiable, Hashable {
    let id: String        // "pid:port" — stable across refreshes
    let pid: Int32
    let port: Int
    let proto: String     // TCP / UDP
    let processName: String
    let command: String   // full command line (for restart)
    let cwd: String       // working directory (for restart)
    let user: String
    let uptime: String    // elapsed run time, e.g. "01:23:45" or "2-04:10:00" ("" if unknown)

    /// True when the process belongs to the current user (safe to signal without sudo).
    var ownedByCurrentUser: Bool {
        user == NSUserName()
    }

    /// Ownership category used to label and color each row.
    enum Category {
        case user    // belongs to you — your dev servers, apps you launched
        case system  // root or a macOS service account (names starting with "_")
        case other   // some other human user on the machine
    }

    var category: Category {
        // root / macOS service accounts are always system.
        if user == "root" || user.hasPrefix("_") { return .system }
        // Apple daemons run under your account but live in system paths.
        if Self.isSystemExecutable(command) { return .system }
        if user == NSUserName() { return .user }
        return .other
    }

    /// True when the executable lives in an Apple/system location (e.g. ControlCenter, sharingd).
    static func isSystemExecutable(_ command: String) -> Bool {
        let exe = command.split(separator: " ").first.map(String.init) ?? command
        let systemPrefixes = [
            "/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/",
            "/usr/bin/", "/Library/Apple/", "/Library/PrivilegedHelperTools/"
        ]
        return systemPrefixes.contains { exe.hasPrefix($0) }
    }
}
