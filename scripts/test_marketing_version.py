"""Tests für die eine Quelle der Versionsnummer (#767).

Aufruf: python3 scripts/test_marketing_version.py
Liest die echten Dateien; der Auslese-Befehl kommt aus testflight.yml, damit genau das geprüft wird, was läuft.
"""
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project.yml"
WORKFLOW = ROOT / ".github" / "workflows" / "testflight.yml"
ERROR = "::error::MARKETING_VERSION not found in project.yml"


def read_lines():
    """Die Auslesezeilen der Archivprüfungen, ohne Einrückung."""
    return [line.strip() for line in WORKFLOW.read_text().splitlines() if line.strip().startswith("MARKETING=$(sed")]


def read_block():
    """Auslesezeile plus die Abbruchzeile danach, wie sie im ersten Prüf-Schritt stehen."""
    lines = [line.strip() for line in WORKFLOW.read_text().splitlines()]
    for index, line in enumerate(lines):
        if line.startswith("MARKETING=$(sed"):
            return line + "\n" + lines[index + 1] + "\n"
    return None


def run_in(folder, script):
    return subprocess.run(["bash", "-c", script], cwd=folder, capture_output=True, text=True)


class MarketingVersionTests(unittest.TestCase):
    def test_marketing_version_is_1_0(self):
        values = re.findall(r'^ *MARKETING_VERSION: *(.*)$', PROJECT.read_text(), re.MULTILINE)
        self.assertEqual(len(values), 1, f"genau eine MARKETING_VERSION-Zeile erwartet, gefunden: {values}")
        self.assertEqual(values[0].strip(), '"1.0"')

    def test_no_version_literal_in_workflow(self):
        literals = re.findall(r'MARKETING="[0-9][^"]*"', WORKFLOW.read_text())
        self.assertEqual(literals, [], "testflight.yml trägt die Version noch fest eingetragen")

    def test_workflow_reads_version_from_project_yml(self):
        lines = read_lines()
        self.assertEqual(len(lines), 2, "beide Archivprüfungen (iOS, macOS) müssen die Version aus project.yml lesen")
        self.assertEqual(lines[0], lines[1], "beide Archivprüfungen lesen auf dieselbe Weise")
        echo = lines[0] + '\nprintf %s "$MARKETING"\n'
        real = run_in(ROOT, echo)
        self.assertEqual(real.returncode, 0, real.stderr)
        self.assertEqual(real.stdout, "1.0")
        with tempfile.TemporaryDirectory() as folder:
            text = re.sub(r'(MARKETING_VERSION: *)"[^"]*"', r'\1"2.3.4"', PROJECT.read_text())
            (Path(folder) / "project.yml").write_text(text)
            other = run_in(folder, echo)
            self.assertEqual(other.returncode, 0, other.stderr)
            self.assertEqual(other.stdout, "2.3.4")

    def test_empty_version_aborts(self):
        block = read_block()
        self.assertIsNotNone(block, "keine Auslesezeile in testflight.yml")
        self.assertIn(ERROR, block, "nach der Auslesezeile fehlt der Abbruch bei leerem Wert")
        with tempfile.TemporaryDirectory() as folder:
            text = "".join(line for line in PROJECT.read_text().splitlines(True) if "MARKETING_VERSION:" not in line)
            (Path(folder) / "project.yml").write_text(text)
            result = run_in(folder, block + "echo weiter\n")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(ERROR, result.stdout + result.stderr)
            self.assertNotIn("weiter", result.stdout)


if __name__ == "__main__":
    unittest.main()
