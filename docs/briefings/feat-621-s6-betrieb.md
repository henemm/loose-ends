---
spec_file: docs/specs/feat-621-schnitt-6a-tuer.md
spec_sha256: e23be58a1cb427357ed8856a56413a7efed143ae40678952504e5c67f25fabc5
spec_frozen_sha256: b16112620fdc2c70d0fe98306cff6e4ceaf49853b071cf2112c6d58dc267ff04
---

# PO-Briefing: feat-621-s6-betrieb

- **Spec:** docs/specs/feat-621-schnitt-6a-tuer.md
- **Issue:** #621
- **Erstellt:** 2026-11-08

## Was gebaut wird

Der Dienst legt nur für Hennings Apple-ID ein Konto an; jede fremde Apple-ID wird bei der Anmeldung abgewiesen.

## Definition of Done

Eine fremde Apple-ID scheitert in App- und Browser-Anmeldung ohne Konto, Sitzung oder gespeichertes Apple-Token; der Gesamttestlauf ist grün.

## Wie geprüft wird

Automatische Tests mit Testdatenbank und nachgebautem Apple belegen beide Anmeldewege und Gleichzeitigkeit; echtes Apple und echter Browser bleiben ungeprüft.

## Kritische Anmerkungen

- Bis Hennings erster Anmeldung könnte ein Fremder zuerst ankommen; die Kontrolle liegt erst im nächsten Schnitt (Betrieb).
- Umfang über Limit: 9 Dateien, ca. 283 Zeilen; Spec begründet es mit Sicherheit, Tech Lead entscheidet.
- Abgewiesene behalten eine bei Apple eingelöste Autorisierung; bewusst nicht aufgeräumt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
