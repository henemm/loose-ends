---
entity_id: feat-622-schnitt-2-claude-sichtbar
type: feature
created: 2026-11-15
updated: 2026-11-15
status: draft
workflow: feat-622-s2-claude-sichtbar
---

# Spec: Was Claude geändert hat, ist im Detail sichtbar, Schnitt 2 (Sichtbarkeit, #622)

## Approval

- [ ] Approved

## GitHub Issue

#622 (Epic #612). Schnitt 2 von 2; das Issue bleibt auch danach offen (PR mit `Refs #622`, nie `Closes #622`), weil der claude.ai-Nachweis aus dem Ticket noch aussteht (braucht die angemeldete App, #615; Nacharbeit von Claude, kein AC hier).
Analyse: `docs/context/feat-622-s2-claude-sichtbar.md`, Gesamtanalyse `docs/context/feat-622-claude-verlauf.md`. Vorgänger: Schnitt 1 (`docs/specs/feat-622-schnitt-1-claude-revisionen.md`, PR #927): jeder Auftrag von Claude schreibt eine Nutzer-Revision mit Grund „Claude“.

## Purpose

Seit Schnitt 1 liegt jede Änderung durch Claude als Revision vor, aber die App zeigt sie nicht: die Einstiegszeile am Ende des Details erscheint nur, wenn die App selbst Felder gesetzt hat, und im Änderungsblatt steht Claude als „Du“ mit der Fußnote „Claude“. Dieser Schnitt setzt den von Henning am 2026-11-15 gewählten Entwurf A um (`docs/artifacts/feat-622-claude-verlauf/index.html`): die bekannte Zeile erscheint auch, wenn nur Claude etwas geändert hat, und nennt es („Zuletzt von Claude · heute 14:02“); das Blatt dahinter zeigt „Claude“ als Urheber.

**Regeln vor Modell:** reine Anzeigelogik über vorhandene Revisionsdaten, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- Keine neue Zeile oben unter „Gesagt“ (Entwurf B, von Henning nicht gewählt).
- Kein Abzeichen für ungesehene Claude-Änderungen: Claude handelt auf die Worte des Nutzers, das Abzeichen gilt Vermutungen der KI. Das Verhalten bleibt unverändert und wird nur abgesichert (AC-9).
- Die Erfassung durch Claude wird nicht benannt (siehe Known Limitations).
- Kein neuer Autor `FieldSource.claude` (siehe Alternativen), keine Änderung an Modell, Schema, Auftragsvertrag oder Dienst.
- Der claude.ai-Nachweis (siehe oben).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Claude bleibt wie in Schnitt 1 entschieden Daten (Autor `.user`, Grund „Claude“), dieser Schnitt liest sie nur; keine bestehende ADR fällt, es gibt keinen Schemawechsel.
- **Rationale:** reine Anzeige über schon vorhandene Revisionen.

## Source

**Files:** `Shared/Services/RevisionService.swift`, `LooseEnds/Views/FieldFormatting.swift`, `LooseEnds/Views/TaskDetailView.swift`, `LooseEnds/App/LooseEndsApp.swift`, `LooseEnds/Resources/Localizable.xcstrings`, `LooseEndsTests/RevisionServiceClaudeTests.swift`, `LooseEndsUITests/ClaudeChangeTests.swift`
**Identifier:** `RevisionService.lastClaudeChange(on:)`, `RevisionService.isByClaude(_:)`, `FieldFormatting.author(of:)`, `TaskDetailView.originSummary`, `RevisionsSheet`

## Implementation Details

### Eine reine Abfrage in `RevisionService`

Claude ist die Marke `author == .user && reason == OrderExecutor.reason` (verifiziert: `OrderExecutor.reason = "Claude"`, `Shared/Services/OrderExecutor.swift:43`).

- `isByClaude(_ revision: Revision) -> Bool`: genau diese Marke. KI-, Regel- und Nutzerrevisionen ohne oder mit anderem Grund sind es nicht.
- `lastClaudeChange(on task: TaskItem) -> Revision?`: die Revision der Aufgabe mit `isByClaude`, deren `createdAt` am neuesten ist; nil, wenn es keine gibt. Die Ansicht liest nur diese Abfrage, sie bestimmt die Marke nirgends selbst.

### Einstiegszeile im Detail

Verifiziert: die Zeile steht in `TaskDetailView` (ca. Zeilen 223-235) unter `if !aiFields.isEmpty`, `originSummary` (ca. 375-382) setzt „N aus deinen Worten · N von der KI“ zusammen. Neu:

- Die Zeile erscheint, wenn `aiFields` nicht leer ist **oder** `lastClaudeChange(on:)` nicht nil ist.
- Text nur Claude: „Zuletzt von Claude · heute 14:02“. Beides: „2 aus deinen Worten · Zuletzt von Claude · heute 14:02“ (der Claude-Teil wird angehängt, die bekannte Zusammenfassung bleibt vorn). Nur automatische Felder: unverändert.
- Zeitform: relativer Tag plus Uhrzeit. Heute: „heute 14:02“, gestern: „gestern 09:10“, älter: Datum plus Uhrzeit nach `.dateTime.day().month().hour().minute()` (wie im Blatt). Die Wörter „heute“/„gestern“ kommen aus `Calendar.isDateInToday`/`isDateInYesterday` und Katalogschlüsseln mit Platzhalter für die Uhrzeit, nicht aus einem festen Text.
- Tippen auf „Zeigen“ öffnet dasselbe Änderungsblatt (`showsRevisions`). Die Kennungen `originSummary` und `revisionsButton` bleiben (`DesignGalleryTests`, `DriveSmokeTests` finden sie).

### Änderungsblatt

Verifiziert: `RevisionsSheet` (ca. 847-905) zeigt den Urheber über `FieldFormatting.author(revision.author)` und die Fußnote `revision.reason`; Zurücksetzen je Zeile gibt es nur für `revision.author.isAutomatic`; die Symbolleiste hat „Reset all“, das über `RevisionService.revertAll` nur automatische Revisionen anfasst.

- Neue `FieldFormatting.author(of revision: Revision) -> String`: „Claude“ für die Claude-Marke, sonst unverändert `author(_:)` (verifiziert: `FieldFormatting.swift:145`).
- Der Urheber „Claude“ steht in `.secondary` (grau wie „Du“), weil `isAutomatic` für `.user` falsch bleibt.
- Kein Zurücksetzen-Knopf an Claude-Zeilen (folgt aus `.user`, kein neuer Code, durch Test belegt). „Reset all“ in der Symbolleiste bleibt, wie es ist, und lässt Claude-Zeilen unberührt.
- Die Fußnote mit dem Grund entfällt für die Claude-Marke, damit „Claude“ nicht doppelt steht; jeder andere Grund bleibt sichtbar.

### Saat für den UI-Test

Verifiziert: das Muster `seedLeftoversIfAsked` in `LooseEndsApp.swift` (ca. 111-140) legt unter einem `--ui-testing-*`-Flag und nur mit `ModelContainerFactory.isUITesting` Aufgaben im Speicher-Store an. Neu: `seedClaudeChangeIfAsked` mit dem Flag `--ui-testing-claude-change`: legt eine offene Aufgabe an und führt darauf einen echten `OrderExecutor.execute`-Auftrag (`setDue`, erwarteter Status `active`, erwartetes Datum nil) aus. Es entsteht also der echte Auftragsweg samt Revision, keine handgemachte. Fehler werden mit `Logger` gemeldet, nie verschluckt.

### Katalog

Neue Schlüssel in `LooseEnds/Resources/Localizable.xcstrings` mit deutschem und englischem Wert (alle Sprachen aus `LanguagePacks.shipped`): „Last by Claude · %@“, „today %@“, „yesterday %@“; für „Claude“ als Urheber ein Schlüssel, weil `String(localized:)` ihn braucht. `scripts/test_catalog_languages.py` muss grün bleiben.

### Entscheidungen

- `park` lässt `nextRank` ohne eigene Zeile fallen: der Status „Geparkt“ sagt es, die App selbst schreibt beim Parken ebenfalls keine Rangzeile.
- Die Erfassung durch Claude wird nicht benannt (keine Revision, der Rohtext ist die Diktatzeile des Nutzers).

## Dependencies

| Entität | Art | Zweck |
|---|---|---|
| `Shared/Services/OrderExecutor.swift` (`reason`, `execute`) | bestehend, unverändert | Quelle der Marke, echter Auftragsweg in der Saat |
| `Shared/Models/Revision.swift` | bestehend, unverändert | `author`, `reason`, `createdAt` |
| `RevisionService.automaticFields`, `origin(of:)` | bestehend, unverändert | bestimmen weiter die automatischen Felder und das Abzeichen |
| `LooseEndsUITests/DriveSmokeTests.swift`, `DesignGalleryTests` | bestehend, unverändert | benutzen `originSummary`/`revisionsButton`, die Kennungen bleiben |
| `ModelContainerFactory.isUITesting` | bestehend | Schutz der Saat |
| Downstream | das eine gemeinsame Detail auf iPhone, iPad und Mac | |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung | LoC |
|---|---|---|---|
| `Shared/Services/RevisionService.swift` | MODIFY | `lastClaudeChange(on:)`, `isByClaude(_:)` | +12 |
| `LooseEnds/Views/FieldFormatting.swift` | MODIFY | `author(of:)` | +6 |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | Zeilenbedingung, Claude-Teil in `originSummary`, Blatt: Urheber, Grau, Fußnote | +30/-8 |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | Saat `--ui-testing-claude-change` | +25 |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | neue Schlüssel de/en | +12/-2 |
| `LooseEndsTests/RevisionServiceClaudeTests.swift` | CREATE | XCTest für die Abfrage | +50 |
| `LooseEndsUITests/ClaudeChangeTests.swift` | CREATE | UI-Test mit Screenshots | +45 |

### Estimated Changes

- Files: 7 (5 Produktivdateien, 2 Testdateien)
- LoC: etwa +180/-10 (Produktivcode etwa +85/-10, Tests etwa +95), unter dem Limit von ±250.

**Ehrlicher Ausweis zur Dateizahl:** Produktiv sind es fünf Dateien (Obergrenze 4–5 laut `openspec.yaml`), mit den zwei neuen Testdateien sieben. Der Schnitt bleibt ein Ziel („Claudes Spur sichtbar“); Tests gehören zu ihm und werden nicht abgetrennt. Die Schätzung der Analyse (+130/-10) war für den Produktivcode zu hoch angesetzt und ist hier nach Zeilen aufgeschlüsselt.

## Test Plan

### Automated Tests (TDD RED)

XCTest in `LooseEndsTests/RevisionServiceClaudeTests.swift` als Klasse `RevisionServiceClaudeTests: XCTestCase` (das QA-Gate zählt nur XCTest, kein Swift Testing); der Container wird in einer lokalen Variablen gehalten.

- [ ] Test 1: GIVEN eine Aufgabe mit zwei Claude-Revisionen (verschiedene `createdAt`) WHEN `lastClaudeChange(on:)` THEN die neuere.
- [ ] Test 2: GIVEN eine Aufgabe mit nur KI-, Regel- und Nutzerrevisionen ohne Grund WHEN `lastClaudeChange(on:)` und `isByClaude` THEN nil und false.
- [ ] Test 3: GIVEN eine Nutzerrevision mit anderem Grund (zum Beispiel „Siri“) und eine KI-Revision mit Grund „Claude“ WHEN `isByClaude` THEN beide false (Marke braucht Autor `.user` und Grund „Claude“).
- [ ] Test 4: GIVEN eine Aufgabe ohne Revisionen WHEN `lastClaudeChange(on:)` THEN nil.
- [ ] Test 5: GIVEN eine Claude-Revision und eine KI-Revision WHEN `automaticFields(on:)` THEN nur die KI-Felder (die Claude-Revision erscheint nicht, das Abzeichen bleibt unberührt).
- [ ] Test 6: GIVEN eine Claude-Revision WHEN `FieldFormatting.author(of:)` THEN „Claude“; GIVEN eine Nutzerrevision ohne Grund THEN weiter „Du“ (bzw. „You“).

UI-Test `LooseEndsUITests/ClaudeChangeTests.swift` (Start mit `--ui-testing-claude-change`, deutsche Sprache, Muster `DriveSmokeTests`):

- [ ] Test 7: GIVEN die Saat WHEN das Detail der Aufgabe geöffnet wird THEN `originSummary` ist erreichbar (`scrolledTo`) und sein Text enthält „Zuletzt von Claude“ und „heute“.
- [ ] Test 8: GIVEN das Detail WHEN `revisionsButton` getippt wird THEN das Blatt zeigt den Urheber „Claude“, keinen Knopf mit Kennung `resetRevision_…`, und das Wort „Claude“ steht in der Zeile genau einmal (keine Fußnote).
- [ ] Test 9: GIVEN das Detail und das Blatt WHEN Screenshots aufgenommen werden THEN je einer hell und dunkel (`shot`), vor dem Haken geöffnet und beschrieben.

### Abnahme

Stufe 1: neue Tests rot vor, grün nach der Umsetzung; alle Unit-Tests und `scripts/test_catalog_languages.py` grün. Stufe 2: `./scripts/sim.sh test-proof ClaudeChangeTests` mit registriertem Beleg, dazu `DriveSmokeTests` und `DesignGalleryTests`, weil sie dieselben Kennungen benutzen. Stufe 3: Kein Pfad der Geräteliste berührt (`LooseEnds/Views`, `LooseEnds/App`, `Shared/Services`, `Localizable.xcstrings` stehen nicht in der Tabelle).

## Acceptance Criteria

- **AC-1:** `RevisionService.lastClaudeChange(on:)` liefert die Claude-Revision (Autor `.user`, Grund „Claude“) mit dem neuesten `createdAt`, nil ohne eine solche (Tests 1 und 4, `RevisionServiceClaudeTests`).
- **AC-2:** KI-Revisionen, Regelrevisionen, Nutzerrevisionen ohne Grund und Nutzerrevisionen mit anderem Grund zählen nicht als Claude (`isByClaude` false) (Tests 2 und 3, `RevisionServiceClaudeTests`).
- **AC-3:** Hat nur Claude eine Aufgabe geändert, erscheint die Einstiegszeile im Detail mit dem Text „Zuletzt von Claude · <Tag> <Uhrzeit>“ (Test 7, `ClaudeChangeTests`).
- **AC-4:** Gibt es automatische Felder und eine Claude-Änderung, steht die bekannte Zusammenfassung vorn und der Claude-Teil angehängt; ohne Claude-Änderung bleibt der Text unverändert (Test 7 für den Claude-Teil, Test 5 für das Nebeneinander von KI- und Claude-Revision, bestehende Kennungen in `DriveSmokeTests`/`DesignGalleryTests` bleiben grün).
- **AC-5:** Die Zeit zeigt „heute“/„gestern“ plus Uhrzeit, für ältere Änderungen Datum plus Uhrzeit (Test 7, `ClaudeChangeTests`: die Saat ist von heute, der Text enthält „heute“).
- **AC-6:** Das Änderungsblatt zeigt für eine Claude-Revision den Urheber „Claude“ statt „Du“; `FieldFormatting.author(of:)` liefert dafür „Claude“ und für andere Revisionen unverändert das bisherige Wort (Tests 6 und 8).
- **AC-7:** Für Claude-Zeilen gibt es keinen Zurücksetzen-Knopf, und die Fußnote „Claude“ erscheint nicht zusätzlich zum Urheber; andere Gründe bleiben sichtbar (Test 8, `ClaudeChangeTests`).
- **AC-8:** Die Kennungen `originSummary` und `revisionsButton` bleiben, `DriveSmokeTests.testChangeListNamesTheBeadMarkInGerman` und `DesignGalleryTests` bleiben grün.
- **AC-9:** Das Ungesehen-Abzeichen zählt Claude-Änderungen nicht: `RevisionService.automaticFields` ignoriert die Claude-Revision (Test 5, `RevisionServiceClaudeTests`).
- **AC-10:** Die Saat `--ui-testing-claude-change` wirkt nur mit `ModelContainerFactory.isUITesting` und erzeugt die Revision über einen echten `OrderExecutor`-Auftrag (belegt durch Test 7: die Zeile erscheint ohne handgemachte Revision).
- **AC-11:** Alle neuen Katalogschlüssel haben deutsche und englische Werte; `scripts/test_catalog_languages.py` bleibt grün.
- **AC-12:** Alle Unit-Tests sind grün, und `./scripts/sim.sh test-proof ClaudeChangeTests` ist grün mit registriertem Beleg samt Screenshots hell und dunkel (Test 9).

## Definition of Done

- [ ] Neue Tests aus dem Test Plan rot vor der Umsetzung, grün danach; alle Unit-Tests grün
- [ ] `scripts/test_catalog_languages.py` grün
- [ ] `./scripts/sim.sh test-proof ClaudeChangeTests` grün, Beleg registriert; `DriveSmokeTests` und `DesignGalleryTests` grün
- [ ] Screenshots der Zeile und des Blatts (hell, dunkel) geöffnet und beschrieben
- [ ] Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“
- [ ] Ausgeliefert per PR mit `Refs #622`, CI grün, gemergt; #622 bleibt offen bis der claude.ai-Nachweis geführt ist, den Claude nach der Anmeldung der App (#615) selbst nachholt und im Issue festhält

## Alternativen

- **Neuer Autor `FieldSource.claude`:** sauberste Beschriftung, ändert aber die CloudKit-synchronisierten Rohwerte des Enums, die Zurücksetzen-Logik (`isAutomatic`) und die Lernlogik (ADR-5: Nutzerkorrekturen sind Beispiele). Würde die Entscheidung aus Schnitt 1 kippen; verworfen.
- **Eigene Zeile „Claude“ oben unter „Gesagt“ (Entwurf B):** fällt sofort auf, kostet aber Platz bei jeder angefassten Aufgabe; Henning hat A gewählt.
- **Abzeichen für ungesehene Claude-Änderungen:** verworfen, das Abzeichen gilt Vermutungen der KI, Claude handelt im Auftrag des Nutzers.
- Keine ADR fällt.

## Risiken

- **Zeilenbedingung:** Aufgaben, die nur durch Claude geändert wurden, zeigen nun eine Zeile, die vorher fehlte; das ist gewollt. Bestehende Tests, die die Abwesenheit der Zeile erwarten, gibt es nicht (Kennungen nur positiv benutzt, verifiziert in `DriveSmokeTests`).
- **Doppelte Anzeige „Claude“:** vermieden durch das Unterdrücken der Fußnote, die nur für die Claude-Marke gilt.
- **Tageswechsel:** „heute“ gilt zum Zeitpunkt der Darstellung; wird das Detail über Mitternacht offen gehalten, bleibt der Text bis zur nächsten Aktualisierung stehen. Harmlos, angenommen.
- **Dateizahl:** fünf Produktivdateien plus zwei Testdateien, siehe Scope; in der PR-Beschreibung genannt.

## Changelog

- 2026-11-15: Erste Fassung (Schnitt 2, Sichtbarkeit; Entwurf A von Henning gewählt).

## Known Limitations

- Eine Aufgabe, die Claude erfasst hat (`capturedVia == .claude`), bekommt keine Zeile, weil dabei keine Revision entsteht; die Zeile spricht nur von Änderungen. Eine eigene Formulierung wäre ein eigenes Ticket, falls gewünscht.
- Beim Parken durch Claude steht keine eigene „Als Nächstes“-Zeile im Blatt; der Status „Geparkt“ deckt es ab.
- Der claude.ai-Nachweis steht aus (siehe GitHub Issue).
