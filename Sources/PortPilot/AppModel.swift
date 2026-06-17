import Foundation
import SwiftUI

/// Observable state shared by the desktop window and the menu-bar UI.
@MainActor
final class AppModel: ObservableObject {
    /// Single shared instance (the AppDelegate window and the MenuBarExtra use the same one).
    static let shared = AppModel()

    /// Normal (user-owned) listeners, refreshed automatically. Never needs a password.
    @Published var userServices: [ServiceInfo] = []
    /// Root/other-user listeners from an admin scan. Cached for the session (no re-prompt).
    @Published var systemExtras: [ServiceInfo] = []

    @Published var isScanning = false
    @Published var lastError: String?
    @Published var query: String = ""
    @Published var autoRefresh = true
    /// When on, the cached admin results are merged into the list. First enable prompts once.
    @Published var adminMode = false
    private var didAdminScan = false

    /// User-assigned names keyed by port (e.g. 3000 -> "IAXO frontend"). Persisted.
    @Published var labels: [Int: String] = [:]
    private let labelsKey = "portLabels"

    /// Ports the user pinned as favorites (shown first). Persisted.
    @Published var pinned: Set<Int> = []
    private let pinnedKey = "pinnedPorts"

    /// When the service list was last refreshed (for the freshness indicator).
    @Published var lastScan: Date?

    private var timer: Timer?
    private var hasStarted = false

    /// The list shown in the UI: user services, plus cached admin extras when admin mode is on.
    var services: [ServiceInfo] {
        guard adminMode else { return userServices }
        let have = Set(userServices.map(\.id))
        return (userServices + systemExtras.filter { !have.contains($0.id) })
            .sorted { $0.port < $1.port }
    }

    var userServiceCount: Int { services.filter { $0.category == .user }.count }

    var filtered: [ServiceInfo] {
        guard !query.isEmpty else { return services }
        let q = query.lowercased()
        return services.filter {
            $0.processName.lowercased().contains(q)
            || String($0.port).contains(q)
            || $0.command.lowercased().contains(q)
            || (labels[$0.port]?.lowercased().contains(q) ?? false)
        }
    }

    /// The filtered list split into display sections: Pinned, Your services, System.
    var sections: [(title: String, items: [ServiceInfo])] {
        let items = filtered
        let pins = items.filter { pinned.contains($0.port) }
        let rest = items.filter { !pinned.contains($0.port) }
        let mine = rest.filter { $0.category == .user }
        let sys  = rest.filter { $0.category != .user }
        return [
            ("📌 Pinned", pins),
            ("Your services", mine),
            ("System", sys),
        ].filter { !$0.items.isEmpty }
    }

    func isPinned(_ port: Int) -> Bool { pinned.contains(port) }

    func togglePin(_ port: Int) {
        if pinned.contains(port) { pinned.remove(port) } else { pinned.insert(port) }
        UserDefaults.standard.set(Array(pinned), forKey: pinnedKey)
    }

    /// Runs once for the app's lifetime (onAppear can fire repeatedly).
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        loadLabels()
        if let arr = UserDefaults.standard.array(forKey: pinnedKey) as? [Int] {
            pinned = Set(arr)
        }
        refresh()
        scheduleTimer()
    }

    // MARK: - Custom project names

    func displayName(for service: ServiceInfo) -> String {
        labels[service.port] ?? service.processName
    }

    func setLabel(_ name: String, for port: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { labels.removeValue(forKey: port) }
        else { labels[port] = trimmed }
        saveLabels()
    }

    private func loadLabels() {
        guard let data = UserDefaults.standard.data(forKey: labelsKey),
              let dict = try? JSONDecoder().decode([Int: String].self, from: data)
        else { return }
        labels = dict
    }

    private func saveLabels() {
        if let data = try? JSONEncoder().encode(labels) {
            UserDefaults.standard.set(data, forKey: labelsKey)
        }
    }

    // MARK: - Refresh / scan

    func scheduleTimer() {
        timer?.invalidate()
        guard autoRefresh else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func toggleAutoRefresh() {
        autoRefresh.toggle()
        scheduleTimer()
    }

    /// Shows/hides the admin (root/system) listeners. The very first enable runs ONE admin
    /// scan (password prompt) and caches the result for the rest of the session — toggling
    /// off and on again does NOT re-prompt. Use refreshSystem() to force a fresh admin scan.
    func toggleAdminMode() {
        adminMode.toggle()
        if adminMode && !didAdminScan { refreshSystem() }
    }

    /// Normal scan of your own listeners. Never prompts for a password.
    func refresh() {
        guard !isScanning else { return }
        isScanning = true
        Task.detached(priority: .userInitiated) {
            let found = PortScanner.scan(admin: false)
            await MainActor.run {
                self.userServices = found
                self.isScanning = false
                self.lastScan = Date()
            }
        }
    }

    /// Explicit admin scan (prompts for a password once, then caches for the session).
    func refreshSystem() {
        Task.detached(priority: .userInitiated) {
            let all = PortScanner.scan(admin: true)
            await MainActor.run {
                if !all.isEmpty {
                    self.systemExtras = all
                    self.didAdminScan = true
                }
                self.lastScan = Date()
            }
        }
    }

    func close(_ service: ServiceInfo) { runAction { ProcessManager.close(service) } }
    func restart(_ service: ServiceInfo) { runAction { ProcessManager.restart(service) } }

    private func runAction(_ action: @escaping () -> ProcessManager.ActionResult) {
        Task.detached(priority: .userInitiated) {
            let result = action()
            await MainActor.run {
                if case .failure(let msg) = result { self.lastError = msg }
                else { self.lastError = nil }
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run { self.refresh() }   // user-only re-scan, no prompt
        }
    }
}
