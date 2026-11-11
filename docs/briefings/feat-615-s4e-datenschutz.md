---
spec_file: docs/specs/feat-615-schnitt-4e-datenschutz.md
spec_sha256: a847f46fca480dafa14f9145df9ede131ed8497df6f7f4a884a0ceb5a8f51c5b
spec_frozen_sha256: 7502ddc1ca59f19cf214e0dca8306bcbc1b5a06f52239cb545ce45916961dacf
---

# PO-Briefing: feat-615-s4e-datenschutz

- **Spec:** docs/specs/feat-615-schnitt-4e-datenschutz.md
- **Issue:** #615
- **Erstellt:** 2026-11-10

## Was gebaut wird

Der Datenschutztext erklärt ehrlich das freiwillige Claude-Konto samt Dienst und Löschen und erscheint auf henemm.com deutsch und englisch.

## Definition of Done

Beide Webseiten zeigen den freigegebenen Konto-Abschnitt, die 30-Tage-Sicherungsfrist gilt nachweislich, und der Store-Schalter bleibt aus.

## Wie geprüft wird

Ein Textprüfskript sucht Kernaussagen und veraltete Sätze; Standort, Fristen und Live-Seiten werden per Beleg geprüft, Rechtsgültigkeit nicht.

## Kritische Anmerkungen

- Der lokale Sicherungsstand auf dem Server selbst (jüngster Dump) fehlt im Wortlaut; der Text nennt nur die Sicherung auf dem zweiten Rechner.
- Hetzner-Auftragsverarbeitungsvertrag ist offen (#625), der Text nennt Hetzner schon; keine Rechtsprüfung, nur Entwurf des Tech Leads.
- Wortlaut deckt Code ab: Aufträge samt Inhalt, Konto, Sitzungen, Apple-Token; Abschrift-Upload bewusst nicht erwähnt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
