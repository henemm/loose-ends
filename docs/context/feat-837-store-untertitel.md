# Context: feat-837-store-untertitel

## Request Summary
Der App-Store-Untertitel (und der Name je Sprache) wird in App Store Connect (ASC) gesetzt: de-DE „Einfach sagen. Kopf frei.“
(25 Zeichen, ersetzt „Gesagt. Sortiert.“), en-US „Say it. Clear your head.“ (24 Zeichen, Lokalisierung der App-Info neu, Name „Loose Ends“).
Wortlaut von Henning am 2026-11-04 freigegeben (Ticket-Kommentar). Der Weg steht im Repo wie die übrigen ASC-Texte, Beleg ist der Wert,
den ASC zurückmeldet. `CLAUDE.md` und `README.md` tragen noch „Say it, it's sorted.“ und werden angepasst.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_store_probe.py` | Liest Name und Untertitel je Sprache und App-Info (Commit 374bb16, `report_subtitles`); nur GET |
| `scripts/asc_review_notes.py` + `scripts/test_asc_review_notes.py` + `.github/workflows/asc-review-notes.yml` | Vorlage für „lesen/setzen“: Wunschtext aus Repo-Datei, Schreiben nur bei Abweichung, Gegenprobe, Ausgabe ohne Werte, Tests, Handlauf-Workflow (152 + 323 + 37 Zeilen) |
| `scripts/asc_wait_build.py`, `asc_what_to_test.py`, `asc_beta_probe.py` | Gemeinsame Bausteine: `read_config`, `find_app_id`, `get_json`, `get_data`, `send_json`, `Probe`, `records`, `attributes`, `Fatal` |
| `scripts/asc_locales.py` | `ASC_LOCALES` = {de: de-DE, en: en-US}, `asc_locales()` für die Liste der auszuliefernden Sprachen |
| `docs/reference/beta-beschreibung.md` | Muster für eine Repo-Datei mit je einem Abschnitt `## de-DE` / `## en-US` |
| `docs/reference/app-review-notizen.md` | Muster für „Text im Repo, Skript setzt ihn“ |
| `CLAUDE.md` Zeile 3, `README.md` Zeile 3 | Claim „Say it, it's sorted.“ passt nicht mehr zum Untertitel |
| `docs/context/feat-772-kopfbild.md` | Vermerkt: ein deutscher Store-Text ist im Repo nicht abgelegt |

## Existing Patterns
- ASC-Schreibwege laufen nur über CI-Handläufe (`workflow_dispatch`, `aktion=lesen|…`), nie lokal (Wächter sperrt Zugangsdaten); die Zugangsdaten liegen als Repo-Geheimnisse.
- Schreiben nur bei Abweichung, danach Gegenprobe gegen ASC, Ausgabe nur Zustände. Untertitel sind öffentlich und dürfen ausgegeben werden.
- Tests laufen im Workflow vor dem Schreiben (`python3 scripts/test_….py`).

## Recherche (zuerst, laut Regel)
- Apple: `POST /v1/appInfoLocalizations` legt eine neue Sprache an (Body: `type appInfoLocalizations`, `attributes.locale|name|subtitle`,
  `relationships.appInfo`), verfügbar ab API 1.2.0. Quelle: https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appinfolocalizations.md
- Wichtig dort: Die App-Store-Version und die App-Info müssen dieselben Lokalisierungen haben, sonst schlägt die Einreichung fehl.
  → en-US muss auch an der Version 1.0.1 stehen (appStoreVersionLocalization), nicht nur an der App-Info.
- Ändern: `PATCH /v1/appInfoLocalizations/{id}` (nur in editierbarem Zustand; Forum-Fall „no resource of type appInfoLocalizations“ = falsche ID oder Sprache fehlt).
  Quelle: https://developer.apple.com/forums/thread/747116. Ein vollständiges, verifiziertes PATCH-Beispiel fand die Suche nicht; Body-Form aus der Apple-Referenz `AppInfoLocalizationUpdateRequest` prüfen.

## Befund aus der Store-Probe (Lauf 41868615757, 2026-11-04 16:34Z)
- Zwei App-Infos: eine `READY_FOR_DISTRIBUTION`, eine `IN_REVIEW`, je nur de-DE „Gesagt. Sortiert.“, en-US fehlt.
- Versionen: iOS 1.0 `READY_FOR_SALE` (live), **iOS 1.0.1 `PREPARE_FOR_SUBMISSION`** (editierbar, de-DE, Bilder da), Mac 1.0 `IN_REVIEW`.
- Offen: Welche App-Info gehört zu iOS, und gibt es dort eine editierbare (Zustand `PREPARE_FOR_SUBMISSION`)? Die Probe zeigt weder Plattform
  noch beide Zustandsfelder. Ohne editierbare App-Info lehnt Apple das Schreiben ab (403/409).

## Dependencies
- Upstream: ASC-API (`appInfos`, `appInfoLocalizations`, `appStoreVersionLocalizations`), CI-Zugangsdaten, #838 (Version 1.0.1 für neue TestFlight-Builds, offener PR).
- Downstream: Store-Auftritt (de-DE und neu en-US); Wortlaut in `CLAUDE.md` und `README.md`; die Mac-Fassung 1.0 in Prüfung teilt sich die App-Info-Ebene womöglich mit iOS.

## Existing Specs
Keine in `docs/specs/` zum Thema.

## Risks & Considerations
- Apple lehnt Änderungen an einer App-Info im Zustand IN_REVIEW oder READY_FOR_DISTRIBUTION ab; der Schreibweg muss das klar melden und nichts anrichten (wie `asc_review_notes`).
- Anlegen von en-US ändert Pflichtangaben der Version: Beschreibung, Keywords, Support-URL und Bilder von 1.0.1 für en-US fehlen dann bei der nächsten Einreichung
  (Datenschutz-URL en-US ist schon gesetzt, #763). Das gehört in die Analyse und Spec: nur App-Info, oder auch die Versions-Lokalisierung?
- Der Untertitel wirkt erst mit der nächsten Einreichung (1.0.1); live ändert sich bis dahin nichts.
- Die Mac-Fassung 1.0 steht in Prüfung: ihre App-Info nicht anfassen.
- Scoping: Skript, Test, Workflow, Textdatei, CLAUDE.md und README = 5 Dateien, knapp am Limit; Test etwa 1,5 bis 2,5 mal so groß wie der Code.

## Analysis

### Type
Feature (Store-Auftritt, kein App-Code).

### Ohne Modell, ohne App
Reiner Textpfad: Wunschtext aus einer Repo-Datei, ein Skript setzt ihn in ASC. Kein Modell, keine App-Änderung, keine Gerätestufe
("Kein Pfad der Geräteliste berührt.").

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/store-untertitel.md` | CREATE | `## de-DE` / `## en-US`, je Name + Untertitel (Muster `beta-beschreibung.md`) |
| `scripts/asc_store_subtitles.py` | CREATE | `lesen` / `setzen`: nur bei Abweichung, App-Info der iOS-Version, Gegenprobe, 30-Zeichen-Grenze vorab |
| `scripts/test_asc_store_subtitles.py` | CREATE | Tests (Parser, Grenze, Auswahl der App-Info, nur-bei-Abweichung, Gegenprobe) |
| `.github/workflows/asc-store-subtitles.yml` | CREATE | Handlauf `lesen|setzen`, Tests vor dem Schreiben (Muster `asc-review-notes.yml`) |
| `scripts/asc_store_probe.py` | MODIFY | beide Zustandsfelder je App-Info ausgeben (bereits begonnen, 374bb16) |
| `CLAUDE.md`, `README.md` | MODIFY | Claim "Say it, it's sorted." (je Zeile 3) |

### Scope Assessment
- Files: 7 (Skript+Test+Workflow+Textdatei = Kern; Docs und Probe klein) → über dem 4–5-Limit, deshalb Schnitte.
- Estimated LoC: ~150 Skript, ~300 Test, ~40 Workflow, ~15 Text, ~10 Docs → ~500, über 250.
- Risk Level: MEDIUM (schreibt in ASC; Apple lehnt ab, wenn keine editierbare App-Info existiert).

### Schnitt-Empfehlung
1. **Schnitt 1 (Befund, klein):** Probe zeigt je App-Info `state` und `appStoreState` getrennt und welche Version dazugehört → beantwortet die offene Frage, ob für iOS eine editierbare App-Info existiert. Läuft als `lesen`, schreibt nichts.
2. **Schnitt 2 (Schreibweg):** Textdatei, Skript, Test, Workflow; setzt de-DE (PATCH) und legt en-US an (POST `appInfoLocalizations`), Gegenprobe gegen ASC.
3. **Schnitt 3 (Wortlaut-Docs):** `CLAUDE.md`/`README.md`.

### Technical Approach
- Wie `asc_review_notes.py`: Handlauf in CI, Ausgabe nur Zustände (Untertitel sind öffentlich, dürfen stehen), Fatal bei fehlender editierbarer App-Info mit klarer Meldung, nichts angerichtet.
- Mac-App-Info (1.0 IN_REVIEW) wird nie angefasst: Auswahl über die Zuordnung zur iOS-Version, nicht über "die erste".
- Apple verlangt gleiche Lokalisierungen an App-Info und Version (Quelle siehe Recherche). Neues en-US an der App-Info heißt: en-US muss bei der Einreichung 1.0.1 auch an der Versions-Lokalisierung stehen (Beschreibung, Keywords, Support-URL, Bilder). Das ist Schnitt-4-Material oder eigenes Ticket, nicht stillschweigend mitnehmen.

### Alternative(n)
- **A: Weg über die ASC-Weboberfläche (Chrome)** statt Skript: schnell, aber nicht wiederholbar, kein Repo-Beleg; widerspricht "Weg steht im Repo wie die übrigen ASC-Texte" aus dem Ticket.
- **B: Nur de-DE ersetzen, en-US später:** halbiert Risiko und LoC, lässt den US-Store ohne Untertitel (Ticket verlangt beides). Kippt keine ADR.
- **C: fastlane `deliver`:** neue Abhängigkeit, verboten ohne Freigabe.
Empfehlung bleibt der Skriptweg (eigener Pfad wie alle übrigen ASC-Texte).

### Befunde, die gegen den Plan sprechen
- Probe: nur zwei App-Infos, READY_FOR_DISTRIBUTION und IN_REVIEW, keine PREPARE_FOR_SUBMISSION. Kann sein, dass es für 1.0.1 (iOS) noch keine editierbare App-Info gibt. Dann wäre Schreiben jetzt nicht möglich und müsste warten, bis Apple sie anlegt (oder die Mac-Prüfung durch ist). Das klärt Schnitt 1, bevor Schnitt 2 gebaut wird.
- Ein verifiziertes PATCH-Beispiel für `appInfoLocalizations` fehlt; Body-Form vor dem Bau gegen die Apple-Referenz prüfen.

### Dependencies
ASC-API, CI-Geheimnisse, #838 (Version 1.0.1).

### Open Questions
- [ ] Gibt es für iOS eine editierbare App-Info? (Schnitt 1 beantwortet es.)
- [ ] en-US an der Versions-Lokalisierung: eigenes Ticket (Empfehlung) oder Teil von #837?
