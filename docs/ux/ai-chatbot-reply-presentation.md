# GainPath Assistant reply presentation

Implemented 2026-11-16 from the owner's request for conclusion-first replies, readable message hierarchy and distinct native Flutter cards.

## Presentation and content

The existing trusted attachments now feed an `AssistantReplyViewModel` and dedicated `AssistantReplyView` renderers. Plain replies use lightweight selectable text. Membership, workout summary, training insight, coaching, recommendation and retry messages have separate layouts.

Membership displays a current plan, up to three verified benefits and one primary action. Additional benefits and published plan options expand separately. Workout cards promote repetitions, duration, status and available estimated form. Training insights lead with the actual comparable average and show observed change and capture count. Unsupported form measurements remain unassessed. Recommendations feature a recorded target and reason with a primary destination action.

Sources use subdued captions and expandable details. Full factual content remains available for Copy and Save. Quiet secondary actions retain helpfulness feedback. Membership uses a soft lavender surface, recommendations a highlighted purple treatment, and insights a distinct icon and metric hierarchy. Cards adapt to 320dp and 200% text by stacking stats.

Coach directory results now include optional server-constructed `coachSuggestions`, derived from authorized directory and price facts. The client validates IDs, currency, duration, list bounds and price before rendering. Book session opens the existing booking flow from the repository's returned-ID allowlist. Checkout continues to revalidate price and availability. Earlier responses without the optional field remain readable as text.

The model instruction now asks for a direct first sentence, short explanation and practical next step using everyday language. This request adds no provider round trip.

## Verification artifacts

Actual Flutter widget screenshots use controlled fixtures. Seven message types were rendered at 390dp and at 320dp with 200% text. Captures are in `build/chatbot-reply-presentation/screenshots/`, with filenames such as `membership-390.png`, `insight-390.png`, `coach-390.png`, `recommendation-390.png` and `error-320-large.png`.

Focused checks cover view-model mapping, verified versus published membership benefits, unscored history, compatible form groups, expansion, controlled CTAs, Retry, copying/saving, long conversation scroll and existing account-scoped repository behavior. The new server tests verify both an empty directory and actual quote-derived coach facts. TypeScript source and test checks pass.

Backend verification passed 42 tests across six selected files. Flutter verification passed 88 tests across nine files, including 14 view-model checks and 19 presentation checks. Fourteen actual renders cover seven reply types at two screen/text configurations. Scoped Flutter analysis reported no issues. The Android arm64 Debug build passed in 23.9 seconds.

The Debug APK is `build/chatbot-reply-presentation/gainpath-ai-assistant-replies-debug.apk`, SHA-256 `9C3E272898D248823B0F2737766024828CD55C285E4C68AE1F0A9A73B41E063C`. It contains the current working tree, including pre-existing local changes. Test, analysis and build logs are retained alongside it.

## Release scope

The change is prepared locally. The optional coach-list projection and prompt wording require a later scoped source update to the existing `fitnessAssistantCommand`. The UI can read older response shapes. This presentation task performed no deployment or live inference.

The existing workout, membership, recommendation and booking data services and controlled routes supply the facts and actions. Screenshots use fixture data. Real provider response wording and physical-device interaction require their respective acceptance checks.
