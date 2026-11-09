# Context: #842 Schnitt 5a-2 — Texte der Versionen 1.0.1 (iOS und Mac)

## Request Summary
Nach Schnitt 5a-1 (Mac 1.0.1 angelegt, Bau 133 zugeordnet) fehlen in den noch nicht eingereichten Versionen 1.0.1
die Texte, die Apple beim Anlegen nicht übernommen hat. 5a-2 schreibt sie per Handlauf, ohne einzureichen.

## Befund (Lauf `lesen` 2026-11-09 10:52Z, `docs/artifacts/feat-842-s5-mac-version/run-42604409575-lesen2.log`)
| Version | Sprache | Beschreibung | Schlüsselwörter | Support-URL | Werbetext | whatsNew | Bilder |
|---|---|---|---|---|---|---|---|
| iOS 1.0.1 | de-DE | 1638 | 100 | 50 | **0** | **0** | 12 |
| iOS 1.0.1 | en-US | 1493 | 94 | 50 | 125 | **0** | 12 |
| Mac 1.0.1 | de-DE | 1638 | 100 | 50 | **0** | **0** | 4 |
| Mac 1.0.1 | en-US | **fehlt ganz** | | | | | |

Review-Detail ist bei beiden Versionen vorhanden. Zustand beider Versionen: `PREPARE_FOR_SUBMISSION`, Bau 133 `VALID`.

## Lücken (das ist der Umfang von 5a-2)
1. Mac en-US existiert nicht → Beschreibung, Schlüsselwörter, Support-URL, Werbetext (Wortlaut steht fertig in `docs/reference/app-store-texte.md`, Abschnitt `## en-US`; `asc_version_texts.py texte` schreibt schon beide Plattformen und legt eine fehlende Locale per POST an).
2. Deutscher Werbetext fehlt auf iOS **und** Mac (nur 1.0 hat ihn; die Datei hat keinen `## de-DE`-Abschnitt, „der deutsche Wortlaut liegt nur bei Apple“).
3. `whatsNew` („Neu in dieser Version“) fehlt überall; Apple verlangt ihn für ein Update. `asc_version_texts.py` kennt das Feld nicht (`LINE_FIELDS`, `LABELS`, Grenzprüfung 4000 Zeichen).
4. Mac-Bilder en-US (5b) und Einreichen sind ausdrücklich nicht Teil von 5a-2.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_version_texts.py` (219 Z.) | Schreibweg: `parse_sections`, `check_section`, `write_locale`, `write_texts`, `verify`; muss `whatsNew` und einen `## de-DE`-Abschnitt lernen |
| `scripts/test_asc_version_texts.py` | bestehende Tests, erweitern (TDD) |
| `docs/reference/app-store-texte.md` | Quelle der Wortlaute; nur `## en-US` vorhanden |
| `.github/workflows/asc-version-texts.yml` | Handlauf `lesen`/`texte`, reicht nichts ein |
| `scripts/asc_store_version.py` | `lesen` belegt den Zustand danach (Zeichenzahlen je Feld) |
| `scripts/asc_review_notes.py` | Review-Detail nur Version 1.0; für 1.0.1 nicht nötig, Detail ist vorhanden |

## Existing Patterns
- Handlauf-Muster (#742/#837/#842): Wortlaut im Repo, Skript schreibt nur bei Abweichung, Gegenprobe im selben Lauf, nie einreichen, Store-Texte dürfen im Log stehen.
- Grenzen: Beschreibung 4000, Werbetext 170 Zeichen, Schlüsselwörter 100 Bytes ohne Leerzeichen nach Komma.
- Wortlaut-Freigabe liegt bei Henning (Produkttext); Texte sind öffentlich, sobald eingereicht.

## Dependencies
- Upstream: `asc_wait_build` (Config, `find_app_id`), `asc_what_to_test` (`get_data`, `send_json`), `asc_beta_probe` (`records`, `attributes`).
- Downstream: Einreichung von iOS und Mac 1.0.1 (nur auf Hennings Wort), Schnitt 5b (Mac-Bilder en).

## Offene Fragen für /20-analyse
- Deutscher Werbetext: Wortlaut von Version 1.0 (READY_FOR_SALE) per `lesen` holen und unverändert übernehmen, oder neu formulieren? (Vorgabe aus S5: „Text von 1.0“.) Muss zuerst gelesen werden, die Datei hat ihn nicht.
- `whatsNew`: Wortlaut de und en, ein Text für beide Plattformen? Henning gibt den Wortlaut frei.
- Soll der deutsche Wortlaut ins Repo (neuer `## de-DE`-Abschnitt; dann überschreibt `texte` auch Beschreibung/Schlüsselwörter bei Abweichung) oder bleibt de-DE bei Apple und nur Werbetext/whatsNew kommen aus einer eigenen Quelle? Alternative: Felder je Locale optional machen.
- Mac-spezifischer en-Text: Die Beschreibung nennt „Reminder on arriving at a place (iPhone, iPad)“ — passt für den Mac, kein Mac-eigener Text nötig.

## Risks & Considerations
- Der Schreibweg gilt für beide Plattformen zugleich; ein de-DE-Abschnitt in der Datei würde die heute bei Apple stehende Beschreibung (1638 Z.) überschreiben, wenn sie abweicht.
- `REQUIRED` verlangt Beschreibung, Schlüsselwörter, Support-URL je Abschnitt; ein Abschnitt nur mit Werbetext/whatsNew bräuchte gelockerte Pflichtfelder.
- Lauf schreibt nichts, wenn keine bearbeitbare Version existiert (Mac 1.0.1 existiert seit 5a-1).
- Umfang: Skript + Tests + Textdatei + evtl. Workflow ≈ 4 Dateien, Limit ±250 LoC im Blick behalten.
- Geräteliste: kein Pfad der Geräteliste berührt (Betriebsskript, kein Produktcode).

## Existing Specs
- `docs/specs/feat-842-schnitt-3-texte-schreiben.md` — Schreibweg für Texte
- `docs/specs/feat-842-schnitt-5a-1-mac-version-anlegen.md` — Grundlage, Known Limitations nennen 5a-2

## Analysis

### Type
Feature (Betriebsskript, kein Produktcode)

### Befund aus der Analyse
- Der deutsche Werbetext von 1.0 steht nirgends im Repo; `asc_version_texts.py lesen` zeigt nur die bearbeitbare Version, 1.0 (READY_FOR_SALE) ist unsichtbar. Er muss zuerst gelesen werden, sonst wäre „Text von 1.0 übernehmen“ geraten.
- `parse_sections`/`check_section` verlangen je Abschnitt Beschreibung, Schlüsselwörter, Support-URL; ein `## de-DE` nur mit Werbetext und whatsNew scheitert heute. Ein vollständiger de-DE-Abschnitt würde dagegen die bei Apple stehende deutsche Beschreibung überschreiben (kein Wortlaut im Repo).
- `whatsNew` fehlt in `LINE_FIELDS`, `LABELS` und der Grenzprüfung (4000 Zeichen); Mac-Locale en-US wird von `write_locale` schon per POST angelegt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_version_texts.py | MODIFY | Feld `whatsNew` (Zeile `Neu in dieser Version:` oder Markerblock), Pflichtfelder nur für neue Locale bzw. wenn Abschnitt `Beschreibung` führt; `lesen` zeigt zusätzlich die zuletzt veröffentlichte Version (nur lesen) |
| scripts/test_asc_version_texts.py | MODIFY | Tests: whatsNew-Grenze, Abschnitt ohne Pflichtfelder bei vorhandener Locale, Locale-Neuanlage verlangt Pflichtfelder, Lesen der veröffentlichten Version |
| docs/reference/app-store-texte.md | MODIFY | `## de-DE` mit Werbetext + Neu-Text, `Neu` auch in `## en-US` |
| docs/artifacts/feat-842-s5a2-texte/ | CREATE | Läufe `lesen`, `texte`, Gegenprobe |

### Scope Assessment
- Files: 3 Code/Text + Belege; ≈ +90/−10 LoC; Risiko NIEDRIG (schreibt nur in nicht eingereichte Versionen, nur bei Abweichung, Gegenprobe im selben Lauf, reicht nie ein).

### Technical Approach (Regelweg, kein Modell)
1. `lesen` erweitern: Werbetext der veröffentlichten Version 1.0 drucken (nur GET).
2. Lauf `lesen` → deutscher Werbetext liegt vor, kommt unverändert als `## de-DE` ins Repo.
3. Abschnitt-Pflichtfelder lockern: nur wenn die Locale bei Apple fehlt (Mac en-US) oder der Abschnitt Beschreibung enthält; ein de-DE-Abschnitt ohne Beschreibung ändert nur Werbetext und whatsNew.
4. `whatsNew` je Sprache ein Text für iOS und Mac; Entwurf in der Spec, Henning gibt frei.
5. Lauf `texte`, danach `lesen` als Beleg (Zeichenzahlen je Feld), Mac en-US vorhanden.

### Alternative
- A: de-DE vollständig ins Repo (Beschreibung, Schlüsselwörter, Support-URL aus Apple lesen): ein Wahrheitsort, aber Überschreibrisiko und 1600 Zeichen Kopie; kippt keine ADR, verwirft aber die Zeile „Der deutsche Wortlaut liegt nur bei Apple“.
- B: Henning trägt Werbetext/whatsNew in App Store Connect von Hand ein: ausgeschlossen (nie Handarbeit für ihn).
Empfehlung: Weg oben (gelockerte Pflichtfelder), weil er nichts überschreibt, was nur bei Apple liegt.

### Dependencies
`asc_wait_build`, `asc_what_to_test`, `asc_beta_probe`; Workflow `asc-version-texts.yml` unverändert (Aktionen `lesen`/`texte`).

### Open Questions
- [ ] Wortlaut „Neu in dieser Version“ de/en: Entwurf in `/30-write-spec`, Freigabe durch Henning (Produkttext, öffentlich).
- [ ] Deutscher Werbetext: Wortlaut aus 1.0 nach erstem Lauf `lesen`; weicht er von „nicht mehr versprechen als die App hält“ ab, entscheidet Henning.
- Geräteliste: Kein Pfad der Geräteliste berührt.
