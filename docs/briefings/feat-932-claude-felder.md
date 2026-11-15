---
spec_file: docs/specs/feat-932-schnitt-1-app.md
spec_sha256: bf334444022794a56770c66f8716a8cf98116772617aa9b4e80fc25f8310daac
spec_frozen_sha256: 1e226a9db539ad5bd27f71a5171f5e6c82acfdcd11c410225a14ee2ed81d6ef3
---

# PO-Briefing: feat-932-claude-felder

- **Spec:** docs/specs/feat-932-schnitt-1-app.md
- **Issue:** #932
- **Erstellt:** 2026-11-15

## Was gebaut wird

Die App führt Aufträge von Claude aus, die Titel und Angaben einer Aufgabe setzen oder ändern.

## Definition of Done

Alle neuen und bestehenden Tests sind grün, der Simulator-Durchlauf der Claude-Änderung ist belegt, und die Änderung ist ausgeliefert.

## Wie geprüft wird

Automatische Tests prüfen jedes Feld, jede Ablehnung ohne Schreiben und den Titelschutz; der echte Ablauf mit Feldern entsteht erst später.

## Kritische Anmerkungen

- Umfang etwa 420 statt 250 Zeilen, laut Spec vor Baubeginn vom PO anzunehmen; Grund sind Sicherheitstests.
- Nur Schnitt 1 von 3; Claude kann erst nach den Dienst-Schnitten wirklich Felder setzen, das Ticket bleibt offen.
- Beiläufig neu: Ein vom Nutzer geänderter Titel wird nicht mehr vom Modell überschrieben (alle Aufgaben).

## Freigabe-Frage

Nimmst du den Umfang von etwa 420 statt 250 Zeilen an, weil der Überhang nur aus Sicherheitstests stammt?

## Ampel

Ampel: rot
