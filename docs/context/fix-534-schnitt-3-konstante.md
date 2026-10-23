# Context: fix-534-schnitt-3-konstante

## Request Summary
Epic #563, Unterticket #534 Schnitt 3: Die Zeitgrenze je Modellaufruf im `EnrichmentCoordinator` (heute geschätzte 30 s aus #530)
wird aus der Messung abgeleitet. Vorschlag der Regel aus `docs/reference/modell-latenz.md`: 25 s (3 × 7,92 s, auf 5 s aufgerundet).
Alternative: 30 s lassen und das Ticket mit Begründung schließen. Henning hat am 2026-10-23 „25 s umsetzen“ gewählt.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/EnrichmentCoordinator.swift:30` | Init-Default `modelTimeout: Duration = .seconds(30)`; Doc-Kommentar zu `modelTimeout` (Z. 24–26) nennt „Generous“ ohne Messbezug. **Die eine Konstante.** |
| `Shared/Enrichment/ModelDeadline.swift` | `ModelDeadline.run(within:)`, `Exceeded(limit:)`; unverändert |
| `LooseEnds/App/LooseEndsApp.swift:34` | einziger Produktaufruf, nimmt den Default (keine eigene Zahl) |
| `LooseEndsTests/RealModelTests.swift:67` | prüft `took < .seconds(30)` mit Text „longer than the coordinator waits (#530)“: zweite Stelle, die dieselbe Zahl trägt; läuft nur mit echtem Modell (`RealModel.isAvailable`), in Sim und CI nie |
| `LooseEndsTests/ModelSeamTests.swift:30,54` | Stub hängt `.seconds(30)`, Coordinator mit 200 ms; unabhängig vom Default, keine Änderung nötig |
| `CLAUDE.md:308` | „time limit per model call, 30 s in the coordinator“: Dokumentation, mitziehen |
| `docs/reference/modell-latenz.md` | Bericht, Zeilen 4, 33, 85–90, 105: „heute 30 s“, „Schnitt 3 offen“; nach der Änderung berichtigen |

## Existing Patterns
- Der Default steht am Init-Parameter; Tests übergeben eine eigene kurze Grenze (200 ms). Es gibt keinen Test, der den Default selbst festnagelt.
- Messregel (Bericht): Dreifaches des größten Werts beider Geräte, auf volle 5 s aufgerundet, mindestens 15 s, über 60 s geht die Frage an Henning zurück. 25 s liegt im erlaubten Bereich.
- Vorgänger-Schnitte: Spec je Schnitt unter `docs/specs/fix-534-schnitt-N-*.md`, Messdaten unter `docs/artifacts/534-modell-latenz/`.

## Dependencies
- Upstream: `ModelDeadline`, `TaskEnricher`/`StubEnricher`, Messwerte aus Schnitt 1 (Mac, Max 4,67 s) und Schnitt 2 (iPhone, Max 7,92 s kalt, 6,72 s warm).
- Downstream: `ModelFailure.isPermanent` behandelt `ModelDeadline.Exceeded` als nicht dauerhaft (`ModelSeamTests.swift:168`): ein Timeout wird also beim nächsten Durchlauf wiederholt. Eine kürzere Grenze lässt Aufrufe früher scheitern, ändert aber diese Einstufung nicht.

## Existing Specs
- `docs/specs/fix-534-schnitt-1-mac-latenz.md`, `docs/specs/fix-534-schnitt-2-iphone-latenz.md`

## Risks & Considerations
- **Stufe 3 greift:** `EnrichmentCoordinator.swift` steht auf der Geräteliste. Abnahme über TestFlight; auf Hennings Geräten nichts vor seinem wörtlichen „jetzt ist ein Test möglich“.
- **Messgrenzen:** Messung fast ganz bei Hitzestufe „serious“, nur sechs kurze Notizen, kein kühles Gerät, kein Stromsparmodus, keine langen Rohtexte. 25 s hat Faktor 3,2 Abstand zum Maximum (30 s: 3,8).
- **Zwei Stellen mit derselben Zahl** (Coordinator-Default und `RealModelTests`): sonst läuft die Prüfung gegen eine andere Grenze als das Produkt.
- **Alternative (Regeln vor Modell / Alternativen):** 30 s lassen; die Messung widerlegt sie nicht. Spricht für 25 s: das Epic verlangt eine belegte statt geschätzte Grenze. Eine zweite Grenze (kalt/warm) ist laut Bericht nicht nötig (Faktor 1,2).
- Ein Wert unter dem Maximum (7,92 s) oder unter 15 s ist ausgeschlossen; 25 s lässt Raum für ein kühleres, aber auch für ein stärker belastetes Gerät.

## Analysis

### Type
Feature (Konfigurationswert aus Messung ableiten; kein Fehlerbild, daher keine Reproduktion nötig)

### Recherche / Beleg
Messbericht `docs/reference/modell-latenz.md` (Schnitt 1 Mac, Schnitt 2 iPhone 16 Pro). Regel: 3 × größter Wert (7,92 s) = 23,8 s, auf 5 s aufgerundet = 25 s; Untergrenze 15 s, Obergrenze 60 s. Henning hat 25 s am 2026-10-23 gewählt.
Ohne Modell: nicht betroffen — die Grenze ist eine Regel-Konstante, kein Modellfeld.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | benannte Konstante `defaultModelTimeout = .seconds(25)` als Init-Default; Doc-Kommentar mit Messbezug statt „Generous“ |
| `LooseEndsTests/RealModelTests.swift` | MODIFY | Prüfgrenze nimmt `EnrichmentCoordinator.defaultModelTimeout` statt eigener 30 |
| `LooseEndsTests/ModelSeamTests.swift` | MODIFY | neuer Test: der Default beträgt 25 s und liegt im Regelbereich 15–60 s (nagelt die Zahl fest, bisher ungeprüft) |
| `CLAUDE.md` | MODIFY | Z. 308 „30 s“ → „25 s, aus Messung #534“ |
| `docs/reference/modell-latenz.md` | MODIFY | „heute 30 s“ / „Schnitt 3 offen“ berichtigen (Z. 4, 33, 85–90, 105) |

### Scope Assessment
- Files: 5 (2 Code, 1 Test-Erweiterung, 2 Doku)
- Estimated LoC: +30/-12
- Risk Level: LOW (ein Zahlenwert; Abstand zum Maximum 3,2×)

### Technical Approach
Die Zahl bekommt einen Namen an einer Stelle; Produkt und Echtmodell-Test lesen dieselbe Konstante, damit die Prüfung nie gegen eine andere Grenze läuft als die App. Ein Unit-Test sichert Wert und Regelbereich.
Alternative: 30 s lassen und mit Begründung schließen (Messung widerlegt sie nicht, Abstand 3,8×). Dagegen: das Epic verlangt eine belegte statt geschätzte Grenze. Eine zweite Grenze (kalt/warm) entfällt (Faktor 1,2 < 5). Keine ADR wird gekippt.

### Dependencies
`ModelDeadline`, `ModelFailure.isPermanent` (Timeout bleibt nicht dauerhaft, unverändert). Einziger Produktaufruf `LooseEndsApp.swift:34` nutzt den Default.

### Gerätestufe
`EnrichmentCoordinator.swift` steht auf der Geräteliste → Stufe 3 über TestFlight, Gerät nur nach Hennings wörtlichem „jetzt ist ein Test möglich“. Messgrenzen: 112/120 Aufrufe bei Hitzestufe „serious“, kein kühles Gerät, kein Stromsparmodus, nur kurze Notizen.

### Open Questions
- [ ] keine
