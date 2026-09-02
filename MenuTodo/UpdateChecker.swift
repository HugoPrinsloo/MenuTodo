import Foundation
import os

@Observable
@MainActor
final class UpdateChecker {
    enum State {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed
    }

    static let releasesURL = URL(string: "https://api.github.com/repos/HugoPrinsloo/MenuTodo/releases/latest")!

    private static let logger = Logger(subsystem: "com.hugoprinsloo.MenuTodo", category: "UpdateChecker")

    private static let automaticChecksDefaultsKey = "automaticUpdateChecks"
    private static let skippedVersionDefaultsKey = "skippedUpdateVersion"
    private static let lastCheckDefaultsKey = "lastUpdateCheck"

    private static let checkInterval: TimeInterval = 6 * 60 * 60

    var state: State = .idle

    var automaticChecks: Bool {
        didSet {
            UserDefaults.standard.set(automaticChecks, forKey: Self.automaticChecksDefaultsKey)
        }
    }

    var skippedVersion: String? {
        didSet {
            UserDefaults.standard.set(skippedVersion, forKey: Self.skippedVersionDefaultsKey)
        }
    }

    var bannerVersion: (version: String, url: URL)? {
        guard case let .available(version, url) = state, version != skippedVersion else { return nil }
        return (version, url)
    }

    init() {
        if UserDefaults.standard.object(forKey: Self.automaticChecksDefaultsKey) == nil {
            self.automaticChecks = true
        } else {
            self.automaticChecks = UserDefaults.standard.bool(forKey: Self.automaticChecksDefaultsKey)
        }
        self.skippedVersion = UserDefaults.standard.string(forKey: Self.skippedVersionDefaultsKey)
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }

    func check() async {
        state = .checking

        var request = URLRequest(url: Self.releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MenuTodo", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try JSONDecoder().decode(Release.self, from: data)
            guard let url = URL(string: release.html_url) else {
                state = .failed
                return
            }

            let latestVersion = Self.stripLeadingV(release.tag_name)
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

            if Self.isNewer(latestVersion, than: currentVersion) {
                state = .available(version: latestVersion, url: url)
            } else {
                state = .upToDate
            }
        } catch {
            Self.logger.error("Failed to check for updates: \(error, privacy: .public)")
            state = .failed
        }
    }

    func checkIfDue() {
        guard automaticChecks else { return }
        let lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckDefaultsKey) as? Date
        if let lastCheck, Date().timeIntervalSince(lastCheck) < Self.checkInterval {
            return
        }
        UserDefaults.standard.set(Date(), forKey: Self.lastCheckDefaultsKey)
        Task { await check() }
    }

    private static func stripLeadingV(_ version: String) -> String {
        version.hasPrefix("v") ? String(version.dropFirst()) : version
    }

    /// Numeric semver comparison: split on ".", compare component-wise as Ints,
    /// missing trailing components count as 0.
    private static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let lhsParts = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rhsParts = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhsParts.count, rhsParts.count)
        for index in 0..<count {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
