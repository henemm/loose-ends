---
spec_file: docs/specs/tooling/fix-178-ci-xcode27.md
spec_sha256: 75d3dae6a5f4c563c3c075ec6960ac70e67577c7b37a06c8620ca61c61f6cd60
---

# PO-Briefing: ci-178-xcode27

- **Spec:** docs/specs/tooling/fix-178-ci-xcode27.md
- **Issue:** #178
- **Erstellt:** 2026-10-05

## Was gebaut wird

Die automatische Prüfung testet die App künftig mit derselben Xcode-Version und demselben Ziel wie du, ohne stille Absenkung.

## Definition of Done

Alle drei Prüfläufe sind grün mit Xcode 27.0 und Ziel 27.0, die Absenkung ist weg, die Projektbeschreibung ist nachgezogen.

## Wie geprüft wird

Es gibt keine neuen Tests; Nachweis sind die echten Prüfläufe selbst, nicht aber, ob die Umstellung dauerhaft stabil bleibt.

## Kritische Anmerkungen

- Rote Oberflächentests möglich, falls der Simulator doch ein KI-Modell hat; ungeprüft, dann hängt das Ticket an #208.
- Das Vorschau-Image kann wegfallen; dann startet keine Prüfung mehr, einen Rückweg auf Xcode 26 gibt es bewusst nicht.
- Zusätzlich zur Anfrage: gemeinsame Hilfsdatei, strenge Simulatorwahl und Entfernen eines Compiler-Schalters im Messcode.

## Freigabe-Frage

Soll die Prüfung ohne Rückweg auf das Vorschau-Image mit festem Xcode 27.0 umgestellt werden?
