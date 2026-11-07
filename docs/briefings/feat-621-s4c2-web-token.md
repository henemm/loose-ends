---
spec_file: docs/specs/feat-621-schnitt-4c2-web-token-ablegen.md
spec_sha256: 865f8b87af462c4b21c02c19b3d62a2bb8086353216ca785bc43b60f2e0fe0cd
spec_frozen_sha256: 85acf3db43a1516df64be85f06663c4d94da978d154be65472fbe00aeaa887e5
---

# PO-Briefing: feat-621-s4c2-web-token

- **Spec:** docs/specs/feat-621-schnitt-4c2-web-token-ablegen.md
- **Issue:** #621
- **Erstellt:** 2026-11-07

## Was gebaut wird

Der Dienst merkt sich die Apple-Berechtigung der Browser-Anmeldung verschlüsselt, damit sie beim Löschen des Kontos bei Apple zurückgegeben wird.

## Definition of Done

Gesamter Testlauf ist grün; ein Test zeigt: Browser-Anmeldung, Kontolöschung, dann gibt der Dienst genau diese Berechtigung bei Apple zurück.

## Wie geprüft wird

Automatische Tests mit Testdatenbank und nachgestelltem Apple prüfen Ablage, Fehlerfälle und Löschen; echtes Apple und Browser bleiben ungeprüft bis zum späteren Betrieb.

## Kritische Anmerkungen

- Früherer Beschluss (Token nicht speichern) wird bewusst umgedreht; der zugehörige Test wird ersetzt. Keine Entscheidung nötig.
- Verhalten gegen echtes Apple erst mit späterem Betrieb nachweisbar; Widerruf über Client-Grenzen ist bei Apple undokumentiert.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
