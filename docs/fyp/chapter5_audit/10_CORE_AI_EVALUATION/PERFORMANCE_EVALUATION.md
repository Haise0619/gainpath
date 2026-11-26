# 5.5.5.4 — Real-time processing performance

## Retained matched phone comparison

Historical 6 October paired CPU/GPU profile measurements from docs/architecture/2026-10-06-pose-step2m-screen-comparison.md:87–113. The same model and nominal 250 ms freshness were used. Case identity, environment and build must remain tied to this report. The camera rate is input throughput, not the rate of accepted pose results.

| Metric | CPU control | GPU candidate |
|---|---:|---:|
| Reported processed/delivered drawable/unique CPU paint FPS | 9.55 | 17.00 |
| Nonempty delivered and unique-painted count | 382 | 680 |
| Native landmark invocation mean, ms | 70.02 | 12.59 |
| Worker computation mean, ms | 102.72 | 56.25 |
| Callback→UI mean, ms | 122.97 | 77.42 |
| Callback→first CPU paint mean, ms | 135.84 | 90.61 |
| Nonempty overlay expiry events | 15 | 0 |

The 3 October external mirror capture gives separate physical-elbow→visible-skeleton enclosures of approximately 0.2–0.7 s, 0.1–1.1 s (censored), 0.2–0.8 s and 0.2–0.8 s for four events. Repeatability is uncertain and these bounds are neither measured percentiles nor additive with the earlier/later telemetry. The paired 6 October filmed-view crossing ranges overlapped, so a physical speedup ratio cannot be stated. CPU paint timestamps exclude subsequent raster/composition/display; the Flutter callback excludes sensor exposure. CPU/GPU test order, thermal state and power were not controlled. The [evidence CSV](../evidence/evaluation_results/POSE_HISTORICAL_METRICS.csv) contains transcribed metrics with boundary and historical provenance. Underlying participant recordings are excluded.

**Pending** current physical-device benchmark. Use exact build and model hash, record fixed device/lens and two common Android devices if available, throttle warm/cold conditions, record capture/delivered/paint rates, dropped/replaced counts, age/processing p50/p95/max and one full warm exercise/round per backend/voice mode. Record five or more minutes for resource/thermal sustained behavior if practical. For sensor-to-display estimates use a simultaneous external recording of a physical event and app overlay, bracket display timing and report uncertainty separately. 9.55 and 17.00 do not characterize all current workouts. Historical matched metrics do not prove 30 FPS or a universal latency target.
