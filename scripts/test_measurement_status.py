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
        self.assertIn("6 von 6 übersprungen", text)
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
        self.put(self.worktree, "textform-run.json")
        self.put(self.worktree, "loose-ends-rawtexts.json")
        self.assertEqual(ms.render(ms.status(self.worktree), markdown=False), "[sim] Messstrecken: alle 6 liefen mit Daten.")

    def test_markdown_puts_the_count_in_bold(self):
        text = ms.render(ms.status(self.worktree), markdown=True)
        self.assertIn("**6 von 6 Messstrecken übersprungen**", text)
        self.assertIn("| `RuleLeaveOneOutReportTests` | übersprungen, fehlt: focusblox-corpus.json |", text)


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
        files = {"focusBloxCorpus": "focusblox-corpus.json", "selfConsistencyRun": "selfconsistency-run.json",
                 "textFormRun": "textform-run.json", "rawSentences": "loose-ends-rawtexts.json"}
        swift = {files[key]: sorted(value) for key, value in self.gated_suites_in_swift().items()}
        self.assertEqual(swift, {name: sorted(suites) for name, suites in ms.GATES.items()})

    def test_rawtexts_file_is_gitignored(self):
        lines = (ms.ROOT / ".gitignore").read_text().splitlines()
        self.assertIn("docs/reference/loose-ends-rawtexts.json", lines)

    def test_no_suite_gates_on_a_corpus_path_of_its_own(self):
        for path in TESTS.glob("*.swift"):
            if path.name == "MeasurementData.swift":
                continue
            self.assertNotIn('repoFile("docs/reference/focusblox-corpus.json")', path.read_text(), path.name)


class NoModelInUnitRunTests(unittest.TestCase):
    """Der Unit-Lauf ruft das On-Device-Modell nie (#395): im Simulator misst es ein anderes Modell als das Gerät.
    Erlaubt ist ein Aufruf nur hinter dem Schalter von `./scripts/sim.sh real-model` (#531)."""

    def test_no_unit_suite_calls_the_model(self):
        call = re.compile(r"FoundationModelsEnricher\s*\(")
        switch = ".enabled(if: RealModel.isRequested"
        callers = sorted(
            str(p.relative_to(ms.ROOT))
            for folder in (TESTS, ms.ROOT / "Measurement")
            for p in folder.rglob("*.swift")
            if call.search(text := p.read_text()) and switch not in text
        )
        self.assertEqual(callers, [])


FIRST = "The first word arrives within 3 s of speech start"
FINAL = "The final text keeps the key words"
# Auszug aus unit-tests.log, CI-Lauf 39167072947 (main, 20b9553), Z. 5246-5253 (#419)
CANCELLED_LOG = f"""◇ Suite "Speech latency (#274)" started.
◇ Test "The app's transcriber asks for fast results" started.
✔ Test "The app's transcriber asks for fast results" passed after 0.001 seconds.
◇ Test "{FIRST}" started.
➜ Test "{FIRST}" was cancelled after 0.003 seconds: "Sprache de_DE wird hier nicht unterstützt"
◇ Test "{FINAL}" started.
➜ Test "{FINAL}" was cancelled after 0.002 seconds: "Sprache de_DE wird hier nicht unterstützt"
✔ Suite "Speech latency (#274)" passed after 0.007 seconds.
"""


class LatencyGuardTests(unittest.TestCase):
    """Der Latenzschutz aus #274 sagt laut, wenn er nicht misst (#419)."""

    def states(self, log):
        return {name: (state, why) for name, state, why in ms.latency_status(log)}

    def test_cancelled_tests_are_named_one_by_one_with_the_reason(self):
        rows = self.states(CANCELLED_LOG)
        self.assertEqual(set(rows), {FIRST, FINAL})
        for state, why in rows.values():
            self.assertEqual(state, "not_measured")
            self.assertIn("Sprache de_DE wird hier nicht unterstützt", why)

    def test_passed_and_failed_are_told_apart_per_test(self):
        log = (f'✔ Test "{FIRST}" passed after 10.2 seconds.\n'
               f'✘ Test "{FINAL}" failed after 10.1 seconds with 1 issue.\n')
        rows = self.states(log)
        self.assertEqual(rows[FIRST][0], "measured")
        self.assertEqual(rows[FINAL][0], "failed")

    def test_a_test_missing_from_the_log_is_not_silent(self):
        rows = self.states(f'✔ Test "{FIRST}" passed after 10.2 seconds.\n')
        self.assertEqual(rows[FIRST][0], "measured")
        self.assertEqual(rows[FINAL], ("not_measured", "nicht im Log"))

    def test_text_names_each_test_as_not_measured(self):
        text = ms.render_latency(ms.latency_status(CANCELLED_LOG), markdown=False)
        self.assertIn("Latenzschutz (#274)", text)
        self.assertIn(f"{FIRST} – NICHT gemessen: Sprache de_DE wird hier nicht unterstützt", text)
        self.assertIn(f"{FINAL} – NICHT gemessen", text)

    def test_markdown_table_and_warning(self):
        rows = ms.latency_status(CANCELLED_LOG)
        text = ms.render_latency(rows, markdown=True)
        self.assertIn("### Latenzschutz (#274)", text)
        self.assertIn(f"| {FIRST} | NICHT gemessen: Sprache de_DE wird hier nicht unterstützt |", text)
        self.assertIn("::warning::Latenzschutz #274 nicht gemessen", ms.latency_warning(rows))

    def test_no_warning_when_both_were_measured(self):
        log = (f'✔ Test "{FIRST}" passed after 10.2 seconds.\n'
               f'✔ Test "{FINAL}" passed after 10.1 seconds.\n')
        self.assertEqual(ms.latency_warning(ms.latency_status(log)), "")

    def test_main_reads_the_log_file(self):
        path = pathlib.Path(tempfile.mkdtemp()) / "unit-tests.log"
        path.write_text(CANCELLED_LOG)
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(ms.main(["--latency-log", str(path)]), 0)
        self.assertIn("NICHT gemessen", out.getvalue())

    def test_missing_log_file_is_said_aloud(self):
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            ms.main(["--latency-log", "/nonexistent/unit-tests.log"])
        self.assertIn("Latenzschutz", out.getvalue())
        self.assertIn("kein Log", out.getvalue())

    def test_cancel_message_carries_the_diagnosis(self):
        source = (TESTS / "SpeechLatencyTests.swift").read_text()
        for key in ("isAvailable", "supportedLocales.count", "installedLocales.count"):
            self.assertIn(key, source)

    def test_ci_and_sim_pass_the_log(self):
        ci = (ms.ROOT / ".github" / "workflows" / "ci.yml").read_text()
        self.assertIn("--latency-log unit-tests.log", ci)
        sim = (ms.ROOT / "scripts" / "sim.sh").read_text()
        self.assertIn("--latency-log", sim)


if __name__ == "__main__":
    unittest.main()
