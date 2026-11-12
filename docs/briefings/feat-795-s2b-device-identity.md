---
spec_file: docs/specs/feat-795-schnitt-2b-device-identity.md
spec_sha256: 2fe96a005d238f1823f5294dd549d163608c3565e613ed61c60bb7044f045179
spec_frozen_sha256: 1991cb0a818d4d3cb65fc95e867735d692fee2086d82ec6a1361e459913fec94
---

# PO-Briefing: feat-795-s2b-device-identity

- **Spec:** docs/specs/feat-795-schnitt-2b-device-identity.md
- **Issue:** #795
- **Erstellt:** 2026-11-12

## Was gebaut wird

Die App bekommt eine feste Gerätekennung und einen einzigen, abgesicherten Zugang zum Dienst für Claude, noch unsichtbar und ungenutzt.

## Definition of Done

Alle Prüfungen laufen grün, die App startet im Simulator unverändert, und nichts im Produkt ruft die neuen Teile bisher auf.

## Wie geprüft wird

Automatische Tests mit einem Stellvertreter-Schlüsselbund belegen jede Regel; der echte Schlüsselbund und der Live-Dienst werden erst im Folgeschnitt erprobt.

## Kritische Anmerkungen

- Ein beschädigter Kennungs-Eintrag würde den Abgleich dieses Geräts blockieren, bis ein späterer Schnitt einen Ausweg bietet; bewusst so entschieden.
- Dass die Kennung eine Neuinstallation überlebt, ist von Apple nicht zugesagt; bei Verlust entsteht eine neue Kennung.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
