"""Liest und pflegt das GitHub Project „loose ends“ aus einem Workflow-Lauf (#385).

Cloud-Sitzungen erreichen das Board nicht (GraphQL und Projects-API gesperrt). Sie stoßen
`.github/workflows/board.yml` an; dieses Skript läuft dort mit dem Secret PROJECT_TOKEN.

Aufruf:
  board.py list                         offene Karten in Hennings Reihenfolge, als Annotation
  board.py set <issue> <Feld=Wert,...>  z. B. `set 203 Status=Done` oder `set 385 Status=In progress,Size=S`

Das Ergebnis steht als `::notice title=board::` am Lauf; eine Cloud-Sitzung liest es über
`repos/{owner}/{repo}/check-runs/{id}/annotations`. Nur Standardbibliothek plus `gh`.
"""
import json
import os
import subprocess
import sys

# "@me": the token belongs to the board owner, and gh then skips its owner-type lookup, which fails
# with a token that carries only the `project` scope ("unknown owner type", #385).
OWNER = os.environ.get("BOARD_OWNER", "@me")
NUMBER = os.environ.get("BOARD_NUMBER", "1")
REPO = os.environ.get("GITHUB_REPOSITORY", "henemm/loose-ends")


class Fatal(Exception):
    pass


def parse_assignments(text):
    """„Status=In progress, Size=M“ → [("Status", "In progress"), ("Size", "M")]."""
    pairs = []
    for part in text.split(","):
        if not part.strip():
            continue
        if "=" not in part:
            raise Fatal(f"Expected Field=Value, got {part.strip()!r}")
        field, value = part.split("=", 1)
        if not field.strip() or not value.strip():
            raise Fatal(f"Expected Field=Value, got {part.strip()!r}")
        pairs.append((field.strip(), value.strip()))
    if not pairs:
        raise Fatal("Nothing to set")
    return pairs


def board_lines(items):
    """Offene Karten in der Board-Reihenfolge (die Liste kommt so von `gh project item-list`).
    Geschlossene Tickets, PRs und Karten mit Status Done fallen weg; die Position bleibt die im Board."""
    lines = []
    for position, item in enumerate(items, start=1):
        content = item.get("content") or {}
        if content.get("type") != "Issue" or item.get("status") == "Done":
            continue
        if (content.get("state") or "OPEN").upper() != "OPEN":
            continue
        cells = [str(position), f"#{content.get('number')}", item.get("status") or "-",
                 item.get("priority") or "-", item.get("size") or "-", content.get("title") or ""]
        lines.append(" | ".join(cells))
    return lines


def option_id(fields, field_name, value):
    """Feld- und Options-ID eines Single-Select-Felds, Groß-/Kleinschreibung egal."""
    for field in fields:
        if field.get("name", "").lower() != field_name.lower():
            continue
        for option in field.get("options") or []:
            if option.get("name", "").lower() == value.lower():
                return field["id"], option["id"]
        names = ", ".join(o.get("name", "") for o in field.get("options") or [])
        raise Fatal(f"{field_name} has no option {value!r} (options: {names})")
    raise Fatal(f"No field {field_name!r} on the board")


def item_id(items, issue):
    """Die Karte zum Ticket, None wenn es nicht auf dem Board liegt."""
    for item in items:
        content = item.get("content") or {}
        if content.get("type") == "Issue" and str(content.get("number")) == str(issue):
            return item["id"]
    return None


def annotation(title, lines):
    """Eine Notice-Zeile für den Lauf; Zeilenumbrüche nach GitHubs Kodierung."""
    body = "\n".join(lines) or "(empty)"
    body = body.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    return f"::notice title={title}::{body}"


def gh_json(*args):
    result = subprocess.run(["gh", *args, "--format", "json"], capture_output=True, text=True)
    if result.returncode != 0:
        raise Fatal(f"gh {' '.join(args[:2])} failed: {result.stderr.strip()}")
    return json.loads(result.stdout)


def items():
    return gh_json("project", "item-list", NUMBER, "--owner", OWNER, "--limit", "500").get("items", [])


def run_list():
    print(annotation("board", ["Pos | Issue | Status | Priority | Size | Titel", *board_lines(items())]))


def run_set(issue, text):
    pairs = parse_assignments(text)
    fields = gh_json("project", "field-list", NUMBER, "--owner", OWNER).get("fields", [])
    project = gh_json("project", "view", NUMBER, "--owner", OWNER)["id"]
    item = item_id(items(), issue)
    if item is None:
        url = f"https://github.com/{REPO}/issues/{issue}"
        item = gh_json("project", "item-add", NUMBER, "--owner", OWNER, "--url", url)["id"]
    done = []
    for field_name, value in pairs:
        field, option = option_id(fields, field_name, value)
        result = subprocess.run(["gh", "project", "item-edit", "--id", item, "--project-id", project,
                                 "--field-id", field, "--single-select-option-id", option],
                                capture_output=True, text=True)
        if result.returncode != 0:
            raise Fatal(f"Setting {field_name} failed: {result.stderr.strip()}")
        done.append(f"#{issue} {field_name} = {value}")
    print(annotation("board", done))


def main(argv):
    try:
        if len(argv) == 2 and argv[1] == "list":
            run_list()
        elif len(argv) == 4 and argv[1] == "set":
            run_set(argv[2].lstrip("#"), argv[3])
        else:
            raise Fatal("Usage: board.py list | board.py set <issue> <Field=Value,...>")
    except Fatal as error:
        print(f"::error title=board::{error}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
