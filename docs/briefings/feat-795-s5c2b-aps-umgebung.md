---
spec_file: docs/specs/feat-795-schnitt-5c2b-aps-umgebung.md
spec_sha256: 184a812eada407f7e45c086ce07da23cdd20e9139a66115f87a44defd199cb7c
spec_frozen_sha256: 7ce3aadf23750f18d53e059c079e99e25126b05f704b4f3ab31a91f70cbaa1e3
---

# PO-Briefing: feat-795-s5c2b-aps-umgebung

- **Spec:** docs/specs/feat-795-schnitt-5c2b-aps-umgebung.md
- **Issue:** #795
- **Erstellt:** 2026-11-19

## Was gebaut wird

Jeder TestFlight-Bau erfährt vor dem Hochladen verlässlich, dass er den echten Apple-Benachrichtigungsweg nutzt, normale Bauten den Testweg.

## Definition of Done

Alle Prüfungen sind grün, und ein TestFlight-Lauf nach dem Merge bestätigt für iPhone und Mac die Zeile „production, OK“.

## Wie geprüft wird

Automatische Prüfskripte decken jede Anforderung ab; ob Apple den Weckruf später wirklich zustellt, beweist dieser Schnitt nicht.

## Kritische Anmerkungen

- Das Mac-Archiv trägt kein Push-Recht; die Mac-Marke bleibt bis zum Folgeschnitt wirkungslos, der Mac bekommt vorerst keinen Weckruf.
- Im iPhone-Archiv wird nur das Vorhandensein des Push-Rechts geprüft, nicht dessen Wert.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
