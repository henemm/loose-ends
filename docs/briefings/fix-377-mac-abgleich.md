---
spec_file: docs/specs/fix-377-mac-abgleich.md
spec_sha256: 9aa56b7e00e666130977dc6795112b04e40ea13b0c1bd3288da1262c9be02e9c
---

# PO-Briefing: fix-377-mac-abgleich

- **Spec:** docs/specs/fix-377-mac-abgleich.md
- **Issue:** #377
- **Erstellt:** 2026-10-13

## Was gebaut wird

Die Einstellungen zeigen, ob die App mit iCloud abgleicht; der Mac bekommt dafür die nötige Anbindung.

## Definition of Done

In den Einstellungen steht „iCloud-Abgleich“ mit lesbarem Zustand; auf deinem Mac zeigt er, warum Aufgaben abweichen.

## Wie geprüft wird

Tests und Simulator belegen Regel und Anzeige; ob dein Mac wirklich abgleicht, zeigt erst dein Test am Gerät.

## Kritische Anmerkungen

- Behebt die Ursache nicht, macht sie nur sichtbar; Mac-Messung braucht dein „jetzt ist ein Test möglich“.
- Sechs statt fünf Dateien (UI-Test-Zusicherung, vier Zeilen); ungeprüft, ob das System die nötigen Abgleich-Ereignisse liefert.
- Anbindung könnte den Mac erstmals abgleichen lassen; zusammengeführte Aufgaben erscheinen, nichts wird gelöscht.

## Freigabe-Frage

Soll dieser Schnitt, der nur sichtbar macht und noch nichts repariert, freigegeben werden?
