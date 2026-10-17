# Module 1 consolidated owner UAT

Installed build: Firebase Android debug, application source `f28cdfd`; backend
`2e14a16`. Exact Rules and three lifecycle callables are deployed. Prior photo and
contact acceptance remain recorded; this integrated module acceptance is pending.
Use one new disposable Member with an email address you control for registration,
password and lifecycle cases. Do not deactivate the existing canonical accounts.

1. **Registration and verification — UC-1.1/1.2.** Try a missing name, invalid
   email, weak password and mismatched confirmation; each should block submission.
   Register the disposable Member. Before verification, protected screens must
   remain gated. Resend once and check the cooldown. The verification button must
   explain an unverified result without losing the pending screen. Open the latest
   real email link, then check verification again. Invalid/expired hosted links
   should offer recovery through a newly requested link.
2. **First profile — UC-1.8/1.9/1.10.** Complete the existing guided setup. Choose
   an age bracket; explicitly confirm your height and weight. Select training
   focus, activity and experience. Finish, close/reopen the app and verify the
   values. No prototype measurements should appear as submitted facts before
   confirmation. Prefer not to say is a valid gender choice.
3. **Account settings — UC-1.6.** Save a display name; the route may close while
   the authenticated greeting refreshes. Reopen Settings and confirm it. Save,
   reopen, replace and clear contact details. Toggle notification/voice choices,
   leave and reopen. These persist choices; actual delivery/voice features are
   separate. Type an unsaved contact edit and use Back: keep editing or explicitly
   discard. Passwords must never appear in contact fields or stored documents.
4. **Profile editing — UC-1.8/1.9/1.10.** Change one physical metric, then experience
   and activity. Reopen each screen. Change a selection and Back out to check the
   discard prompt. Rapid repeated Save taps must not create repeated operations.
   A legacy exact age remains unchanged on unrelated edits; explicitly choosing
   an age bracket replaces it. Existing goals, preferences and workout history
   must remain intact.
5. **Numeric goals — UC-1.11.** Add weekly training sessions, a body-weight target
   and repetitions per workout. Check displayed units and periods (weekly means
   Monday–Sunday UTC). Try zero, an out-of-range value and excessive decimal
   precision. Save valid targets, reopen, edit one and reopen again. Archive one:
   it disappears from current targets; historical snapshots remain stored. No
   fake actual-progress percentage or achievement should appear. Different
   category/unit/period means a new target, not reinterpretation of an old ID.
6. **Picture — UC-1.12.** Use the existing camera/avatar control. Choose a valid
   image, preview, save and reopen. Replace it, reopen, then clear it and check the
   default avatar. Closing a selected but unsaved picture asks before discard.
   Invalid images show an error; an interrupted or uncertain save must not claim
   success. Clearing retains the original private Storage object.
7. **Credentials and session — UC-1.3/1.4/1.6/1.7.** On the disposable account,
   reject a wrong current password, then change to a valid new password. Sign out;
   the previous private routes must close. The old password should fail and the
   new one should work. Request recovery and use the real reset email. Unknown
   email requests must use a neutral confirmation. Sign in again and verify all
   saved settings/profile/goals/photo state. Switch to another Member and verify
   that none of the first Member's private values carry over. Existing Coach login
   and Admin web login should retain their established behavior.
8. **Errors.** Briefly disable network while loading/saving an ordinary profile
   edit. Check that an error or unconfirmed state appears, rather than invented
   values or a success message. Restore network and explicitly reload before
   repeating an uncertain edit. Offline logout must still close private UI.

## Separate approval gate within this checklist: live lifecycle — UC-1.5

Do not perform this on the canonical Member/Admin/Coach accounts. The owner
approved this disposable-account plan on 2026-10-17. Live backend checks created
one clearly labelled disposable Member, saved and reopened its profile,
preferences, numeric target/history and photo, then deactivated it. Old-token
access, pending private access and early reactivation were denied; the saved data
was retained. This fixture was verified through trusted administrative setup,
so these checks do not establish real email delivery or owner UI acceptance.
The server permits restoration from 19:49:59 Kuala Lumpur time on 2026-10-17;
the delayed reactivation/read-back check remains pending.

- For manual UI acceptance, use only an approved disposable Member. In Settings, request
  deactivation, read the warning and confirm its current password. Access should
  stop and the app should sign out. Login should open only Account recovery,
  showing a 30-day deadline and paused access.
- Private profile, preferences, numeric goals and photo bytes must stay
  inaccessible while pending. No record or Storage object should be deleted.
- After the server's 65-minute wait following successful session revocation,
  refresh status, confirm the password and choose Keep my account. Confirm normal
  access resumes with the saved profile/settings/goals/picture preserved.
- Permanent purge is disabled. Do not wait for or expect an automatic deletion;
  that portion of FR-1.4/BR-3 needs separate policy and destructive-cleanup approval.

Reply **PASS** for the integrated module, or **FAIL + step + observed behavior**.
If live lifecycle is not approved/tested, identify it as pending rather than
including it in a manual PASS claim.
