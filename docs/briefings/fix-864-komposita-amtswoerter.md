---
spec_file: docs/specs/enrichment/fix-864-komposita-amtswoerter.md
spec_sha256: d01dfdbeb0524b951ae2e66e02fe95420df77faf5ef8ce07d717691e42d5ab81
spec_frozen_sha256: 01bfa75028e7a4cda8017d35c451056c5668e7f4645daa1860e62d81244ff9a1
---

# PO-Briefing: fix-864-komposita-amtswoerter

- **Spec:** docs/specs/enrichment/fix-864-komposita-amtswoerter.md
- **Issue:** #864
- **Erstellt:** 2026-11-12

## Was gebaut wird

Zusammensetzungen mit Amtswörtern wie „Steuerbescheid“ oder „Amtsgericht“ machen eine Aufgabe wichtig, „Steuerrad“ dagegen nicht.

## Definition of Done

„Steuerbescheid prüfen“ bekommt im Simulator hohe Wichtigkeit, „Steuerrad reparieren“ nicht, und alle bisherigen Tests bleiben grün.

## Wie geprüft wird

Automatische Tests prüfen Treffer, Fehltreffer und bisherige Treffer; nicht erfasst sind Wörter außerhalb der festen Liste.

## Kritische Anmerkungen

- Nur aufgezählte Wörter treffen; Neubildungen wie „Steuerrückzahlungsbescheid“ nicht. Das Ticket klingt allgemeiner, vermeidet so aber Fehltreffer.
- Zusätzlich werden Wörter mit Amtswort hinten („Mietvertrag“, „Scheidungsanwalt“) wichtig; im Ticket nicht genannt, aber dieselbe Logik.
- Issue-Text selbst nicht lesbar; geprüft gegen das Kontextdokument.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
