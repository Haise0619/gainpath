# Module 1 data contract

Implementation reference for FR-1.1–1.7 / UC-1.1–1.12. C3/C4 remain the baseline;
this document records the compatible organization-scoped implementation and
material design decisions. Original dissertation files are unchanged.

## Canonical ownership and provenance

All paths use the authenticated UID and its server-provisioned organization.
Registration provisions only Member, organization `gainpath`, branch `main`.
Client-supplied roles, lifecycle state and organization assignments are forbidden.

| Record | Facts and types | Source, writer and privacy |
|---|---|---|
| Firebase Auth | UID; email; emailVerified; creation metadata; enabled/disabled status | Auth owns credentials and verification. Passwords, reset/verification tokens and ID tokens never belong in Firestore. |
| `users/{uid}` | Existing `schemaVersion:1`, `organizationId`, `primaryBranchId`, `email`, `displayName`, creation/update milliseconds; optional `contactDetails`, `memberPhotoPath`, `accountLifecycle` | Trusted provisioning owns identity/scope and initial timestamps. Auth email is authoritative; Firestore email is an existing provisioned projection. Contact/photo are private owner fields. |
| `orgs/{org}/members/{uid}` | `userId`, `organizationId`, `role`, `status`, `branchIds`, email/name projections, existing millisecond metadata | Trusted provisioning owns assignment. Lifecycle commands alone change Member status. Existing authorized staff membership views remain; private profile/contact/photo are not added to them. |
| `orgs/{org}/profiles/{uid}` | Fitness facts described below | Verified, active, canonical Member owner only; not a general Admin-report data source. |
| `orgs/{org}/preferences/{uid}` | `schemaVersion:1`; booleans `pushNotifications`, `emailUpdates`, `voiceCoaching`; `updatedAt:Timestamp` | Owner choices; server timestamp on save. Missing document means not configured; UI defaults are proposed choices, not evidence of prior consent or delivery. |
| `orgs/{org}/profiles/{uid}/goals/{goalId}` | Versioned numeric target described below | Private Member owner; bounded server queries; no analytics completion producer. |

Display name is edited atomically in `users` and `members`; neither projection
may drift during a Member name change. Name is 1–120 trimmed characters without
control characters. A successful save reads both copies back. Contact is an
optional single string, maximum 200 characters without controls; `''` means
explicitly cleared, absence means never configured. Sign-in email remains
read-only in Settings: password change uses Auth reauthentication. No unsupported
Firestore-only credential change is offered.

`createdAtMillis` from trusted provisioning is creation evidence where its writer
is known. Existing identity `updatedAtMillis` also has client writers: it is
**not** an authoritative lifecycle, verification or engagement event. No legacy
timestamp is backfilled. Auth verification is current state, not a historical
verification time. No app-open, attendance or last-login event is introduced.

## Fitness profile: compatible schema 1 and schema 2

Required common fields:

| Field | Type and meaning | Allowed values |
|---|---|---|
| `gender` | User-supplied enum; optional disclosure represented explicitly | `female`, `male`, `unspecified` (Prefer not to say) |
| `heightCm` | Integer centimetres, user-submitted | 130–210 inclusive |
| `weightKg` | Integer kilograms, user-submitted | 35–160 inclusive; existing UI precision preserved |
| `experience` | User-selected training experience | `beginner`, `intermediate`, `advanced` |
| `activity` | Self-described activity; not verified attendance | `sedentary`, `lightlyActive`, `moderatelyActive`, `veryActive`, `extremelyActive` |
| `goals` | Unique training-focus enum list, 1–6 values | `loseWeight`, `buildMuscle`, `improveEndurance`, `increaseFlexibility`, `generalFitness`, `reduceStress` |
| `updatedAt` | Firestore server Timestamp | Last confirmed profile write; UTC instant |

Schema 1 has `age:int` (13–80) and no ageBracket. Schema 2 has `ageBracket` and
no exact age: `teens` (13–17), `youngAdult` (18–24), `adult` (25–34), `midAdult`
(35–44), `matureAdult` (45–54), `olderAdult` (55–64), `senior` (65–80).
These ranges are the reporting vocabulary over the existing supported age range;
no birthdate is collected. Rendering a derived bracket never migrates a record.
Only the Member explicitly selecting a bracket removes legacy exact age and
upgrades the schema. Other edits preserve the original exact age. Downgrading a
bracket to an invented exact age is denied.

New profile creation adds immutable `createdAt` and `profileCompletedAt`, both
server Timestamps. Existing profiles without these fields remain valid; a later
edit must not invent initial-completion history. All measurements need explicit
confirmation during new setup. Values shown as proposed defaults are never
submitted merely by stepping through the form. Invalid/malformed saved data shows
a repair/error state, without substituting prototype facts.

Reads use the server. Writes compare the original full snapshot in a transaction,
then patch only changed facts. Conflicts require explicit reload; uncertain
read-back never claims success. Repositories/forms are bound to one session
lifetime, including repeated login to the same UID. Sign-out invalidates them and
clears transient private UI data without deleting protected local workout data.

## Numeric goals and historical meaning

Training-focus tags remain in the profile. They are not numeric progress targets.
Numeric goals use a separate bounded subcollection under the existing profile.
Every goal has `schemaVersion:1`, stable `goalId`, `category`, `targetValue`, `unit`,
`evaluationPeriod`, `status`, integer `revision>=1`, and server Timestamps
`createdAt`/`updatedAt`.

| Category | Numeric target | Unit | Evaluation period |
|---|---|---|---|
| `trainingFrequency` | Integer 1–14 | `sessions` | `calendarWeek`: Monday 00:00 UTC through next Monday 00:00 UTC |
| `bodyWeight` | 35–160, at most one decimal | `kg` | `latestMeasurement`: latest eligible measurement, no invented deadline |
| `repetitions` | Integer 1–1000 | `repetitions` | `perSession`: total repetitions in one workout session |

Weight limits reuse existing profile limits. Frequency/repetition upper bounds
are conservative input guardrails added where C3/C4 specify numeric goals without
bounds; they are not training advice or achievement thresholds. Units and periods
are explicit to resolve the dissertation's underspecified numeric targets.

Each create/update/archive atomically writes the current goal and an identical,
immutable snapshot at `goals/{goalId}/revisions/{revision}`. Category, unit,
evaluationPeriod and createdAt cannot change. New intent with different semantics
gets a new ID. Archive changes `status:active` to `archived`; it never deletes
historical meaning or claims completion. Archived records cannot be edited.
Concurrent revision changes reject stale edits. Create forms retain one allocated
ID across retries, preventing duplicate creation after an uncertain response.
Current goal reads request at most 21 records (20 displayed plus an overflow
indicator); history reads, when introduced, must also page at most 21 records.

No goal is marked achieved, no actual measurement is fabricated, and no completion
percentage is displayed. Future Module 5 comparisons must select a trusted
performance/measurement producer, reference `goalId+revision`, and use the exact
unit and UTC interval. Account/profile presence, self-described activity and app
opens are not verified workouts. Cross-module producers remain unchanged.

## Private profile pictures

`users.memberPhotoPath` owns the Member's current reference. Absence means not
configured; `''` means explicitly cleared; nonempty means
`orgs/{org}/memberProfilePhotos/{uid}/{32-lowercase-hex-id}`. The existing Admin
`avatarPath`/`profilePhotos` contract remains separate.

Storage permits authenticated, email-verified, active canonical Member owner get
and create only. Objects are immutable, at most 5 MiB, JPEG/PNG/WebP; list,
overwrite and delete are denied. The client validates the real signature and
decoder, rejects over 24 megapixels, and resizes when needed to fit 512×512
without stretching/upscaling. Smaller valid originals are preserved.
Rendering retrieves authenticated bytes; no public token-bearing URL is stored.
Replacement allocates a new object. Clearing updates only the reference. Failed
uploads/reference conflicts can leave private unreferenced objects; deletion and
orphan cleanup await an approved retention contract.

## Account lifecycle and session safety

The owner delegated the policy decision; this implementation chooses C4's 30-day
grace period with reactivation. **Permanent deletion is not activated.**
The deployment parameter `MEMBER_LIFECYCLE_GRACE30_DAYS_APPROVED=true` enables the
approved non-destructive window; false keeps the explicit pending-approval state.

`users.accountLifecycle` is a server-only map with schemaVersion 1, state
`active|pendingDeletion`, revision, request/deadline/update/reactivation server
milliseconds, policy `grace30Days|pendingApproval`, `sessionNotBeforeSeconds`,
`sessionRevokedAtMillis`, lastRequestId, revocationPending and bounded cleanup
lease/attempt identifiers. Nullable timestamps represent events that have not
occurred. Legacy active accounts without this map load as active revision 0 with
unknown lifecycle history. Suspended membership is not silently reactivated.

Three App-Check-enforced callables derive UID and scope from current Auth and
canonical documents: get status, request deactivation, cancel deactivation.
Transitions require verified email and authentication within five minutes.
Commands carry only schema version, stable request ID and expected revision.
Server-only receipts under
`orgs/{org}/memberLifecycleCommands/{uid}/requests/{requestId}` make retries
idempotent. No password, token, contact, photo or measurement payload is logged
there. Receipts remain private with the account until an approved purge policy.

Request atomically records pending state and projects membership.status to
`pendingDeletion`; normal protected access closes immediately. Auth refresh-token
revocation occurs outside the transaction, then is acknowledged with trusted
completion time. A failed/retried revocation remains pending and safely resumes
through the status command. Sign-out does not erase protected local data.

Reactivation requires completed revocation, expired cleanup lease, fresh password
authentication, the approved deadline, and **65 minutes after successful
revocation**. This deliberate compatibility wait exceeds Firebase's ordinary
one-hour ID-token lifetime, so reopening membership cannot revive old tokens in
frozen adjacent backends that lack revocation checks. It starts at revocation
completion, not at request time. [Firebase session contract](https://firebase.google.com/docs/auth/admin/manage-sessions).
The UI presents the server-returned availability time; device clocks do not
authorize transitions. Restored accounts retain the session barrier. Module 1
Firestore/Storage Rules additionally reject tokens older than that barrier.

A fresh pending login can read its own existing identity/membership documents to
resolve the recovery screen. Firestore grants whole-document reads, so this
limited exception includes existing own contact/reference fields; it grants no
profile, preferences, goal or photo-byte access and no client identity edits.
Pre-request tokens cannot use that recovery read. Admin/Coach flows retain their
existing contracts. Client attempts to edit lifecycle, role, scope, membership
status, receipts or immutable creation metadata are denied.

After the deadline the account stays inaccessible pending trusted support/purge
policy; no deletion is falsely reported. An eventual purge needs separate
approval for Auth, subcollections, Storage/orphans, booking/financial references,
consent/outbox/local history dependencies and lawful audit retention. It must use
an idempotent bounded worker with retries and explicit ownership checks. Deleting
one root document is insufficient. No such worker is deployed in this sprint.

## Reporting readiness and remaining boundaries

Current canonical data can establish active/pending/suspended membership counts
under an authorized server aggregation contract, current verified Auth state,
known creation/completion/deactivation instants, configured targets and their
revisions. It cannot establish missing historical verification/completion times,
past profile measurements, attendance, engagement or goal achievement. Lifecycle
canonical data describes the latest cycle; private command receipts provide
minimal transition evidence, not a public analytics feed.

General Admin clients receive no new private Member access. Future Modules 5/12
must define purpose, authorization, minimization and aggregation before exposing
measurements/contact/lifecycle history. No reporting pipeline, tracking events,
automatic personal-data migration or frozen-system change is introduced.

Deployment evidence and exact live Rules rollback snapshots are kept in the
ignored `build/non-core-crud-sprint/module-1-activation/` directory. Repository
Rules contain unrelated pre-existing drift and must never be deployed wholesale.
Owner manual acceptance and automatic purge remain separate completion gates.
