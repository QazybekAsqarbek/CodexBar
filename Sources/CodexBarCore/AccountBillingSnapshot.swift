import Foundation

/// A live observation, never a paid-through date or evidence of a successful charge.
/// Deliberately not Codable: payment metadata must not enter widgets, history, or cloud sync.
public struct AccountBillingSnapshot: Equatable, Sendable {
    public struct Invoice: Equatable, Sendable {
        public let date: String
        public let status: String
        public let amount: String
    }

    public struct Card: Equatable, Sendable {
        public let brand: String
        public let lastFour: String
        public let isDefault: Bool
    }

    public let isAvailable: Bool
    public let invoices: [Invoice]
    public let cards: [Card]
    public let backupPaymentsEnabled: Bool?
    public let observedAt: Date

    public static func unavailable(observedAt: Date = Date()) -> Self {
        Self(isAvailable: false, invoices: [], cards: [], backupPaymentsEnabled: nil, observedAt: observedAt)
    }

    /// Only allowlisted, already-masked fields may cross the browser boundary.
    public static func parse(_ data: Data, observedAt: Date = Date()) -> Self? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              raw["verified"] as? Bool == true,
              let invoices = raw["invoices"] as? [[String: Any]], !invoices.isEmpty, invoices.count <= 20,
              let cards = raw["cards"] as? [[String: Any]], !cards.isEmpty, cards.count <= 20
        else { return nil }
        var parsedInvoices: [Invoice] = []
        for row in invoices {
            guard let date = row["date"] as? String,
                  date.range(of: #"^\d{1,2}/\d{1,2}/\d{4}$"#, options: .regularExpression) != nil,
                  let status = row["status"] as? String,
                  ["Due", "Paid", "Void", "Failed", "Refunded", "Uncollectible"].contains(status),
                  let amount = row["amount"] as? String, amount.count <= 40,
                  amount.range(
                      of: #"^(?:[A-Z]{3}[\s\u00a0]+|[$€£¥₹₩₽₸]\s?)[0-9][0-9.,\s\u00a0]*$"#,
                      options: .regularExpression) != nil
            else { return nil }
            parsedInvoices.append(Invoice(date: date, status: status, amount: amount))
        }
        var parsedCards: [Card] = []
        for card in cards {
            guard let brand = card["brand"] as? String,
                  ["Visa", "Mastercard", "American Express", "Discover", "UnionPay", "JCB", "Diners Club"]
                      .contains(brand),
                      let lastFour = card["lastFour"] as? String,
                      lastFour.range(of: #"^[0-9]{4}$"#, options: .regularExpression) != nil,
                      let isDefault = card["isDefault"] as? Bool
            else { return nil }
            parsedCards.append(Card(brand: brand, lastFour: lastFour, isDefault: isDefault))
        }
        return Self(
            isAvailable: true,
            invoices: parsedInvoices,
            cards: parsedCards,
            backupPaymentsEnabled: raw["backupPaymentsEnabled"] as? Bool,
            observedAt: observedAt)
    }
}
