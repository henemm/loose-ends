---
spec_file: docs/specs/feat-175-cloudkit-produktion.md
spec_sha256: a7dff1acefae2defa962c6914a1b45d95d5be347b015c00cbf991c7983dd333c
---

# PO-Briefing: feature-175-cloudkit-produktion

- **Spec:** docs/specs/feat-175-cloudkit-produktion.md
- **Issue:** #175
- **Erstellt:** 2026-10-08

## Was gebaut wird

TestFlight-Fassung gleicht Aufgaben zwischen iPhone und iPad ab, nachdem das Cloud-Schema vollständig ausgerollt wurde.

## Definition of Done

Auf dem iPhone erfasste Aufgabe erscheint auf dem iPad; ob Hennings alte Aufgaben ankommen, ist belegt.

## Wie geprüft wird

Unit-Tests prüfen nur Schema-Umfang und Startlogik; der Abgleich selbst wird per Protokoll und Fotos belegt, nicht automatisch.

## Kritische Anmerkungen

- Abweichung vom Issue: Schema wird vor der Messung ausgerollt, endgültig und nur noch additiv.
- Abgleich, Rollout und Sicherung haben keinen automatischen Test; Belege sind Protokolle, und Henning muss iPhone und iPad bedienen.
- Datenumzug und Kontext-Dubletten sind ausgelagert; Issue-DoD verlangt Umzug aber umgesetzt.

## Freigabe-Frage

Soll die Spec freigegeben werden, wobei der endgültige Schema-Rollout später noch getrennt von dir bestätigt wird?
