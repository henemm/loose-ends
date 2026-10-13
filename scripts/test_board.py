"""Tests für board.py (#385): die reinen Teile; den Weg zu GitHub zeigt nur der echte Lauf.

Aufruf: python3 scripts/test_board.py
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import board  # noqa: E402


def issue(number, title="T", status=None, priority=None, size=None, state=None):
    content = {"type": "Issue", "number": number, "title": title}
    if state:
        content["state"] = state
    return {"id": f"item{number}", "content": content, "status": status, "priority": priority, "size": size}


FIELDS = [
    {"id": "F_status", "name": "Status", "options": [{"id": "o_ip", "name": "In progress"}, {"id": "o_done", "name": "Done"}]},
    {"id": "F_size", "name": "Size", "options": [{"id": "o_s", "name": "S"}, {"id": "o_m", "name": "M"}]},
    {"id": "F_title", "name": "Title"},
]


class ParseAssignments(unittest.TestCase):
    def test_several_with_spaces(self):
        self.assertEqual(board.parse_assignments(" Status=In progress, Size = M "),
                         [("Status", "In progress"), ("Size", "M")])

    def test_rejects_missing_value_or_nothing(self):
        for text in ["Status", "Status=", "=Done", "", " , "]:
            with self.subTest(text=text), self.assertRaises(board.Fatal):
                board.parse_assignments(text)


class BoardLines(unittest.TestCase):
    def test_keeps_board_order_and_position_without_done_prs_and_closed(self):
        items = [
            issue(355, "Oben", "Ready", "P0", "S"),
            issue(203, "Fertig", "Done"),
            {"id": "pr", "content": {"type": "PullRequest", "number": 380, "title": "PR"}},
            issue(99, "Zu", "Ready", state="CLOSED"),
            issue(241, "Orte", None, "P1", None),
        ]
        self.assertEqual(board.board_lines(items), [
            "1 | #355 | Ready | P0 | S | Oben",
            "5 | #241 | - | P1 | - | Orte",
        ])


class OptionAndItem(unittest.TestCase):
    def test_option_found_case_insensitive(self):
        self.assertEqual(board.option_id(FIELDS, "status", "done"), ("F_status", "o_done"))

    def test_unknown_option_or_field_names_the_choices(self):
        with self.assertRaises(board.Fatal) as caught:
            board.option_id(FIELDS, "Size", "XXL")
        self.assertIn("S, M", str(caught.exception))
        with self.assertRaises(board.Fatal):
            board.option_id(FIELDS, "Priority", "P0")

    def test_item_by_issue_number(self):
        items = [issue(1), {"id": "pr", "content": {"type": "PullRequest", "number": 2}}, issue(2)]
        self.assertEqual(board.item_id(items, "2"), "item2")
        self.assertIsNone(board.item_id(items, 3))


class Annotation(unittest.TestCase):
    def test_encodes_newlines_and_percent(self):
        self.assertEqual(board.annotation("board", ["a 100%", "b"]), "::notice title=board::a 100%25%0Ab")
        self.assertEqual(board.annotation("board", []), "::notice title=board::(empty)")


class Main(unittest.TestCase):
    def test_wrong_arguments_fail_with_an_error_line(self):
        self.assertEqual(board.main(["board.py"]), 1)
        self.assertEqual(board.main(["board.py", "set", "203"]), 1)


if __name__ == "__main__":
    unittest.main()
