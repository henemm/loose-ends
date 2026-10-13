# Board aus der Cloud (#385)

Cloud-Sitzungen erreichen das GitHub Project „loose ends“ (henemm, Project 1) nicht direkt: GraphQL und die
Projects-API sind dort gesperrt. Zwei Wege ersetzen das.

## 1. Eingebaute Regeln des Boards (einmal von Henning)

Board öffnen → oben rechts **⋯** → **Workflows**:

- **Item closed** → einschalten, Status **Done**.
- **Pull request merged** → einschalten, Status **Done**.

Dann steht jedes geschlossene Ticket ohne Zutun auf „Done“.

## 2. Workflow `board.yml` für alles andere

Einmalig von Henning:

1. https://github.com/settings/tokens → **Generate new token (classic)**, Name „loose-ends board“, Ablauf nach
   Wahl, Scopes **project**, **read:org** und **read:discussion** (`gh project` fragt die beiden letzten ab) → Token
   kopieren.
2. https://github.com/henemm/loose-ends/settings/secrets/actions → **New repository secret**, Name
   `PROJECT_TOKEN`, Wert der Token.

Aufruf aus einer Cloud-Sitzung (REST, kein GraphQL):

```bash
gh api -X POST repos/henemm/loose-ends/actions/workflows/board.yml/dispatches -f ref=main -f inputs[action]=list
gh api -X POST repos/henemm/loose-ends/actions/workflows/board.yml/dispatches -f ref=main \
  -f inputs[action]=set -f inputs[issue]=385 -f 'inputs[fields]=Status=In progress,Size=S'
```

Ergebnis lesen: neuesten Lauf über `repos/henemm/loose-ends/actions/workflows/board.yml/runs?per_page=1`, dessen
Job-ID über `.../actions/runs/{id}/jobs`, dann `repos/henemm/loose-ends/check-runs/{job-id}/annotations`. Die
Notice „board“ enthält bei `list` je offener Karte eine Zeile `Pos | #Nummer | Status | Priority | Size | Titel` in
Hennings Reihenfolge (Position = Platz im Board), bei `set` die gesetzten Werte. Ein Fehler steht als Annotation
„board“ der Stufe error.
