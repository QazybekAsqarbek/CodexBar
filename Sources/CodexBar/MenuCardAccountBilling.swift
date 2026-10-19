import CodexBarCore
import Foundation

extension UsageMenuCardView.Model {
    static func accountBillingNotes(input: Input) -> [String] {
        guard input.provider == .codex, !input.hidePersonalInfo,
              let billing = input.snapshot?.accountBilling else { return [] }
        guard billing.isAvailable else {
            return ["Billing unavailable — check this account's web session"]
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        var notes = ["Billing checked: \(formatter.string(from: billing.observedAt))"]
        if input.now.timeIntervalSince(billing.observedAt) > 15 * 60 {
            notes.append("Billing may be out of date")
        }
        if let invoice = billing.invoices.first {
            notes.append("Latest invoice: \(invoice.status) · \(invoice.date) · \(invoice.amount)")
        }
        let unpaid = billing.invoices.filter { ["Due", "Failed", "Uncollectible"].contains($0.status) }
        if !unpaid.isEmpty {
            notes.append("Unpaid invoices shown: \(unpaid.count)")
        }
        if let paid = billing.invoices.first(where: { $0.status == "Paid" }) {
            notes.append("Last paid invoice shown: \(paid.date)")
        }
        for card in billing.cards {
            let primary = card.isDefault ? " (default)" : ""
            notes.append("\(card.brand) •\(card.lastFour)\(primary)")
        }
        if let backup = billing.backupPaymentsEnabled {
            notes.append("Backup payments: \(backup ? "on" : "off")")
        }
        return notes
    }
}
