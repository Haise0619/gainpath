# Proposed Step 7 physical acceptance protocol

This protocol is ready for review; no new phone trial has been performed.
Use the preserved Step 7 profile diagnostic APK with upload off. Keep the same
phone, upright side view, full-body framing, lighting, model, GPU, direct preview
and baseline rule/filter settings. Log the exact APK hash and each run's setup.
Do not modify the rule during the labelled block.

## Declare labels before recording

Separate attempt detection, task-quality depth, projected angle agreement and
anatomical 3D angle accuracy. They are different questions. The software baseline
defines full by filtered 2D knee angle <=90° with its eligible 150 ms dwell plus
valid descent, ascent and return to standing. A physical task definition such as
the hip crease reaching the upper knee height is a separate proposed depth label;
it is not automatically equivalent to a 90° knee angle or a universal standard.
Agree and write the physical definition before recording. Do not choose it after
seeing app outcomes. Record intended full/shallow attempts separately from the
independently observed depth label.

Use an independent side-view body recording with a clear knee/hip view. Two
raters should label the body recording without seeing the skeleton, app count,
score or diagnostic outcomes. Mark attempt start, deepest region and return to
standing using decoded video presentation timestamps. Mark full/shallow/uncertain
with the declared physical definition, reconcile disagreements and retain the
original labels. Occlusion, insufficient camera angle and ambiguous borderline
attempts remain uncertain rather than being forced into a class. The existing
oblique recording of a phone screen supports six visible attempts, but cannot
certify anatomical angles or recover original world tensors.

## Initial trial blocks

1. Three sets of five slow intended full squats, with a full return to standing.
2. Separately labelled shallow attempts and borderline depth/short bottom holds.
   Do not instruct a participant to force uncomfortable depth for a test label.
3. Three fresh 20-second stationary standing sessions, settling before starting
   each capture. Check that both full and partial counts stay zero. Keep the
   stationary summaries separate from approach and exercise sessions.
4. Controlled visibility loss, brief occlusion and pause/background/resume during
   an attempt; no unseen completion should be invented. Check camera recovery,
   recalibration, app stop/start and that saved scoped results survive restart.
5. Voice-on delivery trial with known correction opportunities. Record mute state
   and eligibility/cooldown separately from whether the user hears the cue.

The earlier suggested engineering gate is exact counts in all three five-full
sets, independently shallow attempts never counted full, zero counts in all
stationary holds, and no completion through sustained loss or pause. This is a
small regression gate, not an agreed population accuracy target. Report the whole
trial, including failures, rather than repeating until only successes remain.

## Match and report events

Predeclare event matching: monotonic ordered attempts and nearest return-to-standing
within ±0.5 s, with one app completion matched to at most one labelled attempt.
Use a synchronized recording showing body and phone when timing is needed.
The scalar logs contain order and relative attempt duration, not independent
wall-clock synchronization; without synchronized evidence, report ordered-count
matching only and do not claim timed precision. Report ambiguous matches separately.

For attempt detection, count full plus partial app completions. Report TP/FP/FN,
precision = TP/(TP+FP), recall = TP/(TP+FN), and F1, including missed attempts and
spurious stationary counts. A zero denominator is unavailable, not 100%.
For depth classification report a full/shallow confusion table on clearly labelled
matched attempts, plus uncertain labels, missed attempts and aborted/unassessable
attempts with their denominators. Also report usable/rejected observations,
interruptions, world availability and retention evictions. Successful-classification
percentages alone conceal coverage failures.

For coaching, independently label correction opportunities under the declared
depth/trunk criteria. Separate whether the analyzer requested the matching
correction, whether audio was eligible, and whether it was delivered audibly.
Report correction precision/recall on opportunities/events with the declared
matching tolerance. A muted or cooling-down request is not evidence that the
pose algorithm failed to recognize an opportunity. Conversely, hearing speech
does not establish correct classification. Terminal depth/trunk penalties help
explain outcomes; they are not independent coaching ground truth.

## Interpret 2D/3D and timing cautiously

Step 7B observes estimated 3D angles; it has no 3D repetition FSM or classification
output. Do not report a 3D-classifier accuracy from these logs. Compare the four
streams' availability/counts and per-attempt ranges as exploratory evidence only.
Their aggregate means/minima can use different valid populations, so subtracting
them is not a paired-frame error metric. Frame-level lag/error analysis would need
a separately reviewed bounded measurement design. Do not add coordinate history
or image uploads to this candidate to obtain it.

Agreement between 2D and estimated 3D is not anatomical accuracy. A trusted
independent 3D reference is required for degree-level world-angle error. A clear
side-view reference video can support projected-angle/task-depth labels under
its own limitations; it does not provide arbitrary-view 3D ground truth. The
same numeric coordinate-filter beta does not imply equal response across units.

For responsiveness, record physical body motion and phone display together using
an external high-frame-rate camera. Decode actual frame timestamps and bracket
movement onset/visible skeleton response; report the resulting interval, frame
resolution and synchronization uncertainty. Internal inference, worker,
input-to-drawable CPU timing and analyzer timing measure separate boundaries.
They do not include every display/camera delay or prove perceived latency.

For stability, use the separate stationary sessions and review visible shake and
false count changes. The summary range includes calibration; record whether it
contains approach or movement before treating it as stationary spread. Without
per-frame traces, ranges cannot establish frequency, variance or temporal lag.

## Decision after evidence

Document errors and coverage first. If the baseline fails, identify geometry,
visibility, dwell/cadence or phase/recovery failure before adjusting one variable.
The first-descent timer distinction is now observable and must be included when
explaining borderline partials. Compare a later rule candidate against the same
fixed labels, and assign a new scoring/rule version if decisions change.

Keep 2D if 3D evidence does not support improvement. Do not enable trusted workout
tuples until physical quality and lifecycle acceptance pass. Then separately
review policy enablement and verify one genuinely captured, pre-consented session
through authenticated acceptance, offline/restart/retry and exactly one accepted
document. Other exercises and rewards follow that remaining acceptance work.
