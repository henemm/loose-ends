# Context: feat-625-s5d2-store-betrieb (#625 Schnitt 5d-2)

## Request Summary
Betriebsschnitt nach S5d-1 (Werkzeug, PR #993, gemergt 2026-11-24): den 1.0.2-Bau erstellen, die Versionen 1.0.2 (iOS und
Mac) bei Apple anlegen, Texte, Marketing-URL, Bilder und Review-Notizen setzen, die Tür des Dienstes öffnen und die
Einreichung so weit vorbereiten, dass `asc-store-submit aktion=pruefen` für beide Plattformen `bereit` meldet. Eingereicht
wird erst nach Hennings Wort.

## Ist-Stand (gemessen 2026-11-24, 16:55 Uhr MEZ)
- `origin/main` = c885f7a (S5d-1). Letzter TestFlight-Lauf 2026-11-19 (820199a), also vor S5c und S5d-1 → **neuer Bau nötig**.
  `project.yml` `MARKETING_VERSION: "1.0.2"`; `testflight.yml` braucht `what_to_test` (Pflicht).
- ASC: iOS und Mac 1.0 und 1.0.1 `READY_FOR_SALE`, keine 1.0.2 (S5d-1-Kontext, Lauf 45345653705; danach nur Läufe aus S5d-1).
- Marketing-Seite `https://www.henemm.com/loose-ends/` antwortet 200 (geprüft 2026-11-24 16:55 MEZ).
- Tür im Betrieb zu (`ALLOWED_APPLE_SUBS` = Hennings sub); Code für `*` + `NEW_ACCOUNTS_PER_DAY` live seit S5a.
- Datenschutz-Etikett: Vorlage `docs/reference/app-store-datenschutzangaben.md`, **Hennings datiertes Ja fehlt**; Eintrag nur im
  ASC-Web (keine API), Henning meldet sich an, Claude trägt ein.
- Review-Notizen 1.0.2 (`docs/reference/app-review-notizen.md`) verweisen in Punkt 1 auf eine **Bildschirmaufnahme eines
  echten iPhone 16 Pro**, die auch die Verbindung zu Claude zeigt (Anmelden mit Apple, Connector in claude.ai, Konto löschen).
  Diese Aufnahme gibt es noch nicht. Bei 1.0 hat Henning sie selbst aufgenommen und selbst mit der Antwort an Apple geschickt
  (#788, 2026-11-01); der API-Upload (#788 Schnitt 2) wurde nie gebaut. `asc_review_notes.py` liest Anhänge nur.

## Related Files
| File | Relevance |
|------|-----------|
| `.github/workflows/testflight.yml` | Bau 1.0.2, Eingaben `what_to_test`, `cleanup_dry_run` |
| `asc-store-version.yml` / `scripts/asc_store_version.py` | `lesen`, `anlegen` (iOS aus `MARKETING_VERSION`, dann Mac, Bau-Zuordnung) |
| `asc-version-texts.yml` / `scripts/asc_version_texts.py` | Texte je Plattform inkl. `marketingUrl` aus `docs/reference/app-store-texte.md` |
| `asc-store-images.yml` | `lesen`/`hochladen`/`platzieren` je Sprache und Plattform; de-DE nur gelesen (Apple übernimmt de-Bilder beim Anlegen, #842-Befund) |
| `asc-review-notes.yml` / `scripts/asc_review_notes.py` | `notizen` je Plattform in die bearbeitbare Version; Anhänge nur lesen |
| `asc-store-submit.yml` | `pruefen` (GET), `einreichen` mit Versionsnummer als Bestätigung |
| `asc-app-info.yml` | Untertitel, Datenschutz-Adresse (schon gesetzt seit #893) |
| henemm-infra `loose-ends/.env`, `scripts/deploy-loose-ends.sh` | `ALLOWED_APPLE_SUBS=*`, `NEW_ACCOUNTS_PER_DAY=20` |
| `docs/reference/app-store-datenschutzangaben.md` | Vorlage Etikett |
| `docs/reference/app-review-notizen.md` | Notiztext 1.0.2 |
| `docs/artifacts/feat-625-s5d2-store-betrieb/` | Belege der Läufe (neu) |

## Existing Patterns
- Handlauf je Schreibweg: `lesen` vorher, schreibende Aktion nur bei Abweichung, Gegenprobe im selben Lauf, nie löschen, POST nie wiederholt.
- ASC-Web-Schritte (Etikett): Claude in Hennings Chrome, Henning nur Anmeldung (Passkey), Claude prüft Vorschau gegen Vorlage.
- Betrieb rennwienix: `ssh rennwienix bash -s < skript`; Deploy `bash scripts/deploy-loose-ends.sh` bei festem Commit.
- Einreichen: `aktion=einreichen -f bestaetigung=1.0.2`, nur nach Hennings ausdrücklichem Wort; Gegenprobe `WAITING_FOR_REVIEW`.

## Dependencies
- Upstream: S5a–S5c, S5d-1 gemergt; #984 Texte; S1/S4 Datenschutztext live.
- Henning: (1) Bildschirmaufnahme auf seinem iPhone mit dem 1.0.2-Bau aus TestFlight, (2) datiertes Ja zum Etikett,
  (3) Anmeldung im ASC-Web, (4) Wort zum Einreichen.
- Downstream: Apples Prüfung; nach Freigabe ist die Verbindung zu Claude für jeden Store-Nutzer da; #625 schließt.

## Existing Specs
- `docs/specs/feat-625-schnitt-5d-1-store-werkzeug.md`, `feat-625-schnitt-5a-offene-tuer.md`, `docs/context/feat-625-s5d-store-einreichen.md`
- `docs/specs/feat-788-schnitt-1-review-notizen.md` (Video-Weg bei 1.0), `feat-842-schnitt-5a-1-mac-version-anlegen.md`, `feat-893-*`

## Risks & Considerations
- **Aufnahme hängt an Henning und seinem Gerät:** ohne sie stimmt Punkt 1 der Notizen nicht. Gerät nur auf sein Wort; die
  Aufnahme selbst macht er (wie bei 1.0). Alternative für die Analyse: Notizen ohne Aufnahme-Verweis, Aufnahme aus dem Simulator
  (Apple verlangte bei 1.0 ein echtes Gerät → eher abgelehnt), Anhang per API (Werkzeug fehlt) oder per ASC-Web.
- **Tür öffnen ist ab sofort öffentlich** (jeder mit Apple-Konto, Tagesgrenze 20) – PO-Entscheidung 2026-11-22; erst direkt vor
  `notizen`/Einreichung, Monitor beobachtet.
- **Etikett gilt sofort app-weit** → erst unmittelbar vor dem Einreichen, nach Hennings datiertem Ja.
- **Bau-Zuordnung:** `anlegen` braucht einen gültigen 1.0.2-Bau je Plattform → TestFlight-Lauf zuerst, `VALID` abwarten.
- **en-US-Texte/Bilder** übernimmt Apple beim Anlegen nicht (#842-Befund) → `asc-version-texts` und `asc-store-images` (en, ios/mac) auffüllen.
- Fast kein Code: Schnitt besteht aus Läufen und Belegen; Code nur, falls ein Werkzeug fehlt (Video-Anhang).
