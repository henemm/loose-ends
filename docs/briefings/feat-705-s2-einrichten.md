---
spec_file: docs/specs/feat-705-schnitt-2a-texte-kontakt.md
spec_sha256: 9d216e875d204394b9a8e6147af9b98708fc18a0d59207cc49ae4fc853b32a96
spec_frozen_sha256: add971e0aeb1c0ed6009212ffaacfa9b427e8043f3827e1960cc87454627eb95
---

# PO-Briefing: feat-705-s2-einrichten

- **Spec:** docs/specs/feat-705-schnitt-2a-texte-kontakt.md
- **Issue:** #705
- **Erstellt:** 2026-10-27

## Was gebaut wird

Ein Handlauf trägt Beschreibung, Feedback-E-Mail und Kontaktdaten für Apples Beta-Prüfung automatisch in TestFlight ein.

## Definition of Done

Nach dem Lauf zeigt die Kontrolle Beschreibung, Feedback-E-Mail und Kontakt bei Apple als gesetzt; ein zweiter Lauf ändert nichts.

## Wie geprüft wird

Tests gegen einen Apple-Nachbau belegen Ablauf, Wiederholbarkeit und Datenschutz im Protokoll, nicht ob Apple Formate und Schreibrecht akzeptiert.

## Kritische Anmerkungen

- Kontaktangaben sind bei Apple nach dem Setzen nicht mehr löschbar; der Lauf startet erst nach deiner getippten Freigabe.
- Das Ticketziel (Fremde installieren per Link) fehlt noch: Gruppe, Link und Einreichung folgen erst in Schnitt 2b.
- Ob Telefonformat, Schreibrecht und fehlende Datenschutz-Adresse reichen, zeigt erst der echte Lauf, kein Test.

## Freigabe-Frage

Soll der Lauf, der Kontaktdaten unwiderruflich bei Apple einträgt, nach dieser Spec gestartet werden?
