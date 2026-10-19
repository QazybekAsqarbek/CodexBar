import CodexBarCore
import SwiftUI

@MainActor
struct ManualSubscriptionNotesSection: View {
    let provider: UsageProvider
    @Bindable var store: UsageStore

    private var emails: [String] {
        let candidates: [String] = if self.provider == .codex {
            self.store.settings.codexVisibleAccountProjection.visibleAccounts.compactMap(\.email)
        } else {
            [self.store.accountInfo(for: self.provider).email].compactMap(\.self)
        }
        return Array(Set(candidates.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }))
            .filter { !$0.isEmpty }.sorted()
    }

    var body: some View {
        if !self.emails.isEmpty, !self.store.settings.hidePersonalInfo {
            Section {
                ForEach(self.emails, id: \.self) { email in
                    if let key = ManualSubscriptionNotes.key(provider: self.provider.rawValue, email: email) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(email).font(.subheadline.weight(.semibold))
                            TextField(
                                L("Paid 15 Oct · next payment 15 Nov · Visa •1234"),
                                text: Binding(
                                    get: { self.store.settings.manualSubscriptionNotes.text(for: key) },
                                    set: { self.store.settings.manualSubscriptionNotes.setText($0, for: key) }),
                                prompt: Text(L("Paid 15 Oct · next payment 15 Nov · Visa •1234")),
                                axis: .vertical)
                                .labelsHidden()
                                .lineLimit(1...3)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel(L("Subscription note (manual)") + ": " + email)
                        }
                    }
                }
            } header: {
                Text(L("Subscription note (manual)"))
            } footer: {
                Text(L("Saved automatically on this Mac. Clear the field to remove the note from the menu."))
            }
        }
    }
}
