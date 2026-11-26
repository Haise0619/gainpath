
# Chapter 5 — Implementation and Testing

This reference describes GainPath as inspected on 25 November 2026 in Malaysia. The primary working tree is `membership-upgrade-work` on `codex/member-notification-bell-dot`, based on `f81fb2d5d48857c75cb5f1b8491086fc4bcceba6` with local changes. An alternate `otp-work` checkout provides branch comparison. The original Chapters 1–4 describe proposed scope. Use the [snapshot](evidence/snapshot.md), [original requirement mapping](13_REQUIREMENTS_TRACEABILITY_MATRIX.csv) and [deviations](14_IMPLEMENTATION_DEVIATIONS.md) to anchor claims.

## 5.1 Implementation and Coding

### 5.1.1 System Development Environment

GainPath uses a Dart/Flutter workspace with a Flutter mobile app and Admin Web app. CI pins Flutter 3.38.9, Java 17 for Flutter and Java 21 for Firebase emulator work. The audit observed Flutter 3.38.9, Dart 3.10.8, Java 20.0.2 and Node 24.19.0. Cloud Functions declare Node 22, and the project locks TypeScript 5.9.3, Firebase CLI 13.35.1 and Vitest 2.1.9. Android build uses minimum API 26, AGP 8.11.1, Kotlin 2.2.20 and Gradle 8.14. Runtime targets inherited from Flutter and historical hardware vary by test. Chapter 3 requests API 23, so report the change. [Version and integration inventory](01_SYSTEM_DEVELOPMENT_ENVIRONMENT.md).

### 5.1.2 System Architecture Implementation

Mobile provides Member and Coach shells. Admin uses a separate Flutter SPA. The shared packages are domain, data, identity, pose and UI. Both normal entry points initialize Firebase. AuthBloc and the feature Cubits/controllers hold UI state. Constructor-injected test repositories are used by a separate test composition. In the ordinary app, scoped Firebase adapters mediate direct reads and writes or invoke callable commands. UI state captures loading, empty, unavailable and loaded views. The backend uses typed command validation and Firestore transaction adapters, plus HTTP provider callbacks, scheduled workers and Firestore event triggers. Firebase Auth identity, App Check and role/organization/branch/ownership guards have different jobs. The registration callable uses Auth identity before verification; other operations enforce their own requirements. Client menu visibility is a presentation control.

Firestore stores a canonical user plus organization-owned membership records, nested per-feature collections and denormalized public Coach projections. Important transactions use append-only receipts or compare-and-set semantics. Media and credential assets live under scope-specific Storage paths. App-scoped files handle workout sessions, checkpoints and continuity. Eligible descriptive backup is controlled by session scope and schema. The 85-export index is a source inventory. Historical deployment records describe targeted releases with conditions; current cloud state was unable to be verified.

The following literal excerpt illustrates a backup transaction's natural identity and conflict boundary. Surrounding code omitted. Source `functions/src/modules/workouts/workout-backup.ts:51–64`.

~~~ts
  const key = kind+'-'+id, path = `orgs/${org}/members/${uid}/workoutBackups/${key}`;
  return store.transact(async tx => {
    await member(tx,auth!,org,uid);
    const previous = await tx.get(path);
    if (previous?.digest === digest) return {schemaVersion:1,status:'backed_up',kind,id,digest};
    if ((previous && (kind === 'session' || previous.digest !== v.baseDigest)) ||
        (!previous && v.baseDigest !== null)) {
      throw new DomainError('already-exists','Backup conflict. Both copies are retained.');
    }
    const revision = await tx.get(path+'/revisions/'+digest);
    const record = {schemaVersion:1,kind,id,key,digest,payloadJson:JSON.stringify(payload),
      classification:'provisional_member_backup',updatedAtMillis:Date.now()};
    if (!revision) tx.create(path+'/revisions/'+digest,record);
    tx.set(path,record);
~~~

Exact repeats short-circuit before mutation. A conflicting immutable session or an incompatible base revision preserves the existing stored payload. This helps the offline client retry safely across interruptions. [Architecture and scope](02_SYSTEM_ARCHITECTURE_IMPLEMENTATION.md) · [Data model](evidence/DATA_MODEL.md) · [Functions inventory](evidence/backend_function_inventory.csv) · [Architecture diagrams](evidence/diagrams/SYSTEM_ARCHITECTURE.md).

### 5.1.3 Functional Module Implementation

| Module | Current implementation and evidence boundary |
|---|---|
| M01 User account and profile | Firebase signup and role-safe routing, verified Member onboarding, fitness preferences and account lifecycle. Default reset link is wired. Optional OTP UI is gated and the main Functions index omits its server export. |
| M02 Virtual coach | Published routines, six analyzer routes, manual logging, video-guided timed workouts, pause/rest/continuity, form cues, summaries and backup. Physical coverage differs by exercise. |
| M03 Gamification | Check-in, badges/achievements, local game history, leaderboard, server point awards, scoped redemption and verification. Eligible workout award amounts are ten AI or five guided points per exercise/day. Game score and spendable points are independent. |
| M04 Membership and payment | Free, Basic and Premium membership, quotes, upgrade/extension, time-bound refund request, guarded payment reconciliation and sandbox provider integration. Xendit test is the new path with method/provider configuration; Billplz Sandbox remains relevant to configured legacy paths and receipts. |
| M05 Member reports | Owner-scoped workout, history, program and progress views. Date/exercise/routine filters, grouped form and training counts, native Android PDF export. |
| M06 Fitness assistant | Consent/disclaimer, scoped context, Gemini prompt construction and response controls, bookmark/feedback and bounded history. Historical liveness is narrower than response quality. |
| M07 Booking | Coach directory, options, transactional slot hold, sandbox settlement, booking confirmation/history, cancellation/reschedule, messaging and reviews. |
| M08 Coach identity | Privileged provisioning and profile/account edit, private certificate lifecycle, controlled directory publication and profile media. |
| M09 Consultation | Assigned Coach appointment/consultation notes, roster, Member messages, status progression and selected client posture/performance context. |
| M10 Availability | Weekly roster, day overrides, branch windows, capacity, exception handling and protection against conflicting reservations. |
| M11 Admin operations | Real Admin sign-in, member/coach/content/branches/rewards/payments management, compliance and group operations. Primary branch audience announcement contracts need parity with the branch-specific implementation. A group-class navigation argument also prevents the current normal Member shell from compiling. |
| M12 Admin reports | Scoped current accounts, booking, sandbox values, workout/check-in measures, dates/branches and exports. Recorded illustrative value includes scenario entries. |
| M13 Recommendations | Consent and admitted evidence rules, deterministic candidate scoring/eligibility, Gemini-assisted guidance within bounded runtime, Admin review and current Member delivery. Historical controlled cohort acceptance does not establish general rollout. |
| Supplementary | Branch facility visits/QR, group classes, operations calendar, legal document acceptance, equipment scanner, support and announcement controls. |

The [module evidence files](03_FUNCTIONAL_MODULE_IMPLEMENTATION/) contain front-to-back flows, source anchors, conditions and tests.

### 5.1.4 Core Technology Implementation

#### 5.1.4.1 Real-Time Human Pose Estimation Pipeline

The phone acquires camera frames, interprets frame orientation and pixel representation, then sends bounded fresh work to an on-device two-stage model. The bundled 224-pixel detector establishes person/ROI geometry; the Full landmark model emits image and optional world estimates with confidence. ROI may be maintained across frames. Android supports a native GPU path with CPU fallback. The scheduler can discard obsolete captures and the renderer projects/mirrors the valid overlay independently of repetition state. The architecture does not require workout camera frames to be sent to cloud AI. Equipment photo identification is a separate operation. [Pipeline](04_CORE_TECHNOLOGY_IMPLEMENTATION/POSE_ESTIMATION_PIPELINE.md).

#### 5.1.4.2 Landmark Processing and Biomechanical Angle Calculation

Use normalized image landmarks with aspect correction. For joint $B$, let $u=A-B$ and $v=C-B$ in aspect-corrected coordinates. Joint angle is $\theta=(180/\pi)\arccos(\operatorname{clamp}((u\cdot v)/(\lVert u\rVert\lVert v\rVert),-1,1))$. A zero-length vector or unacceptable confidence invalidates the joint. For $u=(0,-4)$ and $v=(3,0)$ the angle is 90°. The One Euro filter adjusts cutoff $c=c_{\min}+\beta|\widehat{\dot x}|$ using a filtered temporal derivative. Display filtering can reduce jitter while analyzer states still consume their own eligible samples. [Math and worked examples](04_CORE_TECHNOLOGY_IMPLEMENTATION/LANDMARK_AND_MATHEMATICAL_PROCESSING.md).

#### 5.1.4.3 Exercise-Specific Movement Analysis and Repetition Counting

The six active cases are side-view squat, curl and calf raise, front shoulder press and lateral raise, and side-view floor push-up. Wall push-up, reverse lunge and single-arm row are manual in the primary snapshot. Analyzers enforce geometry, calibration, threshold dwell, valid movement stages and a return. In the default squat, stable standing is at least 160° knee angle for 500 ms. Depth requires 90° or less for 150 ms and the valid return reaches 160°. A valid shallow return can be recorded as partial. Floor push-up verifies TOP/BOTTOM around 155°/105° with qualified dwell and return. The exercise-specific camera contract determines which limbs are used. [Complete exercise threshold matrix and state diagrams](04_CORE_TECHNOLOGY_IMPLEMENTATION/EXERCISE_ANALYSIS_AND_REP_COUNTING.md).

#### 5.1.4.4 Posture Evaluation and Form Correction Algorithm

Rule evaluation screens confidence and track continuity before scoring. Squat uses sustained trunk lean and depth. Curl considers upper-arm/trunk drift, calf raise examines leg geometry, and the front trackers gate bilateral symmetry. Floor form mixes range of motion, alignment, control and extension, $S=.40R+.35A+.15C+.10E$. An illustrative $(90,80,90,100)$ yields 87.5. Some validated 2D or recovered counts omit strict form values. Form is an engineered proxy with a versioned measurement scope. [Rules, formulas and implementation evidence](04_CORE_TECHNOLOGY_IMPLEMENTATION/POSTURE_CORRECTION_AND_SCORING.md).

#### 5.1.4.5 Real-Time Voice Feedback Mechanism

The app selects identified voice events from exercise status and prioritizes interruptions and corrections. Cue policy suppresses duplicates and stale deliveries. The Android bridge manages start deadlines, prerecorded pack clips, effects or eligible TTS, and invalidates audio across owner/session changes. [Voice components](04_CORE_TECHNOLOGY_IMPLEMENTATION/VOICE_FEEDBACK.md).

#### 5.1.4.6 Motion-Based Mini-Game Implementation

Reach & Tap uses pose and projected hand contact/confirmation on reachable targets. Move & Catch measures lateral motion relative to alignment and applies item crossing and catch/hazard rules. Both freeze or rearm on tracking interruptions, keep local game score distinct from reward grants, and expose game/session history. [Game algorithms](04_CORE_TECHNOLOGY_IMPLEMENTATION/MOTION_BASED_MINI_GAMES.md).

#### 5.1.4.7 AI-Powered Equipment Recognition

An authorized Member captures and confirms a bounded image request to a server callable. Gemini returns a structured candidate. Server logic independently resolves eligible published catalog metadata and associated guidance. Unknown, unverified and unavailable outcomes have separate meaning. [Model and catalogue workflow](04_CORE_TECHNOLOGY_IMPLEMENTATION/AI_EQUIPMENT_RECOGNITION.md).

#### 5.1.4.8 AI Fitness Chatbot and Contextual Personalization

The server validates entitlement, a versioned disclaimer, purpose/context limits and turn state, then constructs the prompt from bounded authorized profile/history/catalog information. It parses and handles structured outcomes, caches or persists only appropriate state and protects restricted or unsafe advice paths. [Prompt and response handling](04_CORE_TECHNOLOGY_IMPLEMENTATION/AI_FITNESS_CHATBOT.md).

#### 5.1.4.9 AI-Powered Trainer and Content Recommendation Engine

Eligible consented workout evidence feeds scoped aggregation and rule-driven candidate eligibility/ranking. Some assisted guidance uses Gemini with timeout, schema checks and a deterministic fallback. Reviewed candidate state, approval, durable delivery receipts and Member notification presentation remain distinct. The historical demo cohort has a separate assignment and data-provenance contract. [Recommendation workflow](04_CORE_TECHNOLOGY_IMPLEMENTATION/AI_RECOMMENDATION_ENGINE.md).

### 5.1.5 Implementation Challenges and System Refinements

Camera/landmark variants introduced queue and overlay delays, so capture freshness, accepted-result delivery and display retention are separately controlled. Stale audio was addressed with freshness and native deadlines. Offline recovery introduced scoped checkpoint/backup key and digest logic. Payment, booking and rewards protected replay and inconsistent provider outcomes with transactions and receipts. A changing set of supported trackers and API designs created versioned reporting and branch parity problems. The Member shell call at `member_shell.dart:609` passes `onOpenGroupClasses`, which is absent from the factory signature at `coach_profile_factory.dart:99–103`. Tests that load that composition fail before assertions. [Chronology and rationale](05_IMPLEMENTATION_CHALLENGES.md).

## 5.2 Testing Strategies and Approaches

### 5.2.1 Testing Objectives
Check domain correctness, safe access and data integrity, UI state, recovery, and the physical/evaluation questions separately. Maintain explicit evidence of each environment, scope, build and data source.

### 5.2.2 Unit Testing
Dart unit tests cover pose math, analyzer dwell, models, validators and repositories. Vitest exercises backend policy, idempotency, participant scope and integration adapters with test doubles. Fake clocks and synthetic inputs isolate boundaries.

### 5.2.3 Widget and User Interface Testing
Flutter tests inject local dependencies to exercise route gates, loading/errors, commerce/report states and responsive presentation. Retained screenshots reflect compiled fixtures or specifically dated prior acceptance.

### 5.2.4 Integration Testing
The Firebase Emulator Suite provides local Firebase Auth/Firestore/Storage/Functions contexts when supported by the runner and selected test config. Cross-module cases trace role, backup, reporting and database outcomes. Provider and third-party behavior require their own authorized test targets.

### 5.2.5 System and Functional Testing
Member and Coach workflows span the mobile app plus Admin operations, with distinct expected outcomes at payment, report and queue boundaries. Execution evidence varies by journey and is cited on individual cases.

### 5.2.6 Non-Functional Testing
Security Rules, role/branch test scope, offline recovery, concurrency, compatibility and performance each require their own evidence. Internal frame computation and rendering/first-paint timings do not measure the same interval as external motion and audio.

### 5.2.7 Regression Testing
The snapshot includes regressions for stale capture, phase/controller timing, protected source records, and account/transaction state. Keep initial runner failures and repeat results visible. Architecture rules flag two imports in the working tree.

### 5.2.8 AI Model and Algorithm Evaluation
Synthetic frame sequences verify algorithm logic. Historical phone and external-video experiments measure specific timing and visible behavior. Independent labelled physical samples and provider-response assessment are needed for effectiveness claims.

### 5.2.9 User Acceptance Testing
Historical operator and controlled Admin/Member fixture or sandbox evidence is available. Participant-level Member, Coach and Admin acceptance on the audited snapshot remains open. [Strategies and acceptance record](06_TESTING_STRATEGIES.md) · [UAT](11_USER_ACCEPTANCE_TESTING.md).

## 5.3 Test Plan

### 5.3.1 Test Scope and Objectives
Cover 13 modules plus group classes, QR visits, equipment recognition and compliance. Prioritize physical pose, eligibility/data consistency and representative role tasks.

### 5.3.2 Testing Environment
Record local Windows audit host, runtime mismatches with CI, emulator configuration/project, app build mode, test device/browser, dataset and account scope.

### 5.3.3 Testing Tools and Resources
Use Flutter/Dart Test, Vitest/TypeScript, Flutter Web build, Firebase emulator profiles, fixture stores, auth/rules tests, anonymized screen/frame recordings and structured CSV templates.

### 5.3.4 Testing Schedule
The audit records current 25 November execution plus earlier development checkpoints. Planned physical and participant sessions require explicit build/device reservations and approved test scope.

### 5.3.5 Test Entry and Exit Criteria
Record a reproducible source and toolchain snapshot, exact commands, test fixtures and protected data boundaries before execution. For exit, require result and evidence per case, with failures and blockers dispositioned. Release criteria include physical and policy evidence.

### 5.3.6 Test Acceptance Criteria
Define deterministic expected values for software assertions. Prespecify temporal windows and thresholds for independent physical evaluation. Record acceptable use of assistance in UAT. A fixture success covers the observed contract.

### 5.3.7 Requirements Traceability
The audit matrix covers 87 original FRs, 22 NFR concepts including RTM-only offline and 15 business rules. The RTM and Table 3.34 differ after the offline insertion. Map implementation, verification and deployment separately. [Test plan](07_TEST_PLAN.md) · [RTM](13_REQUIREMENTS_TRACEABILITY_MATRIX.csv).

## 5.4 Test Data

### 5.4.1 Test User Accounts and Role Configuration
Use synthetic verified/unverified/suspended identities with Member, Coach, Admin and branch scope. Keep authorized live demos distinct from emulator identities.

### 5.4.2 User Profile and Fitness Data
Use synthetic profile numbers, goal revisions, activity, experience and account state. Include invalid ranges and separated consent/version state.

### 5.4.3 Exercise and Workout Routine Data
Use stable execution identity, valid mapped views, published routine/Program data, explicit AI/manual/timed mode, and combination checkpoints for interruption and continuity.

### 5.4.4 Pose Estimation and Exercise Movement Dataset
Motion-labelled synthetic landmarks support regression. Historical videos and telemetry are small conditional benchmarks. Independently labelled, consented frames and repeated safe movements remain needed.

### 5.4.5 Gamification and Reward Data
Seed local scores, point ledgers, participation/check-in events, award caps, challenge/voucher histories and eligible tiers. Boundary tests must distinguish wallet points from game score.

### 5.4.6 Membership and Payment Test Data
Use gateway test methods, integer MYR amounts, paid/unpaid/cleared/status recovery/refund examples and synthetic Free/Basic/Premium accounts.

### 5.4.7 Coach Booking and Scheduling Data
Control Malaysian local date, roster intervals/branch, stale and conflicting slots, payment state, cancellation/reschedule notice, assignment and duplicate review.

### 5.4.8 AI Chatbot and Recommendation Test Data
Fix anonymized profiles, eligible workout history, consent changes, review status and synthetic prompts. Keep actual provider output separate from stubs and derived evidence.

### 5.4.9 Invalid, Boundary and Exceptional Test Data
Cover unavailable or malformed responses, wrong scope, expired capability, replay, duplicate upload, unsupported schema, offline pause, occlusion and unusual camera geometry. [Detailed datasets](08_TEST_DATA.md).

## 5.5 Test Cases and Results

### 5.5.1 Test Case Documentation Format
Give stable ID, requirement, module, test category/objective, inputs and state, exact steps, expected and actual results, status, environment, evidence and remarks.

### 5.5.2 Functional Test Cases
Link source assertions to representative positive, negative and boundary scenarios. Exercise the observed normal entry point where possible, especially signup, exercise selection, rewards, payment and role-gated booking/analytics.

### 5.5.3 Cross-Module Integration Test Cases
Trace identity to scoped access, Admin content to workout, workout to backup/report/award, availability to checkout/confirmed booking, consultation to history, rewards to fulfilment, and reviewed recommendation to intended inbox.

### 5.5.4 Non-Functional Test Cases
Collect performance on a known build/device, verify authority and privacy in local rules and service configs, then characterize offline recovery, compatibility, accessibility and browser responsiveness with controlled test data. See [test case directory](09_TEST_CASES/).

### 5.5.5 Core AI Technology Evaluation

#### 5.5.5.1 Pose Detection Performance
Use $100V/E$ for valid detections $V$ among predeclared eligible frames $E$. Count localization error only when independent labels exist. Historical screen observations establish intermittent rendering and tracking behaviors under those conditions.

#### 5.5.5.2 Repetition Counting Evaluation
For trial errors $e_i=d_i-g_i$, report signed mean and $\operatorname{MAE}=\sum |e_i|/n$ plus exact match and over/undercount proportions. Report separate false counts among zero-rep samples. A historical right-side floor debug recording documents five counts with two rejected incomplete extensions. All exercise/device combinations require paired labels.

#### 5.5.5.3 Posture Correction Evaluation
Label safe per-repetition form events independently and prespecify matching windows. Report TP, TN, FP, FN, precision, recall, specificity and F1 per deviation. Validated aggregate confusion matrices are missing. Form-score regression cases exercise algorithm rules.

#### 5.5.5.4 Real-Time Processing Performance
An October matched phone pair observed 9.55 CPU and 17.00 GPU processed/drawable FPS, 70.02 vs 12.59 ms mean landmark native processing and 135.84 vs 90.61 ms callback-to-first CPU paint. The historical trial does not establish the current whole-path 33 ms goal or hardware display latency. [Attributable raw values](evidence/evaluation_results/POSE_HISTORICAL_METRICS.csv).

#### 5.5.5.5 Voice Feedback Evaluation
A historical native debug probe records prepare-to-start median 12.6905 ms and maximum 31.257 ms for ten observed events with audible output. Scope does not include end-to-end deviation-to-acoustic delay. Repeat with time-aligned audio and display on the release candidate.

#### 5.5.5.6 Environmental Robustness Evaluation
Historical clips include real occlusion/visibility and display timing observations. Collect repeated trials across view, light, distance, visibility, background and interruption while holding the build and protocol constant.

#### 5.5.5.7 Equipment Recognition Evaluation
A historical provider diagnostic and catalog/response fixtures exist. Measure labelled model top label and subsequent exact catalogue match separately, including unknowns and invalid cases.

#### 5.5.5.8 AI Chatbot Response Evaluation
Historical Gemini smoke evidence validates limited response paths. A timestamped rubric over independent prompts is needed for clarity, correctness, relevance, safety and grounding.

#### 5.5.5.9 Recommendation Engine Evaluation
Historical controlled guidance includes a fallback observation and a valid Gemini result with unchanged top rank; controlled delivery was observed. Independent rank relevance, cold-start, stale content and general consent/cap coverage require separate evaluation. [All nine evaluation reports](10_CORE_AI_EVALUATION/).

### 5.5.6 User Acceptance Testing
Prior retained operator walkthroughs, acceptance reports and controlled synthetic-role tasks support specific feature paths. Current acceptance requires representative users of each role and a written task/outcome table with participant consent, success, assistance and follow-up. [UAT evidence and protocol](11_USER_ACCEPTANCE_TESTING.md).

### 5.5.7 Test Results Summary
Fresh local verification recorded 2,395 backend passes, 0 failures and 2 skips, and 312 grouped emulator passes, 0 failures and 2 skips. The shared pose package passed 407 tests. Admin recorded 711 passes, 13 failures and 30 skips. Mobile recorded 2,450 passes, 41 failures and 53 skips. Of Mobile's 41 failures, 25 are suite-load compilation failures from the unsupported `onOpenGroupClasses` argument in the Member shell, and 16 are other assertions. The Admin debug web build and both TypeScript checks passed. The architecture gate flagged two imports. The audit did not establish a compiled current Mobile APK or live deployment. [Execution report](12_TEST_EXECUTION_RESULTS.md) · [Exact commands and total run data](evidence/test_logs/RUN_SUMMARY.csv).

## 5.6 Chapter Summary and Evaluation

### 5.6.1 Implementation Summary
GainPath integrates on-device physical motion coaching with cloud identity, entitlements, coaching appointments, reporting and separately mediated cloud AI. The key technical contribution is the exercise-specific landmark/time/phase pipeline with typed local and cloud outcomes.

### 5.6.2 Evaluation of Project Objectives
The functional implementation substantially supports personalized guidance, gamification, consultation, reporting and flexible mobile workflows. Real-time pose integration and historical evaluations demonstrate partial achievement of the exact second objective because broad validation and injury-risk outcomes remain unevidenced. [Exact six objective statements and assessments](15_PROJECT_OBJECTIVE_EVALUATION.md).

### 5.6.3 System Limitations
Current limitations include six supported analyzers, expected camera views, draw/geometry sensitivity, provisional scoring, differing device compatibility, commercial sandbox, gated AI/data consent, multi-branch contract drift and incomplete labelled/participant-level evidence. [Limitations](16_SYSTEM_LIMITATIONS.md).

### 5.6.4 Chapter Conclusion
Use the exact source snapshot and test-run provenance when presenting current capabilities. Use historic tests for their named build and conditions, and present unresolved device, provider and user acceptance as open evaluation. The highest priority is a labelled current-device repetition/form/latency matrix linked to the active exercise contracts. [Pending work](19_MISSING_EVIDENCE_AND_PENDING_TASKS.md).
