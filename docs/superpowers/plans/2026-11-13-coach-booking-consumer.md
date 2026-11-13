# Member Coach Booking consumer optimization

Owner specification: attached Complete Member Coach Booking UI/UX & Business Flow Optimization, 13 November 2026. Direct implementation requested; no additional design approval needed.

## Design and constraints

Choose coach → select date/time → focused review → temporary reservation → Sandbox payment → verified confirmation. New sessions are 60 minutes at the existing server per-session fee, with half-hour start boundaries. Old 30-minute purchases retain their duration, payment, refunds and management contract. Selection uses real coach/branch labels, compact date/time controls, MYT once and a sticky primary action. Review includes exact server price, optional voucher and 12h/24h policies. Hold expiry uses server evidence; unknown outcomes never silently create new attempts. Payment/refund/booking states remain independent.

Do not modify unrelated work or frozen Workout/AI/Rewards/Membership functionality. No live deployment, provider action or installation is needed for this implementation task. Test with synthetic fixtures and isolated emulators. Account guards, verified email, App Check, branches, credentials, overlap, capacity and server prices remain authoritative.

## Implementation stages

- [x] Capture actual baseline Flutter screenshots before widget changes.
- [x] Backend/domain/transport: fixed60 new bookings, optional human names and reviewed-price token, legacy compatibility; isolated tests and typechecks.
- [x] Member selection/review: fixed duration, real names, responsive date/time choices, explicit quote change consent, safe same-intent retries.
- [x] Hold/payment: actual expiry countdown, lifecycle recovery, safe cancellation and payment retry, friendly verified outcomes.
- [x] My Bookings/details: status-led actions, explicit payment/refund evidence, notes pending and preserved management policies.
- [x] Integrate tests/render coverage at320/360/390 and200%, scoped analysis, Android Debug build, emulator and independent review.
- [x] Commit stages separately and document precise outcomes in docs/ux/member-coach-booking-consumer-redesign.md.

## Coordination

Independent backend/domain, payment presentation and booking-list presentation work follows the dispatching-parallel-agents skill. Root owns selection/review composition and final integration. Domain booking-read contracts are owned by backend agent; list backend projection by list agent. No overlapping ownership of widget files. No broad staging of dirty references; append only scoped facts to operational documents.
