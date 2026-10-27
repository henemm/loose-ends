# Adversary Dialog — 342-s2-komplikation-de
Spec: docs/specs/intents/feat-342-s2-komplikation-de.md
Datum: 2026-10-27 15:02

## Checkliste
- [x] **AC-1:** Die Datei `LooseEndsWatchWidgets/Localizable.xcstrings` existiert, hat Quellsprache `en` und enthält die Schlüssel „Capture“ mit `de` = „Erfassen“ und „Opens capture.“ mit `de` = „Öffnet die Erfassung.“, beide mit Zustand `translated`.
- [x] **AC-2:** `scripts/test_infoplist_languages.py` führt den Katalog in `CATALOGS` und scannt den Ordner `LooseEndsWatchWidgets` samt den Modifiern `accessibilityLabel`, `widgetLabel`, `configurationDisplayName` und `description`; der Test schlägt rot fehl, wenn ein Literal der Komplikation im Katalog fehlt. Der Rot-Beweis (Test ohne Katalog rot, mit Katalog grün) ist vor dem Anlegen des Katalogs gezeigt, und eine Selbstprüfung belegt, dass der Modifier-Scan einen fehlenden Schlüssel findet und einen vorhandenen nicht meldet.
- [x] **AC-3:** Das gebaute Watch-Widget-Paket enthält `de.lproj/Localizable.strings` mit beiden Schlüsseln und den deutschen Werten (Bau-Nachweis); die Reproduktion vorher zeigt, dass `de.lproj` im Paket fehlte.
- [x] **AC-4:** `CaptureComplicationTests` und alle bestehenden `scripts/test_*.py` bleiben grün; `project.yml` und `LooseEndsWatchWidgets/CaptureComplication.swift` sind unverändert (`git diff` leer), ebenso alle `Info.plist` (Schritt „Generate leaves the tree clean“ grün).
- [x] **AC-5:** Gerätepunkt: Die Zifferblatt-Galerie der Uhr zeigt Name und Beschreibung der Komplikation auf Deutsch. Der Nachweis läuft nur über TestFlight und nur nach Hennings wörtlichem „jetzt ist ein Test möglich“; bis dahin bleibt das Ticket offen. Nichts davon wird auf Hennings Geräten gestartet, bevor er es geschrieben hat.
- [x] **AC-6:** Keine weiteren Änderungen (Scope-Liste oben: 2 Dateien, ca. +40 LoC).

## Dialog

### Runde 1
**Adversary:** Existiert der Katalog, ist er gueltiges JSON, Quelle en, beide Eintraege mit state translated und korrektem Umlaut? Hat der Scan den Ordner und alle vier Modifier, und wuerde der Test bei kaputtem Scanner rot?
**Implementierer:** Belege selbst erhoben. Code reference: LooseEndsWatchWidgets/Localizable.xcstrings:1 (json.load OK; sourceLanguage en, version 1.0; Zeile 5 "Capture" -> "Erfassen" translated; Zeile 6 "Opens capture." -> "Öffnet die Erfassung." translated, Ö korrekt). Code reference: scripts/test_infoplist_languages.py:27 (Katalog in CATALOGS), :125-128 (MODIFIER_LITERAL mit allen vier Modifiern), :131 (Parameter patterns), :166-170 (Test Komplikation), :172-184 (Selbstpruefung). Lauf `python3 -m unittest scripts/test_infoplist_languages.py -v`: 8 Tests OK, inkl. test_complication_literals_have_a_catalog_entry, test_modifier_scanner_finds_a_missing_key, test_every_catalog_entry_has_german. Vollauf `unittest discover -s scripts -p 'test_*.py'`: Ran 311 tests OK. Rot-Beweis: docs/artifacts/342-s2-komplikation-de/test-red-output.txt zeigt FAILED (failures=1) mit "Capture" und "Opens capture." aus CaptureComplication.swift; der Commit d9cad89 enthaelt den Test, aber keinen Katalog (Katalog ist noch untracked, also nach dem Rot-Lauf angelegt).
Eigene Mutationsprobe (Wegwerfskript): Katalog nur mit "Capture" -> Scan meldet ['Opens capture.']; Text("Foo") ohne Eintrag -> gemeldet; echter Ordner -> {} (nichts fehlt). Der Scanner findet fehlende Schluessel wirklich.
AC-1 PROVEN, AC-2 PROVEN.

### Runde 2
**Adversary:** Edge Cases des Scans: Mehrzeiler, andere Modifier, Interpolation; Bau-Nachweis; Scope; Geraete.
**Implementierer:** Probe: `.description(` mit Literal auf der Folgezeile wird NICHT gefunden, ebenso `.accessibilityHint("Foo")`. Von der Spec nicht verlangt (genau vier Modifier, einzeilig; die Komplikation nutzt sie einzeilig), aber Luecke fuer spaeter -> Finding F001 LOW. Interpolierte Literale werden uebersprungen wie im bestehenden Scan (Code reference: scripts/test_infoplist_languages.py:141).
AC-3: docs/artifacts/342-s2-komplikation-de/build-before.txt: Paket ohne de.lproj; build-after.txt: de.lproj/Localizable.strings, plutil zeigt beide Schluessel mit deutschen Werten, auch in der eingebetteten Watch-App. Beleg vorhanden; Bau von mir nicht wiederholt. PROVEN.
AC-4: `./scripts/sim.sh sim-unit CaptureComplicationTests`: Test Succeeded (3 Tests der Suite "Watch complication (#355)" gruen), Ausgabe docs/artifacts/342-s2-komplikation-de/adversary-test-output.txt. Diff gegen die Basis vor d9cad89 fuer project.yml, CaptureComplication.swift und beide Info.plist ist leer. PROVEN. Hinweis: CI-Schritt "Generate leaves the tree clean" nicht lokal wiederholt; project.yml ist unveraendert.
AC-5: offen laut Spec zulaessig. Im Artefaktordner kein devicectl/device*-Aufruf; ich selbst habe nur den Simulator-Unit-Lauf gestartet. Nichts auf Geraeten getan. OFFEN (zulaessig).
AC-6: gegenueber der Basis: Katalog (neu), scripts/test_infoplist_languages.py (+33/-2), dazu Spec/Kontext/Briefing/Artefakte (Dokumente). Kein weiterer Produktcode. PROVEN.
Code reference (Abdeckung): LooseEndsWatchWidgets/Localizable.xcstrings:5 ; scripts/test_infoplist_languages.py:125.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_infoplist_languages.py:125
  Description: MODIFIER_LITERAL verlangt das Literal direkt nach "(" auf derselben Zeile und kennt nur vier Modifier.
  Spec requirement: AC-2 — genau diese vier Modifier einzeilig; erfuellt.
  Conflict: Mehrzeiler oder spaetere Modifier (accessibilityHint) bleiben unbemerkt; kein Spec-Verstoss.
  Remediation: optional Whitespace nach "(" erlauben und weitere Modifier ergaenzen, wenn die Komplikation waechst.

Confirmation:
  AC: AC-1
  Code reference: LooseEndsWatchWidgets/Localizable.xcstrings:5
  Evidence: gueltiges JSON, en, beide Eintraege translated mit korrekten Werten.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_infoplist_languages.py:166
  Evidence: Test gruen, Rot-Beleg vorhanden, Mutationsprobe findet fehlenden Schluessel.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Die Aenderung betrifft nur Texte und einen Dateivergleich; keine Produktionsschreibstelle eines Feldes, keine verdaechtige Zeile.

## Verdict
**VERIFIED** — AC-1 bis AC-4 und AC-6 belegt (311 Skripttests gruen, Katalog gueltig, Bau-Beleg vorher/nachher, Scope sauber), AC-5 laut Spec offen (Geraetepunkt, nichts auf Geraeten gestartet). Einziger Befund F001 LOW.

## Geprüfte Dateien

- sha256:5cc2d7cb17b1c350303c977063070493bf6991c9416f7f607f30d3651de3f34f  LooseEndsWatchWidgets/Localizable.xcstrings
- sha256:01af732445a534758536fa9ae3dc9acd8e4e3ce8dfbef25b370d927fbe542846  scripts/test_infoplist_languages.py

## Prüfbasis

- base: 50d06000c2e184b197c0b33c18a6fafa3da5092c
- blob:3c9a7d68f2e2b3da5bc38c66086f5180e1e681de  LooseEndsWatchWidgets/Localizable.xcstrings
- blob:a173878780a460135effa4074000ce77904190e8  scripts/test_infoplist_languages.py
