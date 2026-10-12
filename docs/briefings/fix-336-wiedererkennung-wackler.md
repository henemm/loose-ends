---
spec_file: docs/specs/tooling/fix-336-wiedererkennung-wackler.md
spec_sha256: c92e04839ff12ad407b8fafada2783ae8ae6045c9603a94d50f4f24b7151ea2f
---

# PO-Briefing: fix-336-wiedererkennung-wackler

- **Spec:** docs/specs/tooling/fix-336-wiedererkennung-wackler.md
- **Issue:** #336
- **Erstellt:** 2026-10-12

## Was gebaut wird

Der Wiedererkennungs-Test soll in der automatischen Prüfung beim ersten Versuch zuverlässig bestehen, ohne Änderung der App.

## Definition of Done

Drei aufeinanderfolgende Prüfläufe auf dem Build-Server bestehen ohne Wiederholung; die App selbst bleibt unverändert.

## Wie geprüft wird

Lokale Läufe mit und ohne künstliche Last zeigen das Verhalten; der ursprüngliche Ausfall lässt sich nicht gezielt auslösen, also nicht beweisen.

## Kritische Anmerkungen

- Issue-Text war nicht abrufbar; Abgleich nur gegen das Kontextdokument.
- Wirkung nur statistisch: Ausfall nicht erzwingbar, Beleg erst nach Freigabe durch drei grüne Läufe.
- Nur dieser Test wird gehärtet; andere Tests können weiter wackeln, Lösung bräuchte eigenes Ticket.

## Freigabe-Frage

Soll nur die Wartezeit dieses einen Tests auf 60 Sekunden erhöht werden, obwohl andere Tests weiter wackeln könnten?
