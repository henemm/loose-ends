# Context: feat-615-s4e-datenschutz (#615 Schnitt 4e)

## Request Summary
Schnitt 4e von #615: Der Datenschutztext bekommt den Konto-Teil (Mit Apple anmelden, Dienst, Abschrift für Claude,
Löschen), Henning gibt den Wortlaut frei, er wird im Repo und auf henemm.com (deutsch und englisch) veröffentlicht;
laut 4d-Spec folgt danach `LEAccountEnabled` im Store-Bau.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/reference/datenschutz-entwurf.md` | Quelle des Textes (DE + EN-Abschnitt, Beleg-Tabelle, „Offen, nicht belegt“); sagt heute „kein eigener Server, kein Konto bei uns“, „kein `URLSession`“ — beides seit #615 S4b/S4c falsch, sobald der Schalter an ist |
| henemm/henemm-website `content/legal/loose-ends/privacy-policy/_index.md`, `privacy-policy-en/` | öffentliche Seiten (PR #75, #76); Änderung gilt erst, wenn diese angepasst sind |
| `project.yml:82-84` | `LEAccountEnabled: false` (Info-Quelle); Kommentar „only a TestFlight run with `konto`“ |
| `LooseEnds/Info.plist:63` | Abbild, `scripts/test_info_plist_sync.py` vergleicht |
| `scripts/test_asc_what_to_test.py:282-286` | prüft, dass `LEAccountEnabled` in project.yml und Info.plist `False` ist — kippt beim Store-Schalter |
| `.github/workflows/testflight.yml:34,116-118,225-233` | Eingabe `konto` setzt den Schalter per plutil; Archivprüfung verlangt Bool gleich Eingabe |
| `scripts/asc_store_version.py` | ordnet einen `konto`-Bau nie einer Store-Version zu (#615 S4c-2a) |
| `LooseEnds/Claude/AccountWiring.swift` | `isEnabled` liest den Schalter, Rückfall aus |
| `LooseEnds/PrivacyInfo.xcprivacy` | `NSPrivacyCollectedDataTypes` leer — mit Konto im Store wäre mindestens „User ID“ (Apple-`sub`) zu deklarieren |
| `docs/project/00-entscheidungen.md` ADR-21 (Z. 308ff.) | Text ändern, **bevor** ein externer Nutzer Claude verbinden kann; vor externen Nutzern eigener Server (#796, #625) |
| `server/migrations/001–007` | was der Dienst speichert: Abschrift, Aufträge, Ergebnisse, Konten (`apple_sub`), Sitzungen (SHA-256), Apple-Refresh-Token verschlüsselt je Client, OAuth-Datensätze (gehasht) |
| `docs/reference/claude-abschrift-vertrag.md` | Inhalt der Abschrift (offene Aufgaben, „Jetzt“, ohne Rohtext und Notiz) |
| `docs/specs/feat-615-schnitt-4d-auth-oeffnen.md:135,178` | Plan 4e: Text, Freigabe, danach Store-Schalter |

## Existing Patterns
- Rechtstext: Entwurf im Repo mit Beleg-Tabelle, Hennings Freigabe datiert im Status, dann Website-PR (henemm-website) und
  englischer Abschnitt als wortgetreue Übersetzung (#705, #763).
- Store-Sperre: Schalter in `project.yml` aus, TestFlight-Eingabe `konto` schaltet ein, `asc_store_version.py` schützt
  den Store (#615 S4c-2a).

## Dependencies
- Upstream: Betrieb (#796, `loose-ends.henemm.com` auf Hetzner `rennwienix`, nächtlicher pg_dump + restic off-site),
  Tür `ALLOWED_APPLE_SUBS` (nur Hennings Konto), nginx-Logs mit IP-Adressen, fail2ban.
- Downstream: #795 (App lädt Abschrift hoch, führt Aufträge aus) — erst damit fließen Aufgaben zum Dienst; #625
  (Store-Datenschutzangaben, AVV, Einreichung, eigener Server vor externen Nutzern); #622 Nachweis aus claude.ai.

## Existing Specs
- `docs/specs/feat-615-schnitt-4c2a-freischalten.md`, `…-4c2b-knopf-adresse.md`, `…-4d-auth-oeffnen.md`

## Risks & Considerations
- **Store-Schalter vor offener Tür:** `ALLOWED_APPLE_SUBS` lässt nur Hennings Konto zu. Ein Store-Bau mit sichtbarer Gruppe
  „Claude“ zeigt jedem Nutzer einen Anmeldeknopf, der mit „nicht zugelassen“ endet, und die App lädt noch nichts hoch (#795).
  → Produktentscheidung: Schalter in 4e oder erst mit #795/#625.
- **App-Store-Datenschutzangaben** (Nährwert-Etiketten in ASC) und `PrivacyInfo.xcprivacy` müssten vor einem Store-Bau mit
  Konto „User ID“ (und mit #795 „Other User Content“) deklarieren — Umfang von #625.
- Text darf nur sagen, was Code und Betrieb belegen; Abschrift-Upload gibt es im App-Code noch nicht (#795).
- Rechtstext: Hosting-Anbieter (Hetzner, Deutschland), Speicherdauer, Server-Logs (IP), Löschweg (Konto löschen in der App,
  Widerruf bei Apple), Rechtsgrundlage — Wortlaut gibt Henning frei.
- Zwei Repos (loose-ends, henemm-website), beide per PR.

## Analysis

### Type
Feature (Rechtstext, kein App-Code)

### Belegte Fakten für den Konto-Teil (Stand 2026-11-10)
- App fragt bei Apple **keine** Daten an (`AccountSection.swift:177` `requestedScopes = []`): kein Name, keine E-Mail. Gespeichert wird nur die Apple-Kennung (`apple_sub`, `002_accounts.sql`).
- Dienst speichert je Konto: Konto (`apple_sub`, Anlagezeit), Sitzungen nur als SHA-256 (gleitend 90 Tage, #615 S4a), Apple-Refresh-Token AES-256-GCM verschlüsselt je Client (`005`), OAuth-Datensätze des Claude-Konnektors gehasht (`004`), Abschrift/Aufträge/Ergebnisse (`001`, `006`, `007`; Abschrift ohne Rohtext und Notiz, Felder per CHECK begrenzt). Die App lädt heute **noch keine** Abschrift hoch (#795).
- Löschen: „Konto löschen“ in der App → `/auth/delete` entfernt Konto, Sitzungen, Abschrift, Aufträge, Ergebnisse, OAuth-Zeilen, widerruft die Apple-Token je Client (#615 S3c, #621 S4c-1).
- Ort: Hetzner, Server `rennwienix`, Standort nbg1 (Nürnberg; Beleg: `monitor-*.txt` in `docs/artifacts/feat-615-s4d-auth-oeffnen/`, lesender SSH-Zugriff ist gesperrt, Bestätigung in der Spec-Phase offen).
- Server-Protokolle: nginx `access.log` mit IP-Adressen, `logrotate` täglich, `rotate 14` → **14 Tage** (gelesen auf `rennwienix`, `/etc/logrotate.d/nginx`); Container-Logs `json-file` `max-size 10m` ohne Inhalt/Token (#796 S2); fail2ban sperrt eine IP 1 h nach 10 Limit-Treffern.
- Sicherungen: nächtlicher pg_dump, lokal nur der jüngste; off-site restic auf Hennings Heimserver (Deutschland, verschlüsselt, append-only), Aufbewahrung `--keep-daily 7 --keep-weekly 8 --keep-monthly 12 --keep-yearly 3` (henemm-infra `docs/backup-offsite.md`) → gelöschte Kontodaten bleiben in Sicherungen **bis zu ~3 Jahre**.
- Recherche: Logfiles mit IP 7–14 Tage, Rechtsgrundlage Art. 6 Abs. 1 lit. f DSGVO, ist gängige Praxis; Apple 5.1.1(v) verlangt Kontolöschung in der App und Token-Widerruf per REST bei Sign in with Apple (erfüllt).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/datenschutz-entwurf.md` | MODIFY | Konto-Abschnitt DE + EN, Kurzfassung „kein eigener Server“ korrigiert, Beleg-Tabelle, Status/Datum |
| henemm-website `content/legal/loose-ends/privacy-policy/_index.md` | MODIFY | öffentliche deutsche Fassung |
| henemm-website `content/legal/loose-ends/privacy-policy-en/_index.md` | MODIFY | englische Fassung |
| `CLAUDE.md` | MODIFY | Datenschutz-Zeile (Stand Konto-Teil) |
| `project.yml`, `Info.plist`, `scripts/test_asc_what_to_test.py`, `PrivacyInfo.xcprivacy` | nur falls Store-Schalter in 4e | `LEAccountEnabled` an, „User ID“ deklarieren |

### Scope Assessment
- Files: 4 (ohne Schalter), 8 mit Schalter
- Estimated LoC: +≈150/−≈10 Text (ohne Schalter)
- Risk Level: LOW ohne Schalter (nur Text), MEDIUM mit Schalter (öffentlicher Store-Bau zeigt Anmeldung, die für alle außer Henning abgewiesen wird)

### Technical Approach
Empfehlung: Text beschreibt nur, was heute live ist (Konto über Apple, Dienst in Deutschland, Konnektor zu Claude, Protokolle 14 Tage, Sicherungen, Löschen in der App). Die Abschrift kommt als Absatz mit #795 dazu. Der Store-Schalter bleibt in 4e aus und wird mit #625 gesetzt, wenn die Tür (`ALLOWED_APPLE_SUBS`) für andere aufgeht — sonst sieht jeder Store-Nutzer und Apples Prüfer einen Knopf, der mit „nicht zugelassen“ endet (Ablehnungsrisiko im Review).
Ablauf: Wortlaut DE als Entwurf in der Spec, Freigabe Henning, EN wortgetreu, Repo-PR, Website-PR, Seite live prüfen.

### Alternativen
- A1: Schalter in 4e einschalten (Plan aus der 4d-Spec) — kippt nichts formal, aber Store-Nutzer stoßen auf eine geschlossene Tür; erst sinnvoll mit #625.
- A2: Eigene Datenschutzseite nur für den Claude-Dienst statt Abschnitt in der App-Seite — trennt App (privat in iCloud) und Dienst sauber; dagegen: zwei Seiten, zwei URLs bei Apple, Nutzer liest das Wichtigste nicht. Kippt die Entscheidung „eine Seite“ (#705).
- A3: Aufbewahrung der Loose-Ends-Sicherung verkürzen (eigene restic-Regel, z. B. 30 Tage) statt drei Jahre im Text zu nennen — Infra-Arbeit in henemm-infra, eigenes Issue.

### Dependencies
- henemm-website (zweites Repo, PR), #795 (Abschrift-Absatz), #625 (Schalter, Store-Angaben, AVV mit Hetzner).

### Open Questions
- [ ] Store-Schalter in 4e oder mit #625? (Empfehlung: mit #625)
- [ ] Sicherungsdauer: im Text ehrlich nennen (bis zu drei Jahre, verschlüsselt) oder Loose-Ends-Sicherung verkürzen (eigenes Infra-Issue)? (Empfehlung: verkürzen auf 30 Tage, Text nennt 30 Tage)
- [ ] Standort nbg1 lesend bestätigen (Spec-Phase, kein PO-Thema)

### Entscheidungen Henning (2026-11-10)
- **Store-Schalter bleibt in 4e aus.** `LEAccountEnabled` wird erst mit #625 gesetzt, wenn `ALLOWED_APPLE_SUBS` für andere aufgeht; TestFlight `konto=true` bleibt der einzige Weg. 4e ändert nur Text (Repo + Website).
- **Sicherungen: 30 Tage.** Die Loose-Ends-Sicherung bekommt eine eigene off-site Frist von 30 Tagen (Infra-Issue, von Claude umgesetzt); der Text nennt 30 Tage. Text erst veröffentlichen, wenn die Frist am Heimserver greift oder im selben Zug gesetzt ist.
