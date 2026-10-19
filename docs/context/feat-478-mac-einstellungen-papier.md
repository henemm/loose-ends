# Context: feat-478-mac-einstellungen-papier

## Request Summary
#478 (Epic #467, Entwurf #408): Das Einstellungsfenster der Mac-App (⌘,) im Papierstil, wie die Tafel
`docs/artifacts/feat-408-mac-entwurf/Einstellungen.dc.html`: Papier als Grund, Zeilen mit Haarlinien statt grauer Karten,
kleine Überschriften in Großbuchstaben, Hinweise in Grau 12 pt unter der Zeile. Alle bisherigen Einträge und Funktionen bleiben.
Ticket war am 2026-10-18 offen, ohne PR und ohne Commit auf `main` (geprüft in /00-intake).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/SettingsView.swift` | Die eine Ansicht: `Form` + `.formStyle(.grouped)`, Sections Erinnerungen, „Loose ends“ (abends/morgens), iCloud, Kalender, Menüleiste (nur Mac), About. Hier ändert sich fast alles. |
| `LooseEnds/Views/Paper.swift` | Bausteine aus #477: `Paper.ground`, `Paper.wideRowInsets`, `paperGround()`, `captionHead()` (caption semibold, Großbuchstaben, tracking 1, grau), `detailRow()`. |
| `LooseEnds/Views/TaskDetailView.swift` (Z. 280–300) | Vorlage: wide/Mac = `List` + `.listStyle(.plain)` + `.textFieldStyle(.plain)` + `.toggleStyle(.switch)` + `.paperGround()`; compact = `Form` unverändert. |
| `LooseEnds/App/LooseEndsApp.swift:108` | Mac: `Settings { SettingsView }` (Fenster ⌘,). |
| `LooseEnds/App/ContentView.swift:86` | iPhone/iPad: dieselbe View im Sheet hinter dem Zahnrad, mit „Done“. |
| `LooseEndsUITests/SettingsSmokeTests.swift` | Einziger Test; iOS-Sheet, auf dem Mac übersprungen. IDs: `reminderTimePicker`, `iCloudSyncRow`, `settingsDoneButton`. |
| `LooseEndsUITests/MacGalleryTests.swift` | Mac-Galerie in der CI (`mac-gallery-*`, hell/dunkel): Start, Neu, Detail. Einstellungen noch nicht dabei; Mac-Bilder nur von dort. |
| `docs/artifacts/feat-408-mac-entwurf/{Einstellungen.dc.html,mac.css}` | Freigegebener Entwurf (`.sg h3` 11 px/600/Abstand .12em/Großbuchstaben, `.sr` min-height 40, Haarlinie, Wert rechts grau, `.sub` 12 px grau, Status-Wert in Akzent mit Wolkensymbol). |
| `docs/project/03-design-briefing.md` Z. 262–266 | Beschluss: SF für die App (Einstellungen, kleine Überschriften), Papier mit Haarlinien statt Karten, Titel in SF. |

## Existing Patterns
- **Wide/Mac = `List` plain statt `Form`** (#477): Auf dem Mac zeichnet `List` außerhalb von `Form` Rahmen um Textfelder und Kästchen für Toggles, daher `.textFieldStyle(.plain)` und `.toggleStyle(.switch)` setzen. Gilt auch hier.
- Papier hinter allem: `paperGround()` (scrollContentBackground aus + `Paper.ground`). Zeilen: `listRowBackground(Paper.ground)`.
- Kleine Überschriften: `captionHead()`.
- Compact (iPhone/iPad-Sheet) bleibt unverändert: dort ist `Form` grouped auf Papiergrund; das Ticket betrifft nur den Mac (DoD „auf dem Mac“). Offene Frage für die Analyse: ob das iPad-Sheet (breit) mitzieht; Detail tat es (`isWide`), hier wäre `Settings` auf dem Mac der einzige Zielfall.
- Abweichung Entwurf ↔ Ist: Die Tafel ist vom 16.10. und kennt „Wann am Tagesende…“ als eine Auswahl; seit #414/#518 gibt es zwei Schalter (abends/morgens) mit eigenen Uhrzeiten. Das Ticket sagt: „Alle bisherigen Einträge bleiben“, also gilt der Ist-Umfang, im Stil der Tafel.
- Fenstertitel SF 15 pt halbfett, Beschriftungen SF 14 pt, Hinweise Grau 12 pt (aus dem Ticket). Auf macOS kommt der Fenstertitel von `.navigationTitle("Settings")`; ob er sich in der Titelleiste so setzen lässt, ist zu prüfen (sonst eigener Kopf im Inhalt).
- Statuszeile iCloud: Wert in Akzent mit Wolkensymbol; `SyncStatus.summary(...).symbol` und `role == .accent` liefern das schon; „ohne zweite Überschrift davor“ = die Section-Kopfzeile „iCloud“ entfällt (Zeile steht alleine oben).
- Farbbudget: Akzent = Antippbares, Rot = Zeitdruck, Grau = Hierarchie. SF Symbols only (#350).

## Dependencies
- Upstream: `DueNotificationCenter` (Uhrzeiten, `carryMode`), `CarryReminders.Mode`, `CalendarBridge` (Umgebung), `SyncStatus`, `LoginItem` (nur Mac), `AppVersion`, `CalendarPickerSheet`.
- Downstream: `LooseEndsApp.swift` (Mac-Settings-Szene), `ContentView.swift` (Sheet iOS), `SettingsSmokeTests`. Keine Modell- oder CloudKit-Änderung, keine neuen Berechtigungen, keine neuen AppStorage-Schlüssel.

## Existing Specs
- Keine Spec zur Einstellungsansicht; Vorbild für Aufbau und Belege: `docs/artifacts/feat-477-schnitt-2-detail/` und `docs/artifacts/feat-477-mac-papierstil/`.

## Risks & Considerations
- **Geräteliste:** `SettingsView.swift`, `Paper.swift` stehen nicht darauf → Abnahme endet nach Stufe 2 mit „Kein Pfad der Geräteliste berührt.“ Das Ticket verlangt zusätzlich „Abnahme über TestFlight auf dem Mac“; hier gilt Hennings Regel: Mac-Bilder nur aus der CI-Galerie (`MacGalleryTests`), nie von Hennings Mac. Einstellungen müssten in die Galerie (Fenster ⌘, öffnen, hell/dunkel); ob XCUITest das Settings-Fenster erreicht, ist offen.
- `List` auf dem Mac: Toggles, DatePicker (`hourAndMinute`), Button-Zeile mit Chevron verhalten sich anders als in `Form`; jede Zeile braucht Prüfung im Mac-Lauf.
- Das Zeilen-Layout in `Form` setzt Label links/Wert rechts automatisch; in `List` nicht überall (z. B. DatePicker-Label). Evtl. eine kleine `SettingsRow`-Hilfe nötig, ≤ 250 LoC einhalten.
- Accessibility-IDs und Verhalten der Schalter dürfen sich nicht ändern (DoD: „funktionieren wie vorher“).
- Fenstergröße: Entwurf zeigt 640 × 720 pt; die `Settings`-Szene hat heute keine feste Größe.
- Alternative (Pflicht laut Regeln): statt `List` die `Form` mit `.formStyle(.columns)` + eigenen Haarlinien-`Divider`s oder eine eigene `ScrollView`/`VStack` mit `SettingsRow`: volle Kontrolle über Abstand und Haarlinien, dafür mehr eigenes Layout, kein Zeilen-Verhalten von `List` nötig. Wird in /20-analyse am Mac abgewogen (Entwurf-Vorschau ist schon freigegeben, daher keine neue Artefakt-Seite).

## Analysis

### Type
Feature (reine Darstellung, Mac). Kein Fehler, keine Modell-/Regelfrage: „Without the model“ entfällt, es wird kein Modell vorgeschlagen.

### Recherche (vor der Analyse)
- SwiftUI kennt `formStyle` mit `automatic`, `grouped`, `columns`; `grouped` zeichnet die Karten, `columns` das Mac-Raster. Ein Papier-/Haarlinien-Stil ist in keinem davon eingebaut. Quelle: swiftwithmajid.com/2019/06/19/building-forms-with-swiftui, flaviocopes.com/courses/swiftui/swiftui-forms.
- Hausbeleg (#477): `List` plain + `.textFieldStyle(.plain)` + `.toggleStyle(.switch)` + `paperGround()` trägt auf dem Mac Haarlinien und Papier (`TaskDetailView.swift:280–300`).
- Der Fenstertitel eines `Settings`-Fensters ist Titelleiste des Systems. Seine Schrift (SF) setzt das System; 15 pt halbfett ist dort nicht einstellbar. Eigener Kopf im Inhalt wäre ein zweiter Titel neben dem der Titelleiste.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/SettingsView.swift` | MODIFY | Mac: `List` plain auf Papier statt `Form` grouped; Kopfzeilen mit `captionHead()`, Hinweise als graue 12-pt-Zeile unter der Zeile (Mac: Zeile in der Section, iOS: weiter `footer`); iCloud-Zeile ohne Section-Kopf; Zeilenhöhe ≥ 40, Haarlinien; Fensterbreite 640 pt. Compact/iOS-Sheet unverändert. |
| `LooseEnds/Views/Paper.swift` | MODIFY (klein) | Falls nötig `settingsRow`/`settingsHint` als wiederverwendbare Modifier (sonst in `SettingsView` privat). |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | Einstellungen per ⌘, öffnen und hell/dunkel fotografieren (`mac-gallery-settings-*`), Einträge per Accessibility-ID prüfen. |
| `docs/artifacts/feat-478-mac-einstellungen-papier/` | CREATE | Belege aus der CI-Galerie. |

### Scope Assessment
- Files: 3 Code/Test + Belege
- Estimated LoC: +90 / −30 (unter 250)
- Risk Level: LOW–MEDIUM. Betrifft nur die Darstellung auf dem Mac; Bindungen, `onChange`-Logik, AppStorage-Schlüssel, Accessibility-IDs bleiben. Risiko liegt in `List`-Verhalten auf dem Mac (DatePicker-Beschriftung, Button-Zeile, Chevron) und im Erreichen des Settings-Fensters per UI-Test.
- Geräteliste: kein Pfad berührt → „Kein Pfad der Geräteliste berührt.“ Mac-Bilder nur aus der CI-Galerie.

### Technical Approach (Empfehlung)
Wie das Detail in #477: auf dem Mac `List` + `.listStyle(.plain)` + `.textFieldStyle(.plain)` + `.toggleStyle(.switch)` + `paperGround()`, `listRowBackground(Paper.ground)`, Zeilen-Insets 20 pt. Die Zeilen (`sections`) werden einmal geschrieben und von beiden Containern genutzt (`Form` auf iOS, `List` auf Mac), damit nichts doppelt gepflegt wird. Umfang = Ist (zwei Schalter abends/morgens mit eigenen Uhrzeiten, seit #414/#518), im Stil der Tafel vom 16.10.; die Tafel kennt nur eine Auswahl, das ist der einzige Unterschied und wird im Beleg benannt.
Für den Fenstertitel: Titelleiste des Systems behalten. Abweichung zum Ticket („SF 15 pt halbfett“) wird im Bericht genannt.

### Alternative (nicht gewählt)
`Form` mit `.formStyle(.columns)` oder eigene `ScrollView`/`VStack` mit `SettingsRow` und `Divider`: volle Kontrolle über Abstand und Haarlinien und über 12-pt-Hinweise, dafür eigenes Layout, eigene Zugänglichkeit (Zeilen-Gruppierung, Tastaturfokus) und ein zweiter Stil neben dem Detail. Würde #477 als Muster kippen. Sinnvoll erst, wenn `List` in der CI-Galerie eine Zeile nicht sauber trägt (DatePicker-Beschriftung); dann nur für diese Zeile.

### Befunde, die gegen den Plan sprechen
Keine harten. Zu beobachten: (1) `List` setzt DatePicker-Label und Wert auf dem Mac nicht immer links/rechts wie `Form`; (2) Section-`footer` in einer Plain-List steht nicht direkt unter der Zeile, daher Hinweis als eigene Zeile ohne Trennlinie; (3) ob XCUITest das Settings-Fenster per ⌘, erreicht, ist ungeprüft.

### Dependencies
`DueNotificationCenter`, `CarryReminders.Mode`, `CalendarBridge`, `SyncStatus`, `LoginItem` (Mac), `AppVersion`, `CalendarPickerSheet`. `LooseEndsApp.swift:108` (Settings-Szene: feste Breite 640 pt), `ContentView.swift:86` (iOS-Sheet, unverändert).

### Open Questions
- [x] iPad-Sheet mitziehen? Nein: Ticket und Tafel betreffen den Mac; iPad bleibt `Form`.
- [x] Neue Entwurfsvorschau? Nein: Tafel ist freigegeben; Alternativen siehe oben.
- [ ] Fenstertitel: Titelleiste des Systems akzeptieren (Empfehlung) oder eigener Kopf? Wird in der Spec als Entscheidung festgehalten.
