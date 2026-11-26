# Context: #1000 „Neu“ entfällt

## Request Summary

Henning, 2026-11-26 (Epic #999, ADR-22): Weil das Modell aus dem Produktweg ist (#982 S1), gibt es nichts Erfundenes
mehr zu prüfen. Die Sichtung entfällt ganz: kein „Neu“, kein „N zum Durchsehen“, kein „Passt“ (EN „Looks right“).
Eine erfasste Aufgabe steht sofort in ihrer Liste; unter der Schreibzeile bleibt nur, was in dieser Sitzung gesagt
wurde. Danach TestFlight-Bau mit den offenen Gerätepunkten von #982.

Wortlaut im Katalog (nicht „Sieht gut aus“/„N zu sichten“ wie im Issue): DE „Passt“, „%lld zum Durchsehen“,
„Bitte ansehen“, „Neu“.

## Kernbefund

„Neu“ ist **nur eine berechnete Ansicht**. `TaskItem.isOpen` (TaskItem.swift:157-159) umfasst `.unprocessed` und
`.unverified`; `now`, `nowCount`, `badgeCount`, `.due`, `.open`, `.next` (ViewRules.swift:163-227, :378-416) schließen
Aufgaben in „Neu“ nicht aus. Jede Aufgabe in „Neu“ steht also heute schon in ihrer Liste. Keine Datenmigration nötig,
kein CloudKit-Schema betroffen. Wegfallen müssen Oberfläche, Gesten und Hilfsregeln.

Was eine Aufgabe nach „Neu“ bringt: Status `unprocessed` (Erfassung), `unverified` (Regeln fanden keinen Titel),
oder eine KI/Regel-Revision mit `seenAt == nil` (`hasUnseenAutomaticRevisions`, TaskItem.swift:182-186).
Dieselbe Eigenschaft färbt Zeilen akzentfarbig (TaskRow.swift:74, 151, 232) und kursiv (:148) — unabhängig von „Neu“.

## Related Files (App-Code)

| Datei | Rolle |
|---|---|
| `Shared/Models/ViewRules.swift` | :8-49 `ReviewReason`, `needsLook`, `isInNew`, `canConfirm`, `reviewReason`; :52 `dailyViews`; :64-67 `indexViews` (Index-Eintrag „Neu“); :381-383 `case .new` |
| `Shared/Models/Enums.swift` | :88/95/113 `ViewKind.new` (Titel, Symbol `tray`); `SavedView.kind` fällt bei unbekanntem Wert auf `.next` zurück |
| `LooseEnds/Views/InboxDrawerView.swift` | :41 Zahl; :72-113 Kopf „Neu · N zum Durchsehen“ (`inboxBar`, öffnet `.system(.new)`); :179 VoiceOver „Filed in New“ |
| `Shared/Models/InboxDrawer.swift` | reine Schubladenlogik; bleibt, nur Kommentar |
| `LooseEnds/Views/TaskListView.swift` | :120/377-395 `reviewSections` „Bitte ansehen“; :153/593 `detail(reviewing:)`; :328 Leersatz; :632-639 Zeilennotizen „war: …“ |
| `LooseEnds/Views/TaskInteractions.swift` | :88-99 Wisch „Passt“; :149-154 Menü „Passt“; :294-298 `confirm` |
| `LooseEnds/Views/TaskDetailView.swift` | `reviewing`, `inReview`, ReviewNote-Abschnitt :165-171, :327 markSeen nur außerhalb „Neu“, :560-590 Leiste „Passt“, :716-721 |
| `LooseEnds/Views/ReviewNote.swift` | ganze Datei entfällt |
| `Shared/Models/RowKeyAction.swift` | :40-44 `.new` von Leertaste-erledigt ausgenommen |
| `Shared/Services/TaskActions.swift` | :89-100 `confirmReview` |
| `Shared/Enrichment/EnrichmentWriter.swift` | :63-69 setzt `active` bei Titel, sonst `unverified`; Regelrevisionen ungesehen |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | :74-89 Kommentar „Passt vor dem Pass“; Logik bleibt |
| `LooseEnds/App/ContentView.swift` | :240-270 `startUp()` — Ort für einen idempotenten Aufräumpass (Muster `GuessedProjects.release`) |
| `LooseEnds/Resources/Localizable.xcstrings` | ~17 Schlüssel (New, to look over, Looks right, Needs a look, Title not checked …) |

Nicht betroffen: Watch (`nowRows`), Widgets (`now`), Mac-Menüleiste, Abschrift für Claude (`views` nur due/next/open;
Status roh), Server (`View = now|due|next|open`), App Intents. `ReminderSchema.inbox` ist die virtuelle Liste „Loose Ends“,
nicht „Neu“.

## Existing Patterns

- Startpass mit idempotenter Reparatur: `GuessedProjects.release` (schreibt schon `seenAt`, damit Aufgaben nicht nach „Neu“
  zurückkehren), `CatalogService.mergeDuplicateContexts`.
- Schublade #601 (Spec `docs/specs/feat-601-schreibzeile.md`), Kopf Variante B #693.

## Dependencies / Dependents (Tests)

- Unit: `ReviewTrayTests` (entfällt), `InboxDrawerTests`, `StartViewsTests`, `RowKeyActionTests`, `DetailBackTests`,
  `CaptureServiceTests`, `EnrichmentTests`:100/181; leichter: RevisionService-, FieldOrigin-, ProjectNameRule-, OrderExecutor-,
  Subtask-, TitleRule-Tests.
- UI: `InboxDrawerSmokeTests` (läuft auch in `ui-smoke-lang`), `LaunchLanguage.swift`:32, `MacDetailClickTests`:325-351,
  `StartScreenInteractionTests`, `StoreScreenshotsTests`. **Größter Testaufwand:** 16 UI-Testdateien (45 Stellen) öffnen eine
  frisch erfasste Aufgabe über `viewRow_new` (Helfer `CaptureSmokeTests`:943-956, `MacUITestSupport`:78/138 mit Standard
  `list: "viewRow_new"`).
- Store-Bilder (`store-screenshots`) zeigen Detail mit „Passt“ und Kopf „Neu“ — neue Bilder später, nicht Teil dieses Tickets.

## Existing Specs / Docs

ADR-22 (00-entscheidungen.md:350), ADR-17 (:335, „Neu (Eingang)“), `02-datenmodell-und-ansichten.md`:153,
`03-design-briefing.md` (mehrere Stellen), `funktionsuebersicht.md`:13, CLAUDE.md:91-97 und Abschnitt InboxDrawer,
`docs/specs/enrichment/feat-982-schnitt-1-modell-raus.md`:28/154 (Übergabe an #1000).

## Risks

- Umfang: ~11 App-Dateien, ~300 LoC weg, <30 dazu, ~25 Testdateien → mehrere Schnitte nötig (Vorschlag: S0 Tests von
  `viewRow_new` lösen; S1 Detail; S2 Liste/Gesten; S3 Startseite/Index; S4 Regeln/Modelle aufräumen; S5 Texte/Doku).
- Offene Produktfrage: Was bleibt von der Akzentfärbung/Kursivschrift „ungesehen“ in den Zeilen? Ohne „Neu“ hat sie keinen
  Ort mehr, an dem man sie „sieht“ und bestätigt; bleibt sie, bleiben Zeilen dauerhaft getönt.
- Sichtbare Änderung (Startseite, Detail, Liste) → Entwurf vor Spec (Heute/Entwurf, hell/dunkel, Alternative).
- Gerätepunkte von #982 hängen am TestFlight-Bau nach diesem Ticket.

## Analysis

**Type:** Feature (Rückbau einer sichtbaren Funktion, ADR-22).

**Affected Files (Change Type)** — Einzelheiten oben unter „Related Files“:
- MODIFY `Shared/Models/ViewRules.swift` (isInNew, needsLook, canConfirm, reviewReason, `case .new`, dailyViews/indexViews), `Shared/Models/Enums.swift` (`ViewKind.new`), `Shared/Models/RowKeyAction.swift`, `Shared/Services/TaskActions.swift` (`confirmReview`), `Shared/Enrichment/EnrichmentCoordinator.swift` (Kommentar)
- MODIFY `LooseEnds/Views/InboxDrawerView.swift` (Kopf, Zahl, VoiceOver), `TaskListView.swift`, `TaskInteractions.swift`, `TaskDetailView.swift`, `TaskRow.swift` (Tönung, je nach PO-Entscheidung)
- DELETE `LooseEnds/Views/ReviewNote.swift`
- MODIFY `LooseEnds/Resources/Localizable.xcstrings` (~17 Schlüssel), Doku (02-datenmodell, 03-design-briefing, funktionsuebersicht, CLAUDE.md)
- Tests: DELETE `ReviewTrayTests`; MODIFY ~20 Unit-/UI-Testdateien (`viewRow_new` → andere Liste)

**Scope/Risk:** ~11 App-Dateien, ~−300/+30 LoC App-Code, ~25 Testdateien. Kein Schema, keine Migration (Aufgaben in „Neu“
stehen schon in ihren Listen, `isOpen` umfasst `unprocessed`/`unverified`). Risiko mittel: berührt Startseite, Detail und
Listen auf iPhone, iPad und Mac; die UI-Testsuite hängt breit an `viewRow_new`. Kein Pfad der Geräteliste berührt
(Views/Models/Services außerhalb `Shared/Persistence`, `EnrichmentCoordinator` nur Kommentar) → Abnahme endet nach Stufe 2;
der TestFlight-Bau danach dient den offenen Gerätepunkten von #982.

**Technical Approach (Schnitte, je ≤5 App-Dateien/≤250 LoC):**
- S1 Tests lösen: UI-Testhelfer (`CaptureSmokeTests` :943, `MacUITestSupport` :78/:138) und alle `viewRow_new`-Aufrufer auf eine
  Liste umstellen, die frisch Erfasstes heute schon zeigt („Lose Enden“ `viewRow_open`); reiner Testschnitt, App unverändert.
- S2 Oberfläche: Kopf „Neu · N zum Durchsehen“ weg (InboxDrawerView), Index ohne „Neu“ (ViewRules.indexViews), Liste/Wischen/Menü/
  Detail-Knopf „Passt“ weg (TaskListView, TaskInteractions, TaskDetailView, ReviewNote gelöscht). Falls > 5 Dateien: S2a Startseite+Index,
  S2b Liste/Gesten/Detail.
- S3 Regeln und Rest: `ViewKind.new` (SavedView fällt auf `.next` zurück), isInNew & Co., `confirmReview`, RowKeyAction, Tönung nach
  PO-Entscheidung, Katalogschlüssel, Doku. Status `unprocessed`/`unverified` bleiben als Werte (Server, Abschrift, ältere Builds).
- Danach TestFlight-Bau mit „Was testen“ inkl. Gerätepunkte #982 (Session hält Epic #999).

**Alternativen:** (1) „Neu“ als reine Anzeige „Zuletzt erfasst“ behalten — in ADR-22 verworfen. (2) Quittung statt Zeilen unter der
Schreibzeile (Entwurf B) — kippt #677 (ruhige Startseite). (3) Status `unprocessed/unverified` per Startpass auf `active` heben —
unnötig, da Listen sie schon zeigen; kippt nichts, kostet aber Revisionen/CloudKit-Schreiblast.

**Dependencies:** #982 S1 gemergt (kein Modell im Produktweg). `ui-smoke-lang` führt `InboxDrawerSmokeTests` je Sprache aus.

**Open Questions (PO):**
1. Entwurf A (Schublade ohne Kopf) oder B (Quittung)? Empfehlung A. Vorschau: https://claude.ai/artifact/3oGvFJxJ7Mob4WcfZDiam3
   (Quelle `docs/artifacts/feat-1000-neu-entfaellt/index.html`).
2. Tönung „noch nicht angesehen“ in den Zeilen: weg (Empfehlung) oder bis zum ersten Öffnen?

**PO-Entscheidungen (Henning, 2026-11-26, AskUserQuestion):** Entwurf A „Zeilen wie heute“ (Schublade ohne Kopf „Neu“, ohne Zahl).
Tönung „noch nicht angesehen“ in den Zeilen: **weg** (alle Randangaben grau, rot nur bei Zeitdruck).
