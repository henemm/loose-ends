---
spec_file: docs/specs/enrichment/feat-98-deutsche-begruendungen.md
spec_sha256: 42d927f65d6db162a6e8491c113111ec454f08d674330b1ae0c0e26337934ffc
---

# PO-Briefing: feat-98-deutsche-begruendungen

- **Spec:** docs/specs/enrichment/feat-98-deutsche-begruendungen.md
- **Issue:** #98
- **Erstellt:** 2026-09-21

## Was gebaut wird

Die Begründungssätze für automatisch erkannte Fälligkeitsdaten erscheinen auf Deutsch statt Englisch.

## Definition of Done

Alle neun Begründungssätze sind in einem Testlauf nachweislich auf Deutsch hinterlegt und kein bestehender Code hat sich geändert.

## Wie geprüft wird

Ein automatisierter Test liest die deutschen Übersetzungen direkt aus der gebauten App; ob sie auf einem echten Gerät angezeigt werden, prüft kein Test.

## Kritische Anmerkungen

- Anfrage verlangt Beweis auf einem deutschen Gerät; Spec beweist es nur im gehosteten Testlauf, kein Gerätetest mit umgeschalteter Sprache.
- Drei von sechs Kriterien (Anführungszeichen, Wortlaut, Status-Markierung) werden nur manuell per Skript geprüft, nicht automatisiert getestet.

## Freigabe-Frage

Genügt dir der Nachweis aus dem Testlauf, oder brauchst du zusätzlich den sichtbaren deutschen Text auf deinem iPhone?
