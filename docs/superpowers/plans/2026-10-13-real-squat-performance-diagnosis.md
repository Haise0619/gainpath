# Real Squat Performance Diagnosis Plan

User physical feedback: visible tracking delay; voice works after unmuting; local
result survives restart. Diagnose latency without assuming rep accuracy is proven.

Use the existing CPU/default filtering configuration for an observation build.
Use a separate bounded scalar sampler for accepted delivery, first CPU paint and
analyzer runtime, plus existing detector means and scheduler counters. The existing
quality subsystem retains coordinate traces, so do not enable it wholesale. Add a
scalar-only report emitter guarded by non-release GAINPATH_SQUAT_PERFORMANCE.
No raw joint/ROI logs, capture, rule tuning, GPU default switch,
upload or server enablement. Keep normal builds behavior unchanged.

- [x] Test that injected sampler reaches preview/analysis and finite whitelisted
  performance reports exclude frames, joints, ROI, user/session IDs and raw data.
- [x] Implement sampler wiring, analyzer-stage timing and 5-second aggregate
  reports in the real route with lifecycle cleanup.
- [x] Verify affected/mobile suites and source analysis; independent review.
- [x] Build a separately preserved Firebase CPU profile measurement APK; install
  with -r on the connected phone, preserving local results. User can then start
  a session while bounded performance logs are collected.
- [x] Record measured evidence or explicitly pending person/session measurements;
  commit and push the diagnostic work. Physical display latency remains distinct
  from callback-to-delivery/CPU-paint times.

Verification: 253 mobile tests passed, 15 optional checks skipped; source analysis
clean. Review found and corrected a primitive-counter gate that depended on an old
quality flag. Independent crop-aware first-paint regression now passes with those
flags disabled. Final review found no remaining blocker.

Corrected measurement APK SHA256:
3051B590B5CA59E47C59548B4DC67ED24A16A6A3C1DF17DE5365A8C45CC8242B.
Installed with adb install -r after the user confirmed the session ended; launch
succeeded and process existence was verified. Person/session reports are pending.

If a GPU comparison is justified by this baseline, use the existing experimental
backend in a separate matched build. Never claim accuracy/latency acceptance from
host tests or change production policy based on subjective delay alone.

Ruling: independent read-only audit found no queue/double-filter defect and advised
against enabling the coordinate-bearing quality subsystem just for telemetry.
Use input-stamp-to-delivery/paint labels because current timestamps are after plane
copying; physical camera latency remains unavailable. Historical refined-to-filtered
crossing delay is evidence to investigate smoothing, not a current measurement.
