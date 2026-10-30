# Context: feature-705-oeffentlicher-link (#705 Schnitt 2b-2c)

## Request Summary
Den öffentlichen TestFlight-Link der externen Gruppe `Tester` per Handlauf in `asc-beta.yml` einschalten (Limit 50) und
die Prüfliste auf den echten Stand bringen. Das Einschalten im echten Lauf geschieht nur auf Hennings ausdrückliches Wort;
dieser Schnitt liefert Code, Tests und Doku.

## Stand vor diesem Schnitt (gemessen 2026-10-30, Lauf 41019692346, nur lesend)
- Build 125, iOS und macOS: `extern=BETA_APPROVED`, Einreichung `APPROVED` (Doku führt noch „wartet auf Apple“).
- Gruppe `Tester`: extern, `link=aus`, `feedback=an`. Gruppe `Familie`: intern, `link=aus`.
- Beschreibung, Feedback-Mail, Kontaktangaben, Datenschutz-URL (de-DE): gesetzt.
- Bilder/Screenshots: für TestFlight nicht verlangt (die Beta-Prüfung lief ohne); gehören zur App-Store-Veröffentlichung.

## Recherche (Apple-Schnittstelle)
- Apple: `PATCH /v1/betaGroups/{id}` = „Modify a beta group … including changing its TestFlight public link status“
  ([Doku](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-betagroups-_id_)). Der Endpunkt existiert.
- Attribute am Gruppen-Objekt laut Apples Beispielantwort und Fastlane: `publicLinkEnabled`, `publicLinkLimitEnabled`,
  `publicLinkLimit`, `publicLink`, `publicLinkId`. Fastlane setzt beim Anlegen `publicLinkEnabled`, `publicLinkLimit`,
  `publicLinkLimitEnabled`; Standardlimit dort 10 000.
- **Nicht belegt:** Apples Attributseite des Update-Rumpfs war nicht abrufbar (404). Unbekannt: ob `publicLinkLimit` zusammen
  mit `publicLinkLimitEnabled` in einem PATCH gesendet werden muss, ob das Limit bei ausgeschaltetem Link änderbar ist, ob der
  Schlüssel-Rolle reicht. Das klärt der erste echte Lauf; bis dahin sind das Annahmen. Rückfall: Oberfläche von App Store Connect.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_beta_invite.py` | Muster plan/apply, `message()`-Maskierung, `Masked`-stdout, `FORBIDDEN`. Kopf sagt „nie öffentlicher Link, nie DELETE oder PATCH“ — diese Zusage soll für `zuordnen`/`einreichen` bestehen bleiben |
| `scripts/test_asc_beta_invite.py` | `test_never_submits_and_never_enables_link`, `WorkflowTests` verbieten `publicLinkEnabled` im Workflow und prüfen `needs: [setup, assign, submit]`, genau ein `--einreichen`; müssen angepasst werden |
| `scripts/asc_beta_probe.py` | `report_groups` druckt `url=` des Links **unmaskiert** (Z. 103–106); Beleg nach dem Einschalten |
| `.github/workflows/asc-beta.yml` | Aktionen probe/einrichten/zuordnen/einreichen; Probe hängt per `needs` an allen Jobs; neue Aktion + Job nötig |
| `scripts/asc_wait_build.py`, `scripts/asc_what_to_test.py` | geteilte Helfer: `read_config`, `find_app_id`, `get_data`, `send_json` (PATCH möglich? zu prüfen), `Fatal` |
| `docs/reference/testflight.md` | Prüfliste (Zeile „Öffentlicher Link | offen“, „Beta-Review“ steht auf „wartet auf Apple“), Abschnitt Schnitt 2 |
| `CLAUDE.md` | nennt die Handläufe von `asc-beta.yml`; neue Aktion ergänzen |

## Existing Patterns
- Handläufe lesen zuerst, schreiben nur Abweichungen (idempotent), Ausgabe nur Zustandswörter, zweiter Lauf `geschrieben=0`.
- `FakeASC` im Test hält Zustand (GET liest, Schreiben ändert, Anfragen werden gemerkt).
- Rücknehmbares und Nicht-Rücknehmbares sind je eine eigene Aktion; die gefährliche läuft nur nach Hennings Wort.

## Dependencies
- Upstream: App Store Connect API (Schlüssel `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_PRIVATE_KEY`), Gruppe `Tester` aus 2b-1.
- Downstream: Probe-Ausgabe; `docs/reference/testflight.md`; spätere Einladung (#176 zuletzt).

## Risks & Considerations
- **Der Repo ist öffentlich, Actions-Logs auch:** Die Probe druckt `url=<Link>`. Nach dem Einschalten stünde der Einladungslink für jeden lesbar im Log. Die Ausgabe muss vor dem Einschalten maskiert sein (`url=gesetzt`), und die Aktion selbst gibt nie den Link aus. Henning holt den Link in App Store Connect.
- Schalter wirkt nach außen (bis 50 Fremde). Rücknehmbar (PATCH auf `false`), aber nicht geheim zu machen, sobald verteilt. Nur auf Hennings Wort.
- Limit-Semantik unbekannt (siehe Recherche): ein Lauf, der das Limit nicht setzen kann, darf den Link **nicht** ohne Limit einschalten. Reihenfolge: Limit zuerst oder beides in einem PATCH, danach Gegenlesen; stimmt das Limit nicht, den Link wieder ausschalten und mit Fehler enden.
- Der Link ist an Build-Zuordnung gebunden: Tester sehen nur Builds der Gruppe (nur 125; #724 offen, neue Builds nicht automatisch).
- Neuer Build = neue Beta-Prüfung bei Apple; der Link gilt für freigegebene Builds, spätere Builds müssen erneut `APPROVED` sein.
- Scoping: Neue Datei `scripts/asc_beta_link.py` statt `asc_beta_invite.py` zu erweitern hält dessen Zusage „nie Link, nie PATCH“ und seine Tests unberührt; geschätzt 4–5 Dateien, unter 250 Zeilen.

## Analysis

### Type
Feature (Handlauf gegen Apples Schnittstelle; keine App-Änderung, nichts Sichtbares in der App — kein Entwurf nötig).

### Without the model
Entfällt: reine Schnittstellenarbeit, kein Feld, das ein Modell bräuchte.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_beta_link.py` | CREATE | liest Gruppe `Tester` und beide Plattform-Builds; Link nur bei `BETA_APPROVED`; ein PATCH mit `publicLinkEnabled=true`, `publicLinkLimitEnabled=true`, `publicLinkLimit=50`; Gegenlesen; stimmt das Limit nicht, Link wieder aus und Exit 1. `--aus` schaltet ihn wieder ab. Ausgabe nur Zustandswörter, nie der Link |
| `scripts/test_asc_beta_link.py` | CREATE | `FakeASC`-Muster: Idempotenz (zweiter Lauf schreibt nichts), kein Einschalten bei nicht freigegebenem Build, Limit-Abweichung schaltet zurück, 403/422 als Klartext, Ausgabe ohne URL/IDs, Workflow-Datei (neue Aktion, nur `workflow_dispatch`) |
| `.github/workflows/asc-beta.yml` | MODIFY | Aktionen `link` und `link-aus`, ein Job, ruft nur das neue Skript; Probe-Abhängigkeiten bleiben (Beleg = eigener Probe-Lauf danach) |
| `docs/reference/testflight.md` | MODIFY | Zeile „Beta-Review“ auf `APPROVED` (Beleg Lauf 41019692346), Zeile „Öffentlicher Link“, Abschnitt Handlauf `link` |

Unverändert: `scripts/asc_beta_invite.py` und sein Test (Zusage „nie Link, nie PATCH“ bleibt für `zuordnen`/`einreichen`).

### Scope Assessment
- Files: 4 (+ 2 in Teil 1, siehe unten)
- Estimated LoC: +245 / -2 (Skript ~85, Test ~140, Workflow ~12, Doku ~12)
- Risk Level: MEDIUM — Skript und Workflow sind Konfiguration/Infrastruktur (Adversary-Risiko: hoch, mindestens 2 Runden). Der Code schaltet nichts ein, solange niemand die Aktion startet.

### Aufteilung (Scoping-Limit 4–5 Dateien, ±250 Zeilen)
Die Maskierung der Probe gehört nicht in diesen Schnitt, sonst sind es 6 Dateien. Sie ist eine **Vorbedingung des echten Einschaltens**, nicht des Codes:
- **Teil 1 (eigenes Ticket, vorher):** `asc_beta_probe.py` druckt `url=` des Links unmaskiert. Der Repo ist öffentlich, also auch die Logs. Nach dem Einschalten stünde der Einladungslink für jeden lesbar im Log. Fix: `url=gesetzt|-`; 2 Dateien (Probe + Test), ~12 Zeilen.
- **Teil 2 (dieser Workflow):** Skript, Test, Workflow, Doku.
- Reihenfolge am Ende: Teil 1 gemergt → Teil 2 gemergt → **Hennings Wort** → Lauf `link` → Probe → Hennings Gerätedurchgang bleibt davon unabhängig.

### Technical Approach
Regel statt Modell, ein Skript im Muster von 2b-2b: erst lesen (`GET /v1/apps/{app}/betaGroups`, `GET /v1/betaGroups/{id}/relationships/builds`, `buildBetaDetail` je Plattform), dann höchstens ein `PATCH /v1/betaGroups/{id}`. Beides (Link + Limit 50) in **einem** PATCH, danach Gegenlesen von `publicLinkEnabled` und `publicLinkLimit`. Weicht das Limit ab oder fehlt `publicLinkLimitEnabled`, wird der Link in einem zweiten PATCH sofort wieder abgeschaltet und der Lauf endet mit Fehler (ein Link ohne Limit geht nie nach außen). Voraussetzung für das Einschalten: die zugeordneten Builds beider Plattformen stehen auf `BETA_APPROVED`, sonst `nicht-bereit`.

### Alternativen
- **Von Hand in App Store Connect** (Gruppe Tester → Öffentlichen Link aktivieren, Limit 50): zwei Minuten, kein Code, kein Log-Thema. Nachteil: nicht belegt, nicht wiederholbar, nicht rücknehmbar per Beleg. Das ist der **Rückfall**, falls Apple das Limit per Schlüssel nicht setzen lässt. Kippt keine ADR.
- **Link gar nicht nutzen, Tester einzeln per E-Mail einladen:** kein Fremdlink, Apple prüft jeden Einzelnen nicht anders. Bei einer Handvoll Tester ist das die zurückhaltendere Wahl; verworfen, weil das Ticket (#705 DoD) den Einladungslink verlangt. Entscheidung dazu liegt bei Henning und wird im Spec-Schritt nicht neu aufgemacht.

### Dependencies
- Upstream: Gruppe `Tester` + Zuordnung Build 125 (2b-1, Läufe 40534641955/40535068594); Apples Freigabe (gemessen).
- Downstream: Probe-Ausgabe (`link=an`), Teil 1 muss vorher maskieren.

### Open Questions
- [ ] Nimmt Apple `publicLinkLimit` zusammen mit `publicLinkLimitEnabled` in einem PATCH und mit dieser Schlüsselrolle an? Nur der echte Lauf zeigt es; der Code fängt Abweichung ab (Rückschalten).
- [ ] Einladungslink für Henning: Er holt ihn in App Store Connect (Gruppe Tester). Kein Rückkanal im Log.
