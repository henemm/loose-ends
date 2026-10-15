"""#448: every stored property of every SwiftData model has its field in cloudkit/schema.ckdb.

The CI imports that file into CloudKit Development (cloudkit-schema.yml); Henning then deploys it to
Production. A field missing from the file would never reach Production, and the TestFlight build would
fail to sync it. This test reads the @Model classes in Shared/Models the simple way (stored `var`s at
class level, no computed ones, to-many relationships left out, as CloudKit stores those on the other
side) and checks the record type CD_<Class> lists CD_<property>.
"""

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODELS = ROOT / "Shared" / "Models"
SCHEMA = ROOT / "cloudkit" / "schema.ckdb"

PROPERTY = re.compile(r"^    (?:@\w+(?:\([^)]*\))?\s+)*var (\w+):\s*([^={]+?)\s*(=.*)?$")


def model_classes():
    """{class name: [(property, type)]} for every @Model class in Shared/Models."""
    classes = {}
    for path in sorted(MODELS.glob("*.swift")):
        lines = path.read_text(encoding="utf-8").splitlines()
        index = 0
        while index < len(lines):
            if lines[index].strip() == "@Model":
                match = re.match(r"\s*(?:final\s+)?class (\w+)", lines[index + 1])
                name = match.group(1)
                properties = []
                index += 2
                while index < len(lines) and not lines[index].startswith("}"):
                    line = lines[index]
                    found = PROPERTY.match(line)
                    if found and not line.rstrip().endswith("{") and "@Transient" not in line:
                        properties.append((found.group(1), found.group(2).strip()))
                    index += 1
                classes[name] = properties
            index += 1
    return classes


def record_fields():
    """{record type: set of field names} from the schema file."""
    text = SCHEMA.read_text(encoding="utf-8")
    types = {}
    for match in re.finditer(r"RECORD TYPE (\w+) \((.*?)\);", text, re.S):
        fields = {line.strip().split()[0].strip('"') for line in match.group(2).splitlines() if line.strip()}
        types[match.group(1)] = fields
    return types


class CloudKitSchemaTests(unittest.TestCase):
    def test_every_model_property_is_in_the_schema(self):
        classes = model_classes()
        self.assertIn("TaskItem", classes, "no @Model classes found in Shared/Models")
        records = record_fields()
        missing = []
        for name, properties in classes.items():
            fields = records.get(f"CD_{name}")
            if fields is None:
                missing.append(f"record type CD_{name}")
                continue
            for prop, kind in properties:
                to_many = re.fullmatch(r"\[(\w+)\]\??", kind)
                if to_many and to_many.group(1) in classes:
                    continue
                if f"CD_{prop}" not in fields:
                    missing.append(f"CD_{name}.CD_{prop}")
        self.assertEqual(missing, [], "cloudkit/schema.ckdb lacks these; add them (docs/reference/testflight.md, 5a)")

    def test_the_parser_sees_known_fields(self):
        properties = dict(model_classes()["TaskItem"])
        self.assertIn("rawText", properties)
        self.assertIn("notes", properties)
        self.assertNotIn("status", properties, "computed properties are not stored")


if __name__ == "__main__":
    unittest.main()
