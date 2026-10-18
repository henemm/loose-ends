---
spec_file: docs/specs/feat-477-schnitt-1-liste.md
spec_sha256: 6a6bae93f6cc1d3f6134864034214be11d3bbb4e878c04442abda914600cacce
spec_frozen_sha256: 09b67c840eb10f3a8dc91c6573a21f5da7315f9022128ea6e90e2a27e9c1dd72
---

# PO-Briefing: feat-477-mac-papierstil

- **Spec:** docs/specs/feat-477-schnitt-1-liste.md
- **Issue:** #477
- **Erstellt:** 2026-10-17

## Was gebaut wird

Listen auf Mac und breitem iPad zeigen Papier mit Haarlinien und einen Untertitel „N offen · M Min.“.

## Definition of Done

Liste „New“ zeigt auf Mac und breitem iPad Papierzeilen mit Untertitel, das iPhone sieht unverändert aus, alle Tests sind grün.

## Wie geprüft wird

Rechentests belegen den Untertitel; das Aussehen belegen nur Bilder aus Mac-Testlauf und iPad-Simulator, der Hover-Effekt bleibt ungeprüft.

## Kritische Anmerkungen

- Tafel-Abweichung: kein Pfeil, keine Auswahlfarbe; Auswahl kommt erst mit #480.
- Untertitel auf dem iPad unsicher; fehlt er dort, entfällt er ersatzlos.
- Detail fehlt noch; Ticket-Text selbst nicht lesbar, Abgleich nur mit Kontextdokument.

## Freigabe-Frage

Soll die Liste auf Mac und iPad wie beschrieben umgesetzt werden, auch ohne Auswahlfarbe?
