---
entity_id: feat-1000-schnitt-3b-toenung-und-katalog
type: feature
created: 2026-11-27
updated: 2026-11-27
status: draft
workflow: feat-1000-s3b-toenung
---

# Spec: Tönung „noch nicht angesehen“ und Katalogschlüssel von „Neu“ entfallen, Schnitt 3b (Feature #1000, Epic #999)

## Approval

- [ ] Approved

## GitHub Issue

#1000 (Epic #999). Henning, 2026-11-26: „Neu“ entfällt ganz; Entwurf A freigegeben (Tönung weg); Entscheidung ADR-22.
Letzter Schnitt nach S1 (PR #1004), S2 (PR #1005) und S3a (PR #1007).

## Purpose

Ohne Modell und ohne „Neu“ gibt es nichts mehr, worauf die Zeile hinweisen müsste: Ein Merkmal, das eine Regel aus dem
Gesagten gesetzt hat (Etikett, Dauer, Datum), erscheint wie jedes andere grau, die Uhrzeit am Rand grau oder rot bei
Zeitdruck. Akzentfarbe bleibt allein dem Antippbaren (Farbbudget). Dazu verschwinden die Texte, die kein Code mehr zeigt,
aus dem Übersetzungskatalog, und die Doku beschreibt den Stand ohne Tönung.

## Was darf sich nicht ändern

- Rot am Rand für Zeitdruck, der Knopf „Neues Datum“ in Akzent, Perle und Knäuel in der Merkmalzeile.
- Rangfolge und Anzahl der Merkmale (höchstens drei), Zeilenhöhe.
- Änderungsliste, `seenAt`, `RevisionService.markSeen` und `TaskItem.hasUnseenAutomaticRevisions` (Detail und Tests lesen sie weiter).
- Kursivschrift des Titels für Rohtext und `.unverified` (`TaskRow`, Altbestand).
- Alle übrigen Katalogschlüssel und ihre Übersetzungen.

## Alternativen

1. Tönung für Änderungen durch Claude behalten — widerspricht Entwurf A und ADR-22; das Detail zeigt „Zuletzt von Claude“. Verworfen.
2. Katalogschlüssel stehen lassen — tote Übersetzungen, Xcode meldet sie als veraltet. Verworfen, kippt keine ADR.
3. `hasUnseenAutomaticRevisions`/`seenAt` mit entfernen — Modelländerung (CloudKit nur additiv), eigenes Ziel. Nicht hier.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-22
- **Rationale:** Bestehende Entscheidung (Epic #999). Mit diesem Schnitt fällt der KI-Marker „Variante C“ (Design-Briefing,
  Screen 3; #101) und die Ausnahme „incl. AI tint“ im Farbbudget (ADR-14). Keine neue ADR.

## Source

- `LooseEnds/Views/TaskRow.swift` (MODIFY): Rand, Funke, `Trait.tinted`
- `LooseEnds/Views/Paper.swift` (MODIFY): `wideNoteInsets` entfernen
- `LooseEnds/Resources/Localizable.xcstrings` (MODIFY): neun Schlüssel entfernen
- `Shared/Models/TaskItem.swift` (MODIFY, nur Kommentar an `hasUnseenAutomaticRevisions`)
- `Shared/Models/ViewRules.swift` (MODIFY, nur Kommentar in `tasks(for:in:)`)

## Dependencies

| Abhängigkeit | Art | Wirkung |
|---|---|---|
| `TaskItem.hasUnseenAutomaticRevisions`, `FieldSource.isAutomatic` | gerufen von `TaskRow` | die Zeile ruft sie danach nicht mehr; Detail und Tests weiter |
| `scripts/test_catalog_languages.py` | Katalogwächter | Vollständigkeit je Sprache bleibt grün |
| `LooseEndsUITests/InboxDrawerSmokeTests.swift` | UI-Test | Zeilen nach dem Erfassen, Bild `1000-5-lose-enden` zeigt das Etikett |
| Mac Gallery (CI) | Fotos der Zeilen | Tönung verschwindet, sonst nichts |

## Scope

- 5 App-Dateien (2 davon nur Kommentar), ca. −30 LoC Swift; Katalog ist Ressource.
- Test (zählt nicht zum LoC-Limit): `LooseEndsTests/CatalogWithoutNewTests.swift` (CREATE).
- Doku: `docs/project/03-design-briefing.md`, `docs/reference/funktionsuebersicht.md`, CLAUDE.md (Ground rule und Farbbudget).
- Nicht: weitere Kommentare, die „New“ als Geschichte nennen (`SidebarView:5`, `StartPage:70`, `InboxDrawer:4`, `DetailBack:4`,
  `SideColumnView:4`, `GuessedProjects`, `EnrichmentCoordinator:75`); kein Verhalten, Dateigrenze.

## Implementation Details

- `TaskRow.margin`: `unseenAI` entfällt; Stil `mark.pressing ? .red : .secondary`.
- `TaskRow.lines`: der Block `if task.hasUnseenAutomaticRevisions, task.titleSourceRaw == FieldSource.ai.rawValue { Image("sparkle") … }` entfällt.
- `TaskRow.Trait`: `tinted` und `style` entfallen, Merkmale nutzen `.secondary` direkt; `traits` ohne `unseen`.
- Kopfkommentar (:6) und Randkommentar (:57–58) ohne KI-Tönung.
- `Paper.wideNoteInsets` samt Kommentar löschen.
- Katalog: die neun Schlüssel „New“, „%lld to look over“, „Looks right“, „Needs a look“, „was: %@“, „Title not checked“,
  „Not sorted yet“, „Nothing to look over.“, „Changed by AI“ als ganze Einträge entfernen; Xcode-Format (2 Leerzeichen,
  `" : "`) erhalten, damit „Generate leaves the tree clean“ grün bleibt.
- `TaskItem.swift:182–183`: „Unseen revisions by a rule feed the change list and the detail's seen mark (#101).“ ohne Liste und „New“.
- `ViewRules.swift:334`: „(Old, Waiting)“ statt „(New, Old, Waiting)“.

## Test Plan

### Automated Tests (TDD RED)

- `LooseEndsTests/CatalogWithoutNewTests.swift` (neu, Swift Testing):
  - GIVEN das gebaute App-Bündel, in das Xcode `LooseEnds/Resources/Localizable.xcstrings` je Sprache übersetzt (`Bundle.main`, Tabelle `Localizable` für `de`, per `Bundle.main.path(forResource:ofType:inDirectory:forLocalization:)`) WHEN die neun Schlüssel gesucht werden THEN fehlt jeder (RED: alle vorhanden).
  - GIVEN dasselbe Bündel THEN sind Stichproben, die bleiben („New date“, „Now“), weiter da (Schutz gegen Leeren des Katalogs).
- `python3 scripts/test_catalog_languages.py` grün (Vollständigkeit).
- UI: `./scripts/sim.sh test-proof InboxDrawerSmokeTests` (Zeile nach dem Erfassen, „Looks right“ fehlt).
- Sichtbeleg: Bild `1000-5-lose-enden` aus `InboxDrawerSmokeTests` („Mama anrufen“ mit Regel-Etikett „Phone“): vorher Petrol (`docs/artifacts/feat-1000-s3b-toenung/vorher-lose-enden.png`, Lauf S3a), nachher grau.

## Acceptance Criteria

- **AC-1:** Eine Aufgabe, deren Merkmal (Etikett, Dauer, Datum am Rand) eine Regel gesetzt hat und die noch nicht geöffnet wurde, zeigt dieses Merkmal in Grau wie jedes andere; Akzent erscheint in der Zeile nur am Knopf „Neues Datum“, Rot nur bei Zeitdruck. Beleg: Code-Pfad `TaskRow` ohne `.tint` außer im Knopf, Screenshot.
- **AC-2:** Keine Zeile trägt mehr den Funken „Changed by AI“ (`aiMarker_<id>`). Beleg: Code-Pfad, Suche ohne Treffer.
- **AC-3:** Die neun Katalogschlüssel fehlen im Katalog und im gebauten Bündel; alle übrigen Schlüssel und der Katalogwächter bleiben grün. Beleg: `CatalogWithoutNewTests` grün, `test_catalog_languages.py` grün.
- **AC-4:** `Paper.wideNoteInsets` existiert nicht mehr; Build grün. Beleg: Suche ohne Treffer, Build.
- **AC-5:** Design-Briefing (Screen 3/4), Funktionsübersicht und CLAUDE.md beschreiben die Zeile ohne KI-Tönung und die Ansichten ohne „Neu“. Beleg: Diff der Doku.

## Risiken

- Xcode schreibt den Katalog beim Bauen um → nach dem Bauen `git diff` des Katalogs prüfen.
- Ein noch gerufener Schlüssel fiele auf Englisch zurück → Suche (Stand 2026-11-27) ergab nur Kommentare.

## Definition of Done

- [ ] Build grün (`./scripts/sim.sh generate`, dann `./scripts/sim.sh build`)
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh unit`)
- [ ] Alle UI-Tests grün (CI, auch `ui-smoke-lang` und „Mac Gallery (macOS)“); Simulatorbeleg über `./scripts/sim.sh test-proof InboxDrawerSmokeTests`
- [ ] Gerätestufe: Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2.
- [ ] Doku nachgezogen (Design-Briefing, Funktionsübersicht, CLAUDE.md)
- [ ] Ausgeliefert: PR mit `Closes #1000`, CI grün, gemergt; Board Done

## Changelog

- 2026-11-27: Erstfassung (Teil 3b nach S3a).
