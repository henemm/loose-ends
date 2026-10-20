"""Tests für real_model_result.py (#531): der eine Satz am Ende von `sim.sh real-model`.

Aufruf: python3 -m unittest scripts/test_real_model_result.py
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import real_model_result as rmr  # noqa: E402


def case(name, result, children=None):
    return {"name": name, "nodeType": "Test Case", "result": result, "children": children or []}


def tree(cases, suite="RealModelTests"):
    return {"testNodes": [{"name": "LooseEnds", "nodeType": "Test Plan", "children": [
        {"name": "LooseEndsTests", "nodeType": "Unit test bundle", "children": [
            {"name": suite, "nodeType": "Test Suite", "children": cases}]}]}]}


class VerdictTests(unittest.TestCase):
    def test_passed(self):
        code, lines, sentence = rmr.verdict({"totalTestCount": 3}, tree([
            case("Apple Intelligence is available on this Mac", "Passed"),
            case("Every note gets an answer in time", "Passed"),
            case("Most titles keep a word of their note", "Passed")]))
        self.assertEqual(code, rmr.PASSED)
        self.assertIn("BESTANDEN", sentence)
        self.assertEqual(len(lines), 3)

    def test_failed_names_the_reason(self):
        failure = {"name": "Expectation failed: Apple Intelligence is not available: appleIntelligenceNotEnabled",
                   "nodeType": "Failure Message"}
        code, lines, sentence = rmr.verdict({"totalTestCount": 3}, tree([
            case("Apple Intelligence is available on this Mac", "Failed", [failure]),
            case("Every note gets an answer in time", "Skipped"),
            case("Most titles keep a word of their note", "Skipped")]))
        self.assertEqual(code, rmr.FAILED)
        self.assertIn("FEHLGESCHLAGEN", sentence)
        self.assertIn("appleIntelligenceNotEnabled", sentence)
        self.assertTrue(any("appleIntelligenceNotEnabled" in line for line in lines))

    def test_skipped_with_reason(self):
        skip = {"name": "LOOSEENDS_REAL_MODEL=1 is not set (./scripts/sim.sh real-model)", "nodeType": "Skip"}
        code, _, sentence = rmr.verdict({"totalTestCount": 3}, tree([
            case("Apple Intelligence is available on this Mac", "Skipped", [skip])]))
        self.assertEqual(code, rmr.SKIPPED)
        self.assertIn("ÜBERSPRUNGEN", sentence)
        self.assertIn("LOOSEENDS_REAL_MODEL", sentence)

    def test_no_tests_at_all_means_the_variable_did_not_arrive(self):
        code, _, sentence = rmr.verdict({"totalTestCount": 0}, tree([]))
        self.assertEqual(code, rmr.SKIPPED)
        self.assertIn("LOOSEENDS_REAL_MODEL", sentence)

    def test_other_suite_only_is_unknown(self):
        code, _, sentence = rmr.verdict({"totalTestCount": 1}, tree([case("x", "Passed")], suite="OtherTests"))
        self.assertEqual(code, rmr.UNKNOWN)
        self.assertIn("abgebrochen", sentence)

    def test_empty_inputs_are_unknown(self):
        code, _, _ = rmr.verdict({}, {})
        self.assertEqual(code, rmr.UNKNOWN)

    def test_main_without_bundle_is_unknown(self):
        self.assertEqual(rmr.main(["x", "/nonexistent/Test.xcresult"]), rmr.UNKNOWN)
        self.assertEqual(rmr.main(["x"]), rmr.UNKNOWN)


if __name__ == "__main__":
    unittest.main()
