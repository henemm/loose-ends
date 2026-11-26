---
spec_file: docs/specs/feat-1000-schnitt-2-passt-entfaellt.md
spec_sha256: d9e22bc6347fe61d0d0f4ad2cbf62f100f4d9dee7286f53c5826edb1551401ff
spec_frozen_sha256: c0c554676f3a973a9193c9e833c6b22b23cffc297c8fcb9c2ff6859dcfb515b4
---

# PO-Briefing: feat-1000-s2-passt-entfaellt

- **Spec:** docs/specs/feat-1000-schnitt-2-passt-entfaellt.md
- **Issue:** #1000
- **Erstellt:** 2026-11-26

## Was gebaut wird

Erfasste Aufgaben müssen nirgends mehr mit „Passt“ bestätigt werden: Knopf, Wisch, Menüeintrag und Hinweise in Liste und Detail entfallen.

## Definition of Done

Im Simulator zeigt das Detail einer frisch gesprochenen oder getippten Aufgabe weder „Passt“ noch einen Prüfhinweis, das Menü enthält weiterhin „Erledigen“.

## Wie geprüft wird

Ein Oberflächentest erfasst eine Aufgabe und prüft die Abwesenheit von „Passt“; „Beim Öffnen als gesehen markieren“ wird nur im Code geprüft.

## Kritische Anmerkungen

- Zwei Kriterien (keine Reste im Code, immer „gesehen“ beim Öffnen) haben keinen automatischen Test, nur Codeprüfung.
- Zeilen bleiben bis Schnitt 3 akzentfarbig getönt; Regeln und Katalog bleiben ebenfalls bis dahin.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
