#if os(macOS)
import Foundation
import WebKit

/// Reads the English billing page observed in October 2026. No payment actions are invoked.
/// Session bearer material stays inside the page; only masked display metadata leaves it.
enum OpenAIBillingPage {
    static let script = #"""
    const expectedEmail = email.trim().toLowerCase();
    const signal = AbortSignal.timeout(2500);
    const owner = async () => {
      const sessionResponse = await fetch('/api/auth/session', { cache: 'no-store', signal });
      if (!sessionResponse.ok) return false;
      const session = await sessionResponse.json();
      if (session.user?.email?.trim().toLowerCase() !== expectedEmail || !session.accessToken) return false;
      const usageResponse = await fetch('/backend-api/wham/usage', {
        cache: 'no-store', signal, headers: { Authorization: `Bearer ${session.accessToken}` }
      });
      if (!usageResponse.ok) return false;
      const usage = await usageResponse.json();
      return (usage.account_id || usage.accountId) === expectedAccountID &&
        /^(plus|pro|go)(_|$)/.test(String(usage.plan_type || '').toLowerCase());
    };
    if (location.origin !== 'https://chatgpt.com' ||
        !location.pathname.toLowerCase().startsWith('/settings/billing')) return null;
    if (!(await owner())) return null;
    const lines = document.body.innerText.split(/[\n\t]+/).map(s => s.trim()).filter(Boolean);
    const historyStart = lines.indexOf('Transaction history');
    const historyEnd = lines.indexOf('Billing information', historyStart);
    const cardsStart = lines.indexOf('Payment methods');
    const backupStart = lines.indexOf('Backup payment methods', cardsStart);
    const cardsEnd = backupStart >= 0 ? backupStart : lines.indexOf('Cancel plan', cardsStart);
    if (historyStart < 0 || historyEnd < 0 || cardsStart < 0 || cardsEnd < 0) return null;
    const invoices = [];
    const history = lines.slice(historyStart + 1, historyEnd);
    for (let i = 0; i + 2 < history.length; i++) {
      if (/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(history[i])) {
        if (!/^(Due|Paid|Void|Failed|Refunded|Uncollectible)$/.test(history[i + 1]) ||
            !/^(?:[A-Z]{3}\s+|[$€£¥₹₩₽₸]\s?)[0-9][0-9.,\s]*$/.test(history[i + 2])) return null;
        invoices.push({ date: history[i], status: history[i + 1], amount: history[i + 2] });
      }
    }
    const cards = [];
    const paymentLines = lines.slice(cardsStart + 1, cardsEnd);
    for (let i = 0; i + 1 < paymentLines.length; i++) {
      if (/^(Visa|Mastercard|American Express|Discover|UnionPay|JCB|Diners Club)$/.test(paymentLines[i])) {
        const masked = paymentLines[i + 1].match(/^[•·*]{4}\s*([0-9]{4})$/);
        if (!masked) return null;
        cards.push({ brand: paymentLines[i], lastFour: masked[1], isDefault: paymentLines[i + 2] === 'Default' });
      }
    }
    const maskedRows = paymentLines.filter(line => /^[•·*]{4}\s*[0-9]{4}$/.test(line));
    if (maskedRows.length !== cards.length) return null;
    // A changed or unloaded page must not be mistaken for an empty/paid account.
    if (!invoices.length || !cards.length || invoices.length > 20 || cards.length > 20) return null;
    const toggles = [...document.querySelectorAll('[role="switch"]')].filter(element =>
      element.getAttribute('aria-label') === 'Backup payment methods' ||
      (element.getAttribute('aria-labelledby') || '').split(' ').some(id =>
        document.getElementById(id)?.textContent?.trim() === 'Backup payment methods'));
    const checked = toggles.length === 1 ? toggles[0].getAttribute('aria-checked') : null;
    const backupPaymentsEnabled = checked === 'true' ? true : checked === 'false' ? false : null;
    if (!(await owner())) return null;
    return JSON.stringify({ verified: true, invoices, cards, backupPaymentsEnabled });
    """#

    @MainActor
    static func fetch(
        in webView: WKWebView,
        email: String,
        accountID: String,
        deadline: Date) async throws -> AccountBillingSnapshot?
    {
        _ = webView.load(OpenAIDashboardFetcher.usageURLRequest(
            url: URL(string: "https://chatgpt.com/settings/billing")!))
        while Date() < deadline {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(400))
            let data: Data? = try await OpenAIDashboardBrowserCookieImporter
                .runBoundedValueCallback(deadline: deadline) { completion in
                    webView.callAsyncJavaScript(
                        self.script,
                        arguments: ["email": email, "expectedAccountID": accountID],
                        in: nil,
                        in: .page)
                    { result in
                        guard case let .success(value) = result, let text = value as? String else {
                            completion(nil)
                            return
                        }
                        completion(Data(text.utf8))
                    }
                }
            try Task.checkCancellation()
            if let data, Date() < deadline, let snapshot = AccountBillingSnapshot.parse(data) { return snapshot }
        }
        return nil
    }
}
#endif
