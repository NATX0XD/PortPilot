import SwiftUI
import AppKit

// MARK: - Shared style

enum Style {
    static let accent = LinearGradient(
        colors: [Color(red: 0.04, green: 0.52, blue: 1.0), Color(red: 0.70, green: 0.35, blue: 0.96)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static func categoryColor(_ c: ServiceInfo.Category) -> Color {
        switch c {
        case .user:   return .green
        case .system: return .orange
        case .other:  return .gray
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            if let err = model.lastError { errorBanner(err) }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .fontDesign(.rounded)
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.10),
                     Color(red: 0.70, green: 0.35, blue: 0.96).opacity(0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .background(Color(nsColor: .windowBackgroundColor))
            .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Style.accent)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

            VStack(alignment: .leading, spacing: 0) {
                Text("PortPilot").font(.system(.title3, design: .rounded).weight(.bold))
                TimelineView(.periodic(from: Date(), by: 1)) { _ in
                    Text(freshnessString.isEmpty ? "\(model.services.count) services" : freshnessString)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Spacer()

            let userN = model.userServiceCount
            let sysN = model.services.count - userN
            HStack(spacing: 5) {
                countPill("\(userN)", color: .green)
                countPill("\(sysN)", color: .orange)
            }

            CircleButton(system: "arrow.clockwise", spinning: model.isScanning) {
                model.refresh()
            }
            .disabled(model.isScanning)
            .help("Refresh now")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func countPill(_ text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(.quaternary))
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var freshnessString: String {
        if model.isScanning { return "scanning…" }
        guard let last = model.lastScan else { return "" }
        let s = Int(Date().timeIntervalSince(last))
        if s < 2 { return "updated just now" }
        if s < 60 { return "updated \(s)s ago" }
        return "updated \(s / 60)m ago"
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Filter by port, name, or command", text: $model.query)
                .textFieldStyle(.plain)
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().strokeBorder(.white.opacity(0.10)))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if model.isScanning && model.services.isEmpty {
            loadingState
        } else if model.filtered.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.sections, id: \.title) { section in
                        sectionHeader(section.title, count: section.items.count)
                        ForEach(section.items) { service in
                            ServiceRow(service: service, model: model)
                                .padding(.horizontal, 14)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    /// Pretty loading state: a few shimmering skeleton cards while the first scan runs.
    private var loadingState: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { _ in SkeletonRow() }
        }
        .padding(.horizontal, 14).padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold)).tracking(0.5)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40)).foregroundStyle(.secondary)
            Text(model.services.isEmpty ? "No listening services" : "No matches")
                .font(.headline).foregroundStyle(.secondary)
            if model.services.isEmpty {
                Text("Start a dev server and it’ll show up here")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Error banner

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(msg).font(.caption).foregroundStyle(.primary).lineLimit(2).help(msg)
            Spacer()
            Button { model.lastError = nil } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }.buttonStyle(.plain).help("Dismiss")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.orange.opacity(0.15)))
        .padding(.horizontal, 14).padding(.bottom, 8)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(get: { model.autoRefresh },
                                 set: { _ in model.toggleAutoRefresh() })) {
                Text("Auto").font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("Re-scan your services every 5s")

            Spacer()

            Text("v\(appVersion)")
                .font(.caption2).foregroundStyle(.tertiary)

            Spacer()

            Button { model.toggleAdminMode() } label: {
                Label(model.adminMode ? "All" : "System",
                      systemImage: model.adminMode ? "lock.open.fill" : "lock.fill")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(model.adminMode ? AnyShapeStyle(Style.accent)
                                                       : AnyShapeStyle(.quaternary)))
            .foregroundStyle(model.adminMode ? .white : .primary)
            .help("Scan with admin rights to reveal root/system listeners")

            Button { (NSApp.delegate as? AppDelegate)?.showMainWindow() } label: {
                Image(systemName: "macwindow").font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .frame(width: 26, height: 26)
            .background(Circle().fill(.quaternary))
            .help("Open the main window")

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power").font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .frame(width: 26, height: 26)
            .background(Circle().fill(.quaternary))
            .help("Quit PortPilot")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Reusable circular icon button

struct CircleButton: View {
    let system: String
    var spinning: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13, weight: .semibold))
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinning ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
                           value: spinning)
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .background(Circle().fill(.quaternary))
    }
}

// MARK: - Loading skeleton

struct SkeletonRow: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary).frame(width: 52, height: 34)
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 130, height: 11)
                RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 90, height: 8)
            }
            Spacer()
            Circle().fill(.quaternary).frame(width: 26, height: 26)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .opacity(pulse ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

// MARK: - Service card

struct ServiceRow: View {
    let service: ServiceInfo
    @ObservedObject var model: AppModel

    private enum Mode { case normal, confirmClose, confirmRestart, renaming }
    @State private var mode: Mode = .normal
    @State private var draftName = ""
    @FocusState private var nameFocused: Bool

    private var displayName: String { model.displayName(for: service) }
    private var hasCustomName: Bool { model.labels[service.port] != nil }
    private var actionable: Bool { service.category == .user }

    var body: some View {
        HStack(spacing: 11) {
            portPill
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName).font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                    categoryBadge
                    if model.isPinned(service.port) {
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                    }
                }
                if mode == .renaming {
                    renameField
                } else {
                    Text(metaLine).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    if !service.cwd.isEmpty {
                        Text(service.cwd).font(.caption2).foregroundStyle(.tertiary)
                            .lineLimit(1).truncationMode(.head).help(service.cwd)
                    }
                }
            }
            Spacer(minLength: 6)
            trailingControls
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        .help(service.command)
        .contextMenu { rowMenu }
    }

    private var portPill: some View {
        Text("\(service.port)")
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .frame(minWidth: 52)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Style.accent))
            .shadow(color: Color.accentColor.opacity(0.25), radius: 2, y: 1)
    }

    private var categoryBadge: some View {
        let color = Style.categoryColor(service.category)
        let label: String = {
            switch service.category {
            case .user: return "USER"
            case .system: return "SYSTEM"
            case .other: return service.user.uppercased()
            }
        }()
        return Text(label)
            .font(.system(size: 8.5, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }

    @ViewBuilder
    private var trailingControls: some View {
        switch mode {
        case .normal:
            CircleButton(system: "pencil") { startRename() }
                .help("Name this service")
            CircleButton(system: "arrow.clockwise") { mode = .confirmRestart }
                .disabled(!actionable)
                .help(actionable ? "Restart (kill + re-run)" : "Only USER processes")
            CircleButton(system: "xmark") { mode = .confirmClose }
                .disabled(!actionable)
                .help(actionable ? "Close (stop process)" : "Only USER processes")
        case .confirmClose:
            inlineConfirm(label: "Close?", tint: .red) { model.close(service) }
        case .confirmRestart:
            inlineConfirm(label: "Restart?", tint: .orange) { model.restart(service) }
        case .renaming:
            Button { saveRename() } label: { Text("Save").font(.caption.weight(.semibold)) }
                .buttonStyle(.plain)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Capsule().fill(Style.accent)).foregroundStyle(.white)
            CircleButton(system: "xmark") { mode = .normal }
        }
    }

    private func inlineConfirm(label: String, tint: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            Button { action(); mode = .normal } label: {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain).frame(width: 28, height: 28)
            .background(Circle().fill(tint)).help("Confirm")
            CircleButton(system: "xmark") { mode = .normal }.help("Cancel")
        }
    }

    private var renameField: some View {
        HStack(spacing: 6) {
            TextField("e.g. IAXO frontend", text: $draftName)
                .textFieldStyle(.roundedBorder).font(.caption)
                .focused($nameFocused).onSubmit { saveRename() }
            if hasCustomName {
                Button("Clear") { model.setLabel("", for: service.port); mode = .normal }
                    .font(.caption2).buttonStyle(.plain).foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var rowMenu: some View {
        Button(model.isPinned(service.port) ? "Unpin" : "Pin to top") { model.togglePin(service.port) }
        Divider()
        Button("Open http://localhost:\(service.port)") { openURL("http://localhost:\(service.port)") }
        Divider()
        Button("Copy port") { copy("\(service.port)") }
        Button("Copy PID") { copy("\(service.pid)") }
        Button("Copy localhost URL") { copy("http://localhost:\(service.port)") }
        Button("Copy command") { copy(service.command) }
        if !service.cwd.isEmpty {
            Button("Copy working directory") { copy(service.cwd) }
            Divider()
            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: service.cwd)
            }
            Button("Open in Terminal") {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                p.arguments = ["-a", "Terminal", service.cwd]
                try? p.run()
            }
        }
    }

    private var metaLine: String {
        var parts = ["PID \(service.pid)", service.proto, service.user]
        if !service.uptime.isEmpty { parts.append("up \(service.uptime)") }
        let base = parts.joined(separator: " · ")
        return hasCustomName ? "\(service.processName) · \(base)" : base
    }

    private func startRename() {
        draftName = model.labels[service.port] ?? ""
        mode = .renaming
        Task { @MainActor in nameFocused = true }
    }

    private func saveRename() {
        model.setLabel(draftName, for: service.port)
        mode = .normal
    }

    private func openURL(_ s: String) {
        if let url = URL(string: s) { NSWorkspace.shared.open(url) }
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}
