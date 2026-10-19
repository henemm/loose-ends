---
spec_file: docs/specs/fix-419-latenzschutz.md
spec_sha256: c3ac7708fef3685520982a9a36dfe34c5d5ad6abe6b0d5b150f47705437fddae
spec_frozen_sha256: e6ba05aca208a168e931e98fe9a22cada95ae7c29771ccf78d3dd72e4b696eb7
---

# PO-Briefing: fix-419-latenzschutz

- **Spec:** docs/specs/fix-419-latenzschutz.md
- **Issue:** #419
- **Erstellt:** 2026-10-19

## Was gebaut wird

Dass die zwei Sprach-Messtests im Simulator und in der CI nie wirklich messen, wird künftig als eigene Zeile mit Grund sichtbar, statt als "bestanden" durchzugehen.

## Definition of Done

Jeder CI- und Simulatorlauf nennt beide Messtests einzeln als gemessen oder "NICHT gemessen" samt Grund; der Lauf bleibt dabei grün.

## Wie geprüft wird

Skripttests gegen den echten Log-Auszug aus CI-Lauf 39167072947 decken ausgefallen, gemessen, fehlgeschlagen und fehlend ab; der nächste CI-Lauf zeigt die Zeile.

## Kritische Anmerkungen

- Die Ticket-Gegenprobe "ohne .fastResults wird die CI rot" wird nicht erfüllt, weil dort nicht gemessen werden kann.
- Nur der Konstantentest fängt das Entfernen von .fastResults weiter in jedem Lauf; eine langsamere Erkennung bleibt ungeschützt.
- Dass die CI-Läufer die Sprache nicht hergeben, ist Vermutung und wird erst durch die neue Diagnosezeile belegt.
- Fünf Dateien, Obergrenze des Limits; kein Pfad der Geräteliste berührt, nichts auf deinen Geräten.

## Freigabe-Frage

Soll der Ausfall nur laut benannt werden, obwohl der Latenzschutz in CI und Simulator damit weiterhin nicht wirklich misst?
