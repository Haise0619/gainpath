# Module 8 consolidated manual UAT

Source: C3 FR-8.1–FR-8.6, UC-8.1–UC-8.7 and BR-5; C4 Coach and certification records. Owner manual PASS is pending. Backend/emulator checks do not constitute real Firebase UI success.

Use the integrated Firebase Android build and the existing Admin Web at `http://localhost:7359/builds/module8/`. Use authorized test content only; do not alter protected published media or personal accounts belonging to others.

1. **Coach authentication (FR-8.1–8.3):** sign in with valid credentials, confirm invalid credentials give a safe error, request a password reset and follow the secure email link. Cancel logout once, then confirm logout; Back must not expose account or certification data. Sign in again.
2. **Coach settings (FR-8.4):** save a valid international contact number and notification choices, leave/reopen and verify persistence. Try an invalid number and a number already claimed by another Coach. Clear the number and save. Change password with current-password confirmation; verify the old password fails after logout and the new password works. Cancel an edited form and verify discard protection.
3. **Professional profile (FR-8.5):** save biography, specialization tags, experience and optional MYR consultation fee. Check required fields, biography limit and invalid/negative fee rejection. Select a gallery photo, crop and save; reopen, replace using camera, then clear and verify the default avatar. Private draft edits require Admin publication before Member display.
4. **Certifications (FR-8.6):** upload a valid PDF and JPEG/PNG (maximum 5 MB), reopen and preview each, inspect pending status and history. Reject invalid/oversized files. Archive one test document and verify its status/history remain. Retry a failed operation without creating duplicate records. PDF preview is bounded to 20 pages; longer documents may be submitted but preview reports the limit.
5. **Admin review and BR-5:** select that Coach in the existing directory administration screen, inspect private evidence/history, reject a pending document with a reason, and verify the Coach sees it. Approve a valid document, then explicitly publish the reviewed profile. Approval alone must not publish. Reopen both roles and verify status/reason/timestamps.
6. **Member directory and preservation:** before verification/publication, the Coach must be absent and unavailable for new booking selection. After approval/publication, confirm the reviewed profile, fee and photo display. Revoke/archive the last approved test credential and confirm the listing becomes inactive. Existing bookings remain retained; do not modify them for this test. Another Coach/Member must not access private certification files or edit verification fields.

Consultation fee is profile information in this module. Existing frozen Booking pricing/transaction algorithms are unchanged. Certification removal archives the reference; immutable evidence and audit history are retained. Notification choices record preferences, not proof of notification delivery.

## Live activation evidence

Deployment, build/install hashes, focused test results and approved BR-5 maintenance are recorded in the accompanying Module 8 delivery evidence. The owner explicitly approved hiding the sole previously published Coach without approved credentials; identity, private profile and existing bookings must remain intact.
