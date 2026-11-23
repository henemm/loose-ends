# Context: feat-625-s5b-schalter-quelle (#625 S5b)

## Request Summary
Schnitt S5b aus `docs/context/feat-625-konto-schalter.md` (PO-Entscheidung 2026-11-22): Die Verbindung zu Claude
(`LEAccountEnabled`) wird an der Quelle eingeschaltet, nicht mehr nur per CI-Eingang `konto`. Das Datenschutz-Manifest
der App trägt die drei Konto-Typen statisch. S5c baut danach die CI-Mechanik (`konto`, Marke, Store-Sperre) zurück.

## Related Files
| File | Relevance |
|------|-----------|
| `project.yml:73-86` | `LEAccountEnabled: false` + Kommentare (applesignin „without effect while off“, „Only a TestFlight run with konto“) |
| `LooseEnds/Info.plist:63` | Abbild von `project.yml` (`generate`), `test_info_plist_sync.py` hält beide gleich |
| `LooseEnds/PrivacyInfo.xcprivacy` | `NSPrivacyCollectedDataTypes` heute leer; gilt für iOS und Mac (ein Ziel) |
| `scripts/privacy_manifest.py` | `ACCOUNT_TYPES` (UserID, DeviceID, OtherUserContent; linked, kein Tracking, App Functionality), `apply`, `check --account`; Docstring beschreibt „Store-Bauten leer“ |
| `scripts/test_privacy_manifest.py:106-109` | `test_source_is_empty_and_passes_only_without_account` – hält die Quelle leer (muss umgedreht werden) |
| `scripts/test_asc_what_to_test.py:279-286` | `test_account_switch_is_a_false_bool` – hält `project.yml` und `Info.plist` auf `false` (muss umgedreht werden) |
| `scripts/test_app_store_datenschutzangaben.py` | hält die Fragebogen-Vorlage gleich `ACCOUNT_TYPES` – unberührt |
| `LooseEnds/Claude/AccountWiring.swift:10-15` | `isEnabled`: nur echtes Bool `true`; unverändert |
| `LooseEndsTests/AccountSectionTests.swift:142-152` | prüft `isEnabled` mit eingespeisten Dicts, nicht mit der Bundle-Info – unberührt |
| `.github/workflows/testflight.yml` | `konto` (Vorgabe an), plutil-Schalter, Archivprüfungen vergleichen mit `ACCOUNT_BUILD` – Rückbau in S5c |
| `CLAUDE.md` | mehrere Stellen „`project.yml` holds `false`“ – in S5b nachziehen |

## Existing Patterns
- Schalter an der Quelle in `project.yml`, `Info.plist` ist Abbild, CI-Schritt „Generate leaves the tree clean“.
- `PrivacyInfo.xcprivacy` ist von Hand gepflegt (nicht generiert); `privacy_manifest.py apply` erzeugt genau den Soll-Inhalt
  → die Quelle per `apply` schreiben, damit sie byte-gleich zu dem ist, was CI heute im Konto-Bau erzeugt.

## Dependencies
- Upstream: `ACCOUNT_TYPES` als eine Quelle; Fragebogen-Vorlage (S3).
- Downstream: jede Ausgabe der App (Xcode-Lauf, Simulator, TestFlight, Store) zeigt die Gruppe „Claude“; der Dienst nimmt
  seit S5a technisch alle Konten an, die Tür im Betrieb ist aber noch zu (`ALLOWED_APPLE_SUBS` = Hennings Konto) – ein
  fremdes Konto sieht „noch nicht freigeschaltet“. Die Tür öffnet erst S5d direkt vor dem Einreichen.
- UI-Tests laufen alle mit `--ui-testing` (dort ist die Gruppe ohnehin an, Speicher im Arbeitsspeicher, kein Netz).

## Existing Specs
- `docs/specs/feat-625-schnitt-2-privacy-manifest.md` (Manifest folgt dem Schalter), `feat-615-schnitt-4c2a-freischalten.md`
  (Konto-Bau-Mechanik), `docs/context/feat-625-konto-schalter.md` (Schnittplan S5a–S5d).

## Risks & Considerations
- **Kopplung mit S5c:** Nach S5b schlägt ein TestFlight-Lauf mit `konto` aus in der Archivprüfung fehl (Quelle an, Erwartung
  aus). Vorgabe ist `konto` an, und TestFlight-Läufe startet nur die Epic-Sitzung (#612, diese) → kein TestFlight-Lauf
  zwischen S5b und S5c. Ein `v*`-Tag-Lauf (immer `konto` aus) ebenso nicht.
- Kein Store-Bau zwischen S5b und S5d: 1.0.2 wird erst in S5d eingereicht; bis dahin bleibt 1.0.1 (ohne Konto) im Store.
- Geräteliste: `project.yml`, `Info.plist` → Stufe 3 über TestFlight (inhaltlich gleich den Konto-Bauten, die Henning seit
  Wochen hat); Gerätepunkt in der DoD, Ticket bleibt ohnehin offen bis S5d.
- Xcode-Läufe auf Hennings Mac (Debug, Hauptbundle) zeigen ab jetzt ebenfalls die Gruppe – gewollt.
- Umfang: 4 App-Dateien (`project.yml`, `Info.plist`, `PrivacyInfo.xcprivacy`, `privacy_manifest.py` Docstring) + `CLAUDE.md`
  + 2 Testdateien, ~30 LoC.

## Analysis

### Type
Feature (Schnitt S5b von #625, Schnittplan in `docs/context/feat-625-konto-schalter.md`, PO-Entscheidung 2026-11-22)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | `LEAccountEnabled: true`, Kommentare (Schalter + applesignin) auf „an der Quelle an“ |
| `LooseEnds/Info.plist` | MODIFY | Abbild per `./scripts/sim.sh generate` (`<true/>`) |
| `LooseEnds/PrivacyInfo.xcprivacy` | MODIFY | per `python3 scripts/privacy_manifest.py apply` die drei `ACCOUNT_TYPES` (byte-gleich zum heutigen CI-Konto-Bau) |
| `scripts/privacy_manifest.py` | MODIFY | nur Docstring (Quelle trägt die drei Typen; `check --account` bleibt) |
| `scripts/test_privacy_manifest.py` | MODIFY | `test_source_is_empty…` → Quelle trägt genau die drei Typen, besteht nur mit `--account true` |
| `scripts/test_asc_what_to_test.py` | MODIFY | `test_account_switch_is_a_false_bool` → `…_a_true_bool` (Bool `True` in `project.yml` und `Info.plist`) |
| `CLAUDE.md` | MODIFY | Zeile ~502 („`project.yml` holds `false` …“) und Testflight-`konto`-Absatz nachziehen |

### Scope Assessment
- Files: 4 App-/Konfig-Dateien + CLAUDE.md + 2 Testdateien
- Estimated LoC: ~+35/−10 (davon ~25 Manifest-Einträge)
- Risk Level: MEDIUM (wenig Code, aber jede Ausgabe der App zeigt ab jetzt die Gruppe „Claude“; Geräteliste berührt)

### Befunde (verifiziert 2026-11-23 gegen origin/main 04f697f)
- `testflight.yml`: Mit `konto` an (Vorgabe) setzt der Lauf `plutil … YES` und `privacy_manifest.py apply` – nach S5b beides
  No-op (apply ist idempotent, Test vorhanden). Archivprüfungen vergleichen mit `ACCOUNT_BUILD=true` → grün.
  Nur ein Lauf mit `konto` aus oder ein `v*`-Tag-Lauf (immer aus) scheitert danach an `account_switch`/`check --account false`.
  Das ist gewollt laut Plan und wird in S5c durch den Rückbau aufgelöst. Folge: S5b allein bricht keinen Lauf, den diese
  Sitzung startet; trotzdem S5c direkt danach, weil ein Konto-Bau weiter die Marke „KONTO-BAU – nie für den App Store“ trägt
  und `asc_store_version.py` ihn keiner Store-Version zuordnet.
- Unit-Test-Host (kein `--ui-testing`, `XCTestConfigurationFilePath` gesetzt): `forApp` baut ab jetzt ein `AccountState` mit
  `KeychainSessionStore`; `init` liest einmal den Schlüsselbund (`storedToken` → nil bei Fehler, z. B. −34018 unsigniert) →
  `signedOut`. `ClaudeSyncTrigger` ist unter Tests stumm, `PushWakeUp` nil. Kein Netz, kein Absturz erwartet; im Unit-Lauf belegen.
- UI-Tests: alle mit `--ui-testing`, dort war die Gruppe schon an → unverändert. Store-Bilder ebenso.
- `AccountWiring.isEnabled` und seine Tests prüfen eingespeiste Dicts → unberührt.
- Watch/Widgets/Share tragen kein `LEAccountEnabled` → unberührt.

### Technical Approach
Schalter an der Quelle setzen, `generate` das Abbild schreiben lassen, Manifest-Quelle mit dem vorhandenen `apply` füllen
(eine Quelle `ACCOUNT_TYPES`, keine Handkopie), die zwei Wächtertests umdrehen, CLAUDE.md nachziehen. Nachweis: Unit-Lauf,
Python-Tests, `generate` hinterlässt keinen Diff, Simulator ohne `--ui-testing` zeigt die Gruppe „Claude“ in den Einstellungen
(`test-proof` mit einem Start ohne `--ui-testing`-Gruppe-Zwang ist nicht möglich → Simulator-Lauf per `launch` + Screenshot).
Stufe 3 (Geräteliste: `project.yml`, `Info.plist`) über den nächsten TestFlight-Bau nach S5c; Gerätepunkt in der DoD.

### Alternative
- **Schalter bleibt in der CI (`konto`), nur die Store-Sperre fällt:** kein Quelländerung, aber Xcode-/Simulator-Läufe und
  jeder Tag-Lauf blieben ohne Konto, und zwei Wahrheiten (Quelle aus, Archiv an) blieben bestehen. Kippt die PO-Entscheidung
  vom 2026-11-22 (Schnittplan S5b/S5c). Verworfen.
- **S5b und S5c in einem PR:** sicherer gegen Zwischenstände, aber >250 LoC-Grenze nicht berührt, Prüfung je Schnitt klarer.
  Empfehlung: getrennte PRs, S5c unmittelbar danach, kein TestFlight-Lauf dazwischen.

### Open Questions
- keine PO-Frage (Produktentscheidung am 2026-11-22 getroffen)
