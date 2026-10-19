# Manual subscription notes

Settings → Providers → Codex → Subscription note (manual) has one text field
for each detected account. Enter any useful reminder, for example:
`Paid 15 Oct · next payment 15 Nov · Visa •1234`.
The note saves automatically and appears on that account's menu card. Clear the
field to remove it. Other providers show a field for their currently identified
account. Accounts without a known email do not receive a shared fallback note.

Notes are scoped by provider and normalized account email. They persist locally
in this app's preferences, independently of usage refresh, cookies and web
extras. They are not added to snapshot serialization, preference export or
cloud sync. Hide personal information hides both the editor and the menu note.
These are user-entered reminders, not verified payment records or automatic
renewal predictions. Use only the last four card digits in reminders.

The earlier automatic billing prototype was removed from the running code.
It remains in Git history at 8b32fa8 for reference. The installed application
in /Applications is not overwritten by this development build. Debug builds
use their own preferences; notes entered there belong to that build.

Validation: a standalone Swift check exercises the production note store's
account/provider isolation, normalization, save/reload and clearing with an
isolated UserDefaults suite. The native app is packaged for visual verification;
`make check` validates repository formatting, lint and localization.
