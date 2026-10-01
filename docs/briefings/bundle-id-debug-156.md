---
spec_file: docs/specs/tooling/fix-156-pruefkennung.md
spec_sha256: 3b766e35b9836ac6c22f5543173d9f209e3e9a596b980160c31e7392543d652e
---

---
# PO-Briefing: bundle-id-debug-156

- **Spec:** docs/specs/tooling/fix-156-pruefkennung.md
- **Issue:** #156
- **Erstellt:** 2026-10-01

## Was gebaut wird

Prüf-Testbauten auf deinem iPhone bekommen eine eigene App-Kennung und überschreiben deine echte App nicht mehr.

## Definition of Done

Nach einem Prüfbau sind auf deinem iPhone zwei getrennte Apps sichtbar, deine bisherige bleibt unverändert.

## Wie geprüft wird

Automatisierte Tests prüfen die Technik; ob beide Apps wirklich getrennt bleiben, wird einmalig am Gerät abgelesen.

## Kritische Anmerkungen

- Spec wurde nach deiner ersten Freigabe nochmal stark erweitert – du gibst jetzt die neue Fassung frei.
- Umfang hat sich verdreifacht: statt 5 nun 16 Dateien, deutlich über dem sonst üblichen Rahmen.
- Deine normale App ändert sich nicht – Lösung betrifft nur den Testweg, anders als ursprünglich verlangt.

## Freigabe-Frage

Gibst du diese deutlich erweiterte Lösung frei, obwohl sie den Umfang und die Kennung anders löst als ursprünglich gemeldet?
