---
spec_file: docs/specs/fix-978-s3-wiederoeffnen-warten.md
spec_sha256: 8a57346a91ba4f699ac56aed7f2378d814bd9d2b2baff5a1124c039facc33209
spec_frozen_sha256: 1a969944b6f5fc075aeea0b3db05876540f7937da18b1a4d4ab0146fd825c82d
---

# PO-Briefing: fix-978-s3-wiederoeffnen-warten

- **Spec:** docs/specs/fix-978-s3-wiederoeffnen-warten.md
- **Issue:** #978
- **Erstellt:** 2026-11-24

## Was gebaut wird

Der automatische Mac-Test öffnet das Menüleisten-Fenster künftig so wie ein Nutzer, damit er wieder streng prüft statt Fehler zu dulden.

## Definition of Done

Der Wiederholungstest läuft in mindestens 100 Durchgängen je Variante ohne Fehlschlag, und die Pflichtprüfung „Mac Gallery“ ist dreimal beim ersten Versuch grün.

## Wie geprüft wird

Wiederholungsläufe und Aktivitätsprotokolle belegen, dass das Fenster offen bleibt; ob echte Nutzer das Zuklappen je erleben, wird nicht geprüft.

## Kritische Anmerkungen

- Die App selbst bleibt unverändert; nur der Test wird angepasst. Ein seltenes Zuklappen für Nutzer bliebe, falls es existiert.
- Unbelegt, ob die neue Klickart das Problem wirklich beseitigt; die erste Fassung wurde bereits widerlegt, Rückfall ist vorgesehen.
- Bei etwa 0,5 % Fehlerrate beweisen 100 fehlerfreie Läufe die Behebung nur statistisch.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
