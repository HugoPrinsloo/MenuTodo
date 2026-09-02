import SwiftUI
import ServiceManagement
import os

struct SettingsView: View {
    @Environment(TodoStore.self) private var store
    @Environment(UpdateChecker.self) private var updateChecker
    @Binding var showingSettings: Bool
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    private static let logger = Logger(subsystem: "com.hugoprinsloo.MenuTodo", category: "SettingsView")

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 14) {
                generalSection
                updatesSection
            }
        }
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var header: some View {
        HStack {
            Button("‹ Back") {
                showingSettings = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Color("InkSecondary"))

            Spacer()

            Text("Settings")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color("Ink"))
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("GENERAL")

            Toggle(isOn: $launchAtLogin) {
                Text("Launch at Login")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color("Ink"))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Color("Ink"))
            .onChange(of: launchAtLogin) { _, newValue in
                setLaunchAtLogin(newValue)
            }

            Toggle(isOn: Binding(get: { store.autoSortDone }, set: { store.autoSortDone = $0 })) {
                Text("Move done items to the bottom")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color("Ink"))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Color("Ink"))
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("UPDATES")

            Text("Version \(version)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color("InkSecondary"))

            Button("Check for updates") {
                Task { await updateChecker.check() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Color("Ink"))

            updateStatusLine

            Toggle(isOn: Binding(
                get: { updateChecker.automaticChecks },
                set: { updateChecker.automaticChecks = $0 }
            )) {
                Text("Check automatically")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color("Ink"))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Color("Ink"))
        }
    }

    @ViewBuilder
    private var updateStatusLine: some View {
        switch updateChecker.state {
        case .idle:
            EmptyView()
        case .checking:
            Text("Checking…")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color("InkSecondary"))
        case .upToDate:
            Text("You're up to date")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color("InkSecondary"))
        case let .available(version, url):
            HStack(spacing: 4) {
                Text("\(version) available ·")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color("InkSecondary"))
                Button("Download") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color("Ink"))
            }
        case .failed:
            Text("Couldn't check")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color("InkSecondary"))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color("InkSecondary"))
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.logger.error("Failed to update Launch at Login: \(error, privacy: .public)")
        }
    }
}
