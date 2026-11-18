# Context: feat-625-s2-privacy-manifest (#625 Schnitt 2)

## Request Summary
#625 Vorbereitung, Schnitt 2 laut `docs/context/feat-625-store-datenschutz.md`: das Datenschutz-Manifest der App
(`LooseEnds/PrivacyInfo.xcprivacy`) nennt, was die Verbindung zu Claude erhebt (Apple-Kennung, Abschrift/Aufträge,
Installationskennung), samt Test. PO-Entscheidung 2026-11-17: Schalter `LEAccountEnabled` und Einreichung erst nach
#795, #796, #624 (alle drei offen, #623 geschlossen, Stand 2026-11-18).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/PrivacyInfo.xcprivacy` | App-Target (iOS+macOS), `NSPrivacyCollectedDataTypes` leer, `NSPrivacyTracking` false, UserDefaults CA92.1 |
| `LooseEndsWatch/`, `LooseEndsShare/`, `LooseEndsWidgets/`, `LooseEndsWatchWidgets/` `PrivacyInfo.xcprivacy` | ohne Konto-Code, bleiben leer |
| `.github/workflows/testflight.yml:116-118` (iOS), `:423-425` (Mac) | Schritt „Set the account switch“: nur bei `konto` setzt `plutil` `LEAccountEnabled` nach `xcodegen generate` |
| `.github/workflows/testflight.yml:187`, `:493` | Archivprüfung verlangt das Manifest (#177), prüft keinen Inhalt; `account_switch()` prüft den Schalter gegen die Eingabe |
| `scripts/test_*.py` | CI führt alle per `unittest discover -s scripts` aus (`ci.yml:34`) |
| `docs/reference/datenschutz-entwurf.md:145` | Beleg-Zeile „keine erfassten Datentypen deklariert“ – muss die neue Regel nennen (Beleg-Abschnitt ist nicht öffentlich) |
| `Shared/Services/TranscriptCodec.swift`, `LooseEnds/Claude/DeviceIdentity.swift`, `server/migrations/002_accounts.sql` | belegen die drei Datentypen (Abschrift = Other User Content, `X-Device` = Installations-UUID, `apple_sub` = User ID) |

## Existing Patterns
- Konto-Bau-Sonderweg: der Archivinhalt folgt der TestFlight-Eingabe `konto` (Patch nach `generate`, Gegenprobe im Archiv),
  Store-Builds bleiben aus (#615 S4c-2a).
- Repo-Wächter als Python-`unittest` in `scripts/` (z. B. `test_info_plist_sync.py`, `test_entitlements_sync.py`).

## Dependencies
- Upstream: `plutil`/`plistlib`, `project.yml` (`LEAccountEnabled: false`).
- Downstream: App-Store-Datenschutzangaben (Schnitt 3, Fragebogen im ASC-Web), Schalter-Schnitt später.

## Recherche (2026-11-18)
- Schlüssel je Eintrag: `NSPrivacyCollectedDataType`, `NSPrivacyCollectedDataTypeLinked`, `NSPrivacyCollectedDataTypeTracking`,
  `NSPrivacyCollectedDataTypePurposes`; Werte u. a. `NSPrivacyCollectedDataTypeUserID`, `NSPrivacyCollectedDataTypeDeviceID`,
  `NSPrivacyCollectedDataTypeOtherUserContent`, Zweck `NSPrivacyCollectedDataTypePurposeAppFunctionality`
  (https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes).
- Manifest und ASC-Label sind getrennt: das Label wird von Hand in App Store Connect gepflegt; Xcode erzeugt aus den
  Manifesten nur einen Bericht (https://developer.apple.com/forums/thread/756197). Fallberichte nennen eine Ablehnung, wenn das
  Manifest Daten nennt und das Label „Keine Daten erfasst“ sagt – nicht von Apple belegt, aber ein reales Risiko für
  Store-Builds mit Schalter aus.
- Apple-Definition „Device ID“ umfasst „other device-level ID“ → die Installations-UUID (`X-Device`) wird deklariert;
  Server-Protokoll-IPs sind kein eigener Typ (nur relevant als Standort, hier nicht genutzt).

## Risks & Considerations
- **Manifest im Quelltext sofort befüllt** hieße: jeder Store-Bau 1.0.x (Schalter aus, erhebt nichts) widerspräche dem
  heutigen Label und dem Text „ohne Konto kein Verkehr“. Daher Empfehlung: Manifest folgt dem Schalter wie `LEAccountEnabled` –
  Konto-Bauten bekommen die drei Einträge im CI-Schritt, Store-Bauten bleiben leer; die Archivprüfung hält beides fest.
  Beim späteren Umlegen des Schalters wandern die Einträge in die Quelldatei (eine Quelle der Wahrheit: ein Skript mit der Liste).
- Alternative A: Manifest erst mit dem Schalter-Schnitt (nichts jetzt; Konto-TestFlight-Bauten bleiben unvollständig deklariert).
- Alternative B: sofort in die Quelldatei (einfachste Änderung, Widerspruchsrisiko in Store-Review).
- Keine ADR fällt. Kein Pfad der Geräteliste betroffen (Manifest, Skript, Workflow-Datei sind nicht gelistet); Abnahme endet
  nach Stufe 2 bzw. mit dem Archivbeleg eines Konto-TestFlight-Laufs (Workflow-Run, kein Gerät).
- `testflight.yml` ist CI-Code → Adversary-Risiko hoch (2 Runden).

## Analysis

### Type
Feature (Store-Vorbereitung, kein sichtbarer UI-Anteil → kein Entwurf nötig)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/privacy_manifest.py` | CREATE | Eine Quelle der Wahrheit: die drei Konto-Einträge (UserID, DeviceID, OtherUserContent; je linked=true, tracking=false, Zweck AppFunctionality). `apply <manifest>` fügt sie idempotent ein; `check <manifest> --account true|false` prüft: bei `true` genau diese drei, bei `false` keine erfassten Datentypen. Nur `plistlib`, keine Abhängigkeit |
| `scripts/test_privacy_manifest.py` | CREATE | unittest: apply auf Kopie der echten Quelldatei → check true grün; Quelldatei unverändert → check false grün; apply zweimal = einmal; check true auf leerem Manifest rot, check false auf befülltem rot; fremder Eintrag → rot; Quelldatei im Repo hält `NSPrivacyCollectedDataTypes` leer (Store-Bauten) |
| `.github/workflows/testflight.yml` | MODIFY | iOS- und Mac-Job: Schritt „Set the account switch“ ruft zusätzlich `python3 scripts/privacy_manifest.py apply LooseEnds/PrivacyInfo.xcprivacy`; Archivprüfung (iOS `:187`, Mac `:493`) ruft `check` gegen das Manifest im Archiv mit `--account "$ACCOUNT_BUILD"` |
| `docs/reference/datenschutz-entwurf.md` | MODIFY | Beleg-Zeile (`:145`, nicht öffentlich) nennt die Regel: Store-Bauten leer, Konto-Bauten drei Typen aus `scripts/privacy_manifest.py` |
| `docs/reference/testflight.md` | MODIFY (klein) | Abschnitt Konto-Schalter: Manifest folgt `konto` |

### Scope Assessment
- Files: 5 (Limit eingehalten)
- Estimated LoC: +~170 / -~2 (Skript ~60, Test ~90, Workflow ~8, Doku ~6)
- Endstand (2026-11-18, /60-validate): +365 / −3 (Skript 125, Test 211, Workflow 21/−2, Doku 8/−1); Überhang aus den
  Fehlerfall-Tests (AC-5, AC-6). Henning per Rückfrage in /60-validate: „So übernehmen“.
- Risk Level: MEDIUM — CI-Code im Auslieferungsweg (ein Fehler hält jeden TestFlight-Lauf an), aber Store-Bauten ändern
  sich inhaltlich nicht; die Gegenprobe im Archiv macht jeden Fehler laut statt still

### Technical Approach
Empfehlung: **Manifest folgt dem Schalter** wie `LEAccountEnabled` (#615 S4c-2a-Muster): Quelle bleibt leer, Konto-Bauten
bekommen die drei Einträge im CI nach `generate`, die Archivprüfung hält beides fest (Konto ↔ drei Einträge, sonst keine).
`xcodegen generate` schreibt `PrivacyInfo.xcprivacy` nicht neu (Ressource, kein `info.properties`), Reihenfolge zu
`generate` daher unkritisch; Xcode kopiert die Datei unverändert ins Bundle (iOS `<App>.app/PrivacyInfo.xcprivacy`, Mac
`Contents/Resources/`). Beim späteren Umlegen des Schalters (eigener Schnitt) wandert `apply` in die Quelldatei und `check`
wird auf `true` fest – eine Zeile.
Alternativen: (A) nichts jetzt, Manifest erst mit dem Schalter-Schnitt — Konto-TestFlight-Bauten blieben falsch deklariert;
(B) sofort in die Quelldatei — einfachste Änderung, aber jeder Store-Bau 1.0.x (erhebt nichts) widerspräche dem Label
„Keine Daten erfasst“ und dem Text „ohne Konto kein Verkehr“. Keine ADR fällt bei keiner Variante.
Geräteliste: kein Pfad berührt (`PrivacyInfo.xcprivacy` wird im Repo nicht geändert; Skript, Workflow, Doku nicht gelistet).
Nachweis über einen Konto-TestFlight-Lauf (Archivprüfung grün mit `konto` an) und einen ohne `konto` – Workflow-Runs, kein Gerät.
Achtung: ein TestFlight-Lauf lädt einen Bau hoch; Läufe startet laut Zuständigkeit die Sitzung des Epics (#612) – Nachweis
alternativ per `workflow_dispatch` nur bis zur Archivprüfung prüfen (in der Spec klären, ob der Workflow einen Trockenlauf kennt).

### Dependencies
- Upstream: Python `plistlib` (Runner hat python3), `ACCOUNT_BUILD` aus `testflight.yml:38`.
- Downstream: ASC-Datenschutzangaben (Schnitt 3, Fragebogen im Web), Schalter-Schnitt nach #795/#796/#624.
- CI: `ci.yml:34` führt `scripts/test_*.py` automatisch aus.

### Open Questions
- [ ] Keine PO-Frage: Entscheidung „Schalter erst nach #795/#796/#624“ liegt vor (2026-11-17); die Wahl „Manifest folgt
      Schalter“ ist technisch und folgt dem bestehenden Muster.
- [ ] Technisch für die Spec: Nachweisweg ohne echten Upload (Trockenlauf-Eingabe vorhanden?).
