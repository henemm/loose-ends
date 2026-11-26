Refs #1000 (Schnitt 2 von 3, Epic #999, ADR-22)

## Was sich ändert
- Detail: kein Knopf „Passt“ in der Leiste (beide Zweige), kein Hinweis `ReviewNote`; Öffnen markiert immer gesehen.
- Liste: kein Abschnitt „Bitte ansehen“, keine Zeilennotizen „war: …“/„Titel nicht geprüft“/„Noch nicht sortiert“, keine Sonderreihenfolge für „Neu“.
- Wisch und Langdruck-Menü: kein „Passt“.
- `ReviewNote.swift` gelöscht.

App-Code: 4 Dateien, +12/−166.

## Belege
- RED → GREEN: `InboxDrawerSmokeTests.testFreshTaskDetailOffersNoLooksRight` (Detail und „…“-Menü einer frisch erfassten Aufgabe ohne „Passt“, „Complete“ bleibt).
- Unit: 1396 bestanden, 0 fehlgeschlagen, 13 übersprungen (Mess-/Modelltests ohne Gerät).
- Simulatorbeleg: `./scripts/sim.sh test-proof InboxDrawerSmokeTests` 3/3, Screenshots `docs/artifacts/feat-1000-s2-passt-entfaellt/s2-detail.png`, `s2-menue.png`.
- Adversary: VERIFIED, 2 Runden; Builds iOS und Mac grün.
- Gerätestufe: Kein Pfad der Geräteliste berührt.

## Schnitt 3
Regeln (`isInNew`, `needsLook`, `canConfirm`, `reviewReason`), `ViewKind.new`, `TaskActions.confirmReview`, `RowKeyAction`, Tönung, Katalogschlüssel, Doku, `Paper.wideNoteInsets` (jetzt unbenutzt).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
