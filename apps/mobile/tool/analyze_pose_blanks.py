"""Analyze bounded Step 2F blank metadata from ADB logcat, never camera data.

Logical cause decisions, first blank CPU paint and visible CPU recovery are
separate observations. CPU durations are not physical display durations. Missing
transport, bounded-cap overflow and open episodes remain censored observations.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re


BOUNDARY = ("Logical overlay decisions and CPU paint only; no sensor exposure, "
            "display-present, physical-to-preview, physical-to-skeleton or total "
            "physical latency is measured. C-to-refined video timing is separate.")
_PATTERN = re.compile(r"POSE_BLANK_(SUMMARY|EVENT|CHUNK)\s+(\{.*)")
_KINDS = {"blank_begin", "cause_change", "blank_paint", "recovery", "discard"}


def _integer(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, allow_nan=False)


def _strict_json(encoded):
    def invalid_constant(value):
        raise ValueError("Nonfinite JSON number: " + value)
    return json.loads(encoded, parse_constant=invalid_constant)


def _issue(kind, line=None, token=None, **extra):
    return {"kind": kind, "line": line, "captureToken": token, **extra}


def read_reports(path):
    """Return complete (stage, object) records and explicit transport issues.

    Chunk groups remain until EOF so a later conflicting duplicate invalidates a
    record that had appeared complete. Exact retransmission is idempotent.
    """
    direct, chunks, issues = [], {}, []
    for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        match = _PATTERN.search(line)
        if not match:
            continue
        stage, encoded = match.groups()
        token = None
        try:
            value = _strict_json(encoded)
            if not isinstance(value, dict):
                raise ValueError("Record must be a JSON object")
            token = value.get("captureToken")
            if not isinstance(token, str) or not token or len(token) > 256:
                raise ValueError("Missing or invalid capture token")
            if stage != "CHUNK":
                direct.append((line_number, stage, value))
                continue
            target, record = value.get("stage"), value.get("record")
            part, count, data = value.get("part"), value.get("parts"), value.get("data")
            if (target not in {"SUMMARY", "EVENT"} or not _integer(record) or record < 0
                    or not _integer(part) or not _integer(count) or not 0 <= part < count <= 128
                    or not isinstance(data, str) or len(data) > 4096):
                raise ValueError("Invalid chunk envelope")
            key = (token, target, record)
            group = chunks.setdefault(key, {"line": line_number, "parts": {}, "count": count,
                                            "invalid": False})
            if group["count"] != count:
                group["invalid"] = True
                issues.append(_issue("conflicting_chunk", line_number, token,
                                     stage=target, record=record, detail="Part count changed"))
            elif part in group["parts"] and group["parts"][part] != data:
                group["invalid"] = True
                issues.append(_issue("conflicting_chunk", line_number, token,
                                     stage=target, record=record, detail="Part data changed"))
            else:
                group["parts"][part] = data
        except (json.JSONDecodeError, ValueError, TypeError) as error:
            # A truncated record can still identify its capture without treating
            # the remaining metadata as a valid event.
            guessed = re.search(r'"captureToken"\s*:\s*"([^"\\]+)"', encoded)
            token = token if isinstance(token, str) else guessed[1] if guessed else None
            issues.append(_issue("malformed_json" if stage != "CHUNK" else "invalid_chunk",
                                 line_number, token, detail=str(error)))

    for (token, stage, record), group in chunks.items():
        if group["invalid"]:
            continue
        missing = [i for i in range(group["count"]) if i not in group["parts"]]
        if missing:
            issues.append(_issue("missing_parts", group["line"], token, stage=stage,
                                 record=record, missingParts=missing))
            continue
        try:
            payload = _strict_json("".join(group["parts"][i] for i in range(group["count"])))
            if not isinstance(payload, dict) or payload.get("captureToken") != token:
                raise ValueError("Reassembled record identity differs from envelope")
            direct.append((group["line"], stage, payload))
        except (json.JSONDecodeError, ValueError, TypeError) as error:
            issues.append(_issue("invalid_reassembly", group["line"], token, stage=stage,
                                 record=record, detail=str(error)))

    records, seen = [], set()
    for _, stage, value in sorted(direct, key=lambda item: item[0]):
        signature = (stage, _canonical(value))
        if signature not in seen:
            seen.add(signature)
            records.append((stage, value))
    return records, sorted(issues, key=lambda item: item["line"] or 0)


def _episode_report(events, capture):
    by_episode, discards = {}, Counter()
    cause_counts, initial_counts = Counter(), Counter()
    for event in events:
        kind, reason = event.get("kind"), event.get("reason")
        if kind == "discard":
            discards[str(reason)] += 1
            continue
        if kind in {"blank_begin", "cause_change"}:
            cause_counts[str(reason)] += 1
        if kind == "blank_begin":
            initial_counts[str(reason)] += 1
        episode = event.get("episodeId")
        if _integer(episode) and episode > 0:
            by_episode.setdefault(episode, []).append(event)
    result = []
    for episode_id, observations in sorted(by_episode.items()):
        begin = [e for e in observations if e["kind"] == "blank_begin"]
        paint = [e for e in observations if e["kind"] == "blank_paint"]
        recovered = [e for e in observations if e["kind"] == "recovery"]
        starts = [e["observedMicros"] for e in begin]
        paints = [e["observedMicros"] for e in paint]
        recoveries = [e["observedMicros"] for e in recovered]
        logical_duration = cpu_duration = None
        status = "complete"
        if not capture["transportComplete"]:
            status = "incomplete_transport"
        elif capture["censoredByCapacity"]:
            status = "censored_capacity"
        elif len(begin) != 1 or len(recovered) > 1 or len(paint) > 1:
            status = "incomplete_episode"
        elif not recovered:
            status = ("open_at_capture_end" if capture["summary"].get("openEpisodeAtCaptureEnd")
                      == episode_id else "missing_recovery")
        elif recoveries[0] < starts[0] or (paints and not starts[0] <= paints[0] <= recoveries[0]):
            status = "invalid_timestamp_order"
        elif not paints:
            status = "logical_only_not_cpu_painted"
            logical_duration = recoveries[0] - starts[0]
        else:
            logical_duration = recoveries[0] - starts[0]
            cpu_duration = recoveries[0] - paints[0]
        result.append({"episodeId": episode_id, "status": status,
                       "beginMicros": starts[0] if len(starts) == 1 else None,
                       "firstBlankCpuPaintMicros": paints[0] if len(paints) == 1 else None,
                       "recoveryCpuPaintMicros": recoveries[0] if len(recoveries) == 1 else None,
                       "logicalDurationMicros": logical_duration,
                       "cpuBlankDurationMicros": cpu_duration,
                       "causes": [{"reason": e["reason"], "kind": e["kind"],
                                   "observedMicros": e["observedMicros"]}
                                  for e in observations if e["kind"] in {"blank_begin", "cause_change"}],
                       "events": observations})
    return result, dict(cause_counts), dict(initial_counts), dict(discards)


def summarize(records, issues=()):
    """Group metadata by unique capture token, preserving censored events."""
    captures = {}
    def get(token):
        return captures.setdefault(token, {"captureToken": token, "sessionId": None,
                                          "phase": None, "summary": None,
                                          "events": [], "issues": []})
    for stage, value in records:
        capture = get(value["captureToken"])
        for field in ("sessionId", "phase"):
            if capture[field] is None:
                capture[field] = value.get(field)
            elif value.get(field) != capture[field]:
                capture["issues"].append(_issue("identity_mismatch", token=value["captureToken"],
                                                field=field, value=value.get(field)))
        if stage == "SUMMARY":
            if capture["summary"] is not None and capture["summary"] != value:
                capture["issues"].append(_issue("conflicting_summary", token=value["captureToken"]))
            else:
                capture["summary"] = value
        elif stage == "EVENT":
            if (value.get("kind") not in _KINDS or not _integer(value.get("observedMicros"))
                    or not isinstance(value.get("reason"), str)
                    or (value.get("kind") != "discard" and
                        (not _integer(value.get("episodeId")) or value["episodeId"] <= 0))):
                capture["issues"].append(_issue("invalid_event", token=value["captureToken"],
                                                event=value))
            else:
                capture["events"].append(value)
    for issue in issues:
        if issue.get("captureToken"):
            get(issue["captureToken"])["issues"].append(issue)
    # An unattributable truncated line could belong to any observed capture.
    global_issues = [i for i in issues if not i.get("captureToken")]
    for capture in captures.values():
        capture["issues"].extend(global_issues)
        header = capture["summary"]
        if header is None:
            capture["issues"].append(_issue("missing_summary", token=capture["captureToken"]))
            header = {}
        elif header.get("schemaVersion") != 1:
            capture["issues"].append(_issue("unsupported_schema", token=capture["captureToken"]))
        retained = header.get("retainedEvents")
        if not _integer(retained) or retained != len(capture["events"]):
            capture["issues"].append(_issue("retained_event_count_mismatch",
                                            token=capture["captureToken"], declared=retained,
                                            decoded=len(capture["events"])))
        capture["events"].sort(key=lambda event: event["observedMicros"])
        capture["transportComplete"] = not capture["issues"]
        capture["censoredByCapacity"] = bool(header.get("capacityReached") or
                                             header.get("droppedEvents", 0))
        episodes, causes, initial, discards = _episode_report(capture["events"], capture)
        capture.update({"episodes": episodes, "causeCounts": causes,
                        "initialBlankCauseCounts": initial, "discardCounts": discards,
                        "declaredReasonCounts": header.get("reasonCounts", {}),
                        "completeCpuBlankDurationsMicros": [e["cpuBlankDurationMicros"]
                                                           for e in episodes if e["status"] == "complete"],
                        "boundary": BOUNDARY})
    return captures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("output_path", nargs="?", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    destination = args.output or args.output_path
    if destination is None:
        parser.error("Specify --output PATH or a positional output path")
    if args.output is not None and args.output_path is not None:
        parser.error("Specify the output path only once")
    records, issues = read_reports(args.log)
    captures = summarize(records, issues)
    output = {"source": str(args.log), "transportIssues": issues, "captures": captures,
              "boundary": BOUNDARY}
    destination.write_text(json.dumps(output, indent=2, ensure_ascii=False, allow_nan=False),
                           encoding="utf-8")
    for token, capture in captures.items():
        print(token, capture["phase"], "episodes", len(capture["episodes"]),
              "transportComplete", capture["transportComplete"],
              "capacityCensored", capture["censoredByCapacity"],
              "initialCauses", capture["initialBlankCauseCounts"])
    print("transport issues", len(issues))


if __name__ == "__main__":
    main()
