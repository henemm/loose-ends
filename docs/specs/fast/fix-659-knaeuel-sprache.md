# Mini-Spec: #659 Knäuel-Test hängt an der Simulatorsprache

## Was ändert sich
- Der Test `KnaeuelTests.setWords` (`LooseEndsTests/KnaeuelTests.swift:165-177`) erwartet nicht mehr feste englische Sätze. Er prüft, was die Funktion `KnaeuelSince.setWords` entscheidet, in jeder Systemsprache:
  - die drei Textfälle („since this morning“, „since today“, „since yesterday“) gegen ihre eigene Katalogübersetzung `String(localized:)`, und dass die drei Texte voneinander verschieden sind (so ist der Zweig bewiesen, nicht nur der Text);
  - den Wochentag-Fall: Der Text endet auf den Wochentag in `en_US` („Tuesday“), unabhängig vom Rahmen davor;
  - den Datum-Fall: Der Text enthält das Datum in `en_US` („Oct 12“).
- Kein Produktcode wird geändert (`LooseEnds/Views/Knaeuel.swift` bleibt).

## Was darf sich nicht ändern
- Die Zweige der Funktion (vor 12 Uhr = „this morning“, gestern, 2–6 Tage = Wochentag, sonst Datum) bleiben im Test einzeln geprüft: Der Test wird nicht abgeschwächt.
- Alle anderen Tests in `KnaeuelTests.swift` bleiben unverändert.

## Beweis (Test vorher rot, nachher grün)
1. Vorher: `./scripts/sim.sh sim-unit KnaeuelTests` im deutschen Simulator zeigt 5 Fehler (am Stand 96f79e8, aus #88 bekannt; hier zu wiederholen).
2. Nachher: derselbe Lauf grün im deutschen Simulator.
3. Gegenprobe Englisch: derselbe Test mit englischer Simulatorsprache grün (nur wenn sich die Sprache ohne bleibende Änderung am Simulator setzen lässt; sonst benennen, dass der Beleg fehlt, und nicht behaupten).

## Manuelle Test-Schritte
Keine. Kein UI-Test: kein Produktcode, keine View betroffen. „Kein Pfad der Geräteliste berührt.“

## Inline-Test
- [ ] `setWords` in beiden Sprachen grün, gleiche fünf Aussagen wie vorher, aber sprachunabhängig formuliert.

## Alternative
Sprache als Parameter in den Produktcode geben und den Text aus dem passenden Katalog holen: größer, ändert Produktcode, für diesen Fehler nicht nötig. Keine ADR betroffen.

## Umfang
Dateien: 1 (`LooseEndsTests/KnaeuelTests.swift`), etwa +12/−5 Zeilen.
