---
spec_file: docs/specs/feat-795-schnitt-3b2-debug-weg.md
spec_sha256: e304c5f6c060139087d75a2f5b5529d20fdf6ff934c52406ce9b4ebba8b1c57b
spec_frozen_sha256: 3cc0016e1e594c1a45b8040cfffbc20132be750f3746073da4a5411809ecd0da
---

# PO-Briefing: feat-795-s3b2-debug-weg

- **Spec:** docs/specs/feat-795-schnitt-3b2-debug-weg.md
- **Issue:** #795
- **Erstellt:** 2026-11-13

## Was gebaut wird

Entwickler können die Verbindung zwischen App und Claude-Dienst lokal im Simulator komplett durchspielen; für Nutzer ändert sich nichts.

## Definition of Done

Zwei Simulatoren spielen gegen einen lokalen Dienst durch: Aufgabe von B wird als „Claude“-Änderung angelegt, sichtbar per Screenshot und im Dienst.

## Wie geprüft wird

Acht automatische Tests prüfen die Schutzregeln (nie im Store-Bau); ein echter Durchlauf belegt die Kette, nicht aber Apple-Anmeldung oder Server im Internet.

## Kritische Anmerkungen

- Issue #795 ließ sich nicht direkt lesen; Abgleich nur gegen Kontext-Dokument und Vorgänger-Spec.
- Skript- und Simulator-Belege sind Protokolle, keine automatischen Tests.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
