# Context: feat-625-s5d-store-einreichen (#625 Schnitt 5d)

## Request Summary
Letzter Schnitt von #625: Version 1.0.2 mit eingeschalteter Verbindung zu Claude (iOS/iPadOS und Mac) bei Apple
einreichen – mit freigegebenem Datenschutz-Etikett, Store-Texten samt Marketing-URL, Review-Notizen, die das Konto
erklären, und offener Tür des Dienstes (`ALLOWED_APPLE_SUBS=*`, Tagesgrenze), damit Apples Prüfer sich anmelden kann.

## Ist-Stand (gemessen 2026-11-24)
- `asc-store-version.yml aktion=lesen` (Lauf 45345653705): iOS 1.0 und 1.0.1, Mac 1.0 und 1.0.1, alle `READY_FOR_SALE`.
  **Es gibt keine Version 1.0.2 bei Apple**, weder iOS noch Mac. Der #984-Hinweis „Texte schon bei Apple eingetragen“
  kann sich also nicht auf eine 1.0.2-Version beziehen.
- Letzter TestFlight-Lauf 2026-11-19 (820199a), also **vor** S5c (ee54ecc, 2026-11-24). Ein Bau nach S5c fehlt noch;
  `project.yml` trägt `MARKETING_VERSION: "1.0.2"`, Build-Nummer setzt der Lauf.
- Tür im Betrieb zu (`ALLOWED_APPLE_SUBS` = Hennings sub); Code für `*` + `NEW_ACCOUNTS_PER_DAY` live seit S5a (bf1fccf).
- Fragebogen-Vorlage `docs/reference/app-store-datenschutzangaben.md` (S3): datiertes Ja von Henning fehlt noch.
- Store-Texte 1.0.2 (de-DE, en-US) in `docs/reference/app-store-texte.md`, von Henning freigegeben (#984).
- Marketing-URL `https://www.henemm.com/loose-ends/` vorgemerkt (#625-Kommentar 2026-11-23), lieferte zuletzt 200.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_store_version.py` + `.github/workflows/asc-store-version.yml` | `anlegen` legt nur die **Mac**-Version mit der Nummer der bearbeitbaren iOS-Version an; eine iOS-Version anlegen kann es nicht → Lücke für 1.0.2 |
| `scripts/asc_version_texts.py` + `asc-version-texts.yml` | setzt description, keywords, supportUrl, promotionalText, whatsNew je Plattform in die eine `PREPARE_FOR_SUBMISSION`-Version; **kein `marketingUrl`** |
| `scripts/asc_review_notes.py` + `asc-review-notes.yml` | Review-Notizen, fest auf **iOS-Version „1.0“** (`VERSION_STRING`), nur iOS; legt kein Review-Detail an |
| `docs/reference/app-review-notizen.md` | Notizen von 1.0: „no account registration, login or account deletion“, „We run no server of our own“ – mit Konto **falsch**, muss neu |
| `scripts/asc_store_submit.py` + `asc-store-submit.yml` | `pruefen` (GET) / `einreichen` (Bestätigung = Versionsnummer), beide Plattformen, iOS zuerst (#893) |
| `scripts/asc_app_info.py` + `asc-app-info.yml` | Untertitel, Datenschutz-Adresse (`appInfoLocalizations`) |
| `scripts/asc_store_probe.py` | liest u. a. `marketingUrl` (nur lesen) |
| `docs/reference/app-store-datenschutzangaben.md` | Vorlage des Etiketts; Eintrag nur im ASC-Web nach Hennings Ja |
| `docs/reference/app-store-texte.md` | Store-Texte inkl. „Neu in dieser Version“ für 1.0.2 |
| `server/src/accounts.ts` (`admit`, `doorFromEnv`) | offene Tür mit Tagesgrenze (S5a) |
| henemm-infra `loose-ends/.env`, `scripts/deploy-loose-ends.sh` | Betriebswert `ALLOWED_APPLE_SUBS=*`, `NEW_ACCOUNTS_PER_DAY` |
| `.github/workflows/testflight.yml` | 1.0.2-Bau nach S5c |
| Tests: `scripts/test_asc_store_version.py`, `test_asc_version_texts.py`, `test_asc_review_notes.py`, `test_asc_store_submit.py` | Python-Unittests je Skript, laufen im Workflow vor dem Schreiben |

## Existing Patterns
- ASC-Schreibwege: Handlauf-Workflow, `lesen` (nur GET) und eine schreibende Aktion, nur bei Abweichung, Gegenprobe
  im selben Lauf, nie löschen; POST wird nie wiederholt, wo ein Duplikat entstehen könnte (#842 S5a-1 Befund).
- Bearbeitbare Version = genau eine je Plattform im Zustand `PREPARE_FOR_SUBMISSION` (`editable_version`).
- ASC-Web ohne API (Etikett, CloudKit-Console, Hetzner-AVV): Claude öffnet die Seite in Hennings Chrome, Henning meldet
  sich nur an, Claude trägt ein und prüft gegen die Vorlage.
- Betrieb rennwienix: `ssh rennwienix bash -s < skript`, Deploy-Skript per `bash scripts/deploy-loose-ends.sh`.
- Einreichen nur mit Versionsnummer als Bestätigung; Ergebnis `WAITING_FOR_REVIEW` im selben Lauf gegengeprüft.

## Dependencies
- Upstream: S5a (Tür-Code live), S5b (Schalter an), S5c (Mechanik zurückgebaut), #984 (Texte), S1/S4 (Datenschutztext live).
- Downstream: Apples Prüfung; nach Freigabe ist die Verbindung zu Claude für jeden Store-Nutzer da; #625 schließt.

## Existing Specs
- `docs/specs/feat-625-schnitt-5a-offene-tuer.md` … `5c-konto-rueckbau.md`; `docs/context/feat-625-konto-schalter.md` (Schnittplan, PO-Entscheidung 2026-11-22)
- `docs/specs/feat-842-schnitt-5a-1-mac-version-anlegen.md`, `feat-893-*` (Einreichen), `feat-788-*` (Review-Notizen)

## Risks & Considerations
- **Werkzeuglücken:** iOS-Version anlegen, Marketing-URL, Review-Notizen für 1.0.2 auf beiden Plattformen. Zusammen mit
  dem Betrieb (Tür, Etikett, Bau, Einreichen) über 4–5 Dateien → Schnitt teilen (Werkzeug/Notizen zuerst, dann Betrieb).
- **Etikett gilt sofort app-weit**, auch für 1.0.1 → erst direkt vor dem Einreichen eintragen; braucht Hennings datiertes Ja (Rechtsaussage, keine Auto-Ampel).
- **Tür öffnen = jeder mit Apple-Konto** kommt herein (PO-Entscheidung 2026-11-22, Tagesgrenze 20). Vor dem Einreichen nötig, sonst sichere 2.1-Ablehnung.
- **Review-Notizen**: Anmeldung mit Apple (eigene Kennung des Prüfers), Verbindung in claude.ai als eigener Connector (braucht Claude-Konto des Prüfers → Hinweis, wie die Funktion ohne Claude zu sehen ist), Konto löschen in der App (5.1.1(v)), Server in Deutschland.
- **Einreichen ist nicht rücknehmbar per Werkzeug**; Bestätigung = Versionsnummer. Geräteliste (`project.yml`, Info.plist) ist seit S5b schon in TestFlight; neu ist nur der Store-Bau.
- Neuer TestFlight-Bau nötig (nach S5c), `what_to_test` Pflicht.

## Analysis

### Type
Feature (Auslieferung: Werkzeuglücken schließen, dann Betrieb und Einreichung)

### Befunde (2026-11-24)
- **Was Apple beim API-Anlegen übernimmt, ist im Repo belegt** (#842 S5a-1/S5a-2, `docs/context/feat-842-s5a2-texte.md`):
  Mac 1.0.1 per `POST /v1/appStoreVersions` angelegt bekam die de-DE-Texte und -Bilder der Vorversion und ein Review-Detail;
  es fehlten en-US ganz, der Werbetext und `whatsNew`. Das deckt sich mit Runway (Werbetext wird nicht übernommen) und dem
  Apple-Forum (Bilder hängen an der Versions-Lokalisierung). Für iOS 1.0.2 ist dasselbe Bild zu erwarten; `lesen` nach dem
  Anlegen belegt es, die vorhandenen Handläufe (`asc-version-texts`, `asc-store-images`) füllen auf.
- **`marketingUrl` ist ein Feld der Versions-Lokalisierung** (`appStoreVersionLocalizations`), also genau der Weg von
  `asc_version_texts.py`; dort fehlt nur das Feld.
- **Review-Notizen**: Skript fest auf iOS „1.0“; Text sagt „no account … no server of our own“ – mit Konto falsch (Guideline 2.1/5.1.1).
- Quellen: https://www.runway.team/blog/apply-promotional-text-and-whats-new-notes-to-new-versions-in-swift-using-the-app-store-connect-api ,
  https://developer.apple.com/forums/thread/131966 , https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appstoreversionlocalizations

### Schnitt-Teilung
- **S5d-1 Werkzeug (diese Spec):** nur Skripte, Tests, Notiztext; kein App-Code, keine Geräteliste.
- **S5d-2 Betrieb (eigene Spec danach, kaum Code):** TestFlight-Bau 1.0.2 → `anlegen` → `lesen` → Texte/Bilder auffüllen →
  Review-Notizen → Bildschirmaufnahme der Konto-Funktion → Tür auf `*` (Tagesgrenze 20) → Datenschutz-Etikett im ASC-Web
  (Hennings datiertes Ja vorher) → `pruefen` → `einreichen` nur nach Hennings Wort.

### Affected Files (S5d-1)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_store_version.py` | MODIFY | `anlegen` legt auch die **iOS**-Version an, wenn keine bearbeitbare existiert; Nummer aus `project.yml` `MARKETING_VERSION` (eine Quelle), nur wenn sie größer ist als jede vorhandene iOS-Version; danach wie heute Mac mit derselben Nummer und Bau-Zuordnung; POST nie wiederholt, Gegenprobe im Lauf |
| `scripts/asc_version_texts.py` | MODIFY | Zeilenfeld „Marketing-URL“ → `marketingUrl` (https-Prüfung wie `supportUrl`, optional) |
| `scripts/asc_review_notes.py` | MODIFY | statt fest „1.0“ die eine bearbeitbare Version **je Plattform** (iOS und Mac); fehlt das Review-Detail, Abbruch mit Grund (Anlegen bleibt außen vor, Apple legt es beim Anlegen mit an) |
| `docs/reference/app-review-notizen.md` | MODIFY | Notizen 1.0.2: Konto nur über „Mit Apple anmelden“ (eigene Apple-ID des Prüfers, keine Demo-Zugangsdaten nötig), Konto löschen in der App (5.1.1(v)), eigener Dienst auf Server in Deutschland, Verbindung zu Claude (claude.ai-Connector, braucht Claude-Konto; Aufnahme zeigt den Ablauf), App voll nutzbar ohne Konto |
| `docs/reference/app-store-texte.md` | MODIFY | Zeile „Marketing-URL: https://www.henemm.com/loose-ends/“ in de-DE und en-US |
| `scripts/test_asc_store_version.py`, `test_asc_version_texts.py`, `test_asc_review_notes.py` | MODIFY | Tests je Änderung (zählen nicht ins Limit) |

### Scope Assessment
- Dateien: 5 (ohne Tests); geschätzt +90/−25 LoC Skriptcode, Notiztext ~50 Zeilen ersetzt
- Risk Level: LOW–MEDIUM – nur Handlauf-Werkzeug, kein App-Code; Risiko liegt im späteren Schreiben bei Apple
  (doppelte Version per wiederholtem POST → ausgeschlossen durch „nie wiederholen“ und Vorab-Lesen)

### Technical Approach
`anlegen` erweitern statt neues Skript: Plan nur aus GET (Versionen beider Plattformen, Zielnummer aus `project.yml`), dann
höchstens zwei POST (iOS, Mac) und die Bau-Zuordnung wie bisher; jede Bedingung, die nicht passt (Zielnummer ≤ vorhandene,
schon bearbeitbare Version mit anderer Nummer), bricht vor dem ersten Schreiben ab. Texte und Notizen bleiben je eigener
Handlauf mit Gegenprobe.

### Alternativen
- **A: iOS-Version in der ASC-Weboberfläche anlegen** (Claude im Chrome, Henning meldet sich nur an). Spart ~30 LoC, übernimmt
  laut Apple-Hilfe mehr Metadaten. Dagegen: braucht Hennings Anmeldung, nicht wiederholbar/gegenprüfbar; fällt das Muster
  „alles per Handlauf“ (#842 S5a-1, keine ADR-Nummer). Nicht empfohlen.
- **B: Tür nicht öffnen, nur die sub des Prüfers zulassen.** Geht nicht: die sub des Prüfers ist vorher unbekannt; Apple lehnt
  ohne Zugang nach 2.1 ab. PO-Entscheidung 2026-11-22 (offen mit Tagesgrenze) bleibt.

### Dependencies
S5a–S5c gemergt; #984 Texte; Marketing-Seite live (vor dem Setzen auf 200 prüfen).

### Open Questions
- [ ] (S5d-2, nicht jetzt) Hennings datiertes Ja zum Datenschutz-Etikett und zum Einreichen – beides erst im Betriebsschnitt.
- Keine offene Frage für S5d-1.
