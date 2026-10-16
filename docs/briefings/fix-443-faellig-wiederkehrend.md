---
spec_file: docs/specs/fix-443-faellig-wiederkehrend.md
spec_sha256: ab000dff2cf47db6ba0e320e522f737e875ef24ef903667cd4a79a0aa1ff22aa
spec_frozen_sha256: 08ab66d125e33178bf94df0964009e1256954357005ce7aa8b396294771635ac
---

# PO-Briefing: fix-443-faellig-wiederkehrend

- **Spec:** docs/specs/fix-443-faellig-wiederkehrend.md
- **Issue:** #443
- **Erstellt:** 2026-10-16

## Was gebaut wird

Wiederkehrende Aufgaben erscheinen unter „Fällig“ erst am Tag ihrer Fälligkeit, nicht Tage vorher.

## Definition of Done

Im Simulator fehlt eine wöchentliche Aufgabe, auch nach dem Abschließen, unter „Fällig“ und bleibt unter „Wiederholend“ sichtbar.

## Wie geprüft wird

Ein Rechentest und ein Simulator-Durchlauf belegen das; Hennings Original-Aufgaben und echte Geräte werden nicht geprüft.

## Kritische Anmerkungen

- Ursache unbewiesen: Vermutlich schon durch frühere Änderung behoben; dann entsteht nur ein Test, kein Produktcode.
- Die zweite Aufgabe („Mo“) ist nicht als wiederkehrend belegt; getestet wird nur wöchentlich.
- Fix-Umfang erst nach rotem Test bekannt; Ausgang bleibt offen.

## Freigabe-Frage

Soll zuerst nur nachgestellt und das Ticket bei grünem Ergebnis ohne Produktänderung geschlossen werden?
