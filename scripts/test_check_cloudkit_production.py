"""#268: the TestFlight run stops when Production lacks a type or field of cloudkit/schema.ckdb.

The comparison lives in scripts/check_cloudkit_production.py; .github/workflows/testflight.yml only calls it.
These tests pin the comparison (names only, Abbild ⊆ Production), the three outcomes (0 / 1 / 2) and the
wiring of the workflow (upload waits for the check, nothing can skip it).
"""

import contextlib
import io
import pathlib
import re
import tempfile
import unittest

import check_cloudkit_production as check

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "testflight.yml"

SOLL = """DEFINE SCHEMA

    RECORD TYPE CD_TaskItem (
        CD_rawText      STRING QUERYABLE SEARCHABLE SORTABLE,
        CD_notes        STRING QUERYABLE SEARCHABLE SORTABLE,
        "___createTime" TIMESTAMP,
        "___recordID"   REFERENCE,
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world"
    );

    RECORD TYPE CD_Revision (
        CD_reason       STRING QUERYABLE SEARCHABLE SORTABLE,
        "___createTime" TIMESTAMP,
        GRANT READ TO "_world"
    );
"""


def production(extra_fields="", without_notes=False, without_revision=False, notes_line=None):
    notes = "" if without_notes else (notes_line or "        CD_notes        STRING QUERYABLE SEARCHABLE SORTABLE,\n")
    text = (
        "DEFINE SCHEMA\n\n    RECORD TYPE CD_TaskItem (\n"
        "        CD_rawText      STRING QUERYABLE SEARCHABLE SORTABLE,\n"
        f"{notes}{extra_fields}"
        '        "___createTime" TIMESTAMP,\n        GRANT READ TO "_world"\n    );\n'
    )
    if not without_revision:
        text += (
            "\n    RECORD TYPE CD_Revision (\n"
            "        CD_reason       STRING QUERYABLE SEARCHABLE SORTABLE,\n"
            '        "___createTime" TIMESTAMP,\n        GRANT READ TO "_world"\n    );\n'
        )
    return text


def run(soll_text, ist_text):
    """(exit code, everything the script printed) for the two texts written to files."""
    with tempfile.TemporaryDirectory() as folder:
        soll, ist = pathlib.Path(folder, "soll.ckdb"), pathlib.Path(folder, "ist.ckdb")
        if soll_text is not None:
            soll.write_text(soll_text, encoding="utf-8")
        if ist_text is not None:
            ist.write_text(ist_text, encoding="utf-8")
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = check.main([str(soll), str(ist)])
        return code, out.getvalue() + err.getvalue()


class ComparisonTests(unittest.TestCase):
    def test_equal_schemas_pass(self):
        code, _ = run(SOLL, production())
        self.assertEqual(code, 0)

    def test_extra_fields_and_types_in_production_pass(self):
        extra = "        CD_deadField    STRING QUERYABLE SEARCHABLE SORTABLE,\n"
        text = production(extra_fields=extra) + "\n    RECORD TYPE CD_Legacy (\n        CD_x STRING,\n        GRANT READ TO \"_world\"\n    );\n"
        code, _ = run(SOLL, text)
        self.assertEqual(code, 0)

    def test_missing_field_is_reported(self):
        code, output = run(SOLL, production(without_notes=True))
        self.assertEqual(code, 1)
        self.assertIn("CD_TaskItem.CD_notes", output)

    def test_missing_record_type_is_reported(self):
        code, output = run(SOLL, production(without_revision=True))
        self.assertEqual(code, 1)
        self.assertIn("record type CD_Revision", output)

    def test_flags_types_grants_and_system_fields_are_ignored(self):
        other = "        CD_notes        BYTES,\n"
        code, _ = run(SOLL, production(notes_line=other))
        self.assertEqual(code, 0, "same field with another type or other flags is not a finding")
        self.assertEqual(check.parse(SOLL)["CD_TaskItem"], {"CD_rawText", "CD_notes"})

    def test_message_points_to_documentation(self):
        _, output = run(SOLL, production(without_notes=True))
        self.assertIn("docs/reference/testflight.md", output)


class ParserGapTests(unittest.TestCase):
    """Adversary findings F001, F004, F005 on the parser."""

    def test_comment_line_is_ignored(self):
        soll = SOLL.replace("        CD_notes ", "        // a comment\n        CD_notes ", 1)
        fields = check.parse(soll)["CD_TaskItem"]
        self.assertFalse([f for f in fields if f.startswith("//")], fields)
        code, output = run(soll, production())
        self.assertEqual(code, 0, output)

    def test_two_fields_on_one_line_are_both_checked(self):
        soll = SOLL.replace(
            "        CD_rawText      STRING QUERYABLE SEARCHABLE SORTABLE,\n"
            "        CD_notes        STRING QUERYABLE SEARCHABLE SORTABLE,\n",
            "        CD_rawText STRING, CD_notes STRING,\n", 1)
        self.assertEqual(check.parse(soll)["CD_TaskItem"], {"CD_rawText", "CD_notes"})
        code, output = run(soll, production(without_notes=True))
        self.assertEqual(code, 1, output)
        self.assertIn("CD_TaskItem.CD_notes", output)

    def test_duplicate_type_block_in_abbild_is_united(self):
        soll = SOLL + "\n    RECORD TYPE CD_TaskItem (\n        CD_extra STRING,\n    );\n"
        extra = "        CD_extra        STRING,\n"
        code, output = run(soll, production(without_notes=True, extra_fields=extra))
        self.assertEqual(code, 1, output)
        self.assertIn("CD_TaskItem.CD_notes", output)
        code, output = run(soll, production())
        self.assertEqual(code, 1, output)
        self.assertIn("CD_TaskItem.CD_extra", output)

    def test_duplicate_type_block_in_production_is_united(self):
        ist = production() + "\n    RECORD TYPE CD_TaskItem (\n        CD_rawText STRING,\n    );\n"
        code, output = run(SOLL, ist)
        self.assertEqual(code, 0, output)


class UnreadableInputTests(unittest.TestCase):
    def test_unreadable_input_is_exit_2(self):
        cases = {
            "production file missing": (SOLL, None),
            "production file empty": (SOLL, ""),
            "production without record types": (SOLL, "DEFINE SCHEMA\n"),
            "abbild missing": (None, production()),
            "abbild empty": ("", production()),
        }
        for name, (soll, ist) in cases.items():
            with self.subTest(name):
                code, output = run(soll, ist)
                self.assertEqual(code, 2, output)
                self.assertNotIn("CD_TaskItem.CD_notes", output)

    def test_unreadable_message_differs_from_missing_field(self):
        _, missing = run(SOLL, production(without_notes=True))
        _, unreadable = run(SOLL, "")
        self.assertNotEqual(missing, unreadable)


class WorkflowWiringTests(unittest.TestCase):
    def job(self, name):
        text = WORKFLOW.read_text(encoding="utf-8")
        match = re.search(rf"^  {re.escape(name)}:\n(.*?)(?=^  \S[^\n]*:\n|\Z)", text, re.S | re.M)
        self.assertIsNotNone(match, f"job {name} not found in testflight.yml")
        return match.group(1)

    def test_upload_waits_for_schema_check(self):
        self.assertRegex(self.job("upload"), r"needs:\s*(\[\s*)?schema-check")

    def test_no_input_skips_schema_check(self):
        text = WORKFLOW.read_text(encoding="utf-8")
        inputs = re.search(r"^on:\n(.*?)^concurrency:", text, re.S | re.M).group(1)
        self.assertNotRegex(inputs, r"(?i)schema|skip")
        job = self.job("schema-check")
        self.assertNotRegex(job, r"(?m)^    if:", "schema-check must run on every run")
        self.assertIn("scripts/check_cloudkit_production.py", job)
        self.assertIn("--environment production", job)


if __name__ == "__main__":
    unittest.main()
