---
spec_file: docs/specs/feat-621-schnitt-4b1-hinweg.md
spec_sha256: 0d0f342789baed3c6a0ae9c095e5303efe829ca27a47d7c2c3f507af9a303f94
spec_frozen_sha256: 1d84daef0b8e3eb59280b3260f1d2f6c4243db5a73ec16ac54c1230d69279e0f
---

# PO-Briefing: feat-621-s4b-anmeldung

- **Spec:** docs/specs/feat-621-schnitt-4b1-hinweg.md
- **Issue:** #621
- **Erstellt:** 2026-11-06

## Was gebaut wird

Claude-Anmeldung im Browser wird vorbereitet: Der Dienst leitet zur Apple-Anmeldung weiter, ohne dass sich für dich etwas ändert.

## Definition of Done

Der Testlauf des Dienstes ist grün und zeigt, dass der Anmeldeversuch zu Apple weiterleitet; sichtbar ändert sich für dich nichts.

## Wie geprüft wird

Automatische Tests spielen den Hinweg gegen echte Datenbank durch; Apple selbst und der Rückweg mit Kontoanlage bleiben ungeprüft.

## Kritische Anmerkungen

- Der geplante Schnitt ist geteilt: Rückweg und Kontoanlage folgen erst im nächsten Schnitt, durchgängig anmelden geht danach.
- Umfang etwa 270 statt 250 Zeilen; die Freigabe nimmt diese Überschreitung ausdrücklich an.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
