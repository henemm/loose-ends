---
entity_id: feat-98-deutsche-begruendungen
type: feature
created: 2026-09-21
updated: 2026-09-21
status: draft
workflow: feat-98-deutsche-begruendungen
---

# Spec: #98 — Deutsche Begründungstexte der Terminregel

## Approval

- [ ] Approved

## Purpose

`DueDateRule.reason(for:)` (#95) liefert für jede der neun Ausdrucksarten einen Begründungssatz über
`String(localized:)`, den `TaskDetailView` und `FieldEditorView` unverändert anzeigen. Diese neun
Schlüssel fehlen im String-Katalog `LooseEnds/Resources/Localizable.xcstrings` komplett — auf einem
deutschen Gerät fällt die Anzeige auf den englischen Schlüsseltext zurück, obwohl der Katalog für
`de` sonst vollständig ist. Diese Spec ergänzt die neun deutschen Übersetzungen im Katalog und
beweist per Unit-Test, dass das gehostete `de.lproj`-Bundle sie liefert. Kein Produktcode ändert
sich.

## Source

- **Datei:** `LooseEnds/Resources/Localizable.xcstrings`
- **Bezeichner:** neun neue `de`-Einträge, Keys wörtlich aus `Shared/Enrichment/DueDateRule.swift`
- **Datei:** `Shared/Enrichment/DueDateRule.swift` (unverändert, liefert die neun Original-Schlüssel)

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `DateExpression`-Fälle in `DateExpressionParser` (#92/#95, unverändert) | Enum | Legen Anzahl und Bedeutung der neun Sätze fest (`offsetDays`, `weekday`, `weekdayNextWeek`, `weekdayEitherNext`, `endOfMonth`, `dayOfMonth`, `weekend`, `monthRange`, `dayAndMonth`). |
| `DueDateRule.reason(for:)` (#95, unverändert) | Funktion | Erzeugt die neun englischen Schlüsseltexte über `String(localized:)`, wörtlich zu übernehmen. |
| `Localizable.xcstrings` | String-Katalog | `sourceLanguage: en`, 125 vorhandene Schlüssel, `de` sonst vollständig — Ziel der Ergänzung. |
| `TaskDetailView.swift:183-184`, `FieldEditorView.swift:32-33` | Views | Zeigen `revision.reason` unverändert an — kein Konsument wird angefasst. |
| `project.yml` (`SWIFT_EMIT_LOC_STRINGS`, `LOCALIZATION_PREFERS_STRING_CATALOGS`, `TEST_HOST`) | Konfiguration | Automatische Extraktion bei `generate`; `LooseEndsTests` läuft mit `TEST_HOST` gegen `LooseEnds.app`, wodurch `Bundle.main` im Testprozess der App-Bundle ist. |

## Scope

Innerhalb des Limits (2 Dateien, ±5–50 LoC-Regel gilt hier nicht wörtlich, da reine Katalogdaten;
geschätzt ~120 LoC gesamt, überwiegend generierte JSON-Struktur, kein Funktionscode über 50 LoC).

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Neun `de`-Übersetzungen ergänzen (~+80 LoC reine JSON-Katalogdaten), Keys wörtlich aus `DueDateRule.swift` kopiert (Anführungszeichen exakt „…", nicht neu getippt), `extractionState` je neuem Eintrag auf `translated`. |
| `LooseEndsTests/DueDateRuleTests.swift` | MODIFY | Neuer Test (~+40 LoC): für jeden der neun Reason-Keys existiert im gehosteten `de.lproj`-Bundle eine Übersetzung, die vom Schlüssel selbst abweicht. |

Kein Produktcode ändert sich — `DueDateRule.swift`, `EnrichmentDraft.swift`, `EnrichmentWriter.swift`,
`Revision.swift`, `TaskDetailView.swift`, `FieldEditorView.swift` bleiben unangetastet.

### Nicht-Scope

- **Uhr, Widgets, Teilen-Erweiterung:** bauen `Shared/` mit, sehen den Haupt-App-Katalog
  `LooseEnds/Resources/Localizable.xcstrings` aber nicht. Aktuell zeigt keine dieser Oberflächen
  `revision.reason` an; wird das relevant, ist es ein eigenes Ticket.
- **UI-Test:** nicht nötig (siehe Implementation Details) — Projektregel verlangt UI-Tests erst nach
  Design-Freeze und nur als Smoke-Test; dieses Ticket ist reine Content-Ergänzung, kein
  UI-Verhalten.
- **Weitere Sprachen oder dynamische Satzbausteine** (z. B. konkretes Datum im Satz): siehe
  „Alternative" unten, nicht Teil dieses Tickets.

## Implementation Details

**Kein UI-Test nötig.** `LooseEndsTests` läuft mit `TEST_HOST` gegen `LooseEnds.app`
(project.yml:195-210), `Bundle.main` im Testprozess ist damit der App-Bundle.
`Bundle.main.path(forResource: "de", ofType: "lproj")` liefert das kompilierte Katalog-Bundle,
`localizedString(forKey:value:table:)` mit den neun Original-Schlüsseln aus `DueDateRule.swift`
prüft exakt den Laufzeit-Mechanismus, deterministisch, ohne Async-Timing. Ein zusätzlicher UI-Test
(Sprache erzwingen, Task erfassen, Enrichment abwarten, Text lesen) würde denselben Bundle-Lookup
nur über eine deutlich fragilere Kette (Async-Timing der Enrichment-Pipeline,
Datumsausdruck-Erkennung, UI-Rendering) erneut zeigen — kaum zusätzliche Beweiskraft, deutlich mehr
Flakiness-Risiko.

**TDD RED:** Test zuerst schreiben (erwartet für jeden der neun Keys eine deutsche Übersetzung, die
vom Key abweicht) → schlägt fehl, da der Katalog noch keine `de`-Einträge für diese Keys hat und
`localizedString` auf den Key selbst zurückfällt. Danach die neun Katalog-Einträge ergänzen → GREEN.

**Anführungszeichen-Exaktheit:** Die vier Keys mit typografischen Anführungszeichen (`weekdayEitherNext`,
`endOfMonth`, `weekend`, `monthRange`) müssen im Katalog byte-exakt wie im Swift-Quelltext (`"…"`)
stehen, sonst legt Xcode bei der nächsten Neuextraktion einen zweiten, leeren Eintrag an und die
Übersetzung „verschwindet" unbemerkt. Gegenmaßnahme: Keys direkt aus `DueDateRule.swift` kopieren,
nicht neu tippen. Der Unit-Test deckt eine falsche Kopie sofort auf, weil die Testkeys aus derselben
Quelle stammen wie die Katalog-Keys.

**Übersetzungsentwurf** (Stil an bestehenden Katalog-Einträgen orientiert — kurz, sachlich, keine
Redundanz-Punkte; deutsche Anführungszeichen „…" in der Übersetzung, die englischen Schlüssel selbst
bleiben mit "…" unverändert):

| Case | Englischer Schlüssel (Katalog-Key, unverändert) | Deutsche Übersetzung |
|------|--------------------------------------------------|------------------------|
| offsetDays | From a day count in the note. | Aus einer Tagesangabe in der Notiz. |
| weekday | From the weekday named in the note. | Aus dem Wochentag in der Notiz. |
| weekdayNextWeek | From a weekday of next week in the note. | Aus einem Wochentag der nächsten Woche in der Notiz. |
| weekdayEitherNext | From "next" plus a weekday in the note: the following week. | Aus „nächsten" plus Wochentag in der Notiz: die Folgewoche. |
| endOfMonth | From "end of the month" in the note. | Aus „Ende des Monats" in der Notiz. |
| dayOfMonth | From the day of the month in the note. | Aus dem Tag des Monats in der Notiz. |
| weekend | From "weekend" in the note: Saturday. | Aus „Wochenende" in der Notiz: Samstag. |
| monthRange | From "next month" in the note: the first of that month. | Aus „nächsten Monat" in der Notiz: der Erste des Monats. |
| dayAndMonth | From the day and month in the note. | Aus Tag und Monat in der Notiz. |

## Expected Behavior

Given ein deutsches Gerät oder ein Testlauf, der das gehostete `de.lproj`-Bundle abfragt, When einer
der neun `DueDateRule`-Begründungssätze über `revision.reason` angezeigt oder direkt aus dem Katalog
gelesen wird, Then erscheint der deutsche Übersetzungstext aus der Tabelle oben statt des englischen
Schlüsseltexts. Der Regelparser selbst (#95) ändert kein Verhalten — nur die Übersetzung der bereits
vorhandenen Sätze wird ergänzt.

## Acceptance Criteria

- **AC-1 Alle neun Keys haben eine deutsche Übersetzung:** Given das gebaute App-Bundle / When ein
  Unit-Test für jeden der neun Reason-Keys aus `DueDateRule.swift`
  (`offsetDays`, `weekday`, `weekdayNextWeek`, `weekdayEitherNext`, `endOfMonth`, `dayOfMonth`,
  `weekend`, `monthRange`, `dayAndMonth`) `Bundle.main.path(forResource: "de", ofType: "lproj")` lädt
  und `localizedString(forKey:value:table:)` aufruft / Then liefert jeder der neun Aufrufe einen
  String, der vom Schlüssel selbst abweicht.
- **AC-2 RED vor der Katalog-Ergänzung, GREEN danach:** Given der neue Test in
  `DueDateRuleTests.swift`, geschrieben bevor die Katalog-Einträge ergänzt sind / When
  `./scripts/sim.sh unit` läuft / Then schlägt der Test fehl (RED), weil `localizedString` mangels
  `de`-Eintrag auf den Key zurückfällt; nach Ergänzung der neun Katalog-Einträge läuft derselbe Test
  grün (GREEN), ohne dass der Test selbst verändert wurde.
- **AC-3 Anführungszeichen-Exaktheit, kein Duplikat-Key nach Neuextraktion:** Given die vier Keys mit
  typografischen Anführungszeichen (`weekdayEitherNext`, `endOfMonth`, `weekend`, `monthRange`) im
  Katalog / When `xcodegen generate` und ein Build laufen (löst ggf. Neuextraktion aus) / Then bleibt
  in `Localizable.xcstrings` je Key genau ein Eintrag (kein zweiter, leerer Eintrag mit
  abweichenden Anführungszeichen) — geprüft durch Zählen der Vorkommen des exakten Schlüsseltexts im
  Katalog-JSON.
- **AC-4 Übersetzungstext entspricht dem Entwurf:** Given die neun Katalog-Einträge / When ihr `de`-
  Wert mit der Tabelle im Abschnitt „Implementation Details" verglichen wird / Then stimmt jeder der
  neun Werte wörtlich überein.
- **AC-5 `extractionState` steht auf `translated`:** Given die neun neuen Katalog-Einträge / When das
  Katalog-JSON inspiziert wird / Then trägt jeder neue `de`-Eintrag `"extractionState" : "translated"` —
  abweichend von den 125 vorhandenen Einträgen, die kein `extractionState`-Feld tragen (siehe
  Changelog 2026-09-21).
- **AC-6 Kein Produktcode geändert:** Given der fertige Stand / When der Versionsvergleich außerhalb
  von `LooseEnds/Resources/Localizable.xcstrings`, `LooseEndsTests/DueDateRuleTests.swift` und den
  Standard-Workflow-Dokumenten (`docs/specs`, `docs/briefings`, `docs/context`, `docs/artifacts`)
  geprüft wird / Then ist außer diesen Dateien kein Swift-Produktcode unter `Shared/` oder
  `LooseEnds/` verändert (siehe Changelog 2026-09-21).

## Test Plan

### Automated Tests (TDD RED)

**Neu**
- `LooseEndsTests/DueDateRuleTests.swift`: GIVEN das gehostete `de.lproj`-Bundle aus
  `Bundle.main` (TEST_HOST = `LooseEnds.app`) / WHEN für jeden der neun Reason-Keys aus
  `DueDateRule.swift` `localizedString(forKey:value:table:)` aufgerufen wird / THEN weicht das
  Ergebnis vom Key selbst ab (AC-1). Test zuerst ohne Katalog-Einträge geschrieben → RED, nach
  Katalog-Ergänzung → GREEN, ohne den Test zu verändern (AC-2).

**Unverändert**
- Bestehende Fälle in `DueDateRuleTests.swift` (`!reason.isEmpty`, paarweise Verschiedenheit der neun
  Sätze) bleiben unverändert grün — sie prüfen den englischen Quelltext, nicht die Übersetzung.

**Manuell geprüft, nicht als Xcode-Testfall (Katalog-Struktur):**
- `python3 -m json.tool LooseEnds/Resources/Localizable.xcstrings` gegen Parse-Fehler (Teil der
  Definition of Done, kein XCTest — reine Syntaxprüfung von JSON).
- Zählen der Vorkommen der vier anführungszeichen-kritischen Keys im Katalog-JSON zur Prüfung von
  AC-3 (Duplikat-Erkennung), z. B. `grep -c` auf den exakten Schlüsseltext.

Kein UI-Test: siehe „Implementation Details" — reiner Content, kein UI-Verhalten, Projektregel
verlangt UI-Tests erst nach Design-Freeze und nur als Smoke-Test.

## Alternative (geprüft, nicht empfohlen)

`reason(for:)` liefert statt eines fertigen Satzes einen strukturierten Fall (Enum), die View baut
den Satz lokal per `switch` + `String(localized:)`. Würde die bestehende Festlegung aus #95 kippen
("eine Funktion liefert den fertigen, bereits lokalisierten Satz") und Produktcode in `DueDateRule`,
`EnrichmentDraft`, `EnrichmentWriter`, `TaskDetailView` und `FieldEditorView` anfassen — für eine
reine Übersetzungslücke unverhältnismäßig. Nicht empfohlen; als Alternative hier festgehalten, falls
künftig weitere Sprachen oder dynamische Satzbausteine (z. B. das konkrete Datum im Satz) gebraucht
werden — dann würde sich die Abwägung ändern.

## Definition of Done

- [ ] AC-1 bis AC-6 erfüllt, belegt durch die im Test Plan genannten Tests
- [ ] Build erfolgreich (`./scripts/sim.sh build` ohne Errors)
- [ ] Alle Unit Tests grün (inkl. neuer Test in `DueDateRuleTests.swift`), `./scripts/sim.sh unit`
- [ ] Katalog-JSON valide (`python3 -m json.tool LooseEnds/Resources/Localizable.xcstrings`)
- [ ] Kein manueller Testhinweis an Henning — jede Acceptance Criterion ist automatisiert bewiesen
- [ ] Jeder Commit kompiliert
- [ ] Drei Abnahmestufen durchlaufen: Tests → Simulator → Hennings iPhone 16 Pro
      (`./scripts/sim.sh device`) — kein Schritt entfällt, TestFlight ist kein Ersatz dafür
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
      (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] PR referenziert #98 (`Closes #98`)
- [ ] CI grün

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Übersetzungsergänzung innerhalb des bestehenden Lokalisierungsmechanismus
  (`String(localized:)` + String-Katalog, `SWIFT_EMIT_LOC_STRINGS`/`LOCALIZATION_PREFERS_STRING_CATALOGS`
  in `project.yml`). Kein neuer Architekturbaustein, keine neue Schicht, keine Abweichung von ADR-3
  (Rohtext unveränderlich, abgeleitete Felder mit Herkunft und Konfidenz — hier unberührt) oder der
  Festlegung aus #95 ("eine Funktion liefert den fertigen, bereits lokalisierten Satz").

## Changelog

- 2026-09-21: Spec aus dem Analyse-Kontext (`docs/context/feat-98-deutsche-begruendungen.md`)
  erstellt.
- 2026-09-21: Umsetzung VERIFIED (Adversary-Protokoll
  `docs/artifacts/feat-98-deutsche-begruendungen/adversary-dialog.md`), AC-1 bis AC-4 ohne
  Einschränkung. AC-5- und AC-6-Wortlaut redaktionell korrigiert (Findings F001, F002 aus dem
  Adversary-Protokoll, nicht blockierend): Keiner der 125 vorhandenen Katalog-Einträge trägt ein
  `extractionState`-Feld — die neun neuen Einträge sind darin die einzige Ausnahme, nicht
  „konsistent" mit dem Bestand. AC-6 zählte ursprünglich auch die zwingenden Workflow-Artefakte
  (Spec, Briefing, Kontext, RED-Testlauf-Bericht) zum Diff und war damit nie wörtlich erfüllbar;
  gemeint war „kein Swift-Produktcode geändert" — das ist geprüft und zutreffend.
