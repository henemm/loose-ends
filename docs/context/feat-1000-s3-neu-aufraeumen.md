# Context: feat-1000-s3-neu-aufraeumen (#1000 Schnitt 3)

## Request Summary
Letzter Schnitt von #1000 (Epic #999, ADR-22): Nach S1 (Startseite ohne „Neu“) und S2 („Passt“ weg) bleiben
Regeln, die Ansicht `ViewKind.new`, `TaskActions.confirmReview`, die Tönung „noch nicht angesehen“ in den Zeilen
(PO-Entscheid Entwurf A: weg), unbenutzte Katalogschlüssel und Doku-Verweise. Schnittplan: S1-Spec Zeile 33,
S2-Spec Abschnitt „Nicht in diesem Schnitt (Schnitt 3)“.

## Related Files (App-Code)
| Datei | Stelle | Was weg muss |
|---|---|---|
| `Shared/Models/ViewRules.swift` | :8–49 `ReviewReason`, `needsLook`, `isInNew`, `canConfirm`, `reviewReason`; :383 `case .new` | ganz entfernen |
| `Shared/Models/Enums.swift` | :87 `case new`, :95 Titel, :113 Symbol `tray` | Fall entfernen |
| `Shared/Services/TaskActions.swift` | :89–100 `confirmReview` | entfernen |
| `Shared/Models/RowKeyAction.swift` | :44 `.new?` | aus der Liste nehmen |
| `LooseEnds/Views/TaskListView.swift` | :323 Leersatz `case .new: "Nothing to look over."` | Fall weg |
| `LooseEnds/Views/TaskRow.swift` | :74–76 Rand-Tönung, :151–157 Funkel „Changed by AI“, :232/250/257 Merkmal-Tönung | Tönung weg, nur `.secondary` |
| `LooseEnds/Views/Paper.swift` | :11 `wideNoteInsets` (unbenutzt seit S2) | entfernen |
| `LooseEnds/Resources/Localizable.xcstrings` | „New“, „%lld to look over“, „Looks right“, „Needs a look“, „was: %@“, „Title not checked“, „Not sorted yet“, „Nothing to look over.“, „Changed by AI“ | Schlüssel entfernen (Code ruft sie danach nicht mehr) |

Zu prüfen in der Analyse: `TaskRow` :148 `.italic(task.title == nil || task.status == .unverified)` (kursiv für ungeprüften
Modelltitel, ohne Modell nur Altbestand); `TaskItem.hasUnseenAutomaticRevisions` (:184) wird danach nur noch von Tests
gerufen; `GuessedProjects` und `ContentView:246` haben Kommentare zu „Neu“; `EnrichmentCoordinator:75` Kommentar.

## Tests
`LooseEndsTests/ReviewTrayTests.swift` (31 Treffer, prüft die Sichtungsregeln) entfällt bzw. schrumpft. Einzeltreffer in
`CaptureServiceTests`, `DetailBackTests`, `EnrichmentTests`, `PeopleRetiredTests`, `ProjectNameRuleTests`, `RawTextExportTests`
(nur `.new` einer Revision, kein ViewKind), `RevisionServiceTests`, `RowKeyActionTests`, `StartViewsTests`, `SubtaskListsTests`,
`SubtaskTests`, `FieldOriginTests`. UI-Tests: keine Klasse mit `.new`.

## Existing Patterns
- `SavedView.kind` dekodiert `ViewKind(rawValue:) ?? .next` (`Shared/Models/SavedView.swift:26`): eine gespeicherte Ansicht
  „new“ wird nach dem Entfernen ohne Absturz und ohne Migration zur Ansicht „Als nächstes“. `kindRaw` bleibt im Store
  (CloudKit additiv, kein Schemawechsel).
- `TaskStatus.unprocessed`/`.unverified` bleiben als Werte (Modell/Schema additiv); die Listen zeigen solche Aufgaben seit S1.
- Katalogwächter `scripts/test_catalog_languages.py` prüft Vollständigkeit, nicht Verwendung.

## Dependencies / Dependents
- Abschrift für Claude (`TranscriptCodec`) und Server kennen keine Ansicht „new“ — nicht betroffen.
- Watch/Widgets rufen keine der Regeln.
- Kein Pfad der Geräteliste berührt (keine Datei aus der Stufe-3-Tabelle).

## Existing Specs
`docs/specs/feat-1000-schnitt-1-startseite-ohne-neu.md`, `docs/specs/feat-1000-schnitt-2-passt-entfaellt.md`,
ADR-22 in `docs/project/00-entscheidungen.md`.

## Doku
`docs/project/02-datenmodell-und-ansichten.md` (:153–154 Zeile „Neu“), `docs/reference/funktionsuebersicht.md` (:11, :15),
`docs/project/03-design-briefing.md` (Tönung), CLAUDE.md (Ground rules: „`isInNew` … stay until S3“, Satz „Until #1000/#1001 land“).

## Risks
- Umfang: 8 App-Dateien (eine davon Katalog) + Doku > 4–5 Dateien. LoC fast nur Löschungen. Teilung oder PO-Annahme in der Analyse klären.
- Gespeicherte Ansicht „Neu“ wird stumm „Als nächstes“ (Name bleibt der vom Nutzer gesetzte? prüfen, ob `SavedView` einen eigenen Namen trägt).
- Xcode kann beim Bauen die Katalogdatei umschreiben (CI „Generate leaves the tree clean“).

## Analysis

**Type:** Feature (Aufräumen, fast nur Löschungen; ADR-22)

**Befunde aus der Analyse**
- `SavedView` wird in der App nirgends angelegt, gelesen oder geseedet (keine Treffer für `SavedView(`, `FetchDescriptor<SavedView>`).
  Das Entfernen von `ViewKind.new` trifft also keine gespeicherte Ansicht; fiele doch eine an, dekodiert sie zu `.next`.
- `TranscriptCodec`, Server, Watch, Widgets: keine Verwendung — unberührt.
- `TaskItem.hasUnseenAutomaticRevisions` und `RevisionService.markSeen` bleiben: die Änderungsliste und `seenAt` sind
  eigenes Verhalten, nicht „Neu“. Nach S3b ruft nur noch das Detail (`markSeen`) und Tests sie; kein Löschen in diesem Ticket.
- `TaskRow:148` kursiv bei `.unverified`: kein Teil des Schnittplans, bleibt (Altbestand, ohne Modell entsteht kein neuer Fall).
- Kommentare in `GuessedProjects`, `ContentView:246`, `EnrichmentCoordinator:75` erwähnen „Neu“/„Looks right“ nur als Geschichte; kein Drive-by.

**Scope:** 7 Swift-Dateien im App-Code, ca. −120 LoC, dazu Katalog und Doku (beide außerhalb des LoC-Budgets).
Das sprengt die Dateigrenze 4–5 → Teilung in zwei Schnitte, beide in diesem Ticket:

| Schnitt | App-Dateien | Inhalt | LoC (App) |
|---|---|---|---|
| **S3a (dieser Workflow)** | `ViewRules.swift` (MODIFY), `Enums.swift` (MODIFY), `TaskActions.swift` (MODIFY), `RowKeyAction.swift` (MODIFY), `TaskListView.swift` (MODIFY) | `ReviewReason`, `needsLook`, `isInNew`, `canConfirm`, `reviewReason`, `case .new` der Regeln, `ViewKind.new` (Titel, Symbol), `confirmReview`, `.new?` in der Tastaturregel, Leersatz `.new`; CLAUDE.md und Datenmodell-Doku nachziehen | ca. −75 |
| S3b (Folge-Workflow) | `TaskRow.swift`, `Paper.swift` + `Localizable.xcstrings` | Tönung „noch nicht angesehen“ (Rand, Funken „Changed by AI“, Merkmale) weg, `wideNoteInsets` weg, die neun Katalogschlüssel weg; Design-Briefing, Funktionsübersicht | ca. −45 |

Tests (S3a): `ReviewTrayTests.swift` DELETE (prüft nur die entfallenden Regeln), Einzeltreffer in `CaptureServiceTests`,
`DetailBackTests`, `EnrichmentTests`, `PeopleRetiredTests`, `ProjectNameRuleTests`, `RevisionServiceTests`, `RowKeyActionTests`,
`StartViewsTests`, `SubtaskListsTests`, `SubtaskTests`, `FieldOriginTests` anpassen (Erwartung über Status bzw. Listen statt `isInNew`).
Neuer Test: `ViewKind.allCases` enthält kein `new`; eine frisch erfasste Aufgabe steht in „Alle offenen“ (Liste), Regeln ohne Sichtung.

**Risk:** Niedrig. Kompilierfehler fangen jede vergessene Stelle (erschöpfende `switch`); keine Datenmigration, kein CloudKit-Schema,
kein Pfad der Geräteliste. Reihenfolge S3a vor S3b, weil S3b die Katalogschlüssel erst löschen kann, wenn kein Code sie mehr ruft.

**Technical Approach:** Löschen, dann Bauen und Tests; Simulator-Durchlauf: erfassen, Aufgabe steht sofort in „Jetzt“/„Lose Enden“, Index zeigt kein „Neu“.

**Alternativen**
1. Alles in einem Schnitt (7 Dateien) mit PO-Annahme der Überschreitung — spart einen Durchlauf, bricht aber die Dateigrenze; abgelehnt, weil die Teilung ohne Nachteil geht.
2. `ViewKind.new` als verborgenen Altfall behalten (nicht im Index, kein Titel) — nur sinnvoll, wenn gespeicherte Ansichten existierten; tun sie nicht. Fiele keine ADR, wäre aber toter Code.
3. Tönung behalten und nur umdeuten (z. B. für Änderungen durch Claude) — widerspricht dem freigegebenen Entwurf A (PO: Tönung weg) und ADR-22.

**Open Questions:** keine (Entwurf A freigegeben 2026-11-26; Teilung ist Tech-Lead-Sache).
