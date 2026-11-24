"""#995: a pull request runs the app jobs only when it changes something they test."""
import unittest
from pathlib import Path

import yaml

from ci_changes import CI, needs_app

TEXT = CI.read_text()
APP_JOBS = ("ios-build", "ui-smoke-plan", "ui-smoke-lang", "ui-ipad", "mac-gallery")
GATE = "needs.changes.outputs.app == 'true'"


class PathRule(unittest.TestCase):
    def test_scripts_and_docs_only_spare_the_app(self):
        self.assertFalse(needs_app(["scripts/asc_store_version.py", "scripts/test_asc_store_version.py",
                                    "docs/reference/testflight.md", "CLAUDE.md"], TEXT))

    def test_server_claude_and_workflows_spare_the_app(self):
        self.assertFalse(needs_app(["server/src/main.ts", ".claude/x.json", ".github/workflows/ci.yml"], TEXT))

    def test_app_code_needs_the_app(self):
        for path in ("LooseEnds/Views/StartPage.swift", "Shared/Models/TaskItem.swift", "project.yml",
                     "LooseEndsUITests/CaptureSmokeTests.swift", "cloudkit/schema.ckdb"):
            with self.subTest(path=path):
                self.assertTrue(needs_app(["docs/a.md", path], TEXT))

    def test_scripts_ci_runs_need_the_app(self):
        for path in ("scripts/ui_smoke_shards.py", "scripts/sim_prepare.sh", "scripts/mac_ci_entitlements.py",
                     "scripts/sim.sh"):
            with self.subTest(path=path):
                self.assertTrue(needs_app([path], TEXT))

    def test_the_decision_script_itself_spares_the_app(self):
        self.assertFalse(needs_app(["scripts/ci_changes.py", "scripts/test_ci_changes.py"], TEXT))

    def test_empty_list_runs_everything(self):
        self.assertTrue(needs_app([], TEXT))
        self.assertTrue(needs_app(["", "  "], TEXT))

    def test_nested_markdown_is_not_spared(self):
        self.assertTrue(needs_app(["LooseEnds/README.md"], TEXT))


class Workflow(unittest.TestCase):
    def setUp(self):
        self.jobs = yaml.safe_load(TEXT)["jobs"]

    def test_changes_job_decides_from_the_merge_diff(self):
        job = self.jobs["changes"]
        self.assertEqual(job["outputs"]["app"], "${{ steps.decide.outputs.app }}")
        run = next(s["run"] for s in job["steps"] if s.get("id") == "decide")
        self.assertIn("pull_request", run)
        self.assertIn("scripts/ci_changes.py", run)

    def test_app_jobs_wait_for_the_decision(self):
        for name in APP_JOBS:
            with self.subTest(job=name):
                job = self.jobs[name]
                needs = job["needs"] if isinstance(job["needs"], list) else [job["needs"]]
                self.assertIn("changes", needs)
                self.assertIn(GATE, job["if"])

    def test_unit_tests_always_run_the_script_tests(self):
        steps = self.jobs["unit-tests"]["steps"]
        names = [s.get("name") for s in steps]
        script = names.index("Script tests")
        self.assertNotIn("if", steps[script])
        for step in steps[script + 1:]:
            with self.subTest(step=step.get("name")):
                self.assertIn(GATE, step["if"])

    def test_smoke_summary_passes_when_spared(self):
        job = self.jobs["ui-smoke"]
        self.assertIn("changes", job["needs"])
        run = next(s["run"] for s in job["steps"] if s.get("name") == "All parts green")
        self.assertIn("APP", run)


if __name__ == "__main__":
    unittest.main()
