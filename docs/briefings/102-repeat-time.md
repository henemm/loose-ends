---
spec_file: docs/specs/enrichment/rule-102-repeat-time.md
spec_sha256: e61a7ed4b33d73adc17b9b86fd379ca18e7ed35d327dc031431e3ab994c120a2
---

# PO-Briefing: 102-repeat-time

- **Spec:** docs/specs/enrichment/rule-102-repeat-time.md
- **Issue:** #102
- **Erstellt:** 2026-09-24

## Was gebaut wird

Die App merkt sich künftig die Uhrzeit aus dem Text, sobald eine Wiederholung manuell angelegt wird.

## Definition of Done

Beim manuellen Anlegen einer täglichen oder wöchentlichen Wiederholung übernimmt die App automatisch die im Text genannte Uhrzeit.

## Wie geprüft wird

Automatisierte Tests bestätigen Erkennung, Übernahme beim Anlegen und Unverändertsein bei späterer Bearbeitung; sichtbare Anzeige oder Erinnerungswirkung prüfen sie nicht.

## Kritische Anmerkungen

- Die Uhrzeit wird nur gespeichert, wenn danach manuell eine Wiederholung angelegt wird — nicht automatisch beim Diktieren.
- Die gespeicherte Uhrzeit ist nirgends sichtbar und beeinflusst keine Erinnerung — aktuell ohne wahrnehmbaren Effekt.
- Bereits bestehende Wiederholungen bekommen die Uhrzeit nicht nachträglich — nur neu angelegte.

## Freigabe-Frage

Sind Sie einverstanden, dass die Uhrzeit vorerst nur gespeichert wird, ohne in der App sichtbar zu sein oder Erinnerungen zu beeinflussen?
