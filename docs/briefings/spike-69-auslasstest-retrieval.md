---
spec_file: docs/specs/measurement/spike-69-regel-auslasstest.md
spec_sha256: 4bc256a8005cb613a95555acd8e5eb6889b2868eff2eb7b89ff483bdcb872a77
---

# PO-Briefing: spike-69-auslasstest-retrieval

- **Spec:** docs/specs/measurement/spike-69-regel-auslasstest.md
- **Issue:** #131 (Nachfolger von #69)
- **Erstellt:** 2026-09-26

## Was gebaut wird

Ein Rechentest prüft, ob eine Nachbar-Wortregel bei Kontext, Dauer, Energie eine einfache Standardannahme schlägt.

## Definition of Done

Ein Bericht mit echten Zahlen sagt je Merkmal aus, ob die Regel die Standardannahme statistisch abgesichert schlägt oder nicht.

## Wie geprüft wird

Automatisierte Rechentests auf echten gespeicherten Aufgaben beweisen die Rechenlogik; ob ein Sprachmodell besser abschneidet, bleibt unbeantwortet.

## Kritische Anmerkungen

- Beantwortet nur, ob die Wortregel funktioniert; ob das Sprachmodell mit Beispielen hilft, bleibt für später offen.
- Bei Kontexten kann ein echter Vorteil bis 12 Punkte an der kleinen Stichprobe scheitern, als „nicht erfüllt" gelten.
- Ergebnis gilt für gepflegte Titel, nicht für den rohen Erfassungstext, den das Produkt tatsächlich verarbeitet.

## Freigabe-Frage

Reicht diese Regel-Zahl, um über den nächsten, gerätezeitaufwendigen Modelltest zu entscheiden, oder soll direkt das Modell gemessen werden?
