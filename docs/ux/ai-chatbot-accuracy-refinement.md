# GainPath Chatbot response accuracy and card refinement

This local fix addresses the six Xiaomi screenshots supplied on 2026-11-16. The original equipment, nutrition and tomorrow-coach questions are regression inputs.

## Root causes

The server's generated-answer guard matched arbitrary past-tense words and personal pronouns with generic quantities. Its fallback then read workout totals regardless of the original intent. Equipment and nutrition answers could therefore become unrelated accepted-session counts. The revised guard targets actual personal-history claims. An unsupported claim from a general question receives an explicit verification response, without querying workout totals.

Coach discovery ended after the directory tool returned, even when the question requested a particular day. Explicit availability questions now resolve a date and query the existing 60-minute booking-options service for the authorized bounded directory page. Returned slots carry exact date, timezone, branch, price, expiry and timestamps. The client validates the structure and opens existing checkout with a trusted suggestion.

## Personal records and content

Workout answers distinguish exercise captures, unfinished attempts and complete routines. Exercise-specific questions filter the corresponding records and retain nullable Form Score. Cards promote date, repetitions, duration and status. Routine completion and self-reported activity retain their existing semantics.

Tutorial suggestions display authored exercise names and published destinations. Cover images are used only when supplied by the existing published tutorial. Membership display separates verified entitlement, published plan differences and shared benefits, and includes expiry where available.

## Date interpretation

Relative booking dates use the current authoritative booking-policy timezone and server clock, with the exact timezone shown in the answer. GainPath's current Malaysian booking context therefore resolves tomorrow in that scheduling timezone. Automatic conversion from a travelling device's different timezone is outside this change. The response exposes the date and timezone for review before checkout.

## Validation

Final verification passed 78 backend tests across eight files and 124 Flutter tests across ten files. The Flutter suite exercised all five existing quick actions, keyboard layout, 320dp at 200% text, the tutorial cover and expired booking controls. TypeScript source and test checks and scoped Flutter analysis passed. The arm64 Android Debug build succeeded in 14.4 seconds. This was a local release preparation with zero live provider calls.

Fourteen screenshots under `build/chatbot-accuracy/screenshots/` show the actual Flutter renderer at 390dp and at 320dp with 200% text. Replies and account data are fixtures. The tutorial preview uses an existing app image to exercise the published cover layout. The Debug APK and raw verification logs are in `build/chatbot-accuracy/`.

| Original question | Median before | Median after | Callable and provider requests before → after | Progress queries before → after |
|---|---:|---:|---:|---:|
| Which equipment works my chest? | 59.04 ms | 47.04 ms | 1 and 1 → 1 and 1 | 1 → 0 |
| what can i eat healthy | 68.24 ms | 48.36 ms | 1 and 1 → 1 and 1 | 1 → 0 |

The paired benchmark ran nine local trials per question with injected latency of 15 ms per provider call, 2 ms per transaction read batch and 5 ms per workout query. Each question dropped from 11 to eight logical document reads. These timings describe the local harness. Live network and provider latency remain unmeasured. The tomorrow regression verifies one Callable, zero Gemini calls, actual availability service reads and no reservation.
