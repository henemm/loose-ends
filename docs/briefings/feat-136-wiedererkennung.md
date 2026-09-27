---
spec_file: docs/specs/enrichment/feat-136-wiedererkennung.md
spec_sha256: 85bf97c77a02e8f7070fd51c904a95c2604c0c286c5c87e281f97dfe17c3604d
---

# PO-Briefing: feat-136-wiedererkennung

- **Spec:** docs/specs/enrichment/feat-136-wiedererkennung.md
- **Issue:** #136
- **Erstellt:** 2026-09-27

## Was gebaut wird

Eine Aufgabe mit bereits erfasstem Wortlaut übernimmt automatisch Dauer und Kontext der früheren Aufgabe.

## Definition of Done

Fertig, wenn wortgleich wiederkehrende Aufgaben automatisch Dauer und Kontext übernehmen, Nutzerkorrekturen aber nie überschrieben werden.

## Wie geprüft wird

222 automatisierte Tests plus eine Messung an 287 echten Aufgaben belegen Treffer und Schutz vor Wiederbefüllung; Diktat ist ungeprüft.

## Kritische Anmerkungen

- Ein falsch gesetzter Kontext bleibt unsichtbar — bewusst akzeptiertes, strukturelles Risiko dieser Automatik.
- Statt der verlangten Toleranzschwelle gilt Gleichheit: weniger Treffer, aber laut Messung keine falschen mehr.
- Umfang liegt über der Richtgröße (13 Dateien statt 4–5) — als Ausnahme bereits freigegeben.

## Freigabe-Frage

Sollen wortgleich wiederkehrende Aufgaben künftig automatisch Dauer und Kontext übernehmen, mit diesem Umfang und diesen Risiken?
