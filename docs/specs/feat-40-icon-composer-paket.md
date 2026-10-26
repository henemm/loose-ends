---
entity_id: feat-40-icon-composer-paket
type: feature
created: 2026-10-26
updated: 2026-10-26
status: draft
workflow: 40-icon-composer-paket
---

# Spec: #40 — App-Icon als Icon-Composer-Paket (Liquid Glass mit Ebenentiefe)

## Approval

- [ ] Approved (Henning)

## Purpose

Das App-Icon (Motiv B, der Knoten, Petrol auf hellem Grund, #19) ist heute als PNG im Asset-Katalog und wirkt auf iOS 26/27
flach. Liquid Glass bekommt Tiefe, Glanz und Kantenlicht erst aus einem `.icon`-Paket. Henning (2026-10-26): das Icon soll
vor der ersten Einladung Ebenentiefe haben. Motiv und Farbe bleiben (`docs/project/05-logo.md`), nur die technische Form ändert sich.

**Hat es bisher funktioniert?** Ja, die PNGs funktionieren; es ist keine Störung, sondern ein Aussehen-Wunsch.

### Befunde aus dem Spike (2026-10-26, Wegwerf-Projekt, nichts im Repo)

- Ein von Hand geschriebenes `AppIcon.icon` übersetzt `actool` (Xcode 27.1) ohne Icon-Composer-GUI. Schema des Füllers:
  `"fill": {"solid": "srgb:r,g,b,a"}` (nicht als String); die Fehlermeldungen von `actool` benennen falsche Schlüssel brauchbar.
- XcodeGen 2.46 nimmt `AppIcon.icon` als Quelle an (`wrapper.icon`, Resources-Phase); iOS-Simulator-Bau: BUILD SUCCEEDED.
- Liegen `AppIcon.icon` und `AppIcon.appiconset` nebeneinander, baut es fehlerfrei; das `.icon` gewinnt, die PNGs werden ignoriert
  (`Assets.car` gleich groß). **Das DoD-Wort „PNG-Fallbacks bleiben“ ist damit wirkungslos**, aber unschädlich (Apple:
  [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer.md)).
- Im iOS-27-Simulator zeigt der Home-Screen (hell) das neue Icon mit Glanz und Kantenlicht; die Maske am Kreuzungspunkt des Fadens
  bleibt erhalten. Vorschau: `docs/artifacts/40-icon-composer-paket/`.
- Ein fester heller Grund bleibt im Dunkelmodus hell. Dunkel braucht `fill-specializations` (`appearance: dark`) und
  `image-name-specializations`. Dass der Faden dort `#5FC4C9` trägt, wurde im Spike **nicht gesehen** (`simctl ui appearance`
  schaltet den Icon-Stil nicht um) — der Beleg gehört in die Tests (AC-3).

### Entscheidungen (Henning, 2026-10-26, nach Vorschau)

- Dunkel bekommt einen **eigenen dunklen Grund** (Petrol-Schwarz) mit Faden `#5FC4C9`.
- Der Grund ist ein `fill`, keine Ebene; das Paket hat eine Gruppe (Faden mit Glas). Der Wortlaut „zwei Ebenen“ in
  `docs/design/logo/README.md` und `05-logo.md` wird entsprechend berichtigt.

### Alternativen (Analyse)

- **B: Nichts bauen** — die PNGs bleiben korrekt, nur flach; widerspricht Hennings Beschluss.
- **C: Grund als eigene Ebene** — sieht gleich aus, kostet eine Ebene mehr, hält den Wortlaut „zwei Ebenen“.
- **Dunkel durchsichtig wie heute** — System legt seinen Grund darunter; verworfen zugunsten des eigenen Grundes.

Regelweg-Vermerk (Regeln vor Modell): Kein Modell beteiligt; Konfiguration und Bilddateien.

## Source

- **Files:** `LooseEnds/Resources/AppIcon.icon/` (neu), `scripts/test_app_icon_package.py` (neu), `project.yml`
- **Identifier:** `AppIcon` (Icon-Name = `ASSETCATALOG_COMPILER_APPICON_NAME`); Vorbild für den Skripttest: `scripts/test_info_plist_sync.py`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| #19 | Vorarbeit | Motiv und Farbe des Icons sind entschieden und bleiben |
| #176 | Gerätedurchgang | Hell/Dunkel/Getönt/Klar, Watch und Dock werden im selben TestFlight-Durchgang geprüft (N-2) |
| `docs/design/logo/layer-thread.svg` | Quelle | Faden-Ebene mit Maske, Ausgangspunkt der beiden SVG im Paket |
| XcodeGen 2.46, `actool` Xcode 27 | Werkzeug | Paket als Quelle des Targets, Übersetzung zu `Assets.car` |

## Scope

- **Neu:** `LooseEnds/Resources/AppIcon.icon/icon.json`, `LooseEnds/Resources/AppIcon.icon/Assets/layer-thread.svg`
  (Faden `#0F6E73`) und `layer-thread-dark.svg` (Faden `#5FC4C9`), beide aus `docs/design/logo/layer-thread.svg` abgeleitet
  (nur die Strichfarbe unterscheidet sich; Maske bleibt).
- **Neu:** `scripts/test_app_icon_package.py` (Skripttest wie `test_info_plist_sync.py`).
- **Geändert:** `project.yml` — nur wenn der Bau es verlangt (das `.icon` liegt unter `LooseEnds/Resources`, das schon Quelle ist);
  das Watch-Target bekommt dasselbe Paket als Quelle statt einer Kopie. `ASSETCATALOG_COMPILER_APPICON_NAME` bleibt `AppIcon`.
- **Geändert:** `docs/design/logo/README.md` (Abschnitt „Nächster Schritt auf dem Mac“ durch den Ist-Stand ersetzen),
  `docs/project/05-logo.md` (Technische Form: eine Gruppe mit Fill, PNG-Sätze ungenutzt).
- **Nicht angefasst:** Motiv, Farben, die PNG-Sätze im Asset-Katalog (bleiben liegen, in der Doku als ungenutzt benannt; Löschen wäre
  eine spätere Aufräumfrage).
- Umfang: 5 Dateien Code und Daten (`icon.json`, zwei SVG, Skripttest, `project.yml`), ca. +120 LoC (überwiegend SVG-Pfade als Daten), keine Löschung.
  Die zwei Doku-Berichtigungen (README, `05-logo.md`) sind Textzeilen ohne Code und zählen nicht gegen das Dateilimit.

## Acceptance Criteria

- **AC-1:** `LooseEnds/Resources/AppIcon.icon` liegt im Repo; `icon.json` ist lesbares JSON, nennt eine Gruppe mit der Ebene
  `layer-thread.svg` (Glas, Specular, neutraler Schatten) und einen hellen Fill `#F4F3EE`; alle genannten Bilddateien existieren.
- **AC-2:** `./scripts/sim.sh build` (iOS) und der Mac-Bau (`./scripts/sim.sh mac-build`) laufen durch; `actool` meldet keinen Fehler,
  `ASSETCATALOG_COMPILER_APPICON_NAME` bleibt `AppIcon`.
- **AC-3:** Hell, Dunkel und Getönt sind im gebauten Paket belegt: die `Assets.car` der gebauten App enthält die Darstellungen,
  und ein aus ihr gerendertes Bild je Darstellung (`ictool` oder Auslese der `Assets.car`) zeigt im Dunkel den dunklen Grund mit
  Faden `#5FC4C9`. Die Bilder werden geöffnet und beschrieben, nicht gezählt.
- **AC-4:** Im iOS-27-Simulator zeigt der Home-Screen das neue Icon (hell) mit sichtbarer Tiefe; Screenshot als Beleg über
  `./scripts/sim.sh test-proof` bzw. `screenshot`.
- **AC-5:** Das Watch-Target baut mit demselben Paket (keine Kopie der SVGs, Leinwand 1088 vom System angepasst); `watch`-Bau läuft durch.
- **AC-6:** `scripts/test_app_icon_package.py` läuft in der CI im Schritt „Script tests“ und prüft: Manifest lesbar, Bilder vorhanden,
  Hell- und Dunkel-SVG unterscheiden sich nur in der Strichfarbe, Fill-Spezialisierung für Dunkel vorhanden.
- **AC-8:** README und `05-logo.md` nennen den Ist-Stand (eine Gruppe mit Fill, PNG-Sätze ungenutzt) statt „zwei Ebenen / Icon Composer per GUI“.
### Nachgelagert (kein AC, Ticket bleibt offen; Henning, 2026-10-26)

Beides ist erst nach dem Merge belegbar und blockiert die Abnahme nicht. Das Ticket bleibt bis zum Beleg offen.

- **N-1 (früher AC-7):** Das Archiv des TestFlight-Laufs (Prüfschritt „Verify the archive“) findet das Icon weiter; der Probe-Bau (`BUNDLE_ID_SUFFIX`) baut.
- **N-2 (früher AC-9, Gerät, Stufe 3):** Home-Screen in Hell, Dunkel, Getönt und Klar, Watch und Mac-Dock im selben TestFlight-Durchgang wie #176.
  Gilt, weil `project.yml` auf der Geräteliste steht; nichts auf Hennings Geräten, bevor er „jetzt ist ein Test möglich“ schreibt.

## Test Plan

- `scripts/test_app_icon_package.py` (AC-1, AC-6) — zuerst rot, weil das Paket fehlt.
- Bau-Belege (AC-2, AC-5) und Bildbelege (AC-3, AC-4) aus `sim.sh`; Bilder werden angesehen.
- Kein UI-Test: keine Funktion ändert sich; Beleg ist das gerenderte Bild.

## Risiken

1. `Assets.car`-Auslese für Dunkel/Getönt ist unerprobt; fällt sie aus, bleibt N-2 der Beleg (dann ehrlich so benannt).
2. `ictool` hat keine dokumentierten Argumente (`man ictool`).
3. CI pinnt Xcode 27.0, der Spike lief mit 27.1; AC-2 muss in der CI grün sein.
4. Forum-Fall `Exception while running actool` mit `.icon` unter Xcode 27 Beta ([Apple Forum 831309](https://developer.apple.com/forums/thread/831309)) — im Spike nicht aufgetreten.

## Definition of Done

- [ ] `scripts/test_app_icon_package.py` war vor dem Paket rot und ist mit dem Paket grün; alle anderen `scripts/test_*.py` bleiben grün.
- [ ] `./scripts/sim.sh build`, `mac-build` und der Watch-Bau laufen durch; CI grün.
- [ ] Gerenderte Bilder (hell, dunkel) und der Home-Screen-Screenshot sind geöffnet und beschrieben (AC-3, AC-4).
- [ ] README und `05-logo.md` nennen den Ist-Stand.
- [ ] Nachgelagerte Punkte N-1 und N-2 mit Hennings Rückmeldung zum TestFlight-Durchgang abgehakt; bis dahin bleibt das Ticket offen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Aussehen und Ressourcenform des Icons; Motiv, Farbe und Architektur bleiben unberührt.

## Changelog

- 2026-10-26: Initial spec created
