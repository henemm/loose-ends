---
spec_file: docs/specs/tooling/fix-516-schnitt-2-warteliste.md
spec_sha256: 302f9089f66e76d5cad16ad8961e8613fc409a37326b2e88c159ce841d4c5657
spec_frozen_sha256: 7699067c72875db4fa5b078bae4cf5ffb93e763f1e63cf7fc3d2912cf0e895b4
---

# PO-Briefing: fix-516-schnitt-2-warteliste

- **Spec:** docs/specs/tooling/fix-516-schnitt-2-warteliste.md
- **Issue:** #516
- **Erstellt:** 2026-10-19

## Was gebaut wird

Wer zuerst auf die gemeinsame Testsperre wartet, bekommt sie zuerst, und der Stille-Wächter räumt sauber hinter sich auf.

## Definition of Done

Drei nacheinander wartende Testläufe bekommen die Sperre in Ankunftsreihenfolge, ohne Verklemmung oder Restmarken; alle Skripttests laufen grün.

## Wie geprüft wird

Automatische Skripttests mit Stellvertreter-Prozessen belegen Reihenfolge, Abbrüche und Wächter-Ende; ein echter Wettlauf mehrerer Sitzungen wird nicht nachgestellt.

## Kritische Anmerkungen

- Handskripte und alte Stände kennen die Liste nicht und können weiter vordrängeln; die Unfairness ist nur teilweise behoben.
- Stirbt der Testlauf hart, bleibt dessen Xcode-Prozess bewusst stehen und hält den Simulator.
- Die 30-Sekunden-Laufzeitgrenze des Paralleltests ist nur geschätzt, nicht gemessen.

## Freigabe-Frage

Genügt dir eine Warteliste, die nur Läufe mit neuem Stand erfasst und Handskripte weiter vordrängeln lässt?
