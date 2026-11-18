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
