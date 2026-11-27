# Context: feat-1000-s3b-toenung (#1000 Schnitt 3b)

## Request Summary
Letzter Teil von #1000 (Epic #999, ADR-22). S3a (PR #1007, 2026-11-27) hat `ViewKind.new` und die Sichtungsregeln
entfernt. S3b nimmt die Tönung „noch nicht angesehen“ aus der Zeile (PO-Entscheid Entwurf A, 2026-11-26: Tönung weg),
entfernt `Paper.wideNoteInsets` (unbenutzt seit S2), die neun Katalogschlüssel, die kein Code mehr ruft, und zieht
Design-Briefing, Funktionsübersicht und CLAUDE.md nach. Teilung und Umfang: `docs/context/feat-1000-s3-neu-aufraeumen.md`.

## Related Files
| Datei | Stelle | Was |
|---|---|---|
| `LooseEnds/Views/TaskRow.swift` | :6 Kommentar, :57–58 Kommentar, :74–76 Rand-Tönung, :149–155 Funke „Changed by AI“ (`aiMarker_<id>`), :220–224 `Trait.tinted`/`style`, :232/250/257 `unseen`-Tönung | Rand grau oder rot, Merkmale immer `.secondary`, kein Funke |
| `LooseEnds/Views/Paper.swift` | :10–11 `wideNoteInsets` | entfernen (0 Aufrufer) |
| `LooseEnds/Resources/Localizable.xcstrings` | „New“, „%lld to look over“, „Looks right“, „Needs a look“, „was: %@“, „Title not checked“, „Not sorted yet“, „Nothing to look over.“, „Changed by AI“ | Schlüssel entfernen |
| `Shared/Models/TaskItem.swift` | :182–183 Kommentar „drive the marker in the list … keeps no task in New“ | Kommentar richtigstellen (Adversary S3a F002) |
| `Shared/Models/ViewRules.swift` | :334 Kommentar „(New, Old, Waiting)“ | „New“ streichen (Adversary S3a F001) |

Verwendung im Code (gezählt 2026-11-27, nur `*.swift` in App, Shared, Watch, Widgets, Share): „Changed by AI“ 1× (TaskRow),
„New“ und „Looks right“ nur in Kommentaren, die übrigen sieben 0×. Die anderen vier `*.xcstrings` tragen keinen der Schlüssel.

## Existing Patterns
- `Trait.style` ist die einzige Stelle, die Merkmalfarbe festlegt; ohne `tinted` bleibt `.secondary`.
- Farbbudget (CLAUDE.md, ADR-14): Akzent = antippbar; die KI-Tönung war die einzige Ausnahme, sie fällt.
- `scripts/test_catalog_languages.py` prüft Vollständigkeit, nicht Verwendung; Entfernen ganzer Schlüssel bleibt vollständig.
- `hasUnseenAutomaticRevisions` bleibt (Änderungsliste, `markSeen` im Detail, Tests); nur die Zeile liest es nicht mehr.

## Dependencies / Dependents
- UI-Tests: kein Test sucht `aiMarker_` oder „Changed by AI“; `InboxDrawerSmokeTests:111` prüft, dass „Looks right“ fehlt (bleibt gültig).
- Mac Gallery fotografiert die Zeilen; die Tönung verschwindet, sonst nichts.
- Kein Pfad der Geräteliste berührt.

## Existing Specs
`docs/specs/feat-1000-schnitt-3a-regeln-und-ansicht-neu.md`, S1/S2-Specs, ADR-22.

## Risks
- Xcode schreibt beim Bauen den Katalog um (CI „Generate leaves the tree clean“): nach dem Bauen Diff prüfen.
- Ein Schlüssel, der doch noch über `LocalizedStringKey`-Variable gerufen wird, fiele auf Englisch zurück: Suche ergab keine.

## Analysis

**Type:** Feature (Aufräumen, Löschungen; ADR-22, Entwurf A freigegeben 2026-11-26)

**Scope:** 5 App-Dateien (TaskRow, Paper, Katalog, TaskItem- und ViewRules-Kommentar), ca. −30 LoC Swift, Katalog ca. −200 Zeilen JSON
(Ressource), Doku außerhalb. Innerhalb der Grenze 4–5 Dateien.

Nicht in diesem Schnitt: weitere Kommentare, die „New“ als Geschichte nennen (`SidebarView:5`, `StartPage:70`, `InboxDrawer:4`,
`DetailBack:4`, `SideColumnView:4`, `GuessedProjects`, `EnrichmentCoordinator:75`) — kein Verhalten, Dateigrenze; die Kursivschrift
für `.unverified` (`TaskRow:148`, Altbestand).

**Technical Approach:** In `TaskRow` `unseenAI`, `unseen`, `Trait.tinted` und den Funken löschen; Rand `pressing ? .red : .secondary`.
`wideNoteInsets` löschen. Schlüssel per Skript aus dem JSON nehmen (Format von Xcode beibehalten: 2 Leerzeichen, `" : "`).
Test: Unit-Test kann Farben nicht lesen; Nachweis über UI-Test (eine Aufgabe mit ungesehener automatischer Revision zeigt keinen
`aiMarker_`) und Katalogtest (Schlüssel fehlen, Wächter grün), dazu Screenshot der Zeile im Simulator.

**Alternativen**
1. Tönung behalten für Änderungen durch Claude (Eingabekanal) — widerspricht Entwurf A und ADR-22; Claude-Änderungen zeigt schon „Zuletzt von Claude“ im Detail.
2. Schlüssel im Katalog stehen lassen (als „stale“) — kostet nichts zur Laufzeit, hält aber tote Übersetzungen; Xcode markiert sie ohnehin, abgelehnt.
3. `hasUnseenAutomaticRevisions` mitsamt `seenAt` entfernen — wäre Modelländerung (CloudKit additiv), eigenes Ziel, nicht hier.

**Risk:** Niedrig; nur Darstellung und Ressourcen, keine Daten, kein Schema.

**Open Questions:** keine.
