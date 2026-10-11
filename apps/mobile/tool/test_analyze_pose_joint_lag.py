"""Regression tests use invented bounded reports, never device trajectories."""
import json
import unittest
from pathlib import Path
from unittest.mock import patch
from analyze_pose_joint_lag import read_reports, summarize


class BoundedReportTest(unittest.TestCase):
    def test_repeated_phase_names_are_separate_captures(self):
        records = []
        for start, count in [(100, 227), (200, 222)]:
            records.extend([("LAG_PHASE", {"phase": "still", "startedMicros": start}),
                            ("LAG_SUMMARY", {"phase": "still", "paintedFrames": count})])
        captures = summarize(records)
        self.assertEqual(len(captures), 2)
        self.assertEqual([v["summary"]["paintedFrames"] for v in captures.values()], [227, 222])

    def test_chunked_record_is_exactly_reassembled(self):
        payload = {"phase": "still", "captureStartedMicros": 100, "joint": "leftElbow",
                   "inputMicros": 101, "filteredImagePixels": [120.0, 360.0]}
        encoded = json.dumps(payload)
        segments = [encoded[:40], encoded[40:]]
        lines = ["POSE_LAG_CHUNK " + json.dumps({"phase": "still", "captureStartedMicros": 100,
                 "record": 7, "stage": "SAMPLE", "part": i, "parts": 2, "data": s})
                 for i, s in enumerate(segments)]
        with patch.object(Path, "read_text", return_value="\n".join(lines)):
            records, malformed = read_reports(Path("bounded.log"))
        self.assertEqual(malformed, [])
        self.assertEqual(records, [("LAG_SAMPLE", payload)])

    def test_missing_chunk_is_flagged_not_used_as_a_sample(self):
        line = ('POSE_LAG_CHUNK {"phase":"still","captureStartedMicros":100,'
                '"record":7,"stage":"SAMPLE","part":0,"parts":2,"data":"{"}')
        with patch.object(Path, "read_text", return_value=line):
            records, malformed = read_reports(Path("bounded.log"))
        self.assertEqual(records, [])
        self.assertEqual(malformed, [1])


if __name__ == "__main__":
    unittest.main()
