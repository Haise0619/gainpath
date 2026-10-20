# Consultation notes — bounded implementation

Approved scope: FR-9.5 / UC-9.2 / BR-14, using the existing notes editor and roster cards. Implement directly with minimum focused verification; no deployment, provider changes, ratings, payouts or cancellation work.

1. Add an Auth/App Check callable to read participant-only notes and publish an immutable note by the assigned active Coach after a confirmed session ends. Transactionally create the nested note, complete the existing booking and retain a payload-bound retry receipt. Do not touch locks, financial records or other session data.
2. Add a small domain repository and Firebase adapter; reuse ConsultationNotesScreen for both connected and injected mock workflows. Connected reads show loading/error, successful publish waits for the server, uncertain retries keep the original payload/request, and saved notes reopen read-only. Preserve unsaved edits on navigation and account-change protection.
3. Connect existing roster notes button and Member booking detail read action. Add an explicit recent-history range (past 30 days), bounded by existing 31-day page size and participant authorization. Current/future range remains default.
4. Run only the focused notes/history backend tests, one affected editor widget test group, typecheck and targeted analysis/boundary checks. One focused final static review; no full CI/build/emulator matrix.

Decisions: one published note per booking, maximum 5,000 characters; no server drafts or editing published notes. Completion uses server time >= original end time, not device time. Recent history query accepts up to 90 days back with a 31-day page; UI exposes the last 30 days. Note text stays in a booking subdocument and is never projected into Admin listing or financial records. Existing direct client booking writes remain denied; no Rules deployment needed for callable-only access.
