Geteilte Anhänge: Regeln und Speicherweg (#399 Schnitt 1)

Refs #399

Schnitt 1 von 2, ohne sichtbare Änderung. Er legt fest, wie ein geteiltes Foto oder eine Datei vor dem Speichern
beschrieben wird (`SharedAttachment`: Kopie im Temp-Ordner statt `Data`, Titel aus dem Dateinamen, Fotoname,
höchstens 50 MB und 10 je Teilen), welchen Vorschlagstext eine Datei ohne Text liefert (`SharedContent`) und wie
`CaptureService.save` die Anhänge einzeln an die neue Aufgabe hängt. Schnitt 2 schließt die Teilen-Erweiterung an
(Laden, Maske „Anhänge“, Aktivierungsregel) und wird auf dem iPhone über TestFlight geprüft.

- Spec: `docs/specs/feat-399-schnitt-1-anhang-speichern.md`
- Abnahme: Unit-Tests im Simulator. Kein Pfad der Geräteliste berührt.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
