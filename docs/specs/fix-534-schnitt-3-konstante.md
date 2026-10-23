---
entity_id: fix-534-schnitt-3-konstante
type: bugfix
created: 2026-10-23
updated: 2026-10-23
status: draft
workflow: fix-534-schnitt-3-konstante
---

# Spec: Modell-Zeitgrenze aus der Messung, Schnitt 3 — Konstante (#534)

## Approval

- [ ] Approved

## GitHub Issue

#534 (Epic #563). Schnitt 3 von 3, der letzte; mit diesem Schnitt schließt das Issue (`Closes #534`). Schnitt 1 (Mac, PR #609) und Schnitt 2 (iPhone, PR #636) sind gemergt.

## Purpose

Die Zeitgrenze je Modellaufruf im `EnrichmentCoordinator` ist heute 30 s, in #530 geschätzt. Die Messung (`docs/reference/modell-latenz.md`: Mac Maximum 4,67 s,
iPhone 16 Pro Maximum 7,92 s kalt, 6,72 s warm, Faktor kalt/warm 1,2) liefert eine Regel: Dreifaches des größten Werts beider Geräte (23,8 s), aufgerundet auf volle 5 s,
mindestens 15 s, über 60 s geht die Frage an Henning zurück. Ergebnis: **25 s**. Henning hat am 2026-10-23 „25 s umsetzen“ gewählt.

Dieser Schnitt ersetzt die geschätzte Zahl durch die gemessene und gibt ihr einen Namen, den das Produkt und die Prüfung gegen das echte Modell gemeinsam lesen,
damit die Prüfung nie gegen eine andere Grenze läuft als die App.

**Ohne Modell geht es nicht, weil** die Titelverfeinerung Sprachverstehen braucht (Beleg: #202). Dieses Ticket führt kein Modell ein; die Grenze ist eine Regel-Konstante,
kein Modellfeld, und eine Regel-Spalte entfällt (für Latenz gibt es keine Regel, die das Modell ersetzt).

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — ein Zahlenwert aus der Messung; keine bestehende ADR wird gekippt.

## Source

| Datei | Änderung |
|---|---|
| `Shared/Enrichment/EnrichmentCoordinator.swift` | benannte Konstante `static let defaultModelTimeout: Duration = .seconds(25)` als Init-Default; Doc-Kommentar nennt Messung statt „Generous“ |
| `LooseEndsTests/RealModelTests.swift` | Prüfgrenze `took < EnrichmentCoordinator.defaultModelTimeout` statt eigener 30 s |
| `LooseEndsTests/ModelSeamTests.swift` | neuer Test: Default ist 25 s und liegt im Regelbereich 15–60 s |
| `CLAUDE.md` | Zeile zu `ModelDeadline`: „30 s“ → „25 s, aus der Messung #534“ |
| `docs/reference/modell-latenz.md` | „heute 30 s“ und „Schnitt 3 offen“ berichtigen (Zeilen 4, 33, 85–90, 105) |

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `ModelDeadline.run(within:)`, `ModelFailure.isPermanent` | unverändert; ein Timeout bleibt „nicht dauerhaft“ und wird beim nächsten Durchlauf wiederholt |
| `LooseEnds/App/LooseEndsApp.swift:34` | einziger Produktaufruf, nimmt den Default, bleibt unverändert |
| Schnitt 1 und 2 (Messwerte), #530 | gemergt |

## Acceptance Criteria

- **AC-1:** `EnrichmentCoordinator` hat die Konstante `defaultModelTimeout` mit dem Wert 25 s; der Init-Parameter `modelTimeout` nutzt sie als Default. Der Doc-Kommentar benennt die Messung (#534) als Herkunft.
- **AC-2:** `ModelSeamTests` enthält einen Test, der `EnrichmentCoordinator.defaultModelTimeout == .seconds(25)` prüft und dass der Wert im Regelbereich 15 s ≤ Wert ≤ 60 s liegt.
  Der Test wird vor der Änderung RED (Konstante fehlt) und danach GREEN.
- **AC-3:** `RealModelTests.answersInShape` vergleicht gegen `EnrichmentCoordinator.defaultModelTimeout`, nicht gegen eine eigene Zahl. Der Test läuft nur mit echtem Modell und bleibt in Simulator und CI übersprungen.
- **AC-4:** Die übrigen Tests, die eine eigene kurze Grenze (200 ms) übergeben, bleiben unverändert und grün; das Verhalten bei Timeout (Notiz wartet auf den nächsten Durchlauf, Regelschritt läuft trotzdem) ist unverändert.
- **AC-5:** `CLAUDE.md` und `docs/reference/modell-latenz.md` nennen 25 s als gesetzte Grenze mit Verweis auf die Messung; „heute 30 s“ und „Schnitt 3 offen“ kommen nicht mehr vor. Der Bericht behält die Alternativen (30 s lassen) als Begründungsteil.
- **AC-6:** Abnahme Stufe 1 und 2: `sim.sh sim-unit` grün, `sim.sh build` baut, die Produkt-App startet im Simulator und eine Aufgabe wird erfasst und verarbeitet (der Simulator hat unter `--ui-testing` kein Modell; die Verarbeitung läuft über die Regeln durch).
  Stufe 3: `EnrichmentCoordinator.swift` steht auf der Geräteliste. Abnahme über TestFlight (Henning, 2026-10-10): nach dem Merge und Bau bekommt Henning die Buildnummer und einen Prüfschritt; auf seinen Geräten läuft nichts vor seinem wörtlichen „jetzt ist ein Test möglich“.
  Das Ticket bleibt bis zu seiner Rückmeldung offen.
- **AC-7:** Keine weiteren Änderungen: kein Modell-, Schema- oder Permission-Eintrag, keine AppStorage-Keys, kein CloudKit-Feld, keine zweite Grenze für kalt/warm (Faktor 1,2 liegt unter der Schwelle 5).

## Scope

**Affected Files:** fünf (zwei Code, eine Test-Erweiterung, zwei Doku). Identifier: `EnrichmentCoordinator.defaultModelTimeout`. Geschätzt +30/−12 LoC. Risiko niedrig: ein Zahlenwert, Abstand zum größten Messwert 3,2×.
**Grenzen der Messung** (im Bericht benannt): 112 von 120 Aufrufen bei Hitzestufe „serious“, kein kühles Gerät, kein Stromsparmodus, nur sechs kurze Notizen. Ein stärker belastetes Gerät oder lange Rohtexte sind nicht gemessen;
25 s lässt dafür Raum, ist aber keine Garantie. Läuft ein Aufruf im Alltag länger, zählt er als fehlgeschlagen und wird beim nächsten Durchlauf wiederholt, nicht dauerhaft verworfen.

## Test Plan

RED: neuer Test in `ModelSeamTests` (Konstante und Regelbereich) schlägt fehl, solange `defaultModelTimeout` fehlt.
GREEN: `./scripts/sim.sh sim-unit` (alle Unit-Tests), `./scripts/sim.sh build`, Simulator-Durchlauf der Produkt-App (Erfassen, Verarbeiten). Kein sichtbarer Ablauf ändert sich, deshalb kein neuer UI-Test.
Gerät: TestFlight, nur nach Hennings Wort.

## Alternativen

- **30 s lassen und das Ticket mit Begründung schließen:** die Messung widerlegt 30 s nicht (Abstand 3,8×); kein Eingriff in eine Geräte-Pfad-Datei. Dagegen: das Epic #563 verlangt eine belegte statt geschätzte Grenze, und die Konstante hat bisher keinen Messbezug und keinen Test.
- **Zwei Grenzen (kalt großzügig, warm eng):** lohnt erst ab Faktor 5; gemessen 1,2.
- **Grenze pro Gerät oder nach Hitze:** mehr Zustand für einen Fall, den die Messung nicht zeigt.
- **Gewählt:** 25 s nach der Regel, eine benannte Konstante, die Produkt und Prüfung gemeinsam lesen.

## Definition of Done

- [ ] AC-1 bis AC-7 erfüllt
- [ ] `sim.sh sim-unit` grün, `sim.sh build` baut, Simulator-Durchlauf belegt
- [ ] PR mit `Closes #534`, CI grün, gemergt, Hauptordner aktuell
- [ ] TestFlight-Bau mit „Was testen“, Rückmeldung Hennings schließt den Gerätepunkt

## Changelog

- 2026-10-23: Initial (Schnitt 3 von 3)
