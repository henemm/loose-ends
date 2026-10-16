"""#268: stop the TestFlight run when CloudKit Production lacks a type or field of cloudkit/schema.ckdb.

Usage: check_cloudkit_production.py <abbild.ckdb> <production.ckdb>
Exit 0: every record type and field of the file is in Production (extra ones in Production are fine).
Exit 1: something is missing; the list and the way out (docs/reference/testflight.md, 5a) are printed.
Exit 2: a file is missing, empty or has no record type; an uncheckable state is not a green state.
Only names are compared: flags, field types, GRANT lines and system fields ("___…") do not count.
"""

import pathlib
import re
import sys

RECORD_TYPE = re.compile(r"RECORD TYPE (\w+) \((.*?)\);", re.S)
COMMA_OUTSIDE_QUOTES = re.compile(r',(?=(?:[^"]*"[^"]*")*[^"]*$)')


def field_names(line):
    """Field names declared on one line: comments (`//`) and GRANT lines yield none, commas split fields."""
    stripped = line.strip()
    if stripped.startswith("//"):
        return set()
    names = set()
    for part in COMMA_OUTSIDE_QUOTES.split(stripped):
        words = part.split()
        if not words or words[0] == "GRANT":
            continue
        name = words[0].strip('"')
        if name and not name.startswith("___"):
            names.add(name)
    return names


def parse(text):
    """{record type: set of field names}, without comments, GRANT lines and system fields.
    Two blocks of the same type are united."""
    types = {}
    for match in RECORD_TYPE.finditer(text):
        fields = types.setdefault(match.group(1), set())
        for line in match.group(2).splitlines():
            fields |= field_names(line)
    return types


def missing(soll, ist):
    """Sorted findings: `record type X` for a missing type, `X.field` for a missing field."""
    findings = []
    for record, fields in soll.items():
        if record not in ist:
            findings.append(f"record type {record}")
            continue
        findings.extend(f"{record}.{field}" for field in fields - ist[record])
    return sorted(findings)


def read(path, label):
    """The parsed schema, or None after printing why the file cannot be checked."""
    file = pathlib.Path(path)
    try:
        text = file.read_text(encoding="utf-8")
    except OSError as error:
        print(f"::error::{label} nicht lesbar ({path}): {error}. Ein nicht prüfbarer Stand ist kein grüner Stand.")
        return None
    schema = parse(text)
    if not schema:
        print(f"::error::{label} ({path}) ist leer oder enthält kein RECORD TYPE. "
              "Ein nicht prüfbarer Stand ist kein grüner Stand.")
        return None
    return schema


def main(argv):
    if len(argv) != 2:
        print("::error::Aufruf: check_cloudkit_production.py <abbild.ckdb> <production.ckdb>")
        return 2
    soll = read(argv[0], "Schema-Abbild (Datei)")
    ist = read(argv[1], "Production-Export (Datei)")
    if soll is None or ist is None:
        return 2
    findings = missing(soll, ist)
    if not findings:
        print(f"Production kennt alle {len(soll)} Typen des Abbilds samt Feldern.")
        return 0
    print("::error::CloudKit Production kennt diese Typen/Felder aus cloudkit/schema.ckdb nicht: "
          + ", ".join(findings))
    for finding in findings:
        print(f"  fehlt in Production: {finding}")
    print("Weg (docs/reference/testflight.md, Abschnitt 5a): Abbild im selben PR ergänzen; nach dem Merge "
          "importiert die CI es nach Development; dann in der CloudKit Console „Deploy Schema Changes“; "
          "dann diesen Lauf wiederholen.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
