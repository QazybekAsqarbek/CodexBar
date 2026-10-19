import Foundation
import Observation

/// Local, user-entered text. Deliberately independent of usage refresh and web sessions.
@MainActor
@Observable
final class ManualSubscriptionNotes {
    private static let defaultsKey = "manualSubscriptionNotes.v1"
    @ObservationIgnored private let defaults: UserDefaults
    private(set) var notes: [String: String]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.notes = defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
    }

    nonisolated static func key(provider: String, email: String?) -> String? {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !email.isEmpty else { return nil }
        return "\(provider)|\(email)"
    }

    func text(for key: String) -> String {
        self.notes[key] ?? ""
    }

    func setText(_ text: String, for key: String) {
        let text = String(text.prefix(500))
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.notes.removeValue(forKey: key)
        } else {
            self.notes[key] = text
        }
        self.defaults.set(self.notes, forKey: Self.defaultsKey)
    }
}
