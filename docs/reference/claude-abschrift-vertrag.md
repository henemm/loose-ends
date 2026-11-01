# Abschrift und Aufträge für Claude, Vertrag Version 1 (#613, Weg B)

iCloud bleibt der Abgleich zwischen Hennings Geräten (ADR-2). Damit Claude seine Aufgaben sehen und ändern kann, liefert die App
zwei Dinge, die ein eigener Dienst nur weiterreicht: eine **Abschrift** und einen **Auftragsweg**. Dieser Text legt fest, wie beide
aussehen. Der Dienst übernimmt ihn unverändert; eine Änderung am Format ist eine neue Version, keine stille Anpassung.

Die Beispiele unten stehen wörtlich auch in den Tests (`LooseEndsTests/TranscriptCodecTests.swift`,
`LooseEndsTests/OrderExecutorTests.swift`), und `server/test/schema.test.ts` liest sie zur Laufzeit aus diesem Text; weicht eines ab, schlagen die Tests fehl.

## Allgemein

- JSON, Schlüssel sortiert. Datumsangaben in ISO 8601, UTC, ganze Sekunden (`2026-03-12T17:00:00Z`).
- Kennungen sind UUIDs in Großbuchstaben, wie die App sie führt.
- Ein fehlender optionaler Wert fehlt als Schlüssel; er wird nicht als `null` geschrieben.
- `version` ist 1. Ein Auftrag mit anderer Version weist schon der Dienst beim Annehmen ab; `invalid` der App bleibt die
  zweite Wand für Aufträge, die den Dienst nicht durchlaufen haben.

## Abschrift

Die App rechnet die Abschrift auf dem Gerät (`TranscriptCodec`), mit denselben Regeln wie die Ansicht „Jetzt“ (`ViewRules.now`).
Der Dienst rechnet nichts nach: So zeigt Claude dieselbe Zahl wie das App-Symbol und die Startseite („eine Zahl überall“, #637).

- `version`, `generatedAt` (Zeitpunkt der Berechnung), `nowCount` (die Zahl über „Jetzt“, das Knäuel eingerechnet).
- `now`: die Zeilen von „Jetzt“ als Kennungen, in der Reihenfolge der App. `knaeuel` nur, solange eine Aufgabe das Knäuel ist;
  `today` (heute fällig), `lined` („Als nächstes“, nach Rang), `waiting` (von früher übrig, ohne Rang).
- `tasks`: alle Aufgaben, die nicht erledigt und nicht gelöscht sind, geparkte eingeschlossen. Je Aufgabe genau diese Felder:
  `id`, `title`, `status` (`unprocessed`, `unverified`, `active`, `parked`), `dueDate` (optional), `dueHasTime`,
  `contexts` (Namen der Tags, alphabetisch), `project` (Name, optional), `nextRank` (optional), `isKnaeuel`.

Der Dienst nimmt eine Abschrift nur an, wenn ihre Form genau dieser entspricht, und ersetzt eine vorhandene nur durch eine mit
neuerem `generatedAt`; eine ältere oder gleich alte bleibt ohne Wirkung.

Die Abschrift trägt **keinen Rohtext, keine Notiz, keine Anhänge und keine Revisionen**. Mehr Felder sind eine Version 2 und
brauchen vorher die Freigabe im Datenschutztext (#625).

Beispiel:

```json
{
  "generatedAt": "2026-03-12T09:00:00Z",
  "now": {
    "knaeuel": "6F1C2B0A-0000-4000-8000-000000000003",
    "lined": ["6F1C2B0A-0000-4000-8000-000000000002"],
    "today": ["6F1C2B0A-0000-4000-8000-000000000001"],
    "waiting": []
  },
  "nowCount": 3,
  "tasks": [
    {
      "contexts": [],
      "dueDate": "2026-03-12T17:00:00Z",
      "dueHasTime": true,
      "id": "6F1C2B0A-0000-4000-8000-000000000001",
      "isKnaeuel": false,
      "status": "active",
      "title": "Müll rausbringen"
    },
    {
      "contexts": ["Computer"],
      "dueHasTime": false,
      "id": "6F1C2B0A-0000-4000-8000-000000000002",
      "isKnaeuel": false,
      "nextRank": 0,
      "project": "Haus",
      "status": "active",
      "title": "Angebot schreiben"
    },
    {
      "contexts": [],
      "dueHasTime": false,
      "id": "6F1C2B0A-0000-4000-8000-000000000003",
      "isKnaeuel": true,
      "status": "active",
      "title": "Steuer machen"
    }
  ],
  "version": 1
}
```

## Auftrag

Ein Auftrag ist eine Änderung, die Claude auslöst. Die App führt ihn als Nutzeränderung aus (`OrderExecutor`): Autor Nutzer,
Grund „Claude“, mit Revision wie jede Änderung in der App. Version 1 kennt drei Arten (`kind`):

- `capture`: `text` wird erfasst wie jede andere Eingabe (Kanal `claude`), samt der üblichen Anreicherung.
- `complete`: `taskID`, `expectedStatus` (der Status aus der Abschrift, nur ein offener oder geparkter; `done` oder
  `removed` ist `invalid`) und `expectedDueDate`. Die Aufgabe wird abgehakt wie in der App; eine wiederkehrende rollt weiter
  und bekommt einen Abschlussvermerk.
- `setDue`: `taskID`, `date` (fehlt = Fälligkeit entfernen), `hasTime` (ohne Uhrzeit gilt der Tagesbeginn) und
  `expectedDueDate` (die Fälligkeit aus der Abschrift; fehlt = die Aufgabe hatte keine).

Weil eine Aufgabe keinen Änderungszeitpunkt führt, trägt jeder Auftrag den **erwarteten Stand** der Felder, die er ändert.
Stimmt er nicht mehr mit dem Gerät überein, wird nichts geändert. `expectedDueDate` ist bei `complete` und `setDue` Pflicht
in diesem Sinn: Der Wert wird aus der Abschrift übernommen, und fehlt er, heißt das „die Aufgabe hat keine Fälligkeit“.
Die Abschrift sagt nicht, ob eine Aufgabe wiederkehrt; nur über die Fälligkeit hakt derselbe Auftrag eine wiederkehrende
Aufgabe, die schon weitergerollt ist, kein zweites Mal ab. Verglichen wird in ganzen Sekunden, der Genauigkeit der Abschrift.

Bekannte Grenze von Version 1: `dueHasTime` gehört nicht zum erwarteten Stand. Ein `setDue` mit demselben Zeitpunkt und
anderem `hasTime` ändert nur `dueHasTime`, ohne Revision.

Der Status zählt bei `setDue` zum erwarteten Stand: Ist die Aufgabe auf dem Gerät inzwischen erledigt oder gelöscht, wird der
Auftrag als `stale` abgelehnt, auch wenn ihre Fälligkeit gleich blieb (C3a).

Der Dienst nimmt einen Auftrag nur mit `version` = 1 und der Form seiner Art an (C3b): je Art genau die Felder oben, die
Pflichtfelder vorhanden, kein weiterer Schlüssel. Ein Auftrag ohne `version`, den die App nicht dekodieren könnte, erreicht sie
so nicht. Bedeutung prüft der Dienst nicht: `expectedStatus` `done` oder `removed` reicht er durch, `invalid` ist Sache der App.

Der Dienst vergibt jeden Auftrag an genau ein Gerät, **genau einmal und ohne zugesagte Reihenfolge**. Ein Ergebnis kann nur
das Gerät melden, das den Auftrag hält; ein zweites Ergebnis zum selben Auftrag ändert nichts.

Beispiel:

```json
{
  "expectedDueDate": "2026-03-12T17:00:00Z",
  "expectedStatus": "active",
  "id": "0B7D5E3C-0000-4000-8000-000000000010",
  "kind": "complete",
  "taskID": "6F1C2B0A-0000-4000-8000-000000000001",
  "version": 1
}
```

## Ergebnis

Jeder Auftrag bekommt ein Ergebnis: `orderID`, `outcome` (`done` oder `rejected`), bei Ablehnung `reason` und, wo eine Aufgabe
betroffen ist, `taskID`.

- `invalid`: falsche Version, ein Pflichtfeld fehlt, oder der Text einer Erfassung ist leer. Version und Pflichtfelder weist
  schon der Dienst beim Annehmen ab; `invalid` der App bleibt die zweite Wand für Aufträge, die den Dienst nicht durchlaufen haben.
- `missing`: Auf dem Gerät gibt es keine Aufgabe mit dieser Kennung.
- `stale`: Der erwartete Stand stimmt nicht mehr; Claude liest die Abschrift neu und entscheidet erneut.

Bei jeder Ablehnung bleibt das Gerät unverändert: keine Aufgabe, keine Revision, kein Feld.

Beispiel (derselbe Auftrag ein zweites Mal ausgeführt):

```json
{
  "orderID": "0B7D5E3C-0000-4000-8000-000000000010",
  "outcome": "rejected",
  "reason": "stale",
  "taskID": "6F1C2B0A-0000-4000-8000-000000000001"
}
```
