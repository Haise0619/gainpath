# Independent OAuth Console verification — 2026-10-22

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Read-only Google Cloud Console inspection completed while signed in as `owner-google-account-redacted@example.invalid`, project `gainpath-0619`.

- Audience: External; publishing status: Testing.
- Exactly one test user: `owner-google-account-redacted@example.invalid`.
- Registered scopes: `openid`, Google `userinfo.email` (equivalent to requested `email`), `calendar.app.created`, `gmail.send`. No restricted scopes or additional listed scopes.
- Web client: `GainPath gym booking integration`, ID `879719977530-ifb9qd1nqogi0kf79vm5mcqbesno530j.apps.googleusercontent.com`.
- Registered callback: `https://us-central1-gainpath-0619.cloudfunctions.net/googleGymOAuthCallback`.
- App name: GainPath. Support email and developer contact both `owner-google-account-redacted@example.invalid`.

No OAuth settings or credentials were modified. Secret controls were not revealed or copied. Secret payload/client pairing is not yet proven by a successful consent exchange.

Restarted the existing local Admin Web build at `http://localhost:7359/`. Chrome currently shows the GainPath Administrator sign-in page; owner must sign into their GainPath Admin account before the authorized Google connection can begin. Google Cloud sign-in alone does not sign into GainPath. No Google account connection, Coach calendar creation, email sending or booking changes occurred.

Owner authorized continuing to Google account connection, but the final OAuth permission screen remains subject to action-time browser confirmation. Calendar/event creation and email sending remain separately gated.
