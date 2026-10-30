---
entity_id: feat-763-schnitt-13-datenschutz-en
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-763-schnitt-13-datenschutz-en
---

# Spec: #763 Schnitt 13 — Englische Datenschutzseite und Datenschutz-URL je Sprachfassung

Epic #750. Unabhängig; `asc_beta_setup.py` auch in #760. Modell: Haiku. Zwei Repos.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750. Übersetzung vorab freigegeben: wortgetreu zum
  deutschen Text in `docs/reference/datenschutz-entwurf.md`, keine Zusätze, keine Kürzungen; Merge im Website-Repo durch den Agenten.

## Purpose

Deutsche Seite existiert (`henemm/henemm-website`, `content/legal/loose-ends/`, PR #75 dort). App Store Connect führt
die Datenschutz-URL je Sprachfassung; `asc_beta_setup.py` setzt sie nur für `de-DE`. Die App verlinkt die Seite nicht
(kein Treffer in Swift, 2026-10-30).

Ohne Modell geht es nicht: nicht relevant.

## Source

- `scripts/asc_beta_setup.py` Z. 38–40 (`ASC_PRIVACY_POLICY_URL` → `privacyPolicyUrl`), `plan_localization` (Z. 61).
- `scripts/test_asc_beta_setup.py` Z. 125, 179, 208 (`PRIVACY_URL`).
- CLAUDE.md Z. 108–110; `docs/reference/testflight.md` Z. 167.
- Website-Repo: in der Cloud per `add_repo henemm/henemm-website` anhängen (Push erlaubt, geprüft 2026-10-30).

## Scope

| Repo / File | Change Type | Description |
|------|-------------|-------------|
| henemm-website `content/legal/loose-ends/…` | NEW | englische Seite nach der Sprachkonvention der Site |
| docs/reference/datenschutz-entwurf.md | MODIFY | Abschnitt `## English` mit Text, URL, Freigabevermerk |
| scripts/asc_beta_setup.py | MODIFY | `PRIVACY_URLS = {"de-DE": env ASC_PRIVACY_POLICY_URL, "en-US": env ASC_PRIVACY_POLICY_URL_EN or <Konstante>}`; je Locale setzen |
| scripts/test_asc_beta_setup.py | MODIFY | zwei Tests |
| CLAUDE.md, docs/reference/testflight.md | MODIFY | ein Satz je Datei |

LoC Python ≈ +25 / −5.

## Implementation Details

1. Website: Konvention lesen (Hugo-Sprachordner, `.en.md` oder `languages`-Block in der Site-Konfiguration; wie die
   übrigen `legal`-Seiten es halten). Gibt es keine englische Seite im Repo, die Konvention des Generators nehmen und im
   PR nennen. Gleiche Gliederung, gleiche Abschnittszahl, gleiches Datum und gleicher Kontakt wie die deutsche. Build grün,
   Merge, dann `curl -sI <url>` → 200 im PR.
2. Skript: leere URL = nicht anfassen (heute); `en-US` nimmt `ASC_PRIVACY_POLICY_URL_EN`, sonst die Konstante aus Schritt 1
   (damit keine Repo-Variable von Henning nötig ist); die Variable darf die Konstante überstimmen.
3. Beleg bei Apple: `asc-beta.yml` mit `aktion=einrichten` (nie `einreichen`), Probe-Log `datenschutzUrl=gesetzt` für `de-DE` und `en-US`.

## Test Plan

- [ ] `test_asc_beta_setup.py::test_privacy_url_per_locale`: GIVEN beide Variablen WHEN Plan THEN `de-DE` und `en-US` je ihre URL.
- [ ] `::test_en_falls_back_to_constant`: GIVEN nur `ASC_PRIVACY_POLICY_URL` THEN `en-US` = Konstante.
- [ ] Bestehende Tests grün.

## Acceptance Criteria

- **AC-1:** Website-PR gemerged, `curl -sI` zeigt 200 (Ausgabe im PR).
- **AC-2:** Skripttests grün in der CI.
- **AC-3:** Probe-Log mit zwei `datenschutzUrl=gesetzt`-Zeilen (Lauf-Link); scheitert der Lauf an Apple, zählt AC-2 und der Lauf wird genannt.
- **AC-4:** `datenschutz-entwurf.md` trägt den englischen Text mit Freigabevermerk.

## Definition of Done

- [ ] AC-1 bis AC-4 belegt. PR `feat: Datenschutz-URL je Sprachfassung, englische Seite (Refs #750, Closes #763)`; Merge; Board Done.
- [ ] „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-30: Spec erstellt.
