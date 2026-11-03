---
spec_file: docs/specs/feat-796-schnitt-4a-betrieb.md
spec_sha256: 1e3bebf5966bfdd2fd5faeab4336b0e9947373762dcccf6ef3462db2c39f60f1
spec_frozen_sha256: eeee7e076de91ca5e37f2ad19ac4cf42ade41fa511a976b5d574ded79eb46e75
---

# PO-Briefing: feat-796-s4-hetzner-betrieb

- **Spec:** docs/specs/feat-796-schnitt-4a-betrieb.md
- **Issue:** #796
- **Erstellt:** 2026-11-03

## Was gebaut wird

Der Dienst läuft auf dem Hetzner-Server unter loose-ends.henemm.com, nur die Gesundheitsabfrage ist öffentlich, Ausfälle werden gemeldet.

## Definition of Done

Die Adresse antwortet mit gültigem Zertifikat, überlebt Neustart und Datenbank-Abbruch, andere Dienste laufen unverändert, ein Ausfall löst eine Telegram-Meldung aus.

## Wie geprüft wird

Echte Läufe auf dem Server und von außen belegen jede Anforderung; ob die Telegram-Meldung ankommt, bestätigt nur Henning.

## Kritische Anmerkungen

- Nächtliche Sicherung und Rückspielprobe aus dem Ticket fehlen hier; sie folgen als eigener Schnitt, das Ticket bleibt bis dahin offen.
- Ohne Hennings DNS-Eintrag bei Namecheap sind Adresse, Zertifikat und mehrere Belege nicht prüfbar.
- Ankunft der Telegram-Meldung ist nicht automatisch belegbar; Henning muss sie selbst sehen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
