"""Tests für measurement_status.py (#135, #149)."""
import pathlib
import re
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import measurement_status as ms  # noqa: E402

TESTS = ms.ROOT / "LooseEndsTests"


class MainCheckoutTests(unittest.TestCase):
    def test_worktree_belongs_to_the_folder_above(self):
        worktree = pathlib.Path("/Users/hem/Developer/loose-ends/.claude/worktrees/wiggly-munching-kay")
        self.assertEqual(ms.main_checkout(worktree), pathlib.Path("/Users/hem/Developer/loose-ends"))

    def test_main_checkout_and_bare_worktrees_folder_have_none(self):
        self.assertIsNone(ms.main_checkout(pathlib.Path("/Users/hem/Developer/loose-ends")))
        self.assertIsNone(ms.main_checkout(pathlib.Path("/Users/hem/.claude/worktrees")))


class StatusTests(unittest.TestCase):
    def setUp(self):
        self.root = pathlib.Path(tempfile.mkdtemp())
        self.worktree = self.root / ".claude" / "worktrees" / "frisch"
        self.worktree.mkdir(parents=True)

    def put(self, folder: pathlib.Path, name: str):
        (folder / "docs" / "reference").mkdir(parents=True, exist_ok=True)
        (folder / "docs" / "reference" / name).write_text("[]")

    def test_without_data_every_suite_is_named_as_skipped(self):
        text = ms.render(ms.status(self.worktree), markdown=False)
        self.assertIn("5 von 5 übersprungen", text)
        self.assertIn("RecognitionRuleCorpusTests – fehlt: focusblox-corpus.json", text)
        self.assertIn("SelfConsistencyReportTests – fehlt: focusblox-corpus.json, selfconsistency-run.json", text)

    def test_fresh_worktree_finds_the_corpus_of_the_main_checkout(self):
        self.put(self.root, "focusblox-corpus.json")
        rows = dict((suite, ran) for suite, ran, _ in ms.status(self.worktree))
        self.assertTrue(rows["RuleLeaveOneOutReportTests"])
        self.assertFalse(rows["SelfConsistencyReportTests"], "the device run file is still missing")

    def test_everything_present_says_so(self):
        self.put(self.worktree, "focusblox-corpus.json")
        self.put(self.worktree, "selfconsistency-run.json")
        self.assertEqual(ms.render(ms.status(self.worktree), markdown=False), "[sim] Messstrecken: alle 5 liefen mit Daten.")

    def test_markdown_puts_the_count_in_bold(self):
        text = ms.render(ms.status(self.worktree), markdown=True)
        self.assertIn("**5 von 5 Messstrecken übersprungen**", text)
        self.assertIn("| `FocusBloxCalibrationTests` | übersprungen, fehlt: focusblox-corpus.json |", text)


class RegistryMatchesSwiftTests(unittest.TestCase):
    """Die Liste im Skript ist die im Swift-Code (#149: eine Spec nannte vier Suiten, es waren drei)."""

    def gated_suites_in_swift(self):
        found = {}
        for path in TESTS.glob("*.swift"):
            text = path.read_text()
            for match in re.finditer(r"@Suite\((.*?)\)\s*\n\s*struct (\w+)", text, re.S):
                gates, suite = match.group(1), match.group(2)
                for variable in re.findall(r"MeasurementData\.exists\((\w+)\)", gates):
                    source = re.search(rf"private let {variable} = MeasurementData\.(\w+)", text)
                    self.assertIsNotNone(source, f"{path.name}: {variable} kommt nicht aus MeasurementData")
                    found.setdefault(source.group(1), set()).add(suite)
        return found

    def test_every_gate_is_listed_and_nothing_else(self):
        files = {"focusBloxCorpus": "focusblox-corpus.json", "selfConsistencyRun": "selfconsistency-run.json"}
        swift = {files[key]: sorted(value) for key, value in self.gated_suites_in_swift().items()}
        self.assertEqual(swift, {name: sorted(suites) for name, suites in ms.GATES.items()})

    def test_no_suite_gates_on_a_corpus_path_of_its_own(self):
        for path in TESTS.glob("*.swift"):
            if path.name == "MeasurementData.swift":
                continue
            self.assertNotIn('repoFile("docs/reference/focusblox-corpus.json")', path.read_text(), path.name)


if __name__ == "__main__":
    unittest.main()
