# Spec: Energie gibt oder nimmt, −3 … +3, nur von Hand (#112)

Grundlage: Gestaltungsentscheidungen Henning, 2026-10-05, als Kommentare in #112; Entwurf auf der
Design-Leinwand „Loose Ends – Backlog-Entwürfe“, Zeile #112, Variante D.

## Problem

Energie hieß bisher „wie viel Energie braucht die Aufgabe“ (niedrig/mittel/hoch) und kam vom Modell.
Gemessen trägt dort weder das Modell (25 %) noch die Nachbarsuche (60,2 %) gegen die Konstante
„immer low“ (77,3 %), `docs/reference/retrieval-leave-one-out-rules.md`. Henning will stattdessen
wissen, ob eine Aufgabe Energie **gibt oder nimmt** — eine subjektive Angabe, die nur er machen kann.

Regeln vor dem Modell: Für dieses Feld gibt es weder Regel noch Modell; es ist ein reines
Nutzerfeld. Kein Satz „Ohne das Modell scheitert …“ nötig, weil das Modell das Feld verliert.

## Expected Behavior

- **AC-1:** `Energy` hat sieben Stufen −3 … +3. Gespeichert wird die Zahl als Text („-3“ … „3“) im
  bestehenden Feld `energyRaw` — kein SwiftData-Schemabruch, CloudKit sieht dasselbe Feld.
- **AC-2:** Alte Werte „low“, „medium“, „high“ lesen sich als leer: `TaskItem.energy`,
  `FieldCodec.encode(.energy)` und die Anzeige liefern nil, und ein altes KI-Energiefeld trägt kein
  KI-Zeichen mehr (Entscheidung Henning, 2026-10-05: verwerfen).
- **AC-3:** Jede Reglerstellung und „Wert entfernen“ ist eine Nutzer-Revision (Revisionen statt
  Undo); dieselbe Stelle noch einmal schreibt nichts. Geschrieben wird beim Loslassen, nicht je Raste.
- **AC-4:** Feld-Editor Variante D: Regler zwischen leerer und voller Batterie, rastet an sieben
  Stellen; darüber nur Worte (ein bisschen = 1, deutlich = 2, sehr viel = 3, „nimmt“ negativ,
  „gibt“ positiv, Mitte „weder noch“), keine Zahl; darunter „Wert entfernen“, solange ein Wert
  gesetzt ist. Ohne Wert steht „Nicht gesetzt“.
- **AC-5:** Das Modell liefert Energie nicht mehr: `ModelEnrichment` verliert die drei
  Energie-Eigenschaften, Anweisung und Beispiele erwähnen Energie nicht, `EnrichmentDraft` und
  `EnrichmentWriter` kennen das Feld nicht mehr.
- **AC-6:** Detail zeigt nur die Worte, ohne KI-Zeichen; in der Listenzeile erscheint Energie nie.
- **AC-7:** Deutsche Texte im String-Katalog.

„sehr“ wird in den Worten zu „sehr viel“ („nimmt sehr viel Energie“), weil „nimmt sehr Energie“
kein Deutsch ist; die Stufe bleibt 3.

## Scope

`Shared/Models/Enums.swift`, `Shared/Models/TaskItem.swift`, `Shared/Services/FieldCodec.swift`,
`Shared/Services/RevisionService.swift`, `Shared/Enrichment/EnrichmentDraft.swift`,
`EnrichmentWriter.swift`, `EnrichmentCoordinator.swift`, `FoundationModelsEnricher.swift`,
`LooseEndsLab/MeasurementRunner.swift`, `LooseEnds/Views/FieldEditorView.swift`,
`FieldFormatting.swift`, `Localizable.xcstrings`; Tests in `LooseEndsTests/EnergyTests.swift` und
Anpassungen bestehender Tests; Galerie-Schritt in `LooseEndsUITests/DesignGalleryTests.swift`
(`gallery-*-6-energy`, `gallery-*-7-detail-energy`).

Messcode: `MeasurementResult.energy` und `Corpus.Entry.energyTruth` bleiben lesbar (alte
Ergebnisdateien), werden aber nicht mehr befüllt; die FocusBlox-Kalibrierung misst nur noch die Dauer.

## Nicht-Scope

- Alte Werte in der Datenbank aktiv löschen: nicht nötig, sie lesen sich überall als leer; die
  nächste Nutzerangabe überschreibt sie.
- Energie als Filter oder Ansicht.

## Abnahme

Stufe 1 CI (Unit, UI-Smoke, Galerie). Stufe 2 Simulator: Galerie-Bilder `6-energy` und
`7-detail-energy`. Stufe 3 Gerät ist Pflicht: der Schnitt berührt
`Shared/Enrichment/FoundationModelsEnricher.swift` und `EnrichmentCoordinator.swift` (Modellschema).
