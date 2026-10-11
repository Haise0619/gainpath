"""Summarize local Step 2B logcat captures; no network or camera access."""
import argparse
import json
import re
from pathlib import Path


def read(path):
    rows, invalid = [], []
    for line in Path(path).read_text(encoding="utf-8-sig").splitlines():
        match = re.search(r"POSE_QUALITY_(\w+) (.*)", line)
        if not match:
            continue
        try:
            rows.append((match[1], json.loads(match[2])))
        except json.JSONDecodeError:
            invalid.append(match[1])
    return rows, invalid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("capture")
    parser.add_argument("--baseline", help="Subtract counters/timing totals at start of a physical phase")
    parser.add_argument("--output")
    args = parser.parse_args()
    rows, invalid = read(args.capture)
    created = [v for k, v in rows if k == "EVENT" and v["to"] == "session_created"]
    if not created:
        raise SystemExit("No session-created record: fresh-session provenance is unverified.")
    sid = created[-1]["sessionId"]
    rows = [(k, v) for k, v in rows if v["sessionId"] == sid]
    base, base_invalid = read(args.baseline) if args.baseline else ([], [])
    base = [(k, v) for k, v in base if v["sessionId"] == sid]
    def last(records, kind):
        return next((v for k, v in reversed(records) if k == kind), {})
    counters = last(rows, "COUNT").get("counters", {})
    base_counts = last(base, "COUNT").get("counters", {})
    timing = {v["stage"]: v["summary"] for k, v in rows if k == "TIMING"}
    base_timing = {v["stage"]: v["summary"] for k, v in base if k == "TIMING"}
    window = {}
    for name, summary in timing.items():
        initial = base_timing.get(name, {"count": 0, "meanMillis": 0})
        count = summary["count"] - initial["count"]
        total = summary["meanMillis"] * summary["count"] - initial["meanMillis"] * initial["count"]
        window[name] = {"count": count, "meanMillis": round(total / count, 4) if count else None,
                        "latestRollingP95Millis": summary["recentP95Millis"]}
    if args.baseline and window.get("workerPipelineMicros", {}).get("count", 0) <= 0:
        raise SystemExit("No new processed frames in the selected quality session; capture is stopped or replaced.")
    base_rates = sum(k == "RATE" for k, _ in base)
    rates = [v["intervalFps"] for k, v in rows if k == "RATE"][base_rates:]
    events = [v for k, v in rows if k == "EVENT"]
    base_events = sum(k == "EVENT" for k, _ in base)
    report = {"sessionId": sid, "freshSessionCreated": created[-1],
              "malformedLogRecords": invalid, "malformedBaselineRecords": base_invalid,
              "windowCounters": {k: v - base_counts.get(k, 0) for k, v in counters.items()},
              "timings": window, "rateSamples": rates,
              "transitionCounts": {reason: sum(v["to"] == reason for v in events[base_events:])
                                   for reason in sorted({v["to"] for v in events[base_events:]})},
              "latestHealth": last(rows, "HEALTH"), "latestPaint": last(rows, "PAINT"),
              "jointTimestampMismatches": sum(v.get("modelTimestamp") != v.get("paintTimestamp")
                                              for k, v in rows if k == "JOINT"),
              "latencyBoundary": "camera callback to CPU paint; exposure and display-present not supplied"}
    encoded = json.dumps(report, indent=2)
    if args.output:
        Path(args.output).write_text(encoded + "\n", encoding="utf-8")
    print(encoded)


if __name__ == "__main__":
    main()
