---
spec_file: docs/specs/feat-615-schnitt-4b2-sitzung.md
spec_sha256: ad401f318ab2e87ad0c4205f2098784e7ab0c3dcbaf0ce635782f4eba8786fbd
spec_frozen_sha256: de0884082bac9d29203cfe8cf985d670fba9933ee3545b12fe39f2e4d5fd48e6
---

# PO-Briefing: feat-615-s4b2-sitzung

- **Spec:** docs/specs/feat-615-schnitt-4b2-sitzung.md
- **Issue:** #615
- **Erstellt:** 2026-11-09

## Was gebaut wird

Die App bekommt intern die Logik für Anmelden, Abmelden und Konto löschen beim Claude-Dienst; sichtbar ist noch nichts.

## Definition of Done

Alle neuen und bestehenden automatischen Prüfungen laufen grün und die App baut; im Produkt ändert sich nichts, es erscheint keine Schaltfläche.

## Wie geprüft wird

Automatische Tests mit Ersatz-Speicher und Ersatz-Dienst prüfen alle Abläufe und Fehlerfälle; der echte Schlüsselbund und die Oberfläche bleiben ungeprüft.

## Kritische Anmerkungen

- Issue war nicht abrufbar; nur gegen die Kontextdokumente geprüft, nicht gegen den Originaltext.
- Die Anzeige „angemeldet" nach App-Start ist ungeprüft; eine abgelaufene Sitzung fällt erst beim Löschen auf.
- Umfang rund 260 statt 250 Zeilen; die Spec benennt und begründet den Überhang.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
