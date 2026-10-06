# Context: bug-202-titel

## Request Summary
Henning (2026-10-04, aus #198, aufgeteilt in #202): (1) Der Titel wird unzuverlässig gesetzt.
(2) „Wiederherstellen des Titels aus der originalen Spracherkennung“ funktioniert nicht.
Beides aus eigener Benutzung, vermutlich auf dem iPhone mit Apple Intelligence. Verwandt: #159
(Modell setzt im Gerätelauf keinen Titel, Ursache offen), #125 (Titel-Reset und Titel-Treue, geschlossen).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/TaskDetailView.swift:35-51, 131, 236-251` | Titelfeld, Rücksetz-Knopf `resetTitleButton` (nur sichtbar, wenn der Titel von der KI stammt), `resetTitle()`, `commitTitle()`, `titleDraft` wird nur in `.onAppear` und in `resetTitle()` aus `task.title` befüllt |
| `Shared/Services/RevisionService.swift:21-30, 72-76` | `revert` und `firstAIRevision`: Zurücksetzen setzt den **Wert vor der ersten KI-Revision** (`oldValue`) |
| `Shared/Enrichment/EnrichmentWriter.swift:29-37` | Titel nur ab Konfidenz ≥ 0,6 und nicht leer; sonst Status `unverified`. Schreibt `record(.title, old: task.title, …)` |
| `Shared/Services/CaptureService.swift:20` | `TaskItem(rawText:…)` legt die Aufgabe **ohne Titel** an, also ist `task.title` beim ersten KI-Lauf `nil` |
| `Shared/Models/TaskItem.swift:117-121` | `displayTitle`: Titel, sonst Rohtext (auch bei Status `unverified`) |
| `Shared/Services/FieldCodec.swift:37-39` | Titel leeren löscht auch `titleSourceRaw` |
| `Shared/Enrichment/FoundationModelsEnricher.swift:26-31, 58-63` | Prompt und Abbildung; leerer Modelltitel ergibt gar keinen Entwurf |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | Nachzügler-Lauf, der Aufgaben ohne `processedAt` veredelt |
| `LooseEnds/Views/TaskRow.swift:35-37` | Listenzeile: kursiv bei fehlendem Titel oder `unverified` |
| `LooseEndsTests/RevisionServiceTests.swift`, `TitleFidelityPromptTests.swift` | bestehende Tests (revertTitle, aiSetFieldsExcludesUserTitle, Prompt-Inhalt) |

## Existing Patterns
- Abgeleitetes Feld = Wert + `*SourceRaw` + `*Confidence`; Rohtext unveränderlich; jede Änderung eine `Revision`, nichts wird gelöscht.
- Regeln vor Modell: Der Titel ist laut CLAUDE.md das einzige Feld, das ein Modell bekommt (Sprachverstehen). Gemessen 2026-09-20: Titel hält (0,3 % erfunden).
- #125 hat den Rücksetz-Knopf neben das Titelfeld gesetzt und den Prompt auf „zwölf Wörter, nie Zweck/Objekt weglassen“ gelockert.

## Dependencies
- Upstream: `FoundationModelsEnricher` (nur auf dem Gerät mit Apple Intelligence, im Simulator keine Modell-Assets) → `EnrichmentWriter` → `TaskItem.title`.
- Downstream: Listenzeile, Detailansicht, Mitteilungen und Kalender (`CalendarSync`, `DueReminders` lesen den Titel), Revisions-Blatt.

## Existing Specs
- `docs/specs/fix-125-titel-treue.md`, `docs/context/fix-125-titel-treue.md` (Reset-Knopf und Prompt)
- `docs/context/fix-144-recognition-pool-empty.md`, `docs/project/06-annahmen-und-experimente.md`
- Offenes Ticket #159 (Gerät setzt keinen Titel)

## Risks & Considerations
- **Noch nichts reproduziert, keine Ursache benannt.** Die folgenden Beobachtungen stammen aus dem Lesen des Codes und sind Hinweise für die Analyse, keine Befunde:
  - Beim ersten KI-Lauf ist `task.title` `nil`. Die erste KI-Revision trägt deshalb `oldValue = nil`. „Zurücksetzen“ setzt den Titel dann auf `nil`: das Titelfeld zeigt den Platzhalter „Title“, nur die Liste fällt auf den Rohtext zurück. Ob Henning mit „Wiederherstellen aus der Spracherkennung“ genau das meint (er erwartet den Rohtext im Feld), ist zu klären und im Simulator zu zeigen.
  - Ohne Titel (Modell nicht verfügbar, Konfidenz unter 0,6, leerer Modelltitel) bleibt die Aufgabe `unverified` mit dem Rohtext als Anzeige. „Unzuverlässig gesetzt“ kann also bedeuten: das Modell greift nicht jedes Mal. Auf dem Gerät belegbar nur über die Labor-App (#159).
- **Gerätestufe:** Eine Änderung an `FoundationModelsEnricher.swift`/`EnrichmentCoordinator.swift` löst Stufe 3 aus. Eine reine Änderung an `TaskDetailView`/`RevisionService` nicht: dann reicht Simulator, mit dem Satz „Kein Pfad der Geräteliste berührt.“
- **Alternativen zu bedenken (in `/20-analyse` mit Beleg bewerten):** (a) Fallback-Titel per Regel aus dem Rohtext, wenn das Modell nichts liefert; (b) „Wiederherstellen“ setzt den Rohtext als Titel statt `nil`; (c) beim ersten KI-Lauf den Rohtext als Ausgangswert in die Revision schreiben (ändert Daten-Semantik, berührt Persistenz-Pfad nicht, aber Revisions-Verlauf).
- UI-Änderung am Titelfeld = sichtbar → Entwurf vor der Spec (CLAUDE.md „Entwurf vor Spec“).
- Recherche zuerst: In `/20-analyse` Schritt 1 (Apple Foundation Models, Titel-Erzeugung, Verfügbarkeit je Gerät, bekannte Fallberichte).

## Analysis

### Type
Bug (zwei Teile, eine Ursache: der Titel hängt vollständig am Modell, und es gibt keinen Anfangszustand, auf den „Zurücksetzen“ führen könnte).

### Recherche (zuerst, 2026-10-05)
- Foundation Models: `SystemLanguageModel.availability` kennt `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, `.modelNotReady`; Aufrufe können mit Guardrail-, Kontext- und Sprachfehlern scheitern (Apple-Dokumentation `SystemLanguageModel`; Entwicklerforum-Fall „Foundation Model Always modelNotReady“, thread 788983). Das Modell ist kein verlässlicher Lieferant für ein Pflichtfeld.
- Eigene Messung (`docs/reference/date-title-fidelity.md`): 23 Fehlversuche, davon 11 gedrosselt; Drosselung bei Akku und Hintergrund (Forum thread 794408, in #159 zitiert).

### Nachgestellt (Simulator, Hennings Weg: Erfassen → Neu → Detail)
- Beleg: `docs/artifacts/bug-202-titel/simulator-run.txt`, Bilder geöffnet und beschrieben: Titelfeld leer mit Platzhalter „Title“, Liste zeigt Rohtext kursiv mit „Not sorted yet“.
- Teil 1 (unzuverlässig gesetzt): im Simulator reproduziert für „Modell liefert nichts“. Auf dem iPhone ist die Ursache (Drosselung, Konfidenz < 0,6 oder Fehler) nicht belegt, #159 bleibt offen. Das Ergebnis ist in allen drei Fällen dasselbe: `EnrichmentWriter` setzt keinen Titel.
- Teil 2 (Wiederherstellen): im Simulator nicht auslösbar, weil der Reset-Knopf nur bei KI-Titel erscheint und der Simulator kein Modell hat. Belegt nur über den bestehenden Test `RevisionServiceTests.revertTitle` (nach dem Reset ist `task.title == nil`), nicht auf Nutzerweg nachgespielt. Ursache im Code: `CaptureService` legt Aufgaben ohne Titel an, die erste KI-Revision trägt `oldValue = nil`, `revert` setzt genau diesen Wert zurück; das Feld ist danach leer wie im Bild.

### Affected Files (Empfehlung A)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Services/TitleRule.swift` | CREATE | reine Regel: Rohtext → Titel (trimmen, Endpunkt weg, erster Buchstabe groß, höchstens 12 Wörter) |
| `Shared/Services/CaptureService.swift` | MODIFY | setzt den Titel beim Erfassen (keine KI-Markierung, keine Revision) |
| `Shared/Services/RevisionService.swift` | MODIFY | `revert` eines Titels mit `oldValue == nil` setzt `TitleRule` des Rohtexts (Altbestand ohne Titel) |
| `LooseEndsTests/TitleRuleTests.swift` | CREATE | Regel, Erfassung, Reset auf Altbestand und auf Modelltitel |
| `LooseEndsTests/RevisionServiceTests.swift` | MODIFY | `revertTitle` erwartet den Anfangstitel statt `nil` |
| UI-Test (vorhandene Klasse) | MODIFY | Erfassen → Detail zeigt Titel |

### Scope Assessment
- Files: 5–6 (UI-Test in eine vorhandene Klasse legen)
- Estimated LoC: +120/-10
- Risk Level: LOW–MEDIUM (Titel ist ab Erfassung gesetzt; `displayTitle`, `TaskRow`, `showsRawText` verhalten sich dann anders, in der Spec prüfen)
- Gerätestufe: kein Pfad der Geräteliste berührt (`Shared/Services/` steht nicht darin; `FoundationModelsEnricher` und `EnrichmentCoordinator` bleiben unberührt).

### Technical Approach
„Ohne Modell geht es nicht, weil …“ gilt für den Titel nur bei langen Diktaten. Beleg: 312 von 319 Korpus-Rohsätzen haben höchstens 12 Wörter (Median 6); der Rohtext ist fast immer schon der Titel. Das Modell bringt Kürzen und Umformulieren nur bei den 7 längeren Sätzen. Deshalb ist der Regelweg die Empfehlung; das Modell darf wie bisher überschreiben, die Revision trägt dann den Regeltitel als `oldValue`.

### Alternativen (mit gekippter Entscheidung)
- B: Rohtext nur als Platzhalter im leeren Feld. Keine Datenänderung; Liste, Mitteilungen und Kalender bleiben ohne Titel, Reset führt weiter auf ein leeres Feld.
- C: Knopf „Use what you said“ statt automatisch. Kippt „Anreicherung ohne Zutun“, kostet einen Tipp je Aufgabe.
- D: Modell zuverlässiger machen (Wiederholung, anderer Prompt). Hängt an #159, im Simulator nicht beweisbar, löst Teil 2 nicht.
- E: Modell nur für Texte über 12 Wörter anfragen. Berührt `EnrichmentCoordinator` (Gerätestufe), ein späterer Schnitt.
- Bei A gekippt: CLAUDE.md „Rules before the model“ nennt den Titel bisher als einziges Modellfeld und wird angepasst. Die #125-Semantik „Reset = Wert vor der ersten KI-Revision“ bleibt, hat jetzt aber immer einen Wert.

### Dependencies
`CaptureService` ist der eine Schreibweg für alle Kanäle (App, Siri, Watch, Share). `EnrichmentWriter` schreibt `old: task.title`, also automatisch den Regeltitel. `TaskRow`, `DueReminders`, `CalendarSync` lesen den Titel.

### Open Questions
- [x] **Entwurf A von Henning freigegeben (2026-10-05).** Entwurf A, B oder C (Vorschau: https://claude.ai/artifact/5AjgtobfgP4Z5uFtnFbEw3, Datei `docs/artifacts/bug-202-titel/entwurf.html`).
- [x] **Lücke in der Spec, gefunden in /40-tdd-red (2026-10-05), von Henning entschieden:** Zehn bestehende UI-Tests erkennen das offene Detail an `detailRawText` („You said:"). AC-3 blendet die Zeile bei kurzen Texten aus. Entscheidung: `TaskDetailView` bekommt eine unsichtbare Kennung `detailRawTextMarker` (Accessibility-Element, Label = Rohtext, immer vorhanden); `CaptureSmokeTests`, `DesignGalleryTests`, `RecognitionWalkthroughTests` nutzen sie. Spec-Datei bleibt gesperrt, die Abweichung steht hier: Dateien 13 statt 9 (+ `TaskDetailView.swift`, `DesignGalleryTests.swift`, `RecognitionWalkthroughTests.swift`), ca. +30 Zeilen. Verworfen: „You said:" immer zeigen (kippt AC-3), Tests auf Titelfeld umstellen (fragil, Modell ändert den Titel).
- [ ] Status bleibt bis zum Modelllauf „unprocessed“ (Empfehlung: ja, nur der Titel ist schon da).
- [ ] Altbestand ohne Titel: bleibt leer, bis „Zurücksetzen“ gedrückt wird (Empfehlung: nicht nachziehen, eigenes Ticket nur falls gewünscht).
