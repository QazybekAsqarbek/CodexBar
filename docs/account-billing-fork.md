# Account billing in the personal fork

Based on upstream v0.77.0. The Codex card can show the latest visible invoice
(status, invoice date, amount), last visible paid invoice, masked saved cards,
the default-card marker, backup-payments setting when readable, and observation
time. This is an observation of the billing page, not a payment attempt, a
paid-through date, or a prediction of cancellation or retry timing.

## Enable and use

Enable Settings → Providers → Codex → OpenAI web extras and configure the
matching OpenAI cookie session. Select each account to refresh its card. Merely
having a Codex OAuth login does not establish a ChatGPT browser session. Safari
Private Browsing sessions may not be available to the existing cookie importer.
Safari import also requires macOS permission to read its cookie store. During
the local verification, the installed app reported that Full Disk Access was
missing. This permission is not granted by building or enabling web extras.
No credentials are copied between accounts. Existing usage refresh remains
independent of optional billing failures.

The new read runs after the accepted dashboard/subscription enrichment, in the
same scoped website data store. It opens `https://chatgpt.com/settings/billing`
and reads the English page's visible transaction and payment-method sections.
Before and after reading, the browser verifies the session email and the personal
account ID returned by the existing usage endpoint. The bearer remains within
the page. A different user, workspace, changed owner, unsupported locale, missing
section, or timeout yields unavailable. No payment, card editing, default-card
change, cancellation, or retry action is invoked.

## Boundaries

- Personal ChatGPT Plus/Pro/Go accounts only. Team/Business/Enterprise billing,
  Claude cards/invoice status, other providers, and App Store billing have not
  been verified and are not implemented by this adapter. Claude's existing
  renewal/expiry feature is unchanged.
- Only the page's initial invoice history is read; no claim of complete payment
  history. Invoice date is not the time payment succeeded.
- The English billing page was observed live on 2026-10-19. DOM extraction and
  identity checks are covered by synthetic tests; successful authenticated
  extraction inside the new app for every saved account still needs live
  verification. No undocumented invoice/card API schema is assumed.
- Both observed page shapes are supported: multiple cards with a backup-payments
  section, and one card without that optional section.
- An unsupported/empty page is unavailable, never evidence of no cards or no
  outstanding invoices. Unknown backup state is omitted.
- Two saved methods with the same last four digits remain separate rows.
- Billing is memory-only and excluded from UsageSnapshot Codable output:
  no widget, cloud sync, history, or disk cache of these payment details.
- Hide personal information hides the complete billing block. Turning off web
  extras or cookies hides it too. Observations older than 15 minutes are marked.
- Results populate the selected card and its matching cached account row.
  They do not promise background billing collection for unselected accounts.

## Verification

`node --test Scripts/test_account_billing.mjs` exercises the production JS against
synthetic English table content, duplicate cards, identity/workspace changes,
locale drift, and unmasked values. `AccountBillingTests` covers decoding,
persistence exclusion, provider isolation, redaction, and optional native card
rendering with `CODEXBAR_BILLING_PROOF_DIR`. All fixtures are synthetic.
