import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const source = readFileSync(
  new URL("../Sources/CodexBarCore/OpenAIWeb/OpenAIBillingPage.swift", import.meta.url),
  "utf8",
);
const script = source.split('static let script = #"""')[1].split('"""#')[0];
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const run = new AsyncFunction("email", "expectedAccountID", "location", "document", "fetch", script);
const page = `Transaction history
View all
Type\tDate\tStatus\tAmount
ChatGPT Pro\t10/15/2026\tDue\tUSD 100.00
ChatGPT Pro\t9/15/2026\tPaid\tUSD 100.00
Billing information
Billing email
billing@example.test
Payment methods
Add new
Mastercard
•••• 1234
Default
Mastercard
•••• 1234
Visa
•••• 5678
Backup payment methods
Cancel plan`;
async function observe({
  text = page,
  email = "owner@example.test",
  id = "personal-1",
  plan = "pro",
  changed = false,
  backup = true,
} = {}) {
  let reads = 0;
  const fetch = async (url, options) => {
    assert.equal(options.cache, "no-store");
    assert.ok(!options.method || options.method === "GET");
    if (url === "/api/auth/session") {
      reads++;
      return {
        ok: true,
        json: async () => ({
          user: { email: changed && reads > 1 ? "other@example.test" : email },
          accessToken: "synthetic-token",
        }),
      };
    }
    assert.equal(url, "/backend-api/wham/usage");
    return { ok: true, json: async () => ({ account_id: id, plan_type: plan }) };
  };
  return run(
    "owner@example.test",
    "personal-1",
    { origin: "https://chatgpt.com", pathname: "/settings/billing" },
    {
      body: { innerText: text },
      querySelectorAll: () =>
        backup
          ? [{ getAttribute: (key) => ({ "aria-label": "Backup payment methods", "aria-checked": "true" })[key] }]
          : [],
    },
    fetch,
  );
}
test("reads table cells, preserves duplicate masked cards, and identifies default", async () => {
  const result = JSON.parse(await observe());
  assert.equal(result.invoices[0].status, "Due");
  assert.equal(result.cards.length, 3);
  assert.equal(result.cards[0].isDefault, true);
  assert.equal(result.cards[1].isDefault, false);
  assert.equal(result.backupPaymentsEnabled, true);
  assert.ok(!JSON.stringify(result).includes("@"));
  assert.ok(!JSON.stringify(result).includes("synthetic-token"));
});
test("rejects another email, workspace, and a changed owner", async () => {
  for (const options of [{ email: "other@example.test" }, { id: "workspace-2" }, { plan: "team" }, { changed: true }]) {
    assert.equal(await observe(options), null);
  }
});
test("fails closed on partial, localized, or unmasked content", async () => {
  for (const text of [
    "",
    page.replace("Payment methods", "Карты"),
    page.replace("•••• 1234", "1234123412341234"),
    page.replace("Visa", "Unknown card brand"),
  ]) {
    assert.equal(await observe({ text }), null);
  }
});

test("supports currency symbols and fails closed on unknown invoice states", async () => {
  const symbol = JSON.parse(await observe({ text: page.replaceAll("USD 100.00", "$100.00") }));
  assert.equal(symbol.invoices[0].amount, "$100.00");
  assert.equal(await observe({ text: page.replace("Due", "Pending review") }), null);
});

test("reads a single card without the optional backup-payments section", async () => {
  const text = page.replace(
    /Mastercard\n•••• 1234\nDefault\nMastercard\n•••• 1234\nVisa\n•••• 5678\nBackup payment methods/,
    "Visa\n•••• 5678\nDefault",
  );
  const result = JSON.parse(await observe({ text, backup: false }));
  assert.equal(result.cards.length, 1);
  assert.equal(result.cards[0].isDefault, true);
  assert.equal(result.backupPaymentsEnabled, null);
});
