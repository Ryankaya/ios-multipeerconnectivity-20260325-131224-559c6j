import Foundation
import UIKit

@MainActor
final class IdentityStore {
    private let defaults: UserDefaults
    private let displayNameKey = "signal-board.display-name"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadDisplayName() -> String {
        let persisted = defaults.string(forKey: displayNameKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let persisted, !persisted.isEmpty {
            return persisted
        }

        let deviceName = UIDevice.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return deviceName.isEmpty ? "Signal Board Host" : deviceName
    }

    func saveDisplayName(_ name: String) {
        defaults.set(name, forKey: displayNameKey)
    }
}
