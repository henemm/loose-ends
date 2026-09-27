---
spec_file: docs/specs/enrichment/feat-136-wiedererkennung.md
spec_sha256: fc648b91cbbf8e8d47c1f5b83f747a177e77044cd0bb3c55078ae1b29ada0735
---

# PO-Briefing: feat-136-wiedererkennung

- **Spec:** docs/specs/enrichment/feat-136-wiedererkennung.md
- **Issue:** #136
- **Erstellt:** 2026-09-27

## Was gebaut wird

Wird eine Aufgabe wortgleich erneut erfasst, übernimmt die App automatisch Kontexte und Dauer der ersten.

## Definition of Done

Fertig ist es, wenn eine Wiederholung automatisch dieselben Kontexte und Dauer trägt, sichtbar als KI-Hinweis in der Historie.

## Wie geprüft wird

Tests bestätigen dies an alten, sauber betitelten Aufgaben; ob es bei live diktiertem Text genauso trifft, bleibt ungemessen.

## Kritische Anmerkungen

- Statt der bestellten Ähnlichkeitsschwelle (Jaccard 0,34) verlangt die Spec exakte Wortgleichheit — trifft dadurch seltener, aber nie falsch.
- Alle Zahlen stammen aus sauberen Altdaten, nicht aus gesprochenem Text — wie gut es im Alltag trifft, bleibt offen.
- Nebenbei behebt die Spec einen Fehler: die App hätte KI-Werte sonst kurz danach unbemerkt überschrieben.

## Freigabe-Frage

Sind Sie einverstanden, dass die App nur wortgleiche Wiederholungen erkennt, nicht auch ähnlich formulierte?
