---
spec_file: docs/specs/fix-295-mitteilung-absturz.md
spec_sha256: 5e76e3c26b1130096014b4c93c474e8f56cdea6d124bb2ba190ade7224d9b840
---

# PO-Briefing: fix-295-mitteilung-absturz

- **Spec:** docs/specs/fix-295-mitteilung-absturz.md
- **Issue:** #295
- **Erstellt:** 2026-10-10

## Was gebaut wird

Das Antippen einer „fällig“-Mitteilung öffnet die App künftig ohne Absturz.

## Definition of Done

Mitteilung antippen öffnet die App im Simulator ohne Absturz; Henning bestätigt es nach Auslieferung im Alltag auf seinem iPhone.

## Wie geprüft wird

Ein Simulatortest tippt eine eingespielte Mitteilung an, rot vor und grün nach der Korrektur; die Aktionsknöpfe werden nicht direkt getestet.

## Kritische Anmerkungen

- Der Mitteilungstest läuft nur lokal, nie in der Automatik; ein späterer Rückfall in den Fehler bliebe unbemerkt.
- „Erledigt“, „Als nächstes“, „Morgen“ sind nur indirekt über denselben Codeweg belegt, nicht per Test bedient.
- Beweis auf dem iPhone folgt erst nach Ihrem „jetzt ist ein Test möglich“; das Ticket bleibt bis dahin offen.

## Freigabe-Frage

Genügt Ihnen der Simulatorbeweis ohne dauerhaften Automatiktest, bis Sie die Prüfung auf dem iPhone freigeben?
