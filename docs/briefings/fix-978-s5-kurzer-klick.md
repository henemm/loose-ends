---
spec_file: docs/specs/fix-978-s5-kurzer-klick.md
spec_sha256: 728f6b24758e7d5381b7f4ed33f1b76c493dbc15be5b2b226504fd517e5b6b66
spec_frozen_sha256: f5be14fbcc36e148e5b3e689283bf53b8b091337aadbf9fc5acb56072b3047c3
---

# PO-Briefing: fix-978-s5-kurzer-klick

- **Spec:** docs/specs/fix-978-s5-kurzer-klick.md
- **Issue:** #978
- **Erstellt:** 2026-11-25

## Was gebaut wird

Der Mac-Prüfablauf klickt kurz aufs Menüleistensymbol und wiederholt nur einmal, wenn der Klick nachweislich zu lange hielt.

## Definition of Done

Der Pflicht-Check „Mac Gallery“ läuft dreimal hintereinander grün, und ein 40er-Wiederholungslauf je Nutzerweg zeigt keinen roten Fall.

## Wie geprüft wird

Skripttests prüfen nur den Aufbau; ob es wirkt, zeigen erst Probelauf, 40er-Lauf und drei Galerie-Läufe in der CI.

## Kritische Anmerkungen

- Neu gegenüber v6: kleiner App-Zusatz (ca. 25 Zeilen), nur im Testmodus wirksam; Produktverhalten bleibt unberührt.
- Ob der Test den von der App gesetzten Wert lesen kann, ist unbelegt; sonst Stopp und neue Analyse.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
