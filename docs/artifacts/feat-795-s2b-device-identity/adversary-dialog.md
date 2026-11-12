# Adversary Dialog — feat-795-s2b-device-identity
Spec: docs/specs/feat-795-schnitt-2b-device-identity.md
Datum: 2026-11-12 12:32

## Checkliste
- [x] **AC-1:** Erste Erzeugung: GIVEN ein `FakeKeychain`, dessen `copyMatching` `errSecItemNotFound` meldet und dessen `add` Erfolg meldet WHEN `current()` läuft THEN wird genau einmal gelesen und genau einmal `add` gerufen, kein `update`, kein `delete`; die Rückgabe ist eine UUID, und der an `add` übergebene Wert ist deren `uuidString` als UTF-8 (Test `firstCallCreatesAndStoresOnce`).
- [x] **AC-2:** Eintragsform: GIVEN dieselbe Lage wie AC-1 THEN trägt das `add` `service` `com.henning.looseends.device`, `account` `device`, die Klasse `kSecClassGenericPassword`, `kSecUseDataProtectionKeychain` gleich `true`, `kSecAttrAccessible` gleich `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` und kein `kSecAttrSynchronizable` gleich `true`; die Leseabfrage trägt dieselben `service`/`account` (Test `entryUsesDeviceOnlyAccessAndOwnService`).
- [x] **AC-3:** Vorhandene Kennung: GIVEN `copyMatching` liefert Erfolg mit den UTF-8-Daten einer gültigen UUID WHEN `current()` zweimal läuft THEN ist die Rückgabe beide Male genau diese UUID, es wird nie `add`, `update` oder `delete` gerufen (Test `storedIdentityIsReturnedUnchanged`).
- [x] **AC-4:** Kein Zwischenspeicher: GIVEN dieselbe Lage wie AC-3 WHEN `current()` zweimal läuft THEN liest der Schlüsselbund zweimal (zwei `copyMatching`-Aufrufe), die zweite Antwort zählt (Test `noInMemoryCache`, mit zwei verschiedenen eingespielten Werten).
- [x] **AC-5:** Lesefehler erzeugt nie eine Kennung: GIVEN `copyMatching` meldet -34018, -25308 (`errSecInteractionNotAllowed`) oder einen anderen Fehlerstatus WHEN `current()` läuft THEN wirft es `DeviceIdentityError.keychain(<Status>)` mit genau diesem Status und ruft nie `add` (Test `readErrorThrowsAndNeverCreates`, Argumente je Status).
- [x] **AC-6:** Kaputter Eintrag: GIVEN `copyMatching` liefert Erfolg mit Daten, die keine UUID sind (Text `nicht-eine-uuid`, leere Daten, Daten, die kein UTF-8 sind) WHEN `current()` läuft THEN wirft es `DeviceIdentityError.corruptData` und ruft nie `add`, `update` oder `delete` (Test `corruptEntryThrowsAndIsNotReplaced`, Argumente je Fall).
- [x] **AC-7:** Schreibfehler: GIVEN `copyMatching` meldet `errSecItemNotFound` und `add` meldet einen Fehlerstatus (außer `errSecDuplicateItem`, z. B. -34018 oder -25308) WHEN `current()` läuft THEN wirft es `keychain(<Status>)`, es wird nicht erneut gelesen und kein zweites Mal `add` gerufen (Test `addErrorThrows`, Argumente je Status).
- [x] **AC-8:** Gleichzeitiges Erzeugen: GIVEN `copyMatching` meldet zuerst `errSecItemNotFound`, `add` meldet `errSecDuplicateItem`, das zweite `copyMatching` liefert eine gespeicherte UUID WHEN `current()` läuft THEN ist die Rückgabe die gespeicherte UUID (nicht die selbst erzeugte), es gab genau zwei Lesungen, genau ein `add` und kein `update` (Test `duplicateReturnsStoredIdentity`).
- [x] **AC-9:** Duplikat ohne lesbare Gegenstelle: GIVEN `add` meldet `errSecDuplicateItem` und das zweite `copyMatching` meldet `errSecItemNotFound` oder einen Fehlerstatus oder kaputte Daten WHEN `current()` läuft THEN wirft es `keychain(<Status>)` beziehungsweise `corruptData`; es wird nie ein drittes Mal gelesen und nie ein zweites Mal `add` gerufen (Test `duplicateThenUnreadableThrows`, Argumente je Fall).
- [x] **AC-10:** Keine Geheimnisse in Fehlern: GIVEN jeder Fehlerfall aus AC-5 bis AC-9 THEN enthält `String(describing: error)` keine UUID-Zeichenkette (weder die gespeicherte noch die erzeugte) und nur den Fallnamen und gegebenenfalls die Statuszahl (Test `errorsCarryNoIdentity`).
- [x] **AC-11:** Zugang nur aus `signedIn`: GIVEN ein `AccountState` im Status `signedOut`, `signingIn`, `deleting`, `notAllowed` oder `retryLater` WHEN `withSession` läuft THEN ist die Rückgabe `nil`, die Closure läuft nicht und der `Wire`-Transport hat keine Anfrage erhalten (Test `withSessionOnlyWhenSignedIn`, Argumente je Status).
- [x] **AC-12:** Token fehlt oder unlesbar: GIVEN `signedIn`, dessen Store inzwischen keinen Token hält oder dessen `load` wirft WHEN `withSession` läuft THEN ist die Rückgabe `nil`, die Closure läuft nicht, nichts wurde gesendet (Test `withSessionWithoutReadableTokenIsNil`).
- [x] **AC-13:** Erfolgsweg: GIVEN `signedIn` mit gespeichertem Token WHEN `withSession` läuft THEN erhält die Closure den `ServiceClient` und genau den frisch gelesenen Token und deren Ergebnis ist die Rückgabe; ein nach dem Anmelden im Store ersetzter Token kommt bei der nächsten Nutzung an (Test `withSessionPassesFreshToken`).
- [x] **AC-14:** Andere Fehler bleiben Sache des Aufrufers: GIVEN `signedIn` und die Closure wirft `ServiceError.tooManyRequests`, `.refused`, `.unavailable`, `.rejected(500)`, `.invalidResponse` oder `CancellationError` WHEN `withSession` läuft THEN wird genau dieser Fehler weitergeworfen, der Store hält den Token weiter, der Status bleibt `signedIn` (Test `withSessionKeepsSessionOnOtherErrors`, Argumente je Fehler).
- [x] **AC-15:** 401 räumt die Sitzung: GIVEN `signedIn` und die Closure wirft `ServiceError.unauthorized`, der Store hält noch denselben Token WHEN `withSession` läuft THEN ist danach der Store leer, der Status `signedOut`, und `unauthorized` wurde weitergeworfen (Test `unauthorizedClearsSameToken`).
- [x] **AC-16:** 401 zu einem alten Token räumt eine neuere Sitzung nicht: GIVEN `signedIn` und während die Closure läuft wird im Store ein anderer Token gespeichert, danach wirft sie `unauthorized` WHEN `withSession` zurückkehrt THEN hält der Store weiter den neuen Token, der Status ist `signedIn`, `unauthorized` wurde weitergeworfen (Test `unauthorizedKeepsNewerToken`, mit dem Hook des `Wire`-Transports).
- [x] **AC-17:** 401 überschreibt keinen laufenden Ablauf: GIVEN `signedIn` und während die Closure läuft wechselt der Status auf `signingIn` oder `deleting` (Ablauf aus dem Hook), danach wirft sie `unauthorized` WHEN `withSession` zurückkehrt THEN bleibt der Status der des laufenden Ablaufs, `unauthorized` wurde weitergeworfen (Test `unauthorizedNeverOverwritesRunningFlow`, Argumente je Status).
- [x] **AC-18:** Keine Oberfläche berührt: GIVEN jeder Fall aus AC-12 bis AC-17 THEN ist `lastProblem` danach unverändert (`nil`, wenn es vorher `nil` war) (Test `withSessionLeavesLastProblemAlone`).
- [x] **AC-19:** `deleteAccount` unverändert: GIVEN die vorhandenen Tests zu `deleteAccount` (`deleteFailures` mit 401 bei gleichem Token räumt, `staleUnauthorized` mit 401 bei neuerem Token räumt nicht) THEN laufen sie unverändert grün, nach der Verallgemeinerung von `dropSession` (Beleg: die gesamte Suite `AccountStateTests` grün, kein bestehender Test geändert).
- [x] **AC-20:** Nichts wird aufgerufen: GIVEN die ganze Unit-Suite WHEN sie läuft THEN ist sie grün, und `rg "DeviceIdentity|withSession" LooseEnds LooseEndsWatch LooseEndsWidgets LooseEndsShare Shared` findet außerhalb von `DeviceIdentity.swift` und `AccountState.swift` keinen Treffer (Beleg im Abschlussbericht; Test: bestehender `creatingSendsNothing` in `ServiceClientTests` und `AccountWiring`-Tests grün).

## Dialog

### Runde 1
**Adversary:** Sonde: current() bei Lesefehler/-25308 wirft vor add (Z.25); Daten nil bei Erfolg ergibt corruptData (Z.61); Duplikat: genau eine Zweitlesung, kein update (Z.29-32); Fehler tragen nur Fallname/Status (Z.5). 401 in withSession: dropSession vergleicht Token (Z.130), Status wird nur bei noch signedIn gesetzt (Z.122), also kein Ueberschreiben von signingIn/deleting, neuere Sitzung bleibt. deleteAccount nutzt dropSession(token, during: "delete") unveraendert. Logzeile traegt nur StaticString-Anlass, kein Token/UUID. Swift 6: withSession auf @MainActor-Klasse, T: Sendable, kein Datenrennen. Tests: DeviceIdentityTests und AccountStateTests je Test Succeeded; rg-Aufrufersuche erneut: keine Treffer ausserhalb beider Dateien.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Nachbohren: Closure laeuft waehrend signOut + neuem signIn mit Token T2, dann 401 zu T1: stored != token, Status .signedIn (Z.130-131), korrekt. Store leer waehrend Closure und 401: dropSession liefert .signedOut, Status schon signedOut, kein Schaden. CancellationError wird nicht verschluckt (nur unauthorized gefangen). lastProblem wird in withSession nicht angefasst. DeviceIdentity ist zustandslos, kein Zwischenspeicher. Vorbehalt (LOW, kein Finding): parametrisierte Swift-Testing-Faelle erscheinen im xcbeautify-Log nicht einzeln, die Suite meldet aber bestanden. Keine Gegenbeispiele gefunden.
**Implementierer:** (nicht beteiligt)

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:22
  Evidence: Pfad gelesen, Test in DeviceIdentityTests gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:39
  Evidence: Pfad gelesen, Test in DeviceIdentityTests gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:24
  Evidence: Pfad gelesen, Test in DeviceIdentityTests gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:23
  Evidence: Pfad gelesen, Test in DeviceIdentityTests gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:25
  Evidence: Pfad gelesen, Test in DeviceIdentityTests gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:61
  Evidence: Pfad gelesen, Test in DeviceIdentityTests gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:29
  Evidence: Pfad gelesen, Test in DeviceIdentityTests gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:30
  Evidence: Pfad gelesen, Test in DeviceIdentityTests gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:31
  Evidence: Pfad gelesen, Test in DeviceIdentityTests gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:5
  Evidence: Pfad gelesen, Test in DeviceIdentityTests gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: LooseEnds/Claude/AccountState.swift:117
  Evidence: withSession/dropSession gelesen; AccountStateTests-Suite gruen; AC-20: rg ausserhalb beider Dateien ohne Treffer, Gesamtsuite gruen (test-green-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: LooseEnds/Claude/AccountState.swift:117
  Evidence: withSession/dropSession gelesen; AccountStateTests-Suite gruen; AC-20: rg ausserhalb beider Dateien ohne Treffer, Gesamtsuite gruen (test-green-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: LooseEnds/Claude/AccountState.swift:118
  Evidence: withSession/dropSession gelesen; AccountStateTests-Suite gruen; AC-20: rg ausserhalb beider Dateien ohne Treffer, Gesamtsuite gruen (test-green-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: LooseEnds/Claude/AccountState.swift:119
  Evidence: withSession/dropSession gelesen; AccountStateTests-Suite gruen; AC-20: rg ausserhalb beider Dateien ohne Treffer, Gesamtsuite gruen (test-green-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: LooseEnds/Claude/AccountState.swift:121
  Evidence: withSession/dropSession gelesen; AccountStateTests-Suite gruen; AC-20: rg ausserhalb beider Dateien ohne Treffer, Gesamtsuite gruen (test-green-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: LooseEnds/Claude/AccountState.swift:130
  Evidence: withSession/dropSession gelesen; AccountStateTests-Suite gruen; AC-20: rg ausserhalb beider Dateien ohne Treffer, Gesamtsuite gruen (test-green-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: LooseEnds/Claude/AccountState.swift:122
  Evidence: withSession/dropSession gelesen; AccountStateTests-Suite gruen; AC-20: rg ausserhalb beider Dateien ohne Treffer, Gesamtsuite gruen (test-green-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-18
  Code reference: LooseEnds/Claude/AccountState.swift:121
  Evidence: withSession/dropSession gelesen; AccountStateTests-Suite gruen; AC-20: rg ausserhalb beider Dateien ohne Treffer, Gesamtsuite gruen (test-green-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-19
  Code reference: LooseEnds/Claude/AccountState.swift:104
  Evidence: withSession/dropSession gelesen; AccountStateTests-Suite gruen; AC-20: rg ausserhalb beider Dateien ohne Treffer, Gesamtsuite gruen (test-green-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-20
  Code reference: LooseEnds/Claude/AccountState.swift:114
  Evidence: withSession/dropSession gelesen; AccountStateTests-Suite gruen; AC-20: rg ausserhalb beider Dateien ohne Treffer, Gesamtsuite gruen (test-green-output.txt).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: DeviceIdentityTests und AccountStateTests bestanden, 0 failed; Gesamtsuite gruen; 3 von 6 Messstrecken uebersprungen (fehlende Korpusdateien, unabhaengig vom Schnitt)
Edge cases: alle geprueft, keine gebrochen
Regressions: keine
Checklist: 20/20 points proven

## Geprüfte Dateien

- sha256:538b7d5f583f3011799b600a05170fc1baeb481e921b41f65c54e245319e5588  LooseEnds/Claude/AccountState.swift
- sha256:7b759c80fdc89cc56eba84c6911495b8d643cbf1c35a5eb9cad3538506bebcab  LooseEnds/Claude/DeviceIdentity.swift

## Prüfbasis

- base: 9722328da3505a07dacdf00ff45239a8626461d5
- blob:0cd311d22c2959371ede4a66ef9693028eb33457  LooseEnds/Claude/AccountState.swift
- blob:27dcefe6f4981ed8d16696017caa3ef2002568d2  LooseEnds/Claude/DeviceIdentity.swift
