"""Invented metadata-only captures; no camera or landmark trajectory fixtures."""
import json
import unittest
from pathlib import Path
from unittest.mock import patch

from analyze_pose_blanks import main, read_reports, summarize


def summary(token="s:100:1", **extra):
    return {"schemaVersion": 1, "captureToken": token, "sessionId": "s",
            "phase": "slow", "retainedEvents": 4, "capacityReached": False,
            "droppedEvents": 0, "openEpisodeAtCaptureEnd": None, **extra}


def event(kind, time, reason="freshness_expiry", token="s:100:1", **extra):
    return {"captureToken": token, "sessionId": "s", "phase": "slow",
            "episodeId": 1, "kind": kind, "reason": reason,
            "observedMicros": time, **extra}


def lines(records):
    return "\n".join("I/flutter: POSE_BLANK_" + stage + " " + json.dumps(value)
                     for stage, value in records)


def read(text):
    with patch.object(Path, "read_text", return_value=text):
        return read_reports(Path("invented.log"))


class BlankReportTests(unittest.TestCase):
    def test_complete_episode_has_cpu_paint_duration_not_logical_duration(self):
        records = [("SUMMARY", summary()),
                   ("EVENT", event("blank_begin", 1000)),
                   ("EVENT", event("cause_change", 1100, "low_landmark_pose_presence")),
                   ("EVENT", event("blank_paint", 1200, "low_landmark_pose_presence")),
                   ("EVENT", event("recovery", 2000, "low_landmark_pose_presence",
                                   blankDurationMicros=1000))]
        parsed, issues = read(lines(records))
        capture = summarize(parsed, issues)["s:100:1"]
        self.assertEqual(issues, [])
        self.assertEqual(capture["episodes"][0]["cpuBlankDurationMicros"], 800)
        self.assertEqual(capture["episodes"][0]["logicalDurationMicros"], 1000)
        self.assertEqual(capture["causeCounts"], {"freshness_expiry": 1,
                                                "low_landmark_pose_presence": 1})

    def test_repeated_phases_and_sessions_group_by_capture_token(self):
        parsed, issues = read(lines([
            ("SUMMARY", summary("s:100:1", retainedEvents=0)),
            ("SUMMARY", summary("s:100:2", retainedEvents=0)),
            ("SUMMARY", summary("other:100:1", sessionId="other", retainedEvents=0))]))
        self.assertEqual(len(summarize(parsed, issues)), 3)

    def test_exact_duplicate_chunks_are_idempotent_and_reassemble_unicode(self):
        payload = event("blank_begin", 1000, roiSource="tracked_roi", outcome="微")
        encoded = json.dumps(payload, ensure_ascii=False)
        split = len(encoded) // 2
        chunks = [("CHUNK", {"captureToken": "s:100:1", "stage": "EVENT", "record": 1,
                             "part": i, "parts": 2, "data": part})
                  for i, part in enumerate([encoded[:split], encoded[split:]])]
        parsed, issues = read(lines(chunks + chunks))
        self.assertEqual(parsed, [("EVENT", payload)])
        self.assertEqual(issues, [])

    def test_chunked_summary_and_direct_retransmission_are_idempotent(self):
        header = summary(retainedEvents=0)
        chunk = {"captureToken": "s:100:1", "stage": "SUMMARY", "record": 0,
                 "part": 0, "parts": 1, "data": json.dumps(header)}
        parsed, issues = read(lines([("SUMMARY", header), ("CHUNK", chunk)]))
        self.assertEqual(parsed, [("SUMMARY", header)])
        self.assertTrue(summarize(parsed, issues)["s:100:1"]["transportComplete"])

    def test_conflicting_chunk_invalidates_even_previously_complete_record(self):
        payload = json.dumps(event("blank_begin", 1000))
        chunk = {"captureToken": "s:100:1", "stage": "EVENT", "record": 1,
                 "part": 0, "parts": 1, "data": payload}
        parsed, issues = read(lines([("CHUNK", chunk),
                                    ("CHUNK", {**chunk, "data": payload + " "})]))
        self.assertEqual(parsed, [])
        self.assertEqual(issues[0]["kind"], "conflicting_chunk")

    def test_missing_chunk_is_incomplete_and_never_used_for_normal_duration(self):
        chunk = {"captureToken": "s:100:1", "stage": "EVENT", "record": 2,
                 "part": 0, "parts": 2, "data": "{"}
        parsed, issues = read(lines([
            ("SUMMARY", summary(retainedEvents=3)),
            ("EVENT", event("blank_begin", 1000)),
            ("EVENT", event("blank_paint", 1200)),
            ("EVENT", event("recovery", 2000)), ("CHUNK", chunk)]))
        capture = summarize(parsed, issues)["s:100:1"]
        self.assertFalse(capture["transportComplete"])
        self.assertEqual(capture["episodes"][0]["status"], "incomplete_transport")
        self.assertIsNone(capture["episodes"][0]["cpuBlankDurationMicros"])

    def test_capacity_reached_censors_episode_even_with_retained_recovery(self):
        parsed, issues = read(lines([
            ("SUMMARY", summary(retainedEvents=3, capacityReached=True, droppedEvents=5)),
            ("EVENT", event("blank_begin", 1000)),
            ("EVENT", event("blank_paint", 1200)),
            ("EVENT", event("recovery", 2000))]))
        capture = summarize(parsed, issues)["s:100:1"]
        self.assertTrue(capture["censoredByCapacity"])
        self.assertEqual(capture["episodes"][0]["status"], "censored_capacity")
        self.assertIsNone(capture["episodes"][0]["cpuBlankDurationMicros"])

    def test_open_and_never_painted_blank_are_not_cpu_duration_samples(self):
        parsed, issues = read(lines([
            ("SUMMARY", summary(retainedEvents=1, openEpisodeAtCaptureEnd=1)),
            ("EVENT", event("blank_begin", 1000))]))
        episode = summarize(parsed, issues)["s:100:1"]["episodes"][0]
        self.assertEqual(episode["status"], "open_at_capture_end")
        self.assertIsNone(episode["cpuBlankDurationMicros"])

    def test_logical_only_recovery_is_separate_from_cpu_blank_duration(self):
        parsed, issues = read(lines([
            ("SUMMARY", summary(retainedEvents=2)),
            ("EVENT", event("blank_begin", 1000)),
            ("EVENT", event("recovery", 2000))]))
        episode = summarize(parsed, issues)["s:100:1"]["episodes"][0]
        self.assertEqual(episode["status"], "logical_only_not_cpu_painted")
        self.assertEqual(episode["logicalDurationMicros"], 1000)
        self.assertIsNone(episode["cpuBlankDurationMicros"])

    def test_discard_is_noncausal_and_not_a_new_blank(self):
        parsed, issues = read(lines([
            ("SUMMARY", summary(retainedEvents=1)),
            ("EVENT", event("discard", 1000, "stale_result", episodeId=None,
                            causalOverlayClear=False))]))
        capture = summarize(parsed, issues)["s:100:1"]
        self.assertEqual(capture["episodes"], [])
        self.assertEqual(capture["causeCounts"], {})
        self.assertEqual(capture["discardCounts"], {"stale_result": 1})

    def test_truncated_json_and_identity_mismatch_are_explicit(self):
        parsed, issues = read(lines([
            ("SUMMARY", summary(retainedEvents=1)),
            ("EVENT", event("blank_begin", 1000, sessionId="wrong"))]) +
            '\nPOSE_BLANK_EVENT {"captureToken":"s:100:1",')
        capture = summarize(parsed, issues)["s:100:1"]
        self.assertFalse(capture["transportComplete"])
        self.assertTrue(any(i["kind"] == "malformed_json" for i in issues))
        self.assertTrue(any(i["kind"] == "identity_mismatch" for i in capture["issues"]))

    def test_cli_supports_named_and_positional_output(self):
        for extra in ([], ["--output"]):
            with patch("sys.argv", ["analyze_pose_blanks.py", "bounded.log", *extra, "output.json"]), \
                    patch.object(Path, "read_text", return_value=lines([
                        ("SUMMARY", summary(retainedEvents=0))])), \
                    patch.object(Path, "write_text") as written, patch("builtins.print"):
                main()
            report = json.loads(written.call_args.args[0])
            self.assertIn("s:100:1", report["captures"])
            self.assertIn("no sensor exposure", report["boundary"])

    def test_unattributable_malformed_record_conservatively_censors_capture(self):
        parsed, issues = read(lines([("SUMMARY", summary(retainedEvents=0))]) +
                              "\nPOSE_BLANK_EVENT {truncated")
        capture = summarize(parsed, issues)["s:100:1"]
        self.assertFalse(capture["transportComplete"])

    def test_nonfinite_json_cannot_poison_output(self):
        parsed, issues = read('POSE_BLANK_EVENT {"captureToken":"s:100:1","x":NaN}')
        self.assertEqual(parsed, [])
        self.assertEqual(issues[0]["kind"], "malformed_json")


if __name__ == "__main__":
    unittest.main()
