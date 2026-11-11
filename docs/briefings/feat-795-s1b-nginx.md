---
spec_file: docs/specs/feat-795-schnitt-1b-nginx.md
spec_sha256: 0ee9651bf88aaa7ded0ee763355c25081c1f65f203c6585dc11cb09754008088
spec_frozen_sha256: 17427d453f3e9b9d555f6098ce8fcca4ea811c4b4d72aa07aacfde20e1254b49
---

# PO-Briefing: feat-795-s1b-nginx

- **Spec:** docs/specs/feat-795-schnitt-1b-nginx.md
- **Issue:** #795
- **Erstellt:** 2026-11-11

## Was gebaut wird

Der Live-Dienst nimmt von außen die drei Abgleich-Adressen der App an, sonst nichts; sichtbar ändert sich noch nichts.

## Definition of Done

Ein Prüfskript von außen zeigt vorher Fehlschlag, nachher Erfolg, und die anderen Dienste auf dem Server laufen unverändert.

## Wie geprüft wird

Acht Testanfragen ohne Anmeldung belegen, dass die Adressen offen sind und richtig abweisen; echter Durchlauf mit Anmeldung fehlt noch.

## Kritische Anmerkungen

- Eigene Mengenbegrenzung statt der früher notierten gemeinsamen; falsch bemessen, würde deine Heim-Adresse eine Stunde gesperrt (technische Entscheidung, begründet).
- Die Abbruchregel bei Ablehnung gilt nur auf dem Papier, bis spätere Schnitte sie in der App umsetzen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
