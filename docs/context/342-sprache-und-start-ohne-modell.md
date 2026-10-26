# Context: 342-sprache-und-start-ohne-modell

## Request Summary
Schnitt 1 von #342 (Epic #370/#371, M3): Teil 4 „Deutsch und Englisch“ (Vollständigkeit der Sprachtabellen prüfen, Fehlendes
auflisten und schließen) und Teil 5 „Erster Start ohne Modell“ (sagt der Hinweis beim ersten Start, was ohne Apple Intelligence
wirklich passiert?). Schnitt 2 (Datenschutz/Berechtigungstexte) und Schnitt 3 (Beta-Freigabe, Testgruppe) folgen als Teil-Specs.

## Befund Teil 4 (gemessen am 2026-10-26, Skripte im Scratchpad der Sitzung)
Quellsprache aller Tabellen ist Englisch, Deutsch die einzige Übersetzung. „Fehlend“ heißt also: kein `de`-Eintrag.

| Tabelle | Schlüssel | `de` fehlt | `new`/`needs_review` |
|---|---|---|---|
| `LooseEnds/Resources/Localizable.xcstrings` | 481 | 0 | 0 |
| `LooseEnds/Resources/AppShortcuts.xcstrings` | 5 | 0 | 0 |
| `LooseEndsWidgets/Localizable.xcstrings` | 25 | 0 | 0 |
| `LooseEndsShare/Localizable.xcstrings` | 10 | 0 | 0 |

Gegenprobe vom Code her: Literale in `Text/Button/Label/navigationTitle/Section/Toggle/TextField/Picker/Menu/ContentUnavailableView`
(ohne Interpolation) aus `LooseEnds/`, `Shared/`, `LooseEndsWidgets/`, `LooseEndsShare/`, die in der Tabelle ihres Targets fehlen: **0**.
Grenze der Heuristik: Interpolierte Texte, `String(localized:)` (261 Stellen) und `LocalizedStringResource` sind nicht erfasst.

**Echte Lücke: die Watch-Komplikation.** `LooseEndsWatchWidgets` (project.yml) hat keine Sprachtabelle. Ihre Texte
`"Capture"` (Beschriftung, Eckanzeige, Konfigurationsname) und `"Opens capture."` (Beschreibung) bleiben auf einer deutschen Uhr englisch.
Die Watch-App selbst bekommt `Localizable.xcstrings` der iPhone-App (project.yml, Ressourcen der Watch); „Saved“, „Done“,
„Could not save“, „OK“, „Capture“ stehen dort, „Opens capture.“ nicht.

**Berechtigungstexte (nicht Schnitt 1):** `de.lproj/InfoPlist.strings` übersetzt nur Standort und Kamera (+ Siri-Namen).
Mikrofon, Spracherkennung und Kalender (iPhone) sowie Mikrofon/Spracherkennung der Watch stehen nur englisch in `project.yml`.
Das ist Teil 2 (Datenschutz) und berührt `project.yml`/Info.plist, also die Geräteliste. Gehört in Schnitt 2.

## Befund Teil 5
- Der Hinweis lebt in `LooseEnds/Views/OnboardingFlow.swift` (`ModelNote`, `modelNote(for:)`) und `OnboardingView.swift` (`modelNote(_:)`),
  sichtbar nur im Schritt `.siri`, Grund aus `FoundationModelsEnricher().unavailableReason` (`ContentView.swift:191`).
- Drei Texte (alle mit `de`):
  - aus: „…so new tasks get a title and a duration.“
  - nicht bereit: „Tasks captured meanwhile are sorted once it is.“
  - Gerät ohne Modell: „Tasks keep the words you said; due dates, importance and urgency are still found.“
- Soll laut `docs/reference/modell-verfuegbarkeit.md`: Ohne Modell laufen die Regeln (Datum, Wichtigkeit, Dringlichkeit, Tags per Wortliste,
  Wiedererkennung); es fehlen nur die Titelverfeinerung und Dauer/Energie ohne Wiedererkennung. Der dritte Text nennt den Verlust nicht
  (Dauer/Energie) und sagt nicht, dass es nur dort gilt, wo eine Aufgabe zum ersten Mal vorkommt. Prüfstein für die Analyse.
- Tests heute: `OnboardingFlowTests.modelNote` prüft nur die Abbildung Grund → Fall. Es gibt keinen Test, der den **Text** prüft oder
  zeigt, dass der Hinweis auf dem Bildschirm steht. `OnboardingTests` (UI) startet mit `--ui-testing`, dort ist das Modell aus.
  Ob dann ein Hinweis erscheint (Grund ≠ nil im Simulator), ist in der Analyse nachzustellen.

## Related Files
| File | Relevanz |
|---|---|
| `LooseEnds/Views/OnboardingFlow.swift`, `OnboardingView.swift` | Hinweis ohne Modell (Teil 5) |
| `LooseEnds/Resources/Localizable.xcstrings` | Quelle der Texte, auch für die Watch-App |
| `LooseEndsWatchWidgets/CaptureComplication.swift` | zwei Texte ohne Tabelle (Teil 4) |
| `project.yml` | Watch-Widget-Target ohne Ressourcen; **Geräteliste** |
| `LooseEndsTests/OnboardingFlowTests.swift`, `LooseEndsUITests/OnboardingTests.swift` | bestehende Tests |
| `docs/reference/modell-verfuegbarkeit.md` | Soll für den Hinweis |
| `scripts/sim.sh` (`LOOSEENDS_LANG=en … sim-unit`) | Testsprache (#670) |

## Existing Patterns
- Eine Tabelle je Target (`Localizable.xcstrings`), `de` mit `state: translated`; Watch teilt die Tabelle der App per `path: … includes:`.
- Skripttests als `scripts/test_*.py` (z. B. `test_tags_wording.py`, `test_siri_phrases.py`) halten Wortlaut-Regeln fest; passt für eine
  Vollständigkeitsprüfung der Tabellen (dann lief sie in der CI mit).

## Dependencies
- Upstream: `FoundationModelsEnricher.unavailableReason`, `OnboardingFlow`.
- Downstream: Onboarding-UI-Test, `AppShortcuts`/Siri unberührt.

## Risks & Considerations
- Watch-Komplikation lokalisieren heißt `project.yml` ändern (Ressourcen im Widget-Target) und `LooseEndsWatchWidgets/` berühren: beides
  **Stufe 3**. Alternative: bewusst streichen („Capture“ ist ein kurzes Wort), dann Begründung im Ticket. Entscheidung gehört in `/20-analyse`.
- Neue/geänderte Hinweistexte brauchen `de` und berühren keine Logik; ein Wortlaut ist ein Produktthema (Henning gibt frei).
- Kein Test auf Hennings Geräten (Regel vom 2026-10-08).

## Analysis

### Type
Feature (Prüfung mit kleinem Schließen der Lücken). Stand „in Bearbeitung“ gelesen am 2026-10-26: offene PRs #692, #694, #695 berühren weder Onboarding noch Sprachtabellen; keine Karte In progress/In review kollidiert.

### Reproduktion (Simulator, Stand dieses Worktrees, `build` + `launch --ui-testing --ui-testing-onboarding`, Deutsch)
- Der Hinweis „Gerät ohne Modell“ erscheint im Simulator **nicht**: Schritt 1 zeigt nur „Erfassen, ohne die App zu öffnen“ (Screenshot
  Scratchpad `onb-de.png`). Grund: `FoundationModelsEnricher().unavailableReason` ist im iOS-27-Simulator `nil` (er hat ein Modell,
  Memory „Simulator hat ein Modell“). `OnboardingFlowTests.modelNote` prüft nur Grund → Fall; **kein Test und kein Lauf hat den Hinweis je
  auf dem Bildschirm gesehen**. Wie die Kette „Grund → Text auf dem Bildschirm“ im Alltag ohne Modell aussieht, ist bisher unbelegt.
- Hinweistexte gegen `modell-verfuegbarkeit.md` gelesen: „aus“ und „nicht bereit“ stimmen. **„Gerät ohne Modell“ stimmt nur halb:** er nennt
  Fälligkeit/Wichtigkeit/Dringlichkeit, verschweigt Etiketten (Wortliste), und „Aufgaben behalten deine Worte“ verschweigt, dass Dauer ohne
  Modell nur kommt, wenn der Text sie nennt (`DurationRule`, #673) oder die Aufgabe schon vorkam (`RecognitionRule`); Energie nie.

### Befund Teil 4 (Ergänzung zur Messung oben)
Zweiter Abgleich vom Code her, jetzt auch `String(localized:)` (268 Stellen, Interpolation → `%@`): 9 Treffer, davon **eine echte Lücke in der
App**: `FieldFormatting.label(.counts)` = „Counts“ steht nicht in der Tabelle (Verlaufszeile der Detailansicht, `TaskDetailView:836`), auf einer
deutschen App also englisch; zudem veraltet, Nutzerwort ist seit #655 „Perle sammeln“. Die übrigen Treffer sind Formatfolgen (`%lld` statt `%@`,
Platzhalter-Reihenfolge) und zwei Siri-Fehlertexte in `SiriFields` (`Shared/Services`, seit dem Rückbau von #25 nicht im Produktpfad → bewusst
nicht angefasst). Dazu die Watch-Komplikation (zwei Texte ohne Tabelle) und die Berechtigungstexte (Schnitt 2).

### Affected Files (Schnitt 1a — ohne Geräteliste)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/OnboardingView.swift` | MODIFY | Text „Gerät ohne Modell“ nennt Etiketten und die Dauer-Bedingung |
| `LooseEnds/App/ContentView.swift` | MODIFY | Startargument `--ui-testing-model-reason=<case>` setzt den Grund unter Tests (wie die anderen festen Zustände), sonst unverändert |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | neuer/geänderter Text mit `de`, „Counts“ → Nutzerwort mit `de` |
| `LooseEnds/Views/FieldFormatting.swift` | MODIFY | Label für `.counts` auf das Nutzerwort |
| `LooseEndsTests/OnboardingFlowTests.swift` | MODIFY | prüft den Wortlaut je Fall (en/de, nennt „Etiketten“ und die Dauer-Bedingung) |
| `LooseEndsUITests/OnboardingTests.swift` | MODIFY | Hinweis steht auf dem Bildschirm (alle drei Fälle über das Startargument), Deutsch und Englisch |
| `scripts/test_localization_complete.py` | CREATE | CI-Prüfung: jeder Schlüssel aller Tabellen hat `de` (`translated`), jedes Literal in `Text/Button/Label/String(localized:)` steht in der Tabelle seines Targets; Platzhalter gleich viele in en und de |

### Scope Assessment
- Files: 7 (Limit 4–5; Skripttest und Tabelle sind Daten/CI-Wache, Code nur 3 Dateien) — bei der Spec-Schätzung wieder prüfen, sonst teilen: 1a-i Hinweis (Text, Argument, zwei Tests), 1a-ii Vollständigkeitsskript + „Counts“.
- Estimated LoC: +150/−10 (Skript ~80, Tests ~50, Rest ~30)
- Risk Level: LOW — reine Texte, ein Testargument, kein Datenmodell, keine Persistenz
- Geräteliste: kein Pfad berührt → Abnahme endet nach Stufe 2 („Kein Pfad der Geräteliste berührt.“); der Hinweis wird im Simulator über das Startargument durchgespielt und fotografiert.

### Technical Approach
**„Ohne Modell geht es nicht, weil …“ entfällt:** alles hier ist Text und Tabellenvergleich, deterministisch; kein Sprachmodell, die Regelspalte ist 100 %.
1. Hinweis: neuer Wortlaut (Entwurf, Henning gibt frei): EN „This device has no Apple Intelligence. Due dates, importance, urgency and tags are still found; a duration only when you name it or the task came up before.“ / DE „Dieses Gerät hat kein Apple Intelligence. Fälligkeit, Wichtigkeit, Dringlichkeit und Etiketten werden trotzdem erkannt; eine Dauer nur, wenn du sie nennst oder die Aufgabe schon einmal da war.“ Layout unverändert (footnote, grau) → keine Neugestaltung, daher keine Vorschauseite; Henning gibt nur den Wortlaut frei.
2. Beleg: Startargument liefert den Grund; UI-Test und Simulator-Foto je Fall; so schließt die Kette Grund → Bildschirm erstmals.
3. Dauerhafte Wache: `scripts/test_localization_complete.py` läuft in der CI (wie `test_tags_wording.py`), damit Teil 4 nicht noch einmal von Hand geprüft werden muss.

### Alternativen (Pflicht, ADR berührt)
- **Hinweis streichen** und nur im Onboarding-Satz „Funktioniert ohne Apple Intelligence“ sagen: weniger Text, aber ehrlich nur, wenn kein Verlust spürbar ist; Dauer fehlt aber spürbar. Verworfen.
- **Hinweis später zeigen** (nach der ersten Aufgabe, an der Stelle, wo Dauer leer bleibt) statt im Onboarding: ehrlicher, weil kontextnah, aber neue Oberfläche, eigene Vorschau. Als Folge-Idee ins Ticket, nicht in Schnitt 1.
- **Komplikation:** (a) Tabelle `LooseEndsWatchWidgets/Localizable.xcstrings` mit zwei Einträgen, xcodegen nimmt die Datei aus dem Quellordner mit, `project.yml` vermutlich unberührt, aber `LooseEndsWatchWidgets/` steht in der Geräteliste → Stufe 3; (b) die zwei Texte streichen („Capture“ ist ein Kurzwort) → keine Tabelle, aber auch kein Deutsch („Erfassen“). Empfehlung (a), **im Schnitt 2 mitnehmen**: er berührt `project.yml`/Info.plist ohnehin, dann braucht Henning nur einen Gerätedurchgang statt zwei.
- Frühere Entscheidung, die (a) berührt: ADR „eine Tabelle je Target“ bleibt; Berechtigungstexte (Schnitt 2) bleiben getrennt.

### Dependencies
`FoundationModelsEnricher.unavailableReason` (nur Lesen), `OnboardingFlow.modelNote`, `docs/reference/modell-verfuegbarkeit.md` (Soll), `DurationRule`/`RecognitionRule`/`ContextWordRule` (was der Text behaupten darf).

### Open Questions
- [ ] Henning: Wortlaut des Hinweises freigeben (siehe Entwurf) — in `/30-write-spec` als Freigabe.
- [ ] Schnitt-Aufteilung 1a-i / 1a-ii bestätigen, falls die Spec 5 Dateien überschreitet.
- [ ] Nutzerwort für das `.counts`-Label: „Perle sammeln“ (DE) / „Collect bead“ (EN)? Aus #655 zu übernehmen; in der Spec festlegen.
