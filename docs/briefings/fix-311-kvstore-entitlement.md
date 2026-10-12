---
spec_file: docs/specs/fix-311-kvstore-entitlement.md
spec_sha256: 7b89734ef059650441a22e9d67128ea7fcc2683caabe4834b82ed6ae29f8ed45
---

# PO-Briefing: fix-311-kvstore-entitlement

- **Spec:** docs/specs/fix-311-kvstore-entitlement.md
- **Issue:** #311
- **Erstellt:** 2026-10-12

## Was gebaut wird

Die Mitteilungs-Uhrzeit gleicht sich in TestFlight-Bauten zwischen deinen Geräten ab.

## Definition of Done

Uhrzeit am iPhone ändern; auf Mac oder iPad erscheint nach kurzer Zeit dieselbe, und der TestFlight-Bau läuft durch.

## Wie geprüft wird

Skripttest und Archivprüfung belegen die Berechtigung; der echte Abgleich zwischen zwei Geräten bleibt dein Test.

## Kritische Anmerkungen

- Ob Apples Signierung die Berechtigung im TestFlight-Bau akzeptiert, ist unbelegt; sonst Rückfall mit Schemaänderung, der deine Entscheidung kippt.
- Abgleich war nie bestätigt; #311 bleibt bis zu deiner Geräte-Rückmeldung offen.
- Archivprüfung ohne automatischen Test, nur lokal belegt.

## Freigabe-Frage

Soll die Berechtigung ergänzt und dann im TestFlight-Bau auf deinen Geräten geprüft werden?
