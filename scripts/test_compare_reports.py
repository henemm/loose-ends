"""Tests für scripts/compare_reports.py (#73)."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
import compare_reports as cr  # noqa: E402

OLD = """# Treue von Datum

## Datum

| Messung | Modell | Regelparser |
|---|---|---|
| Exakt getroffen | 49.6 % von 139 | 99.3 % von 139 |
| Erfundene Daten bei Sätzen ohne Datum | 95.3 % von 172 | 0.0 % von 172 |
| Sekunden | 8.8 | 8.8 |

## Nach Bauform

| Bauform | Sätze | Datum exakt |
|---|---|---|
| Stichwort | 12 | 80.0 % |
"""


def report(**changes):
    text = OLD
    for old, new in changes.items():
        text = text.replace(old.replace("_", " "), new)
    return text


class ParseTests(unittest.TestCase):
    def test_reads_percent_cells_with_section_row_and_column_as_key(self):
        values = cr.parse(OLD)
        self.assertEqual(values["Datum › Exakt getroffen › Modell"], 49.6)
        self.assertEqual(values["Datum › Exakt getroffen › Regelparser"], 99.3)
        self.assertEqual(values["Nach Bauform › Stichwort › Datum exakt"], 80.0)

    def test_cells_without_percent_are_ignored(self):
        values = cr.parse(OLD)
        self.assertFalse(any("Sekunden" in key for key in values))
        self.assertFalse(any(key.endswith("› Sätze") for key in values))

    def test_comma_decimal_and_repeated_rows_are_kept_apart(self):
        text = "## A\n\n| x | v |\n|---|---|\n| z | 12,5 % |\n| z | 20 % |\n"
        values = cr.parse(text)
        self.assertEqual(sorted(values.values()), [12.5, 20.0])
        self.assertEqual(len(values), 2)


class CompareTests(unittest.TestCase):
    def test_difference_is_new_minus_old_in_points(self):
        rows, outliers, only_old, only_new = cr.compare({"a": 80.0}, {"a": 70.0}, 10)
        self.assertEqual(rows, [("a", 80.0, 70.0, -10.0, True)])
        self.assertEqual(outliers, [], "genau 10 Punkte ist noch kein Ausreißer (mehr als 10)")

    def test_more_than_the_threshold_is_an_outlier_in_either_direction(self):
        _, outliers, _, _ = cr.compare({"a": 80.0, "b": 20.0}, {"a": 60.0, "b": 45.0}, 10)
        self.assertEqual([row[0] for row in outliers], ["a", "b"])

    def test_error_metrics_get_worse_when_they_rise(self):
        rows, _, _, _ = cr.compare({"Erfundene Daten": 0.0, "Exakt": 90.0},
                                   {"Erfundene Daten": 30.0, "Exakt": 95.0}, 10)
        worse = {row[0]: row[4] for row in rows}
        self.assertTrue(worse["Erfundene Daten"])
        self.assertFalse(worse["Exakt"])

    def test_keys_missing_on_one_side_are_named_not_compared(self):
        rows, _, only_old, only_new = cr.compare({"a": 1.0, "b": 2.0}, {"a": 1.0, "c": 3.0}, 10)
        self.assertEqual([row[0] for row in rows], ["a"])
        self.assertEqual(only_old, ["b"])
        self.assertEqual(only_new, ["c"])


class CommandTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: __import__("shutil").rmtree(self.dir))

    def write(self, name, text):
        path = self.dir / name
        path.write_text(text, encoding="utf-8")
        return str(path)

    def run_tool(self, *args):
        return subprocess.run([sys.executable, str(SCRIPTS / "compare_reports.py"), *args],
                              capture_output=True, text=True)

    def test_identical_reports_exit_zero(self):
        a = self.write("a.md", OLD)
        result = self.run_tool(a, a)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Ausreißer: 0", result.stdout)

    def test_a_drop_of_more_than_ten_points_exits_one_and_names_the_field(self):
        a = self.write("a.md", OLD)
        b = self.write("b.md", OLD.replace("99.3 % von 139", "79.0 % von 139"))
        result = self.run_tool(a, b)
        self.assertEqual(result.returncode, 1)
        self.assertIn("Exakt getroffen › Regelparser", result.stdout)
        self.assertIn("-20.3", result.stdout)
        self.assertIn("schlechter, Ausreißer", result.stdout)

    def test_threshold_can_be_raised(self):
        a = self.write("a.md", OLD)
        b = self.write("b.md", OLD.replace("99.3 % von 139", "79.0 % von 139"))
        self.assertEqual(self.run_tool(a, b, "--threshold", "25").returncode, 0)

    def test_missing_file_and_empty_report_exit_two(self):
        a = self.write("a.md", OLD)
        self.assertEqual(self.run_tool(a, str(self.dir / "fehlt.md")).returncode, 2)
        empty = self.write("leer.md", "# nichts\n\nkeine Tabelle\n")
        result = self.run_tool(a, empty)
        self.assertEqual(result.returncode, 2)
        self.assertIn("keine Prozentwerte", result.stderr)

    def test_reports_without_a_common_value_exit_two(self):
        a = self.write("a.md", "## A\n\n| x | v |\n|---|---|\n| z | 5 % |\n")
        b = self.write("b.md", "## B\n\n| y | w |\n|---|---|\n| q | 6 % |\n")
        self.assertEqual(self.run_tool(a, b).returncode, 2)

    def test_real_reports_in_the_repository_parse(self):
        reference = SCRIPTS.parent / "docs" / "reference"
        for name in ("date-title-fidelity.md", "retrieval-leave-one-out-rules.md"):
            path = reference / name
            if path.exists():
                self.assertGreater(len(cr.parse(path.read_text(encoding="utf-8"))), 3, name)


if __name__ == "__main__":
    unittest.main()
