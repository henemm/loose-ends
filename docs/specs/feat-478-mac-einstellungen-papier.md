---
entity_id: feat-478-mac-einstellungen-papier
type: feature
created: 2026-10-18
updated: 2026-10-18
status: draft
workflow: feat-478-mac-einstellungen-papier
---

# Spec: #478 — Einstellungsfenster der Mac-App im Papierstil

## Approval

- [ ] Approved (Henning)

Teil von Epic #467, Entwurf #408 (Tafel `docs/artifacts/feat-408-mac-entwurf/Einstellungen.dc.html`, freigegeben).
Analyse: `docs/context/feat-478-mac-einstellungen-papier.md`. Vorbild für Technik und Belege: #477 (Liste, Detail).

## Purpose

Das Einstellungsfenster der Mac-App (⌘,) zeigt Papier als Grund, Zeilen mit Haarlinien statt grauer Karten, kleine
Überschriften in Großbuchstaben und Hinweise in Grau 12 pt unter der Zeile, wie die Tafel. **Alle bisherigen Einträge und
Funktionen bleiben** und arbeiten wie vorher. iPhone und iPad (Sheet hinter dem Zahnrad) bleiben unverändert.

**Rein regelbasiert.** Reine Darstellung; kein Modell, kein Prompt, kein Schema. „Without the model this fails because …“
entfällt, weil kein Feld abgeleitet wird.

## Source

- **Geändert:** `LooseEnds/Views/SettingsView.swift` (Mac: `List` plain auf Papier; Zeilen einmal geschrieben, von beiden Behältern genutzt)
- **Geändert (klein, nur falls nötig):** `LooseEnds/Views/Paper.swift` (Modifier für Hinweiszeile)
- **Geändert:** `LooseEnds/App/LooseEndsApp.swift` (Breite der `Settings`-Szene)
- **Geändert:** `LooseEndsUITests/MacGalleryTests.swift` (Einstellungen per ⌘, öffnen und fotografieren)
- **Neu:** `docs/artifacts/feat-478-mac-einstellungen-papier/` (Belege aus der CI-Galerie)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Views/SettingsView.swift` | MODIFY | Mac: `List` + `.listStyle(.plain)` + `.textFieldStyle(.plain)` + `.toggleStyle(.switch)` + `paperGround()`; Abschnittsköpfe `captionHead()`; Hinweis als graue 12-pt-Zeile unter der Zeile; iCloud-Zeile ohne eigene Überschrift oben; Zeilenhöhe mindestens 40 pt; iOS: weiter `Form` grouped mit `footer` |
| `LooseEnds/Views/Paper.swift` | MODIFY (klein) | nur falls ein geteilter Modifier für die Hinweiszeile sinnvoll ist, sonst privat in `SettingsView` |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY (1–3 Zeilen) | `Settings`-Szene: feste Breite 640 pt |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | ⌘, öffnet das Fenster, Einträge per Kennung geprüft, Bilder `mac-gallery-settings-*` hell und dunkel |

### Estimated Changes

- Dateien: 3 bis 4, innerhalb der Grenze von 5.
- LoC: ca. +90/−30. Überschreitet die Umsetzung 250, wird gestoppt und mit Schätzung nachgefragt.

Geräteliste: **Kein Pfad der Geräteliste berührt** (`LooseEnds/Views`, `LooseEnds/App/LooseEndsApp.swift`, Tests; weder
`project.yml` noch Entitlements noch Info.plist). Keine Berechtigung, kein AppStorage-Schlüssel, kein Modellfeld, kein
CloudKit-Schema.

## Implementation Details

**Weiche.** Auf dem Mac (`#if os(macOS)`) trägt `SettingsView` eine `List`; auf iOS bleibt die `Form` mit `.formStyle(.grouped)`
unverändert. Das iPad-Sheet zieht nicht mit (Ticket und Tafel betreffen den Mac). Die Zeilen und Bindungen (`time`,
`carryMode`, `eveningTime`, `morningTime`, `opensAtLogin`, `choosesCalendar`) werden einmal geschrieben und in beiden Behältern
verwendet, damit nichts doppelt gepflegt wird. `onChange`, `.task`, `.sheet` und alle Kennungen bleiben am äußeren Behälter.

**Mac-Darstellung** (wie das Detail in #477, `TaskDetailView.swift` 280–300): `List` plain, `.textFieldStyle(.plain)`,
`.toggleStyle(.switch)` (sonst zeichnet `List` auf dem Mac Kästchen und Rahmen), `paperGround()`, `listRowBackground(Paper.ground)`,
Zeilen-Insets 20 pt (`Paper.wideRowInsets`), Zeilenhöhe mindestens 40 pt. Abschnittsköpfe `captionHead()`. Hinweise stehen auf
dem Mac als eigene Zeile direkt unter der Zeile, Schrift 12 pt grau, ohne Trennlinie darunter (eine Plain-`List` setzt den
`footer` nicht dicht unter die Zeile). Beschriftungen SF 14 pt, Werte rechts in Grau. Die iCloud-Zeile steht ohne eigene
Überschrift oben, der Status als Wert in Akzent mit Wolkensymbol (`SyncStatus.summary(...)` liefert Symbol und Rolle schon).

**Umfang = Ist**, im Stil der Tafel: Erinnerungszeit, Abend und Morgen als je ein Schalter mit eigener Uhrzeit (seit #414/#518),
iCloud-Abgleich, Kalender „New events in“, Menüleiste „Open at login“ (nur Mac), About mit Version. Die Tafel vom 16.10. kennt
„Wann am Tagesende …“ nur als eine Auswahl; das ist der einzige Unterschied und wird im Beleg benannt.

**Fenster.** `Settings`-Szene bekommt Breite 640 pt (Tafel: 640 × 720); die Höhe richtet sich nach dem Inhalt. Der Fenstertitel
bleibt die Titelleiste des Systems (`.navigationTitle("Settings")`): das System setzt ihre Schrift, 15 pt halbfett ist dort nicht
einstellbar, ein eigener Kopf im Inhalt wäre ein zweiter Titel. Das ist eine **Abweichung vom Ticket** und wird im Abschlussbericht
genannt.

**Alle Funktionen bleiben:** Uhrzeiten ändern, Schalter, Kalenderauswahl (Sheet), Anmelde-Schalter, Version markierbar. Kennungen
`reminderTimePicker`, `eveningToggle`, `eveningTimePicker`, `morningToggle`, `morningTimePicker`, `iCloudSyncRow`,
`defaultCalendarRow`, `openAtLoginToggle`, `appVersionRow`, `settingsDoneButton` bleiben unverändert.

**Galerie.** `MacGalleryTests` öffnet das Settings-Fenster mit ⌘,, wartet auf `reminderTimePicker`, prüft die Kennungen und
fotografiert hell und dunkel (`mac-gallery-settings-*`). Erreicht XCUITest das Fenster nicht, wird im Test der Weg über das
Menü „Loose Ends > Settings…“ genommen; gelingt auch das nicht, steht der Befund im Bericht und der Beleg wird auf anderem Weg
gebracht (Rückfrage), nie stillschweigend weggelassen.

**Bedingter Rückfall** (wie #477, Schritt 2): Zeigt ein Mac-Bild, dass `List` eine Zeile nicht sauber trägt (Beschriftung und
Uhrzeit nicht links/rechts, Chevron fehlt, Schalter mit Rahmen), wird nur diese Zeile als eigene `HStack` mit `Spacer` gebaut; der
Behälter bleibt.

### Alternativen

- **`Form` mit `.formStyle(.columns)` oder eigene `ScrollView`/`VStack` mit `Divider`:** volle Kontrolle über Haarlinien und
  12-pt-Hinweise, aber eigenes Layout und eigene Zugänglichkeit (Gruppierung, Tastaturfokus) und ein zweiter Stil neben dem Detail;
  kippt #477 als Muster. Nur Rückfall für einzelne Zeilen (siehe oben).
- **iPad-Sheet mitziehen (`isWide`):** hätte eine Darstellung für zwei Fenster; das Ticket verlangt sie nicht. Verworfen.
- **Eigener Fensterkopf mit SF 15 pt halbfett:** trifft das Ticket wörtlich, doppelt aber den Titel der Titelleiste. Verworfen.

## Test Plan

### Automated Tests (TDD RED)

Die Änderung ist reine Darstellung ohne neue Regel; es gibt keine Rechenlogik für einen Unit-Test. Der Nachweis läuft über die
Mac-Galerie (UI-Test, vor der Umsetzung rot, weil `mac-gallery-settings-*` und die Prüfung der Kennungen im Papierstil fehlen):

- [ ] `MacGalleryTests.testSettings`: GIVEN die Mac-App läuft WHEN ⌘, THEN erscheint das Fenster mit `reminderTimePicker`,
  `eveningToggle`, `morningToggle`, `iCloudSyncRow`, `defaultCalendarRow`, `openAtLoginToggle`, `appVersionRow`; Bilder hell
  und dunkel werden abgelegt.

Bestehend, grün zu halten: `SettingsSmokeTests` (iOS-Sheet; Kennungen und Verhalten unverändert), voller Unit-Lauf
(`./scripts/sim.sh sim-unit`, nie auf dem Mac), UI Smoke.

Simulator (Stufe 2): iPhone, Sheet hinter dem Zahnrad, vorher (`main`) und nachher; Bilder geöffnet und beschrieben (unverändert).
Mac: nur Bilder aus dem CI-Job „Mac Gallery (macOS)“ (Artefakt `MacGallery`), nie von Hennings Mac.

## Acceptance Criteria

- **AC-1:** Das Settings-Fenster auf dem Mac zeigt Papier als Grund (hell und dunkel) und Zeilen mit Haarlinien statt grauer
  Karten. Beleg: Galeriebilder `mac-gallery-settings-*` (hell, dunkel) aus dem CI-Lauf, geöffnet und beschrieben.
- **AC-2:** Die Abschnittsköpfe stehen als kleine graue Großbuchstaben (`captionHead()`), die Hinweise als graue 12-pt-Zeile direkt
  unter der Zeile; die iCloud-Zeile steht oben ohne eigene Überschrift, ihr Status als Wert in Akzent mit Wolkensymbol (Sichtbefund
  im Galeriebild).
- **AC-3:** Alle Einträge sind im Fenster vorhanden: Erinnerungszeit, Abend-Schalter, Morgen-Schalter, iCloud-Abgleich, Kalender
  „New events in“, „Open at login“, Version. Beleg: `MacGalleryTests.testSettings` findet die Kennungen `reminderTimePicker`,
  `eveningToggle`, `morningToggle`, `iCloudSyncRow`, `defaultCalendarRow`, `openAtLoginToggle`, `appVersionRow`; im Diff sind
  alle Kennungen unverändert.
- **AC-4:** Die Funktionen sind unverändert: Der Diff zeigt Bindungen, `onChange`, `.task` und `.sheet` ungeändert, keine neuen
  AppStorage-Schlüssel; `SettingsSmokeTests` und der volle Unit-Lauf sind grün.
- **AC-5:** Schalter erscheinen auf dem Mac als Schalter ohne Kästchen und Rahmen, Uhrzeiten als Beschriftung links und Zeit
  rechts, die Kalenderzeile mit Wert und Chevron (Sichtbefund im Galeriebild; trifft einer der Punkte nicht zu, ist der Rückfall
  für diese Zeile umgesetzt und die Galerie danach erneut beschrieben).
- **AC-6:** Das Fenster ist 640 pt breit (Fenstergröße aus der Galerie) und der Fenstertitel steht in der Titelleiste des Systems;
  die Abweichung zum Ticket („SF 15 pt halbfett“) ist im Abschlussbericht benannt.
- **AC-7:** iPhone und iPad bleiben unverändert: die Modifier-Kette der iOS-Zweige ist im Diff unverändert, und das
  iPhone-Simulatorbild des Sheets zeigt vorher (`main`) und nachher dasselbe (beide beschrieben).

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `DueNotificationCenter`, `CarryReminders.Mode`, `DueReminders.Time` | module | Uhrzeiten und Modus; unverändert |
| `CalendarBridge`, `CalendarPickerSheet` | module | Kalenderzeile; unverändert |
| `SyncStatus` | module | Status, Symbol, Rolle; unverändert |
| `LoginItem`, `AppVersion` | module | Mac-Schalter, Version; unverändert |
| `Paper`, `paperGround`, `captionHead` | module | aus #477, unverändert |
| `MacGalleryTests`, CI-Job „Mac Gallery (macOS)“ (#511) | test | liefert die Mac-Bilder |
| Neue externe Abhängigkeit | – | keine |

## Außerhalb des Umfangs

- Neue Einstellungen, geänderte Texte oder Reihenfolge der Einträge.
- Das iPad-Sheet und das iPhone-Sheet.
- Haarlinien-Feinheiten der Listen (F002/F003 aus #477) und Auswahl in Akzent (#480).

## Auslieferung

Nach dem Merge läuft der TestFlight-Bau; Henning bekommt die Buildnummer und die Prüfschritte für den Mac (⌘, drücken: Papier,
Haarlinien, Hinweise in Grau), keine Befehlszeile. Kein Modell, deshalb kein `mac-schema-init`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — keine neue Entscheidung. ADR-1 (eine Codebasis, Abweichung über `#if os(macOS)`) trägt die Weiche; kein
  Modell-, Schema- oder Persistenzeingriff.

## Definition of Done

- AC-1 bis AC-7 erfüllt; Unit-Lauf (`sim-unit`) und UI Smoke grün; `MacGalleryTests.testSettings` grün in der CI.
- Stufe 2: iPhone-Sheet im Simulator gebaut, gestartet, fotografiert, beschrieben; Mac-Bilder aus dem CI-Artefakt `MacGallery`.
- Satz im Abschlussbericht: „Kein Pfad der Geräteliste berührt.“
- PR mit `Closes #478`; Board gepflegt; Belege unter `docs/artifacts/feat-478-mac-einstellungen-papier/`.

## Changelog

- 2026-10-18: Spec aus der Analyse `docs/context/feat-478-mac-einstellungen-papier.md` geschrieben. Entscheidung Fenstertitel:
  Titelleiste des Systems behalten.
