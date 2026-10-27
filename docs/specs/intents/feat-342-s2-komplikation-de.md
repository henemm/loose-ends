---
entity_id: feat-342-s2-komplikation-de
type: feature
created: 2026-10-27
updated: 2026-10-27
status: draft
workflow: 342-s2-komplikation-de
---

# Spec: Uhr-Komplikation auf Deutsch (#342, Schnitt 2, Teil 4)

## Approval

- [ ] Approved

## GitHub Issue

#342 „Einladung externer Tester: was noch fehlt“ (Epic #371), Teil 4 (Deutsch und Englisch), Schnitt 2.
Kontext und Analyse: `docs/context/342-s2-komplikation-de.md`.

## Purpose

Auf einem deutschen Gerät zeigt die Zifferblatt-Galerie der Uhr die Komplikation mit dem Namen „Capture“ und der Beschreibung „Opens capture.“ auf Englisch. Beide Texte sollen auf Deutsch erscheinen („Erfassen“, „Öffnet die Erfassung.“), und ein Test soll das festhalten.

**Ursache (am Code belegt):** `LooseEndsWatchWidgets/` hat keinen String-Katalog. Die vier Literale in `CaptureComplication.swift` (`accessibilityLabel("Capture")` Z. 55, `widgetLabel("Capture")` Z. 67, `configurationDisplayName("Capture")` Z. 96, `description("Opens capture.")` Z. 97) finden im Paket des Watch-Widgets nichts und fallen auf Englisch. Der Code→Katalog-Scan aus #711 sah weder diesen Ordner noch diese vier Modifier (er kennt nur `Text(`, `Button(`, `Label(`, `LabeledContent(`, `navigationTitle(`, `String(localized:`).

**Ohne Modell:** reine Texte und ein Dateivergleich; kein Feld wird vorgeschlagen, das ein Modell setzt. „Without the model this fails because …“ entfällt.

**Recherche (zuerst):** `configurationDisplayName(_:)` und `description(_:)` nehmen `LocalizedStringKey` und lösen gegen den Katalog des Widget-Ziels auf (Apple-Doku, https://developer.apple.com/documentation/swiftui/widgetconfiguration/configurationdisplayname(_:)-4v9q). Der bekannte Forumsfehler (https://origin-devforums.apple.com/forums/thread/823545, FB22509406) betrifft nur `@Parameter`-Titel einer `WidgetConfigurationIntent` auf der echten Uhr; die Komplikation ist statisch ohne Intent, also nicht betroffen. Zum genauen Katalogaufbau im Watch-Widget fand sich keine Apple-Quelle: Der Bau (Paket enthält `de.lproj`) ist der Nachweis.

## Source

- **File:** `LooseEndsWatchWidgets/CaptureComplication.swift` (bleibt unverändert)
- **Identifier:** Schlüssel „Capture“ und „Opens capture.“

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `project.yml` Z. 179–194 | Quelle des Ziels `LooseEndsWatchWidgets` | bindet den ganzen Ordner als Quelle ein; ein Katalog dort wird ohne Änderung mitgebündelt, bleibt **unverändert** |
| `LooseEndsWidgets/Localizable.xcstrings` | Vorbild | Katalogformat (Quelle `en`, je Eintrag `de` mit Zustand `translated`), „Capture“ → „Erfassen“ dort schon vorhanden |
| `scripts/test_infoplist_languages.py` | bestehender Test (#708, #711) | `CATALOGS`, `CODE_FOLDERS`, `LITERAL`; CI führt alle `scripts/test_*.py` per `unittest discover` aus |
| `LooseEndsTests/CaptureComplicationTests.swift` | bestehender Test | rendert die Ansicht, keine Textprüfung; bleibt unberührt |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsWatchWidgets/Localizable.xcstrings` | CREATE | „Capture“ → „Erfassen“, „Opens capture.“ → „Öffnet die Erfassung.“ |
| `scripts/test_infoplist_languages.py` | MODIFY | Katalog in `CATALOGS`; Ordner `LooseEndsWatchWidgets` mit den Modifiern `accessibilityLabel`, `widgetLabel`, `configurationDisplayName`, `description` in den Scan; ein Test für die Komplikation samt Selbstprüfung |
| `LooseEndsWatchWidgets/CaptureComplication.swift` | UNCHANGED | Literale bleiben, nur der Katalog fehlt |
| `project.yml` | UNCHANGED | Ordner ist schon Quelle |

### Estimated Changes

- Files: 2 (1 neu, 1 geändert)
- LoC: ca. +40
- Risk Level: LOW (nur Texte). Keine UI-Änderung, daher kein Entwurf nötig. Stufe 3 greift, weil `LooseEndsWatchWidgets/` auf der Geräteliste steht.

## Implementation Details

1. **Katalog** `LooseEndsWatchWidgets/Localizable.xcstrings` im Format von `LooseEndsWidgets/Localizable.xcstrings`: `sourceLanguage` `en`, `version` `1.0`, zwei Einträge mit `de` / `stringUnit` / `state` `translated`:
   - „Capture“ → „Erfassen“
   - „Opens capture.“ → „Öffnet die Erfassung.“
2. **Test** (`scripts/test_infoplist_languages.py`):
   - `CATALOGS` bekommt `LooseEndsWatchWidgets/Localizable.xcstrings`; der bestehende Test `test_every_catalog_entry_has_german` deckt damit die Vollständigkeit ab.
   - Ein zweites Muster `MODIFIER_LITERAL` für `accessibilityLabel(`, `widgetLabel(`, `configurationDisplayName(`, `description(` mit Literal ohne Interpolation. `literals_missing_from_catalog` bekommt dafür einen Parameter für das Muster (Standard: das bisherige `LITERAL`), damit der Scan der App (`LooseEnds`, `Shared`) unverändert bleibt und nicht plötzlich fremde `description(`-Aufrufe meldet.
   - Neuer Test `test_complication_literals_have_a_catalog_entry`: jedes Literal aus `LooseEndsWatchWidgets/` (Muster `LITERAL` plus `MODIFIER_LITERAL`) steht in `LooseEndsWatchWidgets/Localizable.xcstrings`.
   - Selbstprüfung `test_modifier_scanner_finds_a_missing_key`: eine Wegwerf-Datei mit `.configurationDisplayName("Capture")`, `.description("Opens capture.")`, `.widgetLabel("Capture")`, `.accessibilityLabel("Capture")` und einem Katalog ohne diese Schlüssel meldet beide Schlüssel; mit Katalog meldet er nichts.
3. **Rot-Beweis vor dem Katalog:** Test zuerst mit dem erweiterten Scan, aber ohne die Katalogdatei laufen lassen (rot: Datei fehlt bzw. beide Schlüssel fehlen), dann Katalog anlegen (grün).
4. **Bau-Nachweis:** Reproduktion vorher: Watch-Widget bauen, im Paket fehlt `de.lproj`. Nachher: gleiches Paket enthält `de.lproj/Localizable.strings` mit beiden Schlüsseln und deutschen Werten.

**Side-Effects, ausdrücklich:** keine neue Berechtigung, kein AppStorage-Key, keine Änderung an `project.yml`, `Info.plist`, Entitlements oder CloudKit-Schema, keine Audio-Dateien. Neue Datei: ein Katalog.

## Test Plan

### Automated Tests (TDD RED)

- [ ] `scripts/test_infoplist_languages.py` · `test_complication_literals_have_a_catalog_entry`: GIVEN die vier Literale der Komplikation und noch kein Katalog WHEN geprüft THEN RED (Meldung nennt „Capture“ und „Opens capture.“ samt `CaptureComplication.swift`), GREEN nach dem Katalog.
- [ ] `test_modifier_scanner_finds_a_missing_key` (Selbstprüfung): fehlender Schlüssel wird gefunden, vorhandener nicht.
- [ ] `test_every_catalog_entry_has_german` mit dem neuen Katalog in `CATALOGS`: GREEN.
- [ ] Alle übrigen `scripts/test_*.py` und `CaptureComplicationTests` bleiben GREEN.
- Läufe: `python3 -m unittest scripts/test_infoplist_languages.py` (rot, dann grün); `python3 -m unittest discover -s scripts -p 'test_*.py'`; Bau per `./scripts/sim.sh watch-test-proof` bzw. Bau des Watch-Widget-Ziels und Blick ins Paket.

## Acceptance Criteria

- **AC-1:** Die Datei `LooseEndsWatchWidgets/Localizable.xcstrings` existiert, hat Quellsprache `en` und enthält die Schlüssel „Capture“ mit `de` = „Erfassen“ und „Opens capture.“ mit `de` = „Öffnet die Erfassung.“, beide mit Zustand `translated`.
- **AC-2:** `scripts/test_infoplist_languages.py` führt den Katalog in `CATALOGS` und scannt den Ordner `LooseEndsWatchWidgets` samt den Modifiern `accessibilityLabel`, `widgetLabel`, `configurationDisplayName` und `description`; der Test schlägt rot fehl, wenn ein Literal der Komplikation im Katalog fehlt. Der Rot-Beweis (Test ohne Katalog rot, mit Katalog grün) ist vor dem Anlegen des Katalogs gezeigt, und eine Selbstprüfung belegt, dass der Modifier-Scan einen fehlenden Schlüssel findet und einen vorhandenen nicht meldet.
- **AC-3:** Das gebaute Watch-Widget-Paket enthält `de.lproj/Localizable.strings` mit beiden Schlüsseln und den deutschen Werten (Bau-Nachweis); die Reproduktion vorher zeigt, dass `de.lproj` im Paket fehlte.
- **AC-4:** `CaptureComplicationTests` und alle bestehenden `scripts/test_*.py` bleiben grün; `project.yml` und `LooseEndsWatchWidgets/CaptureComplication.swift` sind unverändert (`git diff` leer), ebenso alle `Info.plist` (Schritt „Generate leaves the tree clean“ grün).
- **AC-5:** Gerätepunkt: Die Zifferblatt-Galerie der Uhr zeigt Name und Beschreibung der Komplikation auf Deutsch. Der Nachweis läuft nur über TestFlight und nur nach Hennings wörtlichem „jetzt ist ein Test möglich“; bis dahin bleibt das Ticket offen. Nichts davon wird auf Hennings Geräten gestartet, bevor er es geschrieben hat.
- **AC-6:** Keine weiteren Änderungen (Scope-Liste oben: 2 Dateien, ca. +40 LoC).

## Alternativen

- **A. App-Katalog per `includes` einbinden** (wie `LooseEndsWatch`): kein neuer Katalog, aber Änderung an `project.yml` und damit am Gerätegate. Verworfen. Kippt keine ADR.
- **B. Texte im Swift-Code per `Locale` wählen:** umgeht den Katalog und bricht die Ein-Katalog-Regel (ein Katalog je Ziel, `FieldCodec`-Prinzip „eine Kodierung“). Verworfen.
- **C. Nur den Scan erweitern, Texte unübersetzt lassen:** würde die Lücke melden, aber nicht schließen. Verworfen.
- **Gewählt:** eigener Katalog je Ziel wie bei `LooseEndsWidgets` und `LooseEndsShare`, Regelweg, Test hält ihn fest.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Übersetzung eines Zielkatalogs nach bestehendem Muster, keine neue Struktur, Dependency oder Datenform.

## Definition of Done

- [ ] AC-1 bis AC-4 und AC-6 durch Tests und Bau belegt; AC-5 offen bis TestFlight und Hennings Wort
- [ ] PR mit `Refs #342` (Ticket bleibt offen), CI grün, gemergt, Hauptordner aktuell
- [ ] Fortschritt als Kommentar in #342
- [ ] Beobachtbar: auf einer deutschen Uhr zeigt die Galerie „Erfassen“ und „Öffnet die Erfassung.“
- [ ] Regressionslauf grün

## Changelog

- 2026-10-27: Initial spec created
