"""Summarize bounded Step 2D reports, never a per-frame landmark stream.

Input is an ADB logcat dump filtered to POSE_LAG aggregates/fixed representatives
and existing quality metrics. No camera/video inputs or workout writes.
Crossing pairing remains manual: every candidate bracket is printed without
claiming that ambiguous/missing crossings form a matching pair.
"""
import argparse
import json
import re
from pathlib import Path


def read_reports(path):
    records = []
    malformed = []
    chunks = {}
    for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        match = re.search(r"POSE_(LAG_[A-Z]+|QUALITY_[A-Z]+|FOUNDATION_METRICS) (\{.*)", line)
        if not match:
            continue
        try:
            stage, value = match[1], json.loads(match[2])
            if stage != "LAG_CHUNK":
                records.append((stage, value))
                continue
            key = (value["captureStartedMicros"], value["record"])
            group = chunks.setdefault(key, {"firstLine": line_number, "parts": {},
                                           "count": value["parts"], "stage": value["stage"]})
            part = value["part"]
            if (not 0 <= part < group["count"] <= 100 or part in group["parts"]
                    or value["parts"] != group["count"] or value["stage"] != group["stage"]):
                malformed.append(line_number)
                group["invalid"] = True
                continue
            group["parts"][part] = value["data"]
            if len(group["parts"]) == group["count"] and not group.get("invalid"):
                restored = json.loads("".join(group["parts"][i] for i in range(group["count"])))
                records.append(("LAG_" + group["stage"], restored))
                del chunks[key]
        except (json.JSONDecodeError, KeyError, TypeError):
            malformed.append(line_number)
    malformed.extend(group["firstLine"] for group in chunks.values())
    malformed.sort()
    return records, malformed


def summarize(records):
    phases = {}
    active = {}
    for stage, value in records:
        if not stage.startswith("LAG_"):
            continue
        label = value["phase"]
        if stage == "LAG_PHASE":
            active[label] = value["startedMicros"]
        start = value.get("captureStartedMicros", active.get(label, "unknown"))
        phase = phases.setdefault(f"{label}@{start}", {"stats": {}, "crossings": {}, "samples": []})
        if stage == "LAG_PHASE":
            phase["start"] = value
        elif stage == "LAG_SUMMARY":
            phase["summary"] = value
        elif stage == "LAG_STAT":
            phase["stats"][value["joint"]] = value
        elif stage == "LAG_CROSSING":
            phase["crossings"].setdefault(value["joint"], {})[value["spaceDirection"]] = value["events"]
        elif stage == "LAG_SAMPLE":
            phase["samples"].append(value)
    return phases


def candidates(phase):
    result = []
    for joint, events in phase["crossings"].items():
        for direction in ["raise", "lower"]:
            raw = events.get(f"refinedImageNormalized/{direction}", [])
            filtered = events.get(f"filteredImageNormalized/{direction}", [])
            for r_index, raw_event in enumerate(raw):
                r0, r1 = raw_event["inputBracketMicros"]
                # Nearby same-direction candidates only. No automatic averaging,
                # interpolation, or pairing across confidence/freshness loss.
                for f_index, filtered_event in enumerate(filtered):
                    f0, f1 = filtered_event["inputBracketMicros"]
                    if -250000 <= f0 - r1 <= 1000000:
                        result.append({"joint": joint, "direction": direction,
                                       "refinedIndex": r_index, "filteredIndex": f_index,
                                       "refinedInputBracketMicros": [r0, r1],
                                       "filteredInputBracketMicros": [f0, f1],
                                       "delayBracketMillis": [(f0-r1)/1000, (f1-r0)/1000],
                                       "status": "candidate_manual_pairing_required"})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    records, malformed = read_reports(args.log)
    phases = summarize(records)
    output = {"source": str(args.log), "malformedLines": malformed, "phases": phases,
              "crossingCandidates": {p: candidates(v) for p, v in phases.items()},
              "boundary": "Input timestamps measure filter response only; not sensor-to-display latency."}
    args.output.write_text(json.dumps(output, indent=2, allow_nan=False), encoding="utf-8")
    for name, phase in phases.items():
        print(name, "painted", phase.get("summary", {}).get("paintedFrames"),
              "mismatches", phase.get("summary", {}).get("timestampMismatches"))
        for joint, stat in phase["stats"].items():
            if "Elbow" in joint or "Wrist" in joint:
                print(joint, "mean/p95/max px", stat.get("displacementMeanPixels"),
                      stat.get("displacementP95Pixels"), stat.get("displacementMaxPixels"),
                      "rejected", stat.get("rejected"))
    print("malformed", malformed)


if __name__ == "__main__":
    main()
