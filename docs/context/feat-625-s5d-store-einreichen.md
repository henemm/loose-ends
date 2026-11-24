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
