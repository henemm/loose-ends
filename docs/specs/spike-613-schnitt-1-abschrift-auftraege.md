---
entity_id: spike-613-schnitt-1-abschrift-auftraege
type: feature
created: 2026-10-31
updated: 2026-10-31
status: draft
workflow: spike-613-backend-weg-b
---

# Spec: Abschrift und Aufträge, Schnitt 1 — App-Seite (#613, Weg B „Fenster für Claude“)

## Approval

- [ ] Approved

## GitHub Issue

#613 (Spike, Epic #612). Schnitt 1 (im Kontext „C2“); das Issue bleibt offen (`Refs #613`, nie `Closes #613`).

**Der Ticket-Text ist überholt.** Er verlangt, ADR-2 abzulösen, PowerSync zu prüfen und das Ergebnis als ADR-19 festzuhalten. Seit 2026-10-31 gilt Weg B:
iCloud/CloudKit (ADR-2) bleibt der Abgleich zwischen den Geräten; ein eigener schlanker Dienst auf Hetzner hält nur eine Abschrift und einen Auftragsweg.
ADR-19 und ADR-20 sind vergeben, die Entscheidung des Spikes wird **ADR-21** und ergänzt ADR-2, ohne es abzulösen.

## Purpose

Claude soll Hennings Aufgaben sehen (dieselbe „Jetzt“-Liste und dieselbe Zahl wie in der App, „eine Zahl überall“, #637) und drei Dinge auslösen können: erfassen, abhaken,
Fälligkeit setzen. Dafür braucht es zwei Dinge, die die App liefert: eine **Abschrift** (Aufgaben samt fertig berechneter Ansicht „Jetzt“ aus `ViewRules`) und einen **Ausführer**,
der einen Auftrag aus Claude als Nutzeränderung mit Grund „Claude“ in den lokalen Store schreibt. Der Dienst auf Hetzner transportiert beides nur.

Dieser Schnitt legt den **Vertrag auf der App-Seite** fest: rein, aus Unit-Tests getrieben, **kein Netz, kein Dienst, keine Oberfläche**. Der Dienst (spätere Schnitte) übernimmt den Vertrag unverändert.

Tragende Entscheidungen:

- Die Abschrift berechnet die Ansicht auf dem Gerät mit `ViewRules`; der Dienst rechnet nichts nach. So kann Claude nie eine andere Zahl zeigen als die App.
- Ein Auftrag trägt den **erwarteten Stand** der Felder, die er ändert (Status bzw. Fälligkeit), denn `TaskItem` hat kein `modifiedAt`. Weicht der Store ab, wird der Auftrag abgelehnt und nichts geändert.
  Keine eigene Konfliktlösung im Sinne eines Sync-Frameworks.
- Der Ausführer folgt dem Muster von `SiriCapture` (#225): externe Eingabe, Autor `.user`, Grund benannt, bei Ablehnung bleibt nichts liegen.

**Regeln vor Modell:** Alles hier ist deterministisch und regelbasiert; kein Sprachmodell beteiligt. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

**Grenze dieses Schnitts:** `TaskListView.swift:371-409` ordnet „Fällig“ und „Lose Enden“ zusätzlich in der Oberfläche (Überfällige oben, Blöcke #657). Die Abschrift trägt deshalb in Schnitt 1 nur
„Jetzt“ (Reihenfolge und Zahl aus `ViewRules.now`). Die UI-Ordnung nach `ViewRules` zu verschieben ist ein eigenes Folgeticket, nicht Teil dieses Spikes.

**Datensparsamkeit:** Die Abschrift trägt weder Rohtext noch Notiz, Anhänge oder Revisionen. Eine Erweiterung gehört ins Produkt-Ticket und braucht die Datenschutzfreigabe (#625).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Dieser Schnitt legt nur den Vertrag auf der App-Seite fest. ADR-21 (ergänzt ADR-2, löst es nicht ab; ADR-19 und ADR-20 sind vergeben) entsteht im letzten Schnitt des Spikes, mit Messung und Kostenrechnung.

ADR-2 (iCloud als Abgleich) bleibt unberührt. Berührt wird auch ADR-4 nicht (Anreicherung läuft einmal): eine per Auftrag erfasste Aufgabe durchläuft die übliche Anreicherung.

## Source

**File:** `Shared/Services/TranscriptCodec.swift` (Hauptdatei; übrige Dateien in der Tabelle)
**Identifier:** `TranscriptCodec`, `Transcript`, `OrderExecutor`, `Order`, `OrderResult`, `CaptureChannel.claude`

| Datei | Änderung |
|---|---|
| `Shared/Services/TranscriptCodec.swift` | NEU, rein: `[TaskItem]` + `now` + `calendar` → `Transcript` (Codable, `Sendable`, JSON) |
| `Shared/Services/OrderExecutor.swift` | NEU: `Order` (Codable) prüfen und gegen einen `ModelContext` ausführen → `OrderResult` (Codable) |
| `Shared/Models/Enums.swift` | MODIFY: `CaptureChannel.claude` (Rohwert-Enum, kein Schemafeld, keine CloudKit-Änderung) |
| `LooseEndsTests/TranscriptCodecTests.swift` | NEU |
| `LooseEndsTests/OrderExecutorTests.swift` | NEU |
| `docs/reference/claude-abschrift-vertrag.md` | NEU: Vertrag in Prosa plus JSON-Beispiel für Abschrift, Auftrag und Ergebnis (Version 1) |

Produktivcode: höchstens 250 hinzugefügte Zeilen (Tests zählen getrennt). Neue Dateien brauchen `./scripts/sim.sh generate`.

**Vertrag Version 1 (Kurzfassung; maßgeblich ist `docs/reference/claude-abschrift-vertrag.md`):**

- Abschrift: `version` (1), `generatedAt`, `nowCount`, `now` (`knaeuel?`, `today`, `lined`, `waiting`: Listen von Aufgaben-IDs), `tasks` (alle nicht erledigten Aufgaben).
- Aufgabe in `tasks`: `id`, `title`, `status`, `dueDate` (ISO 8601, optional), `dueHasTime`, `contexts` (Namen), `project` (Name, optional), `nextRank` (optional), `isKnaeuel`.
- Auftrag: `version`, `id` (UUID), `kind` (`capture` | `complete` | `setDue`) und je Art `text`; `taskID`, `expectedStatus`; `taskID`, `date?`, `hasTime`, `expectedDueDate?`.
- Ergebnis: `orderID`, `outcome` (`done` | `rejected`), `reason?` (`invalid` | `stale` | `missing`), `taskID?`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `ViewRules.now(in:now:calendar:)`, `ViewRules.nowCount(in:now:calendar:)`, `ViewRules.tasks(for:in:now:calendar:)` | wiederverwendet, unverändert |
| `CaptureService.save(_:via:sourceURL:in:)` (leerer Text wirft `CaptureError.emptyText`) | wiederverwendet, unverändert |
| `TaskActions.complete(_:now:calendar:)` (wiederkehrende Aufgabe rollt weiter, `CompletionRecord`) | wiederverwendet, unverändert |
| `RevisionService.set(.dueDate, to:, on:, contexts:, projects:, now:)`, Muster `SiriCapture.write` (~Z. 180–198) | wiederverwendet, unverändert |
| `TaskActions.setDue` | Vorbild für `dueHasTime` (Tagesdatum = Tagesbeginn); nicht aufgerufen, weil es die Revision verwirft |
| `TaskItem(rawText:capturedVia:sourceURL:ownerID:)`, `TaskStatus` | unverändert |
| Dienst, MCP-Werkzeuge, Anmeldung | folgen in späteren Schnitten, hier nicht beteiligt |

## Acceptance Criteria

- **AC-1:** `TranscriptCodec` bildet `[TaskItem]` plus `now` und `calendar` rein (ohne Netz, ohne Dateizugriff, ohne Seiteneffekt auf den Store) auf einen `Transcript` Version 1 ab: `version`, `generatedAt`, `nowCount`, `now`
  (Listen von Aufgaben-IDs `knaeuel` (optional), `today`, `lined`, `waiting`) und `tasks` = alle nicht erledigten Aufgaben mit **ausschließlich** den Feldern `id`, `title`, `status`, `dueDate` (ISO 8601),
  `dueHasTime`, `contexts` (Namen), `project` (Name), `nextRank`, `isKnaeuel`. Rohtext, Notiz, Anhänge und Revisionen kommen nicht vor. Belegt durch `TranscriptCodecTests` (Test über die Feldmenge: das JSON
  enthält genau diese Schlüssel; erledigte Aufgaben fehlen; ein Rohtext mit auffälligem Wortlaut taucht im JSON nicht auf).
- **AC-2:** `transcript.nowCount == ViewRules.nowCount(...)`, und die IDs in `now` entsprechen `ViewRules.now(...)` für dieselben Aufgaben in genau dessen Reihenfolge, mit festem `now` und festem Kalender.
  Der Test arbeitet mit gemischtem Bestand: heute fällig, als nächstes (mit Rang), überfällig ohne Rang, Knäuel, erledigt, geparkt. Belegt durch `TranscriptCodecTests`.
- **AC-3:** JSON-Rundlauf: kodieren, dekodieren ergibt Gleiches; Datumsangaben sind ISO 8601; die Schlüssel sind stabil. Der Test vergleicht die Kodierung gegen ein festes JSON-Beispiel (Fixture),
  das wörtlich auch in `docs/reference/claude-abschrift-vertrag.md` steht. Belegt durch `TranscriptCodecTests`.
- **AC-4:** Auftrag `capture(text)` legt über `CaptureService.save` mit Kanal `.claude` eine Aufgabe an; Ergebnis `done` mit der neuen `taskID`. Leerer oder nur aus Leerraum bestehender Text
  ergibt `rejected(invalid)`; es wird nichts gespeichert (Anzahl der Aufgaben vorher gleich nachher). Belegt durch `OrderExecutorTests`.
- **AC-5:** Auftrag `complete(taskID, expectedStatus)`: stimmt der Status, ruft der Ausführer `TaskActions.complete` auf und meldet `done`. Eine wiederkehrende Aufgabe rollt weiter statt `done` zu werden
  und erhält einen `CompletionRecord`, wie beim Abhaken in der App. Belegt durch `OrderExecutorTests` (einmalige und wiederkehrende Aufgabe).
- **AC-6:** Auftrag `setDue(taskID, date|nil, hasTime, expectedDueDate)` schreibt über `RevisionService.set(.dueDate, …)` eine Revision mit Autor `.user` und Grund „Claude“; `dueHasTime` wird wie in der App gesetzt
  (Tagesdatum = Tagesbeginn, mit Uhrzeit die Uhrzeit). `date = nil` entfernt die Fälligkeit, ebenfalls als Revision. Belegt durch `OrderExecutorTests` (Revision gezählt, Autor und Grund geprüft).
- **AC-7:** Weicht der erwartete Stand (Status bzw. Fälligkeit) vom Store ab, ergibt das `rejected(stale)`; eine unbekannte `taskID` ergibt `rejected(missing)`. Bei **jeder** Ablehnung (auch `invalid`)
  bleibt der Store unverändert: der Test zählt Revisionen, Aufgaben und die Felder Status, Fälligkeit, `dueHasTime` vorher und nachher. Belegt durch `OrderExecutorTests`.
- **AC-8:** Nachweis ohne Dienst mit zwei getrennten Stores. Store A erzeugt die Abschrift; ein `complete`-Auftrag wird **nur aus der Abschrift** gebildet (ID und Status aus dem JSON, durch JSON hindurchgereicht);
  Store B mit identisch angelegten Aufgaben (gleiche IDs) führt ihn aus. Danach ist die neue Abschrift von B konsistent: `nowCount` sinkt um 1, wenn die erledigte Aufgabe in „Jetzt“ stand, und sie fehlt in `tasks`.
  Wird derselbe Auftrag ein zweites Mal ausgeführt, ergibt das `rejected(stale)` (kein doppeltes Abhaken, wiederkehrende Aufgaben rollen nicht ein zweites Mal weiter). Belegt durch `OrderExecutorTests`.
  *Hinweis, kein AC:* Doppeltes Ausführen eines `capture`-Auftrags verhindert erst der Dienst, indem ein Auftrag an genau ein Gerät geht (Schnitt C3).
- **AC-9:** Konventionen: kein `try?`, `Logger` statt `print`, Swift 6 strict concurrency (`Transcript`, `Order`, `OrderResult` und ihre Teile sind `Sendable`), keine in Watch oder Widget unverfügbare API
  (`Shared/` kompiliert auch dort). Belegt durch den Bau (`./scripts/sim.sh build`) und den vollen Unit-Lauf; die Dateiliste des PR enthält außer den sechs oben genannten Dateien (plus erzeugtem Projekt) nichts.
- **AC-10:** `docs/reference/claude-abschrift-vertrag.md` beschreibt Abschrift, Auftrag und Ergebnis (Version 1) in Prosa und enthält je ein JSON-Beispiel, das **identisch** mit den Fixtures in
  `TranscriptCodecTests` und `OrderExecutorTests` ist. Belegt durch die Tests, die das Dokument einlesen und Fixture und Dokumentbeispiel vergleichen (Pfad relativ zum Quelltext, Test überspringt nie stumm: fehlt die Datei, schlägt er fehl).

## Scope

**Affected Files:** vier Code-Dateien (`TranscriptCodec.swift`, `OrderExecutor.swift`, `Enums.swift`, plus die zwei Testdateien) und ein Vertragsdokument. Geschätzt ≈ +230 LoC Produktivcode.
Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema (`CaptureChannel` ist ein Rohwert-Enum; `scripts/test_cloudkit_schema.py` bleibt unberührt), keine Oberfläche, kein Netz.
Neue Quelldateien in `Shared/Services/` erfordern `./scripts/sim.sh generate`.

Bei Überschreitung von 250 Zeilen Produktivcode: stoppen und `OrderExecutor` in zwei Schnitte teilen (zuerst `capture` und `complete`, dann `setDue`).

## Test Plan

**Zuordnung AC → Test:** AC-1 bis AC-3: `TranscriptCodecTests`. AC-4 bis AC-8: `OrderExecutorTests`. AC-9: Bau und voller Unit-Lauf. AC-10: Fixture-Vergleich in beiden Testdateien.
Funktionsnamen entstehen in TDD RED und werden dort eingetragen.

RED: Beide Testdateien schlagen fehl (Typen fehlen), solange `TranscriptCodec.swift`, `OrderExecutor.swift` und `CaptureChannel.claude` fehlen. GREEN: nach der Umsetzung beide grün.

Läufe (Simulator):

- `./scripts/sim.sh generate`
- `./scripts/sim.sh sim-unit TranscriptCodecTests`
- `./scripts/sim.sh sim-unit OrderExecutorTests`
- voller Unit-Lauf grün, `./scripts/sim.sh build` baut

**Keine UI-Tests:** Der Schnitt ändert keine Oberfläche und keinen Ablauf in der App; nichts ruft den Codec oder den Ausführer auf. Stufe 2 der Abnahme belegt der Unit-Lauf im Simulator,
`sim.sh build` zeigt, dass die App weiter baut.

Testaufbau: `ModelContext` immer zusammen mit seinem `ModelContainer` halten (lokale Variable bzw. Hilfsstruktur); Beziehungen in SwiftData sind ungeordnet, Tests mit mehr als einem Kontext vergleichen als Menge.
Feste Zeit: `now` und `calendar` werden übergeben, nie `Date()` im geprüften Pfad (außer der Ausführer braucht `now` für die Revision; dann wird es ebenfalls übergeben).

## Alternativen

- **Claude liest CloudKit direkt über die CloudKit-Web-API, ohne Abschrift.** Verworfen: Das Webtoken gilt höchstens zwei Wochen; das `CD_`-Format von SwiftData müsste nachgebaut werden;
  es gäbe keine fertig berechneten Ansichten (Claude zeigte eine andere „Jetzt“-Zahl als die App); Schreiben ginge ohne Revision. Gekippt würde mit ihr die Annahme von Weg B, ADR-2 bliebe unberührt.
- **Die Abschrift trägt alle ~71 Felder von `TaskItem`.** Verworfen: Datensparsamkeit (Rohtext, Notizen und Anhänge verließen iCloud ohne Bedarf), und der Vertrag soll klein und stabil bleiben.
  Erweiterung später als Vertragsversion 2.
- **Aufträge ohne erwarteten Stand (letzter Schreiber gewinnt).** Verworfen: Claude arbeitet auf einer Abschrift, die veraltet sein kann; ein stilles Überschreiben widerspräche „Nothing is deleted“ und „Revisions, not undo“.
- **Den Auftrag direkt über `TaskActions.setDue` ausführen.** Verworfen: es verwirft die Revision, der Grund „Claude“ ließe sich nicht setzen. Gewählt ist der Weg von `SiriCapture.write`.

## Nicht in diesem Schnitt / Folgeschnitte

Folgeschnitte des Spikes (jeweils eigene Spec):

- C0 Umgebung (lokales `node` reparieren)
- C1 `server/`-Gerüst und Postgres-Schema
- C3 Dienstkern (Abschrift und Aufträge ohne Anmeldung, Auftrag geht an genau ein Gerät)
- C4 MCP-Werkzeuge `get_now`, `list_tasks`, `create_order`
- C5 A/B-Nachweis gegen den laufenden Dienst
- C7 Betrieb auf Hetzner (rennwienix) samt Speichermessung
- C6a OAuth mit node-oidc-provider
- C6b Mit Apple anmelden (Web-Ablauf)
- C8 ADR-21

Haltepunkte bei Henning: Halt 1 nach C5 und C7, Halt 2 nach C6.

Außerdem nicht hier, als eigene Tickets nach dem Spike: Verschieben der UI-Ordnung von „Fällig“ und „Lose Enden“ nach `ViewRules`; weitere Aufträge (parken, verschieben, „Als nächstes“); Kontolöschung mit Apple-Widerruf;
Datenschutztext (#625); Anbindung in der App (Senden der Abschrift, Abholen der Aufträge beim Öffnen und im Hintergrundlauf).

## Abnahme

Stufe 1: Unit-Tests (`TranscriptCodecTests`, `OrderExecutorTests`, voller Lauf) grün. Stufe 2: Simulator-Bau (`./scripts/sim.sh build`) erfolgreich; ein sichtbarer Ablauf ist nicht geändert, der Unit-Lauf im Simulator
ist der Nachweis. Stufe 3 entfällt: Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt
- [ ] `TranscriptCodecTests` und `OrderExecutorTests` grün; voller Unit-Lauf grün; `sim.sh build` baut
- [ ] `docs/reference/claude-abschrift-vertrag.md` im Repo, Beispiele identisch mit den Fixtures
- [ ] #613 kommentiert (Stand Schnitt 1, Folgeschnitte), Board-Karte aktuell

## Changelog

- 2026-10-31: Initial (Schnitt 1, App-Seite)
