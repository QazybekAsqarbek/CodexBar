import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CodexBar
@testable import CodexBarCore

@MainActor
struct AccountBillingTests {
    private static let fixture = #"""
    {"verified":true,
     "invoices":[
       {"date":"10/15/2026","status":"Due","amount":"USD 100.00"},
       {"date":"9/15/2026","status":"Paid","amount":"USD 100.00"}],
     "cards":[
       {"brand":"Visa","lastFour":"1234","isDefault":true},
       {"brand":"Visa","lastFour":"1234","isDefault":false}],
     "backupPaymentsEnabled":true}
    """#

    private func billing() throws -> AccountBillingSnapshot {
        try #require(AccountBillingSnapshot.parse(Data(Self.fixture.utf8)))
    }

    @Test func `keeps unpaid status and duplicate card records`() throws {
        let billing = try self.billing()
        #expect(billing.invoices.first?.status == "Due")
        #expect(billing.cards.count == 2)
        #expect(billing.cards[0].isDefault)
        #expect(!billing.cards[1].isDefault)
    }

    @Test func `never serializes payment metadata into shared snapshots`() throws {
        let snapshot = try UsageSnapshot(primary: nil, secondary: nil, updatedAt: Date())
            .withAccountBilling(self.billing())
        let data = try JSONEncoder().encode(snapshot)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.contains("1234"))
        #expect(!text.contains("accountBilling"))
        #expect(try JSONDecoder().decode(UsageSnapshot.self, from: data).accountBilling == nil)
        #expect(snapshot.with(primary: nil, secondary: nil).accountBilling == snapshot.accountBilling)
    }

    @Test func `rejects unverified and unmasked payloads`() {
        for fixture in [
            Self.fixture.replacingOccurrences(of: "true", with: "false"),
            Self.fixture.replacingOccurrences(of: "1234", with: "1234123412341234"),
        ] {
            #expect(AccountBillingSnapshot.parse(Data(fixture.utf8)) == nil)
        }
    }

    @Test func `redacts all billing details and isolates providers`() throws {
        let snapshot = try UsageSnapshot(primary: nil, secondary: nil, updatedAt: Date())
            .withAccountBilling(self.billing())
        #expect(try self.notes(snapshot, provider: .codex, hidden: true).isEmpty)
        #expect(try self.notes(snapshot, provider: .claude, hidden: false).isEmpty)
        let visible = try self.notes(snapshot, provider: .codex, hidden: false)
        #expect(visible.contains { $0.contains("Due") })
        #expect(visible.filter { $0.contains("•1234") }.count == 2)
        #expect(!visible.contains { $0.contains("paid through") })
    }

    @Test func `render synthetic billing card when requested`() throws {
        guard let directory = ProcessInfo.processInfo.environment["CODEXBAR_BILLING_PROOF_DIR"] else { return }
        let snapshot = try UsageSnapshot(
            primary: .init(usedPercent: 15, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: Date()).withAccountBilling(self.billing())
        let model = try UsageMenuCardView.Model.make(self.input(snapshot, provider: .codex, hidden: false))
        let renderer = ImageRenderer(content: UsageMenuCardView(model: model, width: 380)
            .padding(20).background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .light))
        renderer.scale = 2
        let bitmap = try NSBitmapImageRep(cgImage: #require(renderer.cgImage))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("billing-preview.png"))
    }

    private func notes(_ snapshot: UsageSnapshot, provider: UsageProvider, hidden: Bool) throws -> [String] {
        try UsageMenuCardView.Model.accountBillingNotes(input: self.input(snapshot, provider: provider, hidden: hidden))
    }

    private func input(_ snapshot: UsageSnapshot, provider: UsageProvider, hidden: Bool) throws -> UsageMenuCardView
    .Model.Input {
        try .init(
            provider: provider,
            metadata: #require(ProviderDefaults.metadata[provider]),
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "owner@example.test", plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: hidden,
            now: Date())
    }
}
