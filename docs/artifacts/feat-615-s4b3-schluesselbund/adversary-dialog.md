# Adversary Dialog — feat-615-s4b3-schluesselbund
Spec: docs/specs/feat-615-schnitt-4b3-schluesselbund.md
Datum: 2026-11-09 12:13

## Checkliste
- [x] **AC-1:** Abfragen: Jede der vier Abfragen (add, read, update-Suche, delete) enthält `kSecClass == kSecClassGenericPassword`, `kSecAttrService == "com.henning.looseends.session"`, das feste Konto und `kSecUseDataProtectionKeychain == true`; keine enthält `kSecAttrSynchronizable`. Die Add-Attribute tragen zusätzlich `kSecAttrAccessible == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` und `kSecValueData` mit dem Token als UTF-8; die Lese-Abfrage `kSecReturnData == true` und `kSecMatchLimitOne`; die Update-Änderungsattribute enthalten **nur** den Schlüssel `kSecValueData`. Test: „keychain: abfragen“.
- [x] **AC-2:** Statusabbildung (tabellengetrieben): `save` mit Add-Status `errSecSuccess` ist Erfolg und löst kein Update und kein Delete aus; Add-Status `-34018` (`errSecMissingEntitlement`), `errSecInteractionNotAllowed` und ein beliebiger anderer Wert werfen `SessionStoreError.keychain(<Status>)`. Test: „keychain: statusabbildung save“.
- [x] **AC-3:** Ablauf `save` bei Duplikat: Add liefert `errSecDuplicateItem` → genau ein Update mit der Suchabfrage `base` und den Änderungsattributen nur `kSecValueData` (neues Token); Update `errSecSuccess` ergibt Erfolg; die aufgezeichnete Folge ist genau Add, Update, ohne Delete. Test: „keychain: save duplikat wird update“.
- [x] **AC-4:** Rennen nach Duplikat: Add `errSecDuplicateItem`, Update `errSecItemNotFound` wirft `keychain(errSecItemNotFound)`; es gibt keinen zweiten Add und kein zweites Update (genau zwei Aufrufe). Ein anderer Update-Fehler (z. B. `-34018`) wirft `keychain(<Status>)`. Test: „keychain: update ohne treffer ist fehler ohne retry“.
- [x] **AC-5:** `load`: NotFound → `nil` (kein Fehler); Erfolg mit den Daten von `"T1"` → `"T1"`; jeder andere Status (`-34018`, `errSecInteractionNotAllowed`, beliebig) wirft `keychain(<Status>)` und liefert nie `nil`. Test: „keychain: load statusabbildung“.
- [x] **AC-6:** `clear`: Erfolg und NotFound → kein Fehler; jeder andere Status (`-34018`, beliebig) wirft `keychain(<Status>)`; die Abfrage ist die Delete-Abfrage aus AC-1. Test: „keychain: clear statusabbildung“.
- [x] **AC-7:** Dekodierung: Lese-Erfolg mit leeren Daten, mit `nil`-Daten und mit Daten ohne gültiges UTF-8 (z. B. `0xFF 0xFE`) wirft `SessionStoreError.corruptData`, nie `nil`, nie einen Absturz. Test: „keychain: leere und ungueltige daten“.
- [x] **AC-8:** `-34018` bleibt Fehler: für `save`, `load` und `clear` liefert Status `-34018` jeweils `keychain(-34018)`, und `load` ergibt in keinem Fall `nil`. Test: „keychain: fehlende berechtigung ist kein nil“.
- [x] **AC-9:** Keine Preisgabe: Der Marker `SECRET-TOKEN` als Token in `save` und als Daten in `load` taucht in `String(describing:)` keines geworfenen Fehlers auf (alle Fehlerpfade aus AC-2 bis AC-7). Test: „keychain: fehler ohne token“.
- [x] **AC-10:** F4: `ServiceClient` mit `FakeTransport(.fail(URLError(.cancelled)))` wirft für alle drei Routen (`signIn`, `logout`, `delete`) `CancellationError` (nicht `ServiceError.unavailable`); die übrigen Codes `notConnectedToInternet`, `timedOut`, `cannotConnectToHost` bleiben `ServiceError.unavailable`, eine echte `CancellationError` aus dem Transport bleibt `CancellationError`. Test: „serviceclient: abbruch ist cancellation“ (in `ServiceClientTests.swift`); die bestehenden Tests dort bleiben grün.
- [x] **AC-11:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `LooseEnds/Claude/KeychainSessionStore.swift`, `LooseEnds/Claude/SessionStore.swift`, `LooseEnds/Claude/ServiceClient.swift`, `LooseEndsTests/KeychainSessionStoreTests.swift`, `LooseEndsTests/ServiceClientTests.swift` und `CLAUDE.md` (kein `project.yml`, keine Entitlements, keine `Info.plist`, nichts unter `Shared/` oder `server/`, kein Aufrufer des Stores); `grep -nE 'print\(' LooseEnds/Claude/KeychainSessionStore.swift` ohne Treffer; keine Funktion über 50 Zeilen. Beleg: einmalig in `/60-validate` im Validierungsprotokoll, kein Test gegen `origin/main`.
- [x] **AC-12:** Doku: Der Eintrag „`LooseEnds/Claude`“ in `CLAUDE.md` nennt `SessionStoring`, `KeychainSessionStore` und `AccountState` (jeweils mit „noch ohne Aufrufer“). Beleg: einmalig in `/60-validate` per `grep -n 'KeychainSessionStore' CLAUDE.md` im Validierungsprotokoll.
- [x] **AC-13:** Regression: `./scripts/sim.sh sim-unit` (alle Unit-Tests) ist grün; `./scripts/sim.sh build` baut die App mit der neuen Datei (nach `generate`) ohne Fehler und ohne neue Warnungen aus den geänderten oder neuen Dateien. Beleg: Lauf im Validierungsprotokoll.

## Dialog

### Runde 1
**Adversary:** Alle AC einzeln gegen Code und Tests geprueft. Tests: KeychainSessionStoreTests und ServiceClientTests gruen (docs/artifacts/feat-615-s4b3-schluesselbund/adversary-test-output.txt, je exit 0, Test Succeeded). Testdatei-Diff gegen 1e3bd75: nur `Call: @unchecked Sendable`, keine Assertion geschwaecht.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Claude/KeychainSessionStore.swift:35
  Evidence: `base` traegt Class, Service, Account, kSecUseDataProtectionKeychain=true; add (Z.44), read (Z.51), update-Suche und delete (Z.84/95) nutzen base bzw. base+; kein kSecAttrSynchronizable im Code. Update-Attribute nur kSecValueData (Z.56). Test queries() prueft alle vier Abfragen und `Array(attributes.keys) == [kSecValueData]`.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Claude/KeychainSessionStore.swift:81
  Evidence: Add-Status != Duplikat geht an check(): Erfolg ohne Folgeaufruf, sonst keychain(status); Test saveStatus (tabellengetrieben, -34018, InteractionNotAllowed, InternalComponent, 4711) erwartet ops == [.add].
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/KeychainSessionStore.swift:84
  Evidence: Duplikat -> genau ein update(base, value(token)), kein delete. Test duplicateBecomesUpdate: ops == [.add,.update], update.query.count == 4, attributes.count == 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/KeychainSessionStore.swift:84
  Evidence: Update-Status NotFound/-34018/4711 -> keychain(status), keine weitere Operation (ops == [.add,.update]).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Claude/KeychainSessionStore.swift:87
  Evidence: NotFound -> nil; Erfolg -> decode; sonst check wirft. Test loadStatus deckt "T1", NotFound, alle Fehlerstatus (auch mit gelieferten Daten).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Claude/KeychainSessionStore.swift:94
  Evidence: Erfolg und NotFound ohne Fehler, sonst keychain(status); Test clearStatus prueft zusaetzlich base-Abfrage der Delete-Operation.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Claude/KeychainSessionStore.swift:64
  Evidence: decode wirft corruptData fuer nil, leer und ungueltiges UTF-8 (0xFF 0xFE); Test corruptData mit genau diesen drei Argumenten.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Claude/KeychainSessionStore.swift:59
  Evidence: check() kennt nur errSecSuccess als Nicht-Fehler, -34018 wird nie zu nil; load gibt nil nur bei errSecItemNotFound (Z.89). Test missingEntitlementIsNoNil fuer save/load/clear, load auch mit Daten.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Claude/SessionStore.swift:13
  Evidence: SessionStoreError-Faelle tragen nur OSStatus bzw. nichts, strukturell kein Token; Test errorsCarryNoToken zaehlt 17 Fehler (4*4+1) und prueft String(describing:). Keine Logger-/print-Aufrufe in KeychainSessionStore.swift (grep leer).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Claude/ServiceClient.swift:90
  Evidence: `catch let error as URLError where error.code == .cancelled` steht vor `catch is URLError` und wirft CancellationError; Test cancelledIsCancellation (3 Routen), transportErrors haelt die anderen Codes auf unavailable und echte CancellationError durchgereicht.
  Status: CONFIRMED

AC-11 (nur vermerkt, einmaliger Beleg in /60-validate): Die Dateimenge ausserhalb docs und .claude gegen origin/main ist CLAUDE.md, ServiceClient.swift, SessionStore.swift, KeychainSessionStoreTests.swift, ServiceClientTests.swift (F4-Test liegt im RED-Commit 1e3bd75) plus unversioniert KeychainSessionStore.swift; kein project.yml, keine Entitlements/Info.plist, nichts unter Shared/ oder server/; kein Aufrufer des Stores (grep ausserhalb der Datei leer); kein print/try?; alle Funktionen deutlich unter 50 Zeilen (Datei 99 Zeilen). Nichts spricht dagegen.
AC-12 (nur vermerkt): CLAUDE.md-Eintrag nennt SessionStoring, KeychainSessionStore (no caller yet), AccountState (no caller yet). Nichts spricht dagegen.
AC-13: Die Klassen-Laeufe sind gruen; der volle Lauf liegt in test-green-output.txt (Orchestrator belegt ihn in /60-validate). Keine Warnung/Fehler im Klassenlauf.

**Implementierer:** (nicht anwesend, Kontextisolation)

### Runde 2
**Adversary:** Mutationsgegenproben (Datei vorher gesichert, danach exakt zurueckkopiert, `cmp` identisch):
- M1 Duplikat-Zweig: update ersetzt durch delete+add. Ergebnis rot (exit 65): "keychain: abfragen", "save duplikat wird update", "update ohne treffer ist fehler ohne retry" (mut1.txt).
- M2 -34018 in load als nil: rot: "load statusabbildung", "fehlende berechtigung ist kein nil", "fehler ohne token" (mut2.txt).
- M3 F4: `.cancelled` -> `.badURL` im catch: "serviceclient: abbruch ist cancellation" rot, exit 65 (mut3.txt).
Zusaetzliche Randpruefungen: SystemKeychain.copyMatching liefert `result as? Data` (Erfolg ohne Daten -> corruptData); kein kSecAttrSynchronizable irgendwo; Store ist ungenutzt (kein Regressionspfad, ServiceClient-Aenderung nur im Fehlerpfad). Beobachtung ohne Spec-Verstoss: `save("")` legt einen leeren Eintrag an, der beim Laden corruptData ergibt.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Claude/KeychainSessionStore.swift:81
  Description: save akzeptiert einen leeren Token und schreibt leere Daten, die load als corruptData meldet.
  Spec requirement: AC-7 — leere Daten sind corruptData (nur Lesepfad spezifiziert)
  Conflict: Kein Verstoss; Asymmetrie zwischen save und load.
  Remediation: In 4c beim Aufrufer sicherstellen, dass nie ein leeres Token gespeichert wird (ServiceClient lehnt leere sessionToken bereits ab).

Dateiabdeckung:
  Code reference: LooseEnds/Claude/KeychainSessionStore.swift:73
  Code reference: LooseEnds/Claude/SessionStore.swift:13
  Code reference: LooseEnds/Claude/ServiceClient.swift:82
  Code reference: LooseEndsTests/KeychainSessionStoreTests.swift:9
  Code reference: LooseEndsTests/ServiceClientTests.swift:127
**Implementierer:** (nicht anwesend)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

Alle AC-1 bis AC-10 mit Code und Test belegt, AC-11/AC-12 ohne Gegenbefund (einmaliger Beleg in /60-validate), AC-13 Klassenlaeufe gruen. Drei Mutationsgegenproben machen die Tests rot. Tests: KeychainSessionStoreTests und ServiceClientTests bestanden, 0 fehlgeschlagen. Einziger Befund F001 LOW (informativ).

## Geprüfte Dateien

- sha256:4344ca5891c5694a7dc10d821ec8394ea448700d5cdc21342e65b0d7645cd921  LooseEnds/Claude/KeychainSessionStore.swift
- sha256:684fafbdcc3c127ef2abba17f942385471a7d49cc185719f249d2f9cd9ea1a31  LooseEnds/Claude/ServiceClient.swift
- sha256:052047d0938f6c1a6a440ff7901842a68b7803f2ec38f097b079f593440d8c5c  LooseEnds/Claude/SessionStore.swift
- sha256:8bd62edb4cc47b64a50c64b72fbe50ebf4eb0eae52bc77065eaf854697ad7232  LooseEndsTests/KeychainSessionStoreTests.swift
- sha256:efe5f514ec0becdd4bd536437ff7ab93f3ee703316be7660fe5ea1fc456c2f69  LooseEndsTests/ServiceClientTests.swift

## Prüfbasis

- base: 8967580370673d60b5633c6185a5c4c2b5cdf7a6
- blob:7e3cadcece5cdfffcad3995f800fd580a8aa61a3  LooseEnds/Claude/KeychainSessionStore.swift
- blob:4af7af7ef49d55bb64432308ff79227cf55368da  LooseEnds/Claude/ServiceClient.swift
- blob:103ab9926fef9e6b4028cb55a79afc8b8071f721  LooseEnds/Claude/SessionStore.swift
- blob:2250f8d57b2486b7ba068b8a0a5c7bdb65c07bed  LooseEndsTests/KeychainSessionStoreTests.swift
- blob:98b936a7045fcb77c5f08850640681dee77a1d09  LooseEndsTests/ServiceClientTests.swift
