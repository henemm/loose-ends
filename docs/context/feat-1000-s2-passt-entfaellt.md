# Context: #1000 Schnitt 2 – Liste „Neu“, Wischen, Menü und Detail-Knopf „Passt“ entfallen

Gesamtanalyse, PO-Entscheidungen (Entwurf A, Tönung weg) und Schnittplan: `docs/context/feat-1000-neu-entfaellt.md`.
Schnitt 1 (gemergt, PR #1004): `docs/specs/feat-1000-schnitt-1-startseite-ohne-neu.md` – Startseite ohne Kopf „Neu“,
Index/Seitenleiste ohne „Neu“. Seitdem ist die Liste „Neu“ nur noch über eine gespeicherte Ansicht (`SavedView.kind`) erreichbar.

## Request Summary

Die Sichtung verschwindet aus Liste, Gesten und Detail: kein Abschnitt „Bitte ansehen“, keine Zeilennotizen „war: …“/„Titel
nicht geprüft“/„Noch nicht sortiert“, kein Wisch und kein Menüeintrag „Passt“, kein Detail-Knopf „Passt“, kein Hinweis
`ReviewNote`. Das Detail markiert Änderungen beim Öffnen immer als gesehen (heute nicht, wenn aus „Neu“ geöffnet).
Regeln (`isInNew`, `needsLook`, `canConfirm`, `reviewReason`, `ViewKind.new`), `TaskActions.confirmReview`, `RowKeyAction`,
Tönung, Katalogschlüssel und Doku bleiben für Schnitt 3.

## Related Files (Stand origin/main 6c87205)

| Datei | Was entfällt |
|---|---|
| `LooseEnds/Views/TaskListView.swift` | :120-121 Zweig `kind == .new` → `reviewSections`; :247-249 Reihenfolge für `.new` (Tastaturwahl); :328 Leersatz „Nothing to look over.“ (Switch über `ViewKind` braucht weiter einen `.new`-Fall bis S3); :377-395 `reviewSections`; :153/:593 `detail(_:reviewing:)`; :632-639 Zeilennotizen für `.new` |
| `LooseEnds/Views/TaskInteractions.swift` | :7 Doc; :88-99 Wisch „Looks right“ (`swipeConfirm_…`); :149-154 Menü „Looks right“ (`menuConfirm`); :294-298 `confirm(_:)` |
| `LooseEnds/Views/TaskDetailView.swift` | :8-15 Doc; :29-30 `reviewing`; :91 `inReview`; :165-172 Abschnitt `ReviewNote`; :327 `if !reviewing` vor `markSeen()`; :560-588 Leiste „Looks right“ (`detailConfirmButton`, zwei Zweige: aus „Neu“ `canConfirm`, sonst `needsLook && title != nil`); :716-721 `confirmReview()` |
| `LooseEnds/Views/ReviewNote.swift` | ganze Datei (50 Zeilen, `reviewNote`) |

`aiFields` im Detail bleibt (Titelzeile :125, Änderungsliste :223, :376, :742).

## Existing Patterns

- Schnitt 1 hat Elemente per Abwesenheitsprüfung in UI-Tests belegt (`XCTAssertFalse(element(...).exists)`), Hilfen
  `element(_:in:)` in `LooseEndsUITests`.
- Frisch Erfasstes im Simulator: Status `unprocessed`, Titel aus `TitleRule` → `needsLook` wahr, Titel gesetzt; deshalb zeigt
  das Detail einer Zeile der Schreibzeile (`drawerRow_…`) heute `detailConfirmButton` (vgl. `StoreScreenshotsTests`:111-116,
  der den Knopf bedingt antippt). Das ist der Weg für den RED-Test.

## Dependencies / Dependents (Tests)

- `StoreScreenshotsTests`:111-116 tippt `detailConfirmButton` bedingt und prüft `reviewNote` → Zeilen entfallen.
- Keine UI-Tests für `swipeConfirm_…`/`menuConfirm` (Liste „Neu“ ist seit S1 ohne Oberflächenweg).
- Unit `ReviewTrayTests`, `EnrichmentTests`:168 testen Regeln/`TaskActions.confirmReview` → bleiben bis Schnitt 3.
- `RowKeyAction`:44 nimmt `.new` von Leertaste aus → Schnitt 3.

## Existing Specs

ADR-22 (`docs/project/00-entscheidungen.md`:350); #349 (Detail aus „Neu“), #318 (Passt außerhalb „Neu“), #188 (Sichtungsfach),
#681 (Menü „Passt“) sind damit überholt.

## Risks

- Verhaltensänderung: Öffnen des Details markiert jetzt immer gesehen (vorher nicht aus „Neu“). Ohne „Neu“ ist das der
  einzige sinnvolle Weg; Tönung entfällt ohnehin in S3.
- `ViewKind.new` bleibt bis S3: Eine gespeicherte Ansicht „Neu“ zeigt dann eine schlichte Liste (fällt in den Standardzweig),
  ohne Sichtungsabschnitte — bewusst, S3 entfernt den Fall.
- Katalogschlüssel („Looks right“, „Needs a look“, „Nothing to look over.“, „was: %@“ …) werden unbenutzt; der Katalog-Wächter
  prüft Vollständigkeit, nicht Verwendung; Aufräumen in S3.
- Kein Pfad der Geräteliste berührt → Abnahme endet nach Stufe 2.
- Umfang: 4 App-Dateien, ~−150/+5 LoC.

## Analysis

**Type:** Feature (Rückbau, ADR-22), Schnitt 2 von 3.

**Affected Files (Change Type):**
- MODIFY `LooseEnds/Views/TaskListView.swift` — `reviewSections`, `.new`-Reihenfolge, `.new`-Zeilennotizen, `reviewing`-Parameter weg; Leersatz-Switch behält `.new` bis S3 (dann neutraler Satz „Nothing lined up yet.“ wiederverwenden, kein neuer Katalogschlüssel).
- MODIFY `LooseEnds/Views/TaskInteractions.swift` — Wisch- und Menüeintrag „Looks right“, `confirm(_:)` weg; `case .new?` im Wisch entfällt (fällt in `default`).
- MODIFY `LooseEnds/Views/TaskDetailView.swift` — `reviewing`, `inReview`, ReviewNote-Abschnitt, beide Leisten-Knöpfe „Looks right“, `confirmReview()` weg; `onAppear` markiert immer gesehen; Doc-Kommentar angepasst.
- DELETE `LooseEnds/Views/ReviewNote.swift` (Projekt ist generiert, Ordner-Quellen; `generate` nötig).
- MODIFY (Test) `LooseEndsUITests/StoreScreenshotsTests.swift` — bedingtes Antippen von „Passt“ und `reviewNote`-Prüfung entfallen.
- CREATE/MODIFY (Test) UI-Test: frische Erfassung über die Schreibzeile → Detail ohne `detailConfirmButton` und ohne `reviewNote`; Langdruck-Menü einer Zeile in „Lose Enden“ ohne `menuConfirm`. Heute rot, weil frisch Erfasstes `unprocessed` mit Titel ist (`needsLook`).

**Scope/Risk:** 4 App-Dateien, geschätzt −150/+5 LoC App-Code. Risiko niedrig bis mittel: nur Entfernen von Bedienelementen; einzige Verhaltensänderung ist „Öffnen markiert immer gesehen“. Kein Pfad der Geräteliste → Abnahme Stufe 2.

**Technical Approach:** Erst RED-UI-Test (Detail und Menü ohne „Passt“), dann Löschungen in obiger Reihenfolge, `generate`, Build, Unit + betroffene UI-Klassen, Simulatorbeleg per `test-proof`.

**Alternativen:**
1. „Passt“ im Detail behalten, nur Liste/Gesten entfernen — widerspricht ADR-22 („kein ‚Looks right‘“); verworfen.
2. Statt Knopf: Status beim Öffnen auf `active` heben — schreibt Revisionen/CloudKit-Last, gehört zu S3s Regel-Aufräumen; kippt keine ADR, bleibt Rückfall.
3. S2 und S3 zusammen — sprengt 4–5 Dateien (Enums, ViewRules, RowKeyAction, TaskActions, Katalog dazu); verworfen.

**Dependencies:** S1 gemergt. S3 räumt Regeln, `ViewKind.new`, Katalog, Doku, Tönung.

**Open Questions:** keine (PO-Entscheidungen aus der Gesamtanalyse gelten).
