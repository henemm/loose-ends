# Context: feat-893-c-gruende

## Request Summary
Schnitt C von #893: Bei einer 409-Antwort auf `einreichen` nennt das Werkzeug die Gründe aus `meta.associatedErrors` (nur Codes und `source`-Pfade), damit die Ursache der Ablehnung sichtbar wird und behoben werden kann. Danach erneuter Lauf (nach Hennings Wort).

## Ausgangslage (Lauf 42787146277, 2026-11-10)
- `POST /v1/reviewSubmissionItems` → 409 `STATE_ERROR.ENTITY_STATE_INVALID` („This resource cannot be reviewed…"). Gründe stehen nur in `meta.associatedErrors`.
- Bei Apple liegt eine leere iOS-Einreichung `READY_FOR_REVIEW`; der nächste Lauf verwendet sie wieder (AC-5). Mac nicht angefasst.
- Vermutete Ursachen (Fallberichte, noch nicht belegt): Version noch in anderer Einreichung, oder fehlende Pflichtangaben (App-Datenschutz, Altersfreigabe, Inhaltsrechte, Exportkonformität).

## Related Files
| File | Relevance |
|------|-----------|
| scripts/asc_store_submit.py (`send_once`, Z. 301–320) | fängt HTTPError, nutzt `error_codes`; hier kommt die Ausgabe der associatedErrors hinzu |
| scripts/asc_what_to_test.py (`error_codes`, Z. 43) | liest nur `errors[].code` (Regex `[A-Z0-9_.]+`, max. 5); von mehreren Skripten geteilt, besser nicht ändern |
| scripts/test_asc_store_submit.py (Z. 163–191, 564 ff.) | nachgestellte API (`refuse`), AC-8-Test, AC-10-Test (keine Kennungen/Wortlaut) |
| docs/specs/feat-893-schnitt-b-einreichen.md | AC-8 und AC-10 – Regeln bleiben bindend |
| .github/workflows/asc-store-submit.yml | Lauf per `gh workflow run` |

## Existing Patterns
- Ausgabe nur Zustandswörter/Codes, nie Rohantwort, Kennungen, Store-Wortlaut (AC-10).
- Je Schreibaufruf genau einmal, nie wiederholt (`send_once`).
- Fehlercodes per Regex-Whitelist gefiltert; Störungen im Rumpf ergeben leere Liste.

## Dependencies
- Upstream: ASC-API-Fehlerformat (`errors[].meta.associatedErrors` als Objekt: Pfad → Liste von Fehlern mit `code`; genaue Form per Recherche zu belegen).
- Downstream: `einreichen`-Ausgabe im Workflow-Log; Beleg unter docs/artifacts.

## Existing Specs
- docs/specs/feat-893-schnitt-a-pruefen.md, docs/specs/feat-893-schnitt-b-einreichen.md

## Risks & Considerations
- Genaue JSON-Form von `associatedErrors` ungeklärt → in /20-analyse recherchieren; Parser defensiv, Whitelist für Code und Pfad.
- `source`-Pfade könnten Kennungen enthalten → filtern/kürzen (AC-10).
- Alternative zum Ausgeben der Gründe: vorab per GET prüfen (Altersfreigabe, Datenschutz, Exportkonformität, Mitgliedschaft in Fremd-Einreichung) und in `pruefen` aufnehmen – ergänzt Schnitt A, ohne Schreibaufruf nötig.
- Nach Behebung greift die Wiederverwendung (AC-5); Schreiblauf nur nach Hennings ausdrücklichem Wort.
- Aktueller Zweig `feat-893-b-einreichen` ist gemergt; für C neuer Zweig von main nötig.

## Analysis

### Type
Feature (Diagnose-Ausgabe im Einreichwerkzeug; kein Fehler im Produkt).

### Recherche (vor allem anderen, 2026-11-10)
- Das Muster ist bekannt: 409 `STATE_ERROR.ENTITY_STATE_INVALID`, Text „This resource cannot be reviewed, please check associated errors to see why“ — Quellen: [Apple-Forum 820511](https://developer.apple.com/forums/thread/820511), [rxliuli: neue Pflichtfelder](https://rxliuli.com/blog/app-store-connect-new-required-fields).
- Der eigentliche Grund steht nur in `meta.associatedErrors`. **Die genaue JSON-Form ist nirgends dokumentiert**: Apples Seiten zu ErrorResponse/„pinpointing the location of errors“ erwähnen `meta.associatedErrors` nicht, und keine der Fallberichte zitiert den Block. Ein Entwurf „Pfad → Liste von Fehlern mit code“ ist Vermutung und wird nicht als Tatsache behandelt.
- Belegte Ursachen in Fallberichten: neues Pflichtfeld in der Altersfreigabe (z. B. Social Media), altes Item in einer anderen aktiven Einreichung, hängender Review-Zustand.

### Affected Files
| File | Change | Description |
|------|--------|-------------|
| scripts/asc_store_submit.py | MODIFY | `send_once`: bei HTTP 4xx zusätzlich die Gründe aus `meta.associatedErrors` ausgeben (eigener, defensiver Leser, `error_codes` aus asc_what_to_test.py bleibt unverändert) |
| scripts/test_asc_store_submit.py | MODIFY | Tests: Form Objekt und Form Liste, fehlender/kaputter Block, Kennungen im Pfad werden maskiert, Obergrenze, kein Title/Detail-Wortlaut (AC-10), weiterhin genau ein Schreibaufruf |
| docs/artifacts/feat-893-c-gruende/ | CREATE | Beleg des echten Laufs (Rohform der Antwort als Strukturschema ohne Kennungen) |

### Scope Assessment
- Files: 2 Code/Test + 1 Beleg
- Estimated LoC: +45/-2 Code, +70 Tests
- Risk Level: LOW (nur Ausgabe im Fehlerzweig, kein neuer Schreibaufruf)

### Technical Approach (Empfehlung)
Der Leser nimmt `errors[].meta.associatedErrors` tolerant: Objekt (Schlüssel = Pfad, Wert = Liste) oder Liste; je Eintrag `code` (Whitelist `[A-Z0-9_.]+`) und Pfad aus Schlüssel oder `source.pointer`, dort jede Kennung (UUID, Zahlen) durch `<id>` ersetzt, nur `[A-Za-z/_.<>-]`, höchstens 8 Einträge, jede Störung ergibt nichts. Ausgabe: `… (codes: …; gründe: <pfad>=<code>, …)`. Zusätzlich gibt der Leser bei unbekannter Form nur die Schlüsselnamen der obersten Ebene von `meta` aus (Whitelist), damit der nächste Lauf die Form sichtbar macht, selbst wenn der Parser danebenliegt. Danach ein Lauf mit der wiederverwendeten leeren Einreichung (AC-5), nur nach Hennings Wort; er kostet genau einen Schreibaufruf.

### Alternative
Vorab per GET prüfen (Altersfreigabe-Erklärung, App-Informationen, Datenschutz-Angaben, Fremd-Einreichung) und in `pruefen` aufnehmen. Vorteil: kein Schreibaufruf nötig. Nachteil: Es rät die Ursachen aus Fallberichten, Apple bietet keinen Endpunkt „darf eingereicht werden“, und jede neue Pflichtangabe von Apple läge außerhalb der Liste. Dafür kippt keine ADR. Empfehlung bleibt die Ausgabe der Gründe, weil sie die tatsächliche Ursache liefert; die GET-Prüfung wird nur dann ein Folgeticket, wenn die Gründe eine prüfbare Angabe nennen.

### Regeln vor Modell
Kein Modell beteiligt; reine Regel- und Regex-Lösung.

### Dependencies
Upstream: ASC-Fehlerformat (ungeklärt, s. o.). Downstream: Ausgabe im Workflow-Log, Beleg unter docs/artifacts. Neuer Zweig von main nötig (der aktuelle Zweig ist gemergt).

### Open Questions
- [ ] Echte Form von `associatedErrors` — klärt erst der nächste Lauf; der Parser deckt beide plausiblen Formen ab und zeigt sonst die Schlüsselnamen.
