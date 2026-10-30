---
entity_id: feat-762-schnitt-12-doku
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-762-schnitt-12-doku
---

# Spec: #762 Schnitt 12 — ADR-10 neu, Checkliste `neue-sprache.md`, CLAUDE.md

Epic #750. Zuletzt, nach #751–#761 und #763. Modell: Haiku. Nur Doku.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750.

## Purpose

Die Entscheidungen des Epics stehen in den Issues; nach dem Umbau gehören sie in `00-entscheidungen.md`, und der Weg
einer dritten Sprache in eine Checkliste, deren Zeilen auf existierende Dateien und Skripte zeigen.

Ohne Modell geht es nicht: nicht relevant.

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| docs/project/00-entscheidungen.md | MODIFY | ADR-10 neu (Z. 149–150), Tabelle R2-15 ergänzen |
| docs/reference/neue-sprache.md | NEW | Checkliste, acht Punkte (Inhalt: Issue #762) |
| CLAUDE.md | MODIFY | „Where things live“: `Shared/Language`; Verweis auf die Checkliste; Skriptnamen aus #756; „Ship“-Format aus #760; Datenschutzzeile aus #763 prüfen |

## Implementation Details

ADR-10, neuer Wortlaut (Kern): „Lokalisierung ab Tag eins. String Catalog, Englisch Basis, Deutsch parallel. Seit #750
(2026-10-30) tragen Sprachpakete in `Shared/Language/` jedes Regelwort; `LanguagePacks.shipped` ist die einzige
Sprachliste, Skripte lesen sie. Regeln prüfen alle ausgelieferten Sprachen zugleich (Denglisch im Korpus, kein Sprachfeld
im Produkt). Der Prompt an das Modell ist englisch, die Antwort folgt der Sprache der Notiz. Das Knäuel heißt je Sprache
anders (en „the Tangle“). Eine Sprache gilt als ausgeliefert, wenn sie die Schwelle aus `date-title-fidelity.md` erreicht.“

Checkliste: acht Punkte wie im Issue; Punkt 4 (Prompt) trägt den Vermerk „Stufe 3, einziger Gerätepunkt“; dazu „braucht
keine Sprache“ (`Locale.current`-Stellen) und die Widget-Textausnahme (#758).

## Test Plan

- [ ] Skript-Check im PR: jede Datei- und Skriptnennung in `neue-sprache.md` existiert (`grep -oE '`[^`]+\.(swift|py|md|json|yml)`' docs/reference/neue-sprache.md | tr -d '`' | sort -u | xargs -I{} sh -c 'test -e "{}" || echo "fehlt: {}"'` leer).
- [ ] `scripts/test_catalog_languages.py` und alle Skripttests grün (CLAUDE.md-Änderung bricht nichts).

## Acceptance Criteria

- **AC-1:** Grep-Check leer (Ausgabe im PR).
- **AC-2:** Kein Status- oder Prioritätsdokument entstanden (`git diff --stat main -- docs/project` zeigt nur `00-entscheidungen.md`).
- **AC-3:** Abschlusskommentar in #750 mit den vierzehn PR-Links.

## Definition of Done

- [ ] AC-1 bis AC-3 belegt. PR `docs: ADR-10 Sprachpakete, Checkliste neue Sprache (Refs #750, Closes #762)`; Merge; Board Done; Epic #750 schließen.

## Changelog

- 2026-10-30: Spec erstellt.
