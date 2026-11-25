---
spec_file: docs/specs/fix-978-s5-kurzer-klick.md
spec_sha256: 415740ee8398184bcd89aff1809341cd291a8b72011fdf8bce7a9582b018f39e
spec_frozen_sha256: 972bb923eb53afee4bef4689f7662286e5463efd356e220c6959f31d9a5debe2
---

# PO-Briefing: fix-978-s5-kurzer-klick

- **Spec:** docs/specs/fix-978-s5-kurzer-klick.md
- **Issue:** #978
- **Erstellt:** 2026-11-25

## Was gebaut wird

Der automatische Mac-Test klickt das Menüleistensymbol kurz wie ein Mensch, sodass das Panel nicht mehr zufällig zuklappt.

## Definition of Done

Der Mac-Galerie-Prüflauf ist dreimal hintereinander grün, und der Nachweislauf zeigt bei 40 Klicks je Testweg kein zugeklapptes Panel.

## Wie geprüft wird

Skripttests und ein Nachweislauf mit 40 Klicks je Weg belegen das; ob echte Nutzer das Problem erleben, wird nicht geprüft.

## Kritische Anmerkungen

- Ob der kurze Klick auch nach „Open Loose Ends“ trägt, ist ungemessen; scheitert der Nachweislauf dort, stoppt die Arbeit.
- Ursache liegt im Prüfwerkzeug, die App bleibt unverändert; langes Gedrückthalten schließt das Panel weiterhin, wie bei Systemmenüs.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
