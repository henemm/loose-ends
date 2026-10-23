# Adversary Dialog — fix-534-schnitt-3-konstante
Spec: docs/specs/fix-534-schnitt-3-konstante.md
Datum: 2026-10-23 13:19

## Checkliste
- [x] **AC-1:** `EnrichmentCoordinator` hat die Konstante `defaultModelTimeout` mit dem Wert 25 s; der Init-Parameter `modelTimeout` nutzt sie als Default. Der Doc-Kommentar benennt die Messung (#534) als Herkunft.
- [x] **AC-2:** `ModelSeamTests` enthält einen Test, der `EnrichmentCoordinator.defaultModelTimeout == .seconds(25)` prüft und dass der Wert im Regelbereich 15 s ≤ Wert ≤ 60 s liegt. Der Test wird vor der Änderung RED (Konstante fehlt) und danach GREEN.
- [x] **AC-3:** `RealModelTests.answersInShape` vergleicht gegen `EnrichmentCoordinator.defaultModelTimeout`, nicht gegen eine eigene Zahl. Der Test läuft nur mit echtem Modell und bleibt in Simulator und CI übersprungen.
- [x] **AC-4:** Die übrigen Tests, die eine eigene kurze Grenze (200 ms) übergeben, bleiben unverändert und grün; das Verhalten bei Timeout (Notiz wartet auf den nächsten Durchlauf, Regelschritt läuft trotzdem) ist unverändert.
- [x] **AC-5:** `CLAUDE.md` und `docs/reference/modell-latenz.md` nennen 25 s als gesetzte Grenze mit Verweis auf die Messung; „heute 30 s“ und „Schnitt 3 offen“ kommen nicht mehr vor. Der Bericht behält die Alternativen (30 s lassen) als Begründungsteil.
- [x] **AC-6:** Abnahme Stufe 1 und 2: `sim.sh sim-unit` grün, `sim.sh build` baut, die Produkt-App startet im Simulator und eine Aufgabe wird erfasst und verarbeitet (der Simulator hat unter `--ui-testing` kein Modell; die Verarbeitung läuft über die Regeln durch). Stufe 3: `EnrichmentCoordinator.swift` steht auf der Geräteliste. Abnahme über TestFlight (Henning, 2026-10-10): nach dem Merge und Bau bekommt Henning die Buildnummer und einen Prüfschritt; auf seinen Geräten läuft nichts vor seinem wörtlichen „jetzt ist ein Test möglich“. Das Ticket bleibt bis zu seiner Rückmeldung offen.
- [x] **AC-7:** Keine weiteren Änderungen: kein Modell-, Schema- oder Permission-Eintrag, keine AppStorage-Keys, kein CloudKit-Feld, keine zweite Grenze für kalt/warm (Faktor 1,2 liegt unter der Schwelle 5).

## Dialog

### Runde 1
**Adversary:** Ich greife jede AC an. (1) Aufrufer: die Suche nach `EnrichmentCoordinator(` im Produktcode ergibt genau einen Treffer, `LooseEnds/App/LooseEndsApp.swift:34`, ohne `modelTimeout:`; Watch, Widgets, Share haben keinen. Kein `.seconds(30)` mehr im Produktcode. (2) Rechnung: 25/7,92 = 3,16 -> 3,2; 25/4,67 = 5,35 -> 5,4; 30/4,67 = 6,42 -> 6,4; 3 x 7,92 = 23,76 -> auf 5 s aufgerundet 25, im Bereich 15-60. Die Messwerte 4,67 (warm Mac) und 7,92 (kalt iPhone) stehen in den Tabellen des Berichts (Zeilen 27, 50). Alles stimmt. (3) Die Klasse ist `@MainActor`; `nonisolated static let` auf `Duration` (Sendable) ist korrekt, damit der Init-Default und der Test `defaultLimitIsMeasured` (Struct-Suite, Funktion ohne @MainActor) ohne Aktor-Hop lesen. Test grün im Lauf (Zeile 703 test-green-output.txt, 907 Haken, 0 Fehler). (4) Statusliste des Arbeitsbaums: geändert nur CLAUDE.md, RealModelTests.swift, EnrichmentCoordinator.swift, modell-latenz.md; ModelSeamTests kam im RED-Commit c0d061d (steht auch in der Spec-Dateiliste); sonst nur Artefakte und das ungetrackte `.claude/`. Kein project.yml, kein Schema, keine Entitlements. (5) Reste: die Suche nach "heute 30", "Schnitt 3 offen", "nicht festgelegt" in beiden Docs ohne Treffer; verbleibende "30 s" sind die berichtigte Alternative (a), die Rückschau und eine fremde Sperrzeit in CLAUDE.md:76. Der Abschnitt "Offen" nennt Schnitt 3 nicht mehr. Das Zitat "25 s umsetzen" ist in Spec und Kontext belegt. Gegenprobe RED: test-red-output.txt zeigt den Fehler an `defaultLimitIsMeasured`. Erste Zweifel: die Test-Proof-Läufe gelten nur für CaptureSmokeTests, und der erste Lauf hatte einen flaky Fehler.
**Implementierer:** Die Konstante hat nur den Wert geändert; das Verhalten bei Timeout (ModelDeadline) ist unberührt. Die flaky Stelle liegt in einem UI-Test ohne Modell, der Timeout-Pfad wird dort nie erreicht.

### Runde 2
**Adversary:** Ich prüfe den flaky Befund: test-proof-output.txt zeigt `testCompletedTaskShowsUnderCompleted` bestanden, 23 von 23, 0 Fehler; simulator-run.txt (Kopf `c0d061d`, Basis `68a1e65`, Ergebnis Passed, 0 übersprungen) bestätigt. Der Test hat mit dem Zeitlimit des Modells nichts zu tun (UI-Test, `--ui-testing` schaltet das Modell ab); der Lauf belegt also keine Wirkung der 25 s im Produkt. Das ist laut Spec die Gerätestufe. AC-4: die zwei Aufrufe mit `.milliseconds(200)` (ModelSeamTests.swift:32 und :58) sind unverändert, die Suite lief grün. AC-6 Stufe 3: `EnrichmentCoordinator.swift` steht auf der Geräteliste; in den Belegen gibt es nur Simulator-Läufe (iPhone 17, iOS 27.0), nichts auf Hennings Geräten; die TestFlight-Abnahme ist offen und ans Ticket gebunden, das ist laut Spec zulässig. Rest-Risiko steht in Spec und Bericht: Messung bei Hitzestufe serious, kurze Notizen; bei Überschreitung zählt der Aufruf als gescheitert und wird wiederholt. Ich finde keinen Fehler. RealModelTests laufen ohne Modell nicht (Skip, laut AC-3 gewollt); Zeile 68 vergleicht mit der Konstante. Übersprungen im sim-unit: eine Messstrecke (selfconsistency-run.json fehlt) und zwei Latenzschutz-Tests (Sprache de_DE nicht unterstützt), beide vorbestehend, im Lauf benannt, ohne Berührung mit dieser Änderung.
**Implementierer:** Keine weiteren Punkte. Die Gerätepunkte bleiben bis Hennings Rückmeldung offen.

### Bestätigungen
Confirmation:
  AC: AC-1
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:15 (`nonisolated static let defaultModelTimeout: Duration = .seconds(25)`), Init-Default Zeile 38, Doc-Kommentar Zeilen 12-14 nennt #534 und `modell-latenz.md`.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsTests/ModelSeamTests.swift:45 (`defaultLimitIsMeasured`: ==25 s, >=15 s, <=60 s); RED in test-red-output.txt, GREEN in test-green-output.txt:703.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEndsTests/RealModelTests.swift:68 (`took < EnrichmentCoordinator.defaultModelTimeout`); Suite bleibt per `.enabled(if: RealModel.isRequested)` (Zeile 36) übersprungen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsTests/ModelSeamTests.swift:32 (200 ms unverändert, Suite grün); Verhalten in Shared/Enrichment/EnrichmentCoordinator.swift:48 unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:12 (Quelle der Zahl); CLAUDE.md "25 s in the coordinator, from the measurement #534" und docs/reference/modell-latenz.md Zeilen 4-5, 33, 85-93; keine Reste der alten Formulierungen.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:38 (Produktpfad über LooseEndsApp.swift:34); sim-unit 907 Haken/0 Fehler, test-proof 23/23 am Stand c0d061d, Gerätestufe benannt und offen, nichts auf Geräten gelaufen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:15 (eine einzige Konstante, keine zweite Grenze); die Statusliste zeigt keine weiteren Dateien.
  Status: CONFIRMED


## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Begründung: Alle AC-1 bis AC-7 mit Code und Belegen bestätigt, keine Funde. Tests: 907 bestanden, 0 fehlgeschlagen (sim-unit), 23/23 UI (test-proof); übersprungen: 1 Messstrecke und 2 Latenzschutz-Tests, vorbestehend und unabhängig. Offen und zulässig: Gerätestufe über TestFlight nach Hennings Wort.

## Geprüfte Dateien

- sha256:234df1d6628cc55c930a389d38e9b7e0f0f8fd6ae63503d007884be5ece64c5f  LooseEndsTests/ModelSeamTests.swift
- sha256:c2f19b1794b86af3a79b131adc337f1633c5071d29fa0c5b9b2f46361a1eeea9  LooseEndsTests/RealModelTests.swift
- sha256:3f2b8cc2a9fbce94f90dd93db033914acfb6c5ced9970a0fd56281a26dba2c16  Shared/Enrichment/EnrichmentCoordinator.swift

## Prüfbasis

- base: 68a1e65d377d9fcd12592006dc05bdb05e7864ee
- blob:9c43764aefe3231f97f19a3ae8a937ed6d8a4212  LooseEndsTests/ModelSeamTests.swift
- blob:a39ac8a78a6557e63a2d30d9a0e3b7789808b948  LooseEndsTests/RealModelTests.swift
- blob:fb8b9b6c431a14f846a331df9bbb920b70e26138  Shared/Enrichment/EnrichmentCoordinator.swift
