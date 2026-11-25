import AppIntents
import os.log
import ItsytvCore

private let log = Logger(subsystem: "com.atv-kbd.app", category: "Intent")

struct AppleTVDeviceEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Apple TV")
    static var defaultQuery = AppleTVDeviceQuery()

    var id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

struct AppleTVDeviceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AppleTVDeviceEntity] {
        identifiers.map { AppleTVDeviceEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [AppleTVDeviceEntity] {
        pairedDeviceEntities()
    }

    func defaultResult() async -> AppleTVDeviceEntity? {
        pairedDeviceEntities().first
    }

    /// Returns paired devices, filtering out stale rpBA (MAC address) entries.
    private func pairedDeviceEntities() -> [AppleTVDeviceEntity] {
        let allIDs = KeychainStorage.allPairedDeviceIDs()
        let macPattern = /^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$/
        let filtered = allIDs.filter { $0.wholeMatch(of: macPattern) == nil }
        log.error("pairedDeviceEntities: allIDs=\(allIDs, privacy: .public) filtered=\(filtered, privacy: .public)")
        return filtered.map { AppleTVDeviceEntity(id: $0) }
    }
}

struct OpenRemoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Open ATV KBD"
    static var description: IntentDescription = "Opens ATV KBD for an Apple TV"
    static var openAppWhenRun = true

    @Parameter(title: "Apple TV", description: "Which Apple TV to control")
    var device: AppleTVDeviceEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        log.error("Intent perform() called, device=\(device.id)")

        for i in 0..<20 {
            let delegate = AppDelegate.shared
            log.error("Attempt \(i): delegate=\(delegate == nil ? "nil" : "set")")

            if let delegate {
                delegate.openAppleTV(id: device.id)
                return .result()
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }

        log.error("Intent timed out waiting for app")
        throw IntentError.appNotReady
    }

    enum IntentError: Error, CustomLocalizedStringResourceConvertible {
        case appNotReady

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .appNotReady:
                "ATV KBD failed to start — please try again"
            }
        }
    }
}

struct AtvKbdShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenRemoteIntent(),
            phrases: ["Open \(.applicationName)"],
            shortTitle: "Open ATV KBD",
            systemImageName: "appletv.fill"
        )
    }
}
