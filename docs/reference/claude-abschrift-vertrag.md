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

- `views` (optional, #621): die Kennungen der Ansichten „Fällig“ (`due`: heute und überfällig, ohne Wartende), „Als nächstes“
  (`next`, nach Rang) und „Lose Enden“ (`open`: alles Offene, Geparktes eingeschlossen) in der Reihenfolge der App
  (`ViewRules.tasks(for:)`). Nur Kennungen, nichts Neues über eine Aufgabe. Fehlt der Schlüssel (ältere App), sagt der Dienst es
  Claude, statt die Liste aus `tasks` nachzurechnen: Der Dienst rechnet keine Ansicht. Die Beispiele unten bleiben ohne `views`.

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
Grund „Claude“, mit Revision wie jede Änderung in der App, soweit das Feld ein Revisionsfeld ist (Status, Rang in „Als nächstes“ und Unteraufgaben sind es nicht; wie beim Abhaken entsteht dort keine Revision, #622). Version 1 kennt sechs Arten (`kind`); Verschieben auf einen anderen Tag ist `setDue`, Löschen und Massenänderungen gibt es nicht:

- `capture`: `text` wird erfasst wie jede andere Eingabe (Kanal `claude`), samt der üblichen Anreicherung.
- `complete`: `taskID`, `expectedStatus` (der Status aus der Abschrift, nur ein offener oder geparkter; `done` oder
  `removed` ist `invalid`) und `expectedDueDate`. Die Aufgabe wird abgehakt wie in der App; eine wiederkehrende rollt weiter
  und bekommt einen Abschlussvermerk.
- `setDue`: `taskID`, `date` (fehlt = Fälligkeit entfernen), `hasTime` (ohne Uhrzeit gilt der Tagesbeginn) und
  `expectedDueDate` (die Fälligkeit aus der Abschrift; fehlt = die Aufgabe hatte keine).
- `setNext` (#622): `taskID`, `expectedStatus`, `on` und optional `expectedNextRank` (der Rang aus der Abschrift; fehlt = keiner).
  Die Aufgabe kommt ans Ende von „Als nächstes“ (`on` wahr) oder heraus (falsch), wie der Wisch. Verlangt `on` den Zustand, den sie
  schon hat, oder ist die Aufgabe geparkt, ist es `invalid`; stimmen Status oder Rang nicht mehr, `stale`.
- `park` (#622): `taskID`, `expectedStatus`. Parkt eine offene Aufgabe wie der Wisch (raus aus „Als nächstes“, das Knäuel-Zeichen
  fällt). Eine schon geparkte, erledigte oder gelöschte ist `invalid`.
- `addSubtask` (#622): `taskID`, `expectedStatus`, `text`. Fügt eine Zeile unter einer Aufgabe der obersten Ebene hinzu, getippt
  wie sie ist (die App kürzt Leerraum an den Enden). Leerer Text, eine Unteraufgabe oder eine geparkte Aufgabe als Elternteil ist `invalid`.

Weil eine Aufgabe keinen Änderungszeitpunkt führt, trägt jeder Auftrag den **erwarteten Stand** der Felder, die er ändert.
Stimmt er nicht mehr mit dem Gerät überein, wird nichts geändert. `expectedDueDate` ist bei `complete` und `setDue` Pflicht
in diesem Sinn: Der Wert wird aus der Abschrift übernommen, und fehlt er, heißt das „die Aufgabe hat keine Fälligkeit“.
Die Abschrift sagt nicht, ob eine Aufgabe wiederkehrt; nur über die Fälligkeit hakt derselbe Auftrag eine wiederkehrende
Aufgabe, die schon weitergerollt ist, kein zweites Mal ab. Verglichen wird in ganzen Sekunden, der Genauigkeit der Abschrift.

`dueHasTime` gehört nicht zum erwarteten Stand und ist kein Revisionsfeld. Ein `setDue`, das denselben Zeitpunkt träfe und nur
`hasTime` ändern würde (möglich nur um Mitternacht), wird deshalb als `invalid` abgelehnt; sonst geschähe die Änderung ohne
Revision (#777).

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

- `invalid`: falsche Version, ein Pflichtfeld fehlt, der Text einer Erfassung ist leer, oder ein `setDue` träfe denselben
  Zeitpunkt und änderte nur `hasTime`. Version und Pflichtfelder weist
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

## Wege der App (#795 S1)

Die App spricht mit dem Dienst über drei Wege, alle `POST`, alle mit `Authorization: Bearer <App-Sitzung>` (das Sitzungs-Token
aus `/auth/apple`, nie das OAuth-Token von Claude). Jede Antwort trägt `Cache-Control: no-store`; jede Ablehnung hat keinen Körper
und sagt nie, welche Prüfung scheiterte. Reihenfolge der Prüfungen: Methode (405 mit `Allow: POST`), Sitzung (401), Gerät (400),
Inhaltstyp `application/json` (415), Körper höchstens 256 KiB, beim Lesen gezählt (413), JSON und Form (400).

`X-Device` ist die Kennung der Installation, eine UUID (`8-4-4-4-12` Hex, Groß- oder Kleinschreibung); der Dienst führt sie in
Kleinschreibung. `transcript` braucht kein Gerät: die Abschrift gehört dem Konto.

```http
POST /app/transcript
Authorization: Bearer <App-Sitzung>
Content-Type: application/json

<Abschrift>
```

- `POST /app/transcript`: 204 ohne Körper, auch wenn der Dienst schon eine gleich alte oder neuere Abschrift hat (`generatedAt`
  entscheidet, eine je Konto); 400 bei ungültiger Abschrift.
- `POST /app/orders/claim` mit `X-Device`, ohne Körper: 200 mit dem Auftrag als JSON, 204, wenn keiner offen ist.
- `POST /app/orders/result` mit `X-Device` und dem Ergebnis: 204 (auch für dasselbe Ergebnis ein zweites Mal), 409, wenn der Auftrag
  unbekannt, nie vergeben, einem anderen Gerät oder Konto zugeordnet oder zurückgeholt ist; 400 bei ungültigem Ergebnis.

**Rückholen.** Ein vergebener Auftrag ohne Ergebnis, dessen Vergabe älter als 10 Minuten ist, geht beim nächsten `claim` an das
fragende Gerät (die Zeit rechnet die Datenbank). Folgen: (a) Ein Ergebnis des alten Geräts danach ist abgelehnt (409). (b) Ein
Auftrag mit Ergebnis wird nie zurückgeholt. (c) Zugestellt wird mindestens einmal, nicht genau einmal: Hat das alte Gerät den
Auftrag schon ausgeführt, macht der erwartete Stand aus der zweiten Ausführung `stale`; nur ein `capture` ist nicht geschützt und
kann doppelt erfasst werden. (d) Fragt dasselbe Gerät erneut, bekommt es seinen Auftrag zurück und darf das Ergebnis melden.
