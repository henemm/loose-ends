# Context: feat-837-s2-schreibweg

## Request Summary
Schnitt 2 von #837: ein Schreibweg im Repo, der den App-Store-Untertitel in App Store Connect (ASC) setzt — de-DE „Einfach sagen. Kopf frei.“
(25 Zeichen, ersetzt „Gesagt. Sortiert.“) und en-US „Say it. Clear your head.“ (24 Zeichen, App-Info-Lokalisierung neu, Name „Loose Ends“).
Wortlaut freigegeben (Henning, 2026-11-04). Beleg ist der Wert, den ASC zurückmeldet. Schnitt 1 (Probe liest Zustand, Felder, Untertitel) ist
gemergt (PR #840); Schnitt 3 (Claim in `CLAUDE.md`/`README.md`) folgt danach.

## Stand vor dem Bau (Store-Probe, Lauf 41985831338, 2026-11-05 07:14Z)
- App-Info 1: `READY_FOR_DISTRIBUTION` / `READY_FOR_SALE`, de-DE „Gesagt. Sortiert.“
- App-Info 2: `IN_REVIEW` / `IN_REVIEW`, de-DE „Gesagt. Sortiert.“
- **Keine App-Info auf `PREPARE_FOR_SUBMISSION`.** Versionen: iOS 1.0 `READY_FOR_SALE`, iOS 1.0.1 `PREPARE_FOR_SUBMISSION`, Mac 1.0 `IN_REVIEW`.
- In der ASC-Weboberfläche sind die App-Informationen für iOS und Mac gemeinsam und gesperrt, solange macOS 1.0 in Prüfung ist.
  Henning hat am 2026-11-05 entschieden: warten, Mac-Prüfung nicht zurückziehen.
- Folge: Der Schreibweg lässt sich bauen und testen, **in ASC schreiben kann er erst, wenn eine App-Info editierbar ist**. Bis dahin muss
  `setzen` mit klarer Meldung abbrechen und nichts anrichten.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_store_probe.py` | `report_subtitles`: liest je App-Info Zustände und je Sprache Name + Untertitel (nur GET); Abfragemuster für `appInfos` und `appInfoLocalizations` |
| `scripts/asc_review_notes.py` + `scripts/test_asc_review_notes.py` + `.github/workflows/asc-review-notes.yml` | Vorlage „lesen / setzen“: Wunschtext aus Repo-Datei, Grenze vorab, Schreiben nur bei Abweichung, 403/409 → klare Meldung, Gegenprobe, Ausgabe `zusammenfassung geschrieben=N` |
| `scripts/asc_what_to_test.py` | Bausteine `send_json` (POST/PATCH), `get_data`, `ATTEMPTS`; `split_sections` liest `de:`/`en:`-Abschnitte |
| `scripts/asc_wait_build.py` | `read_config`, `find_app_id`, `get_json`, `Fatal` |
| `scripts/asc_beta_probe.py` | `Probe`, `records`, `attributes` |
| `scripts/asc_locales.py` | `ASC_LOCALES` = {de: de-DE, en: en-US}, `asc_locales()` aus `LanguagePacks.shipped` |
| `docs/reference/beta-beschreibung.md` | Muster einer Repo-Datei mit je einem Abschnitt `## de-DE` / `## en-US` |
| `docs/reference/app-review-notizen.md` | Muster „Text im Repo, Skript setzt ihn“ |
| `docs/context/feat-837-store-untertitel.md` | Kontext und Analyse von Schnitt 1 inkl. Recherche und Schnitt-Plan |
| `docs/specs/feat-837-schnitt-1-app-info-befund.md` | Spec Schnitt 1 |

## Existing Patterns
- ASC-Schreibwege laufen nur als CI-Handlauf (`workflow_dispatch`, `aktion=lesen|…`), nie lokal (Wächter sperrt die Zugangsdaten).
- Erst prüfen, dann schreiben: Grenze (hier 30 Zeichen je Untertitel/Name) vor der ersten Anfrage; Schreiben nur bei Abweichung; danach Gegenprobe.
- Die Workflows führen die Skript-Tests vor dem Schreiben aus (`python3 scripts/test_….py`).
- Ausgabe nur Zustände; Untertitel und Name sind öffentlich und dürfen in der Ausgabe stehen.

## Recherche (aus Schnitt 1, Quellen)
- `POST /v1/appInfoLocalizations` legt eine Sprache an (`type appInfoLocalizations`, `attributes.locale|name|subtitle`, `relationships.appInfo`).
  https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appinfolocalizations
- `PATCH /v1/appInfoLocalizations/{id}` ändert sie, nur in editierbarem Zustand. https://developer.apple.com/forums/thread/747116
- Apple: App-Info und App-Store-Version müssen dieselben Lokalisierungen haben, sonst scheitert die Einreichung.

## Dependencies
- Upstream: ASC-API (`appInfos`, `appInfoLocalizations`, für en-US ggf. `appStoreVersionLocalizations`), CI-Geheimnisse, Ende der Mac-Prüfung (Apple).
- Downstream: Store-Auftritt de-DE und neu en-US; Einreichung von iOS 1.0.1; Schnitt 3 (`CLAUDE.md`, `README.md`).

## Existing Specs
- `docs/specs/feat-837-schnitt-1-app-info-befund.md` (Schnitt 1, abgeschlossen).

## Risks & Considerations
- **Gesperrt bis Ende der Mac-Prüfung.** Der Abnahmebeleg (Wert aus ASC) ist erst danach möglich; bis dahin endet der Workflow vor `phase8_complete` oder wird
  nach dem Bau angehalten. Der Bau „auf Verdacht“ wurde nach Schnitt 1 ausdrücklich zurückgestellt; zu klären in `/20-analyse`, ob jetzt gebaut oder gewartet wird.
- **en-US zieht Pflichtangaben nach sich** (Befund 2026-11-05, Weboberfläche): en-US ist „Nicht lokalisiert“. Eine neue en-US-App-Info verlangt bei der nächsten
  Einreichung auch eine en-US-Versions-Lokalisierung: Beschreibung, englische Schlüsselwörter (die deutschen 100/100 sind nicht übertragbar), Support-URL,
  Bilder. Im Repo liegen dafür keine Texte. Das ist Produktinhalt (Henning) und vermutlich ein eigenes Ticket; ohne es blockiert en-US die Einreichung 1.0.1.
- Welche App-Info nach der Sperre die editierbare ist: Auswahl über `state == PREPARE_FOR_SUBMISSION`, nie „die erste“; mehrere oder keine → Abbruch.
- PATCH-Body für `appInfoLocalizations` ist nicht an einem verifizierten Beispiel belegt; vor dem Bau gegen Apples `AppInfoLocalizationUpdateRequest` prüfen.
- Scoping: Textdatei, Skript, Test, Workflow = 4 Dateien; Test ≈ 1,5–2,5 × Code → Schätzung vor dem Bau gegen 250 LoC halten.
- Keine Gerätestufe: Kein Pfad der Geräteliste berührt.

## Analysis

### Type
Feature (Schreibweg für Store-Metadaten, CI-Handlauf)

### Stand bei der Analyse (Store-Probe, Lauf 41986073901, 2026-11-05 07:16Z)
- Unverändert: App-Info 1 `READY_FOR_DISTRIBUTION`, App-Info 2 `IN_REVIEW`, beide de-DE „Gesagt. Sortiert.“, keine `PREPARE_FOR_SUBMISSION`.
- **Versions-Lokalisierungen: iOS 1.0.1 und Mac 1.0 haben nur de-DE.** Es gibt keine en-US-Store-Seite (Beschreibung, Schlüsselwörter, Bilder).

### Recherche (2026-11-05)
- Apple: Haben Version und App-Info nicht dieselben Lokalisierungen, scheitert die Einreichung der Version.
  https://developer.apple.com/documentation/appstoreconnectapi/app-info-localizations
- App-Info-Lokalisierung trägt Name, Untertitel, Datenschutz-URL; Versions-Lokalisierung Beschreibung, Schlüsselwörter, Neuigkeiten.
  Sprachen nur in editierbarem Zustand änderbar. https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/
- PATCH `/v1/appInfoLocalizations/{id}`: JSON:API-Umschlag `{"data": {"type": "appInfoLocalizations", "id", "attributes": {"subtitle"}}}`, nur die
  gesendeten Felder ändern sich (Gemeinschafts-Implementierungen; Apples POST-Beispiel nutzt denselben Umschlag). Belegt erst der echte Lauf.
  https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appinfolocalizations

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/app-store-untertitel.md` | CREATE | Wunschtext je Sprache (`## de-DE`, ggf. `## en-US`), Muster `beta-beschreibung.md` |
| `scripts/asc_app_info.py` | CREATE | `lesen` / `untertitel`: editierbare App-Info genau eine mit `state == PREPARE_FOR_SUBMISSION`, sonst Abbruch „App-Informationen gesperrt (Zustände …)“, nichts geschrieben; 30-Zeichen-Grenze vor der ersten Anfrage; PATCH nur bei Abweichung, 403/409 → klare Meldung; Gegenprobe; `zusammenfassung geschrieben=N` |
| `scripts/test_asc_app_info.py` | CREATE | Nachbau-Server wie `test_asc_review_notes.py`: gesperrt → 0 Schreibaufrufe; gleich → 0; abweichend → 1 PATCH mit nur `subtitle`; zu lang → Abbruch vor jeder Anfrage; Gegenprobe-Abweichung → Fehler |
| `.github/workflows/asc-app-info.yml` | CREATE | Handlauf `aktion=lesen|untertitel`, Tests vor dem Schreiben, Schlüssel wie `asc-review-notes.yml` |

### Scope Assessment
- Files: 4
- Estimated LoC (Vorlage `asc_review_notes`: Code 152, Test 323, Workflow 37):
  - nur de-DE: Code ≈ 90, Test ≈ 170, Workflow ≈ 37, Text ≈ 15 → **≈ 310**
  - mit en-US (zusätzlich POST anlegen + Tests): **≈ 370**
- Beides über 250 → Vorschlag Teilung: **S2a** Skript + Tests (≈ 250, ganz im Nachbau beweisbar, jetzt baubar), **S2b** Textdatei + Workflow + echter Lauf
  (≈ 60, Beleg = Wert aus ASC, erst nach Ende der Mac-Prüfung).
- Risk Level: LOW (nur Store-Metadaten, kein App-Code; Schreiben nur bei genau einer editierbaren App-Info)

### Technical Approach
Bauen jetzt (technische Entscheidung): Der Weg bricht bei gesperrter App-Info ab und richtet nichts an, also kostet der Vorbau nichts, und am Tag der Freigabe
ist nur noch der Lauf nötig. Bausteine wiederverwenden (`read_config`, `find_app_id`, `get_json`, `Fatal`, `get_data`, `send_json`, `ATTEMPTS`, `records`,
`attributes`); kein neuer Code für Abfragen. Untertitel und Name sind öffentlich und dürfen in der Ausgabe stehen.

**Alternative:** Kein Skript, Henning trägt den Untertitel einmal in der Weboberfläche ein (zwei Felder). Kippt das Muster „Store-Text im Repo, Skript setzt ihn“
(#788, #760). Dagegen: Henning soll keine Einstellungen eintragen (Memory „Einstellungen: ich übernehme“), und der Text wäre nicht im Repo nachvollziehbar.

### Dependencies
- Ende der Mac-Prüfung (Apple) für den echten Lauf und den Abnahmebeleg.
- en-US hängt an einer englischen Store-Seite für die Version (Beschreibung, Schlüsselwörter, Support-URL, Bilder), die es nicht gibt.

### Entscheidungen (Henning, 2026-11-05, per Auswahl)
- **Deutsch und Englisch jetzt.** Der Weg setzt de-DE per PATCH und legt en-US per POST an (Name „Loose Ends“, Untertitel „Say it. Clear your head.“).
  Folge: vor der Einreichung von iOS 1.0.1 braucht es eine englische Store-Seite → **#842** (M3, P1, M), nicht Teil dieses Schnitts.
- **Ein Schritt, keine Teilung.** Ausnahme von der 250-LoC-Grenze vom PO freigegeben; Schätzung ≈ 370 LoC (Code ≈ 110, Test ≈ 210, Workflow ≈ 37, Text ≈ 15).
- Bauen jetzt; die Abnahme mit dem Wert aus ASC folgt nach Ende der Mac-Prüfung (gesperrt → Abbruch, nichts geschrieben).

### Open Questions
- keine
