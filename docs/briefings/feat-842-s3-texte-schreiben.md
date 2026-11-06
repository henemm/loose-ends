---
spec_file: docs/specs/feat-842-schnitt-3-texte-schreiben.md
spec_sha256: 91e0dce044e3acbdb68fd652e694cf448c16299dce5ff2cf5b2d99f427b46da8
spec_frozen_sha256: 99efb3e588193f01d912e07e851c92cc883dc6b0ab0dbff2646fc84de83c88e8
---

# PO-Briefing: feat-842-s3-texte-schreiben

- **Spec:** docs/specs/feat-842-schnitt-3-texte-schreiben.md
- **Issue:** #842
- **Erstellt:** 2026-11-06

## Was gebaut wird

Die englische App-Store-Seite von Version 1.0.1 bekommt Beschreibung, Schlüsselwörter, Support-Adresse und Werbetext, automatisch geschrieben.

## Definition of Done

Nach dem Lauf zeigt die englische Seite von 1.0.1 alle vier Texte, und eine zweite Abfrage bei Apple bestätigt den Wortlaut.

## Wie geprüft wird

Tests mit Apple-Nachbau belegen Auswahl, Schreiben und Schutz des deutschen Textes; ob Apple Texte und Längen annimmt, zeigt erst der echte Lauf.

## Kritische Anmerkungen

- Der englische Wortlaut ist noch nicht von dir freigegeben; Support-Adresse ist die deutsche Kontaktseite.
- Umfang etwa 315 Zeilen, über der 250er-Grenze; Teilung bewusst verworfen, deine Freigabe bestätigt das.
- Mac-Seite nicht prüfbar, weil keine Mac-Version in Bearbeitung ist.

## Freigabe-Frage

Gibst du den englischen Wortlaut samt deutscher Kontaktseite als Support-Adresse so frei, oder was soll sich ändern?

## Ampel

Ampel: rot
