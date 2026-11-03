---
spec_file: docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md
spec_sha256: a118bfee89f4964ad63b39f524ef9bf6dbae06ece6bd0f59f83680ea0ac333a7
spec_frozen_sha256: fffb819f044176b5bb58d7bec012e857006699e0c4fffbd3eef49eb978306527
---

# PO-Briefing: feat-615-s2-apple-anbindung

- **Spec:** docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md
- **Issue:** #615
- **Erstellt:** 2026-11-03

## Was gebaut wird

Der Dienst erkennt, ob ein „Mit Apple anmelden“-Nachweis echt ist, damit niemand ein fremdes Konto öffnen kann.

## Definition of Done

Alle Prüfungen für gefälschte, abgelaufene und falsch adressierte Nachweise schlagen automatisch fehl, gültige bestehen, und die Dienst-Tests sind grün.

## Wie geprüft wird

Automatische Tests mit selbst erzeugten Schlüsseln spielen viele Angriffsfälle durch; echtes Apple wird nicht angesprochen, das folgt erst später.

## Kritische Anmerkungen

- Nur Teil von Schnitt 2: Code einlösen und Widerruf folgen in zwei weiteren Schnitten.
- Echtes Apple ist offline nicht belegbar; Wiederverwendung eines Nachweises (Replay) wird erst im Netzwerk-Schnitt gelöst.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
