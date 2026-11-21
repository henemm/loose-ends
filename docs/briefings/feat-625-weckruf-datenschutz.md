---
spec_file: docs/specs/feat-625-schnitt-4-weckruf-datenschutz.md
spec_sha256: 70f58595d8ee7e674862026400b25b97127e60e274df7de48f6a129a8286df81
spec_frozen_sha256: 4fb3f503297fc029c5284ddf1d9f7e3c4584c547c252f4c11dda91de56ee91d0
---

# PO-Briefing: feat-625-weckruf-datenschutz

- **Spec:** docs/specs/feat-625-schnitt-4-weckruf-datenschutz.md
- **Issue:** #625
- **Erstellt:** 2026-11-21

## Was gebaut wird

Der öffentliche Datenschutztext erklärt auf Deutsch und Englisch, dass die App ein Gerätetoken für stille Weckrufe speichert.

## Definition of Done

Beide Datenschutzseiten auf henemm.com zeigen den neuen Weckruf-Absatz, und die Prüfung gegen die Live-Seiten ist grün.

## Wie geprüft wird

Ein Skript prüft, dass die Kernsätze auf den Seiten stehen; ob sie sachlich stimmen, belegt nur der Abgleich mit dem Code.

## Kritische Anmerkungen

- Der Text sagt ehrlich: „Abmelden“ löscht das Gerätetoken nicht, nur „Konto löschen“ tut das.
- Die Alternative, Abmelden löscht das Token, bräuchte App- und Dienständerungen; die Spec empfiehlt sie nicht.

## Freigabe-Frage

Gibst du den Wortlaut frei, einschließlich des Satzes, dass „Abmelden“ das Gerätetoken nicht löscht?

## Ampel

Ampel: rot
