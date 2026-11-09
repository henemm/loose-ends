# Adversary Dialog — feat-615-s4b2-sitzung
Spec: docs/specs/feat-615-schnitt-4b2-sitzung.md
Datum: 2026-11-09 10:01

## Checkliste
- [x] **AC-1:** Start mit gespeichertem Token: `AccountState(client:store:)` ergibt Status `signedIn`, `lastProblem == nil`, null Anfragen am Transport. Test: „account: start mit token“.
- [x] **AC-2:** Start ohne Token ergibt `signedOut`; ein Lesefehler der Ablage ergibt ebenfalls `signedOut`; beide Fälle mit null Anfragen. Test: „account: start ohne token und bei lesefehler“.
- [x] **AC-3:** `beginSignIn` aus `signedOut`, `notAllowed` und `retryLater` (letztere beiden über einen vorangegangenen Lauf hergestellt) gibt einen 64 Zeichen langen Hex-String in Kleinbuchstaben zurück und setzt Status `signingIn`; aus `signingIn`, `signedIn` und `deleting` wirft es `AccountError.notPossibleNow` und lässt Status und offene Nonce unverändert. Test: „account: beginsignin nur aus erlaubten zustaenden“.
- [x] **AC-4:** Das von `beginSignIn` Zurückgegebene ist der Hash der Nonce, die `completeSignIn` sendet: Der Anfragekörper von `POST /auth/apple` trägt `nonce` (roh, 43 Zeichen) mit `Nonce.hash(<nonce>) ==` Rückgabewert von `beginSignIn`, dazu die übergebenen Werte `identityToken` und `code` und sonst nichts. Zwei `beginSignIn`-Läufe liefern verschiedene Werte. Test: „account: body traegt rohe nonce zum hash“.
- [x] **AC-5:** `completeSignIn` ohne vorheriges `beginSignIn` sendet nichts und ändert den Status nicht (aus `signedOut` und aus `signedIn`); die Nonce wird verbraucht: ein zweiter `completeSignIn` nach einem ersten (egal wie ausgegangen) sendet keine zweite Anfrage. Test: „account: completesignin ohne nonce und nonce einmalig“.
- [x] **AC-6:** Erfolg: 200 mit `{"sessionToken":"T1"}` speichert `T1` in der Ablage und setzt dann Status `signedIn`; `lastProblem == nil`. Test: „account: anmelden speichert und ist angemeldet“.
- [x] **AC-7:** Speicherfehler beim Speichern: Der Dienst antwortet 200, `save` wirft; Ergebnis Status `signedOut`, Ablage ohne Token (nie ein Zwischenzustand `signedIn`: der Test prüft den Status nach dem Aufruf und dass die Ablage leer ist). Test: „account: speicherfehler ergibt abgemeldet“.
- [x] **AC-8:** Fehlerabbildung `completeSignIn` (tabellengetrieben, Ablage bleibt in jedem Fall leer): `unauthorized` → `notAllowed`; `unavailable` (auch als `URLError` aus dem Transport) → `retryLater`; `rejected(400)`, `rejected(500)` und `invalidResponse` (200 mit leerem Token) → `signedOut`; `CancellationError` aus dem Transport → `signedOut` und `lastProblem == nil`. Test: „account: anmelden fehlerabbildung“.
- [x] **AC-9:** `cancelSignIn` aus `signingIn` mit offener Nonce ergibt `signedOut` und verwirft die Nonce (ein folgender `completeSignIn` sendet nichts); in `signedOut`, `signedIn` und während die Anfrage von `completeSignIn` läuft ist es wirkungslos (Status und Ergebnis der laufenden Anmeldung unverändert). Test: „account: cancelsignin“.
- [x] **AC-10:** `signOut` mit Token: Zum Zeitpunkt der Dienstanfrage ist die Ablage bereits leer und der Status bereits `signedOut` (Haken-Transport prüft beides); genau eine Anfrage `POST /auth/logout` mit `Authorization: Bearer <Token>`. Ob der Dienst 204, 401, 503 oder `CancellationError` liefert: Status bleibt `signedOut`, `lastProblem == nil`. Test: „account: signout lokal zuerst dann dienst“.
- [x] **AC-11:** `signOut` ohne Token (Ablage leer oder Lesefehler) sendet null Anfragen und endet in `signedOut`; schlägt `clear` fehl, ist der Status trotzdem `signedOut` und die Anfrage `POST /auth/logout` wird dennoch gesendet. Test: „account: signout ohne token und bei loeschfehler“.
- [x] **AC-12:** `deleteAccount` mit Token, Antwort 204: genau eine Anfrage `POST /auth/delete` mit `Authorization: Bearer <Token>`, danach Ablage leer, Status `signedOut`, `lastProblem == nil`. Aus jedem anderen Status als `signedIn` (`signedOut`, `signingIn`, `notAllowed`, `retryLater`, `deleting`) sendet es nichts; ist die Ablage bei Status `signedIn` leer oder nicht lesbar, sendet es nichts und endet in `signedOut`. Test: „account: konto loeschen erfolg und nur aus signedin“.
- [x] **AC-13:** Fehlerabbildung `deleteAccount` (tabellengetrieben): `unauthorized` → Ablage leer, Status `signedOut`; `unavailable`, `rejected(500)` und `invalidResponse` → Status `signedIn`, Token weiter in der Ablage, `lastProblem == .retryLater`; `CancellationError` → Status `signedIn`, Token weiter in der Ablage, `lastProblem == nil`. Ein folgender erfolgreicher Löschversuch setzt `lastProblem` zurück. Test: „account: konto loeschen fehlerabbildung“.
- [x] **AC-14:** Veraltete 401: Wechselt während der Löschanfrage das gespeicherte Token von `T1` auf `T2` (Haken-Transport ersetzt es in der Ablage vor der Antwort 401), bleibt `T2` in der Ablage stehen und der Status ist `signedIn`; nur wenn die Ablage noch `T1` hält, wird sie geleert. Test: „account: veraltete 401 loescht keine neue sitzung“.
- [x] **AC-15:** Doppelaufrufe: Läuft eine Anfrage (Haken-Transport hält sie an), erzeugen ein zweites `completeSignIn` bzw. ein zweites `deleteAccount` sowie `signOut` keine zweite Anfrage und `beginSignIn` wirft `notPossibleNow`; am Ende hat der Transport genau eine Anfrage gesehen und der Zustand entspricht dem Ergebnis der ersten. Test: „account: doppelaufrufe waehrend anfrage“.
- [x] **AC-16:** Keine Preisgabe: Weder `lastProblem` noch `status` noch ein geworfener `AccountError` enthalten Token oder Nonce (`String(describing:)` mit Markern wie `"SECRET-TOKEN"` in Token und Dienstantwort). Der Kern ruft `print` nirgends auf und loggt nur Fallnamen; Beleg einmalig in `/60-validate` im Protokoll: `grep -nE 'print\(' LooseEnds/Claude/SessionStore.swift LooseEnds/Claude/AccountState.swift` ohne Treffer und Sichtung jeder `logger.`-Zeile auf Token-, Nonce- und Körperfreiheit (kein dauerhafter Test für den grep-Teil). Test (Marker-Teil): „account: zustand ohne token und nonce“.
- [x] **AC-17:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `LooseEnds/Claude/SessionStore.swift`, `LooseEnds/Claude/AccountState.swift` und `LooseEndsTests/AccountStateTests.swift` (kein `project.yml`, keine Entitlements, keine `Info.plist`, nichts unter `Shared/` oder `server/`, keine Schlüsselbund-Anbindung); keine Funktion über 50 Zeilen. Beleg: einmalig in `/60-validate` im Validierungsprotokoll, kein Test gegen `origin/main`.
- [x] **AC-18:** Regression: `./scripts/sim.sh sim-unit` (alle Unit-Tests) ist grün; `./scripts/sim.sh build` baut die App mit den neuen Dateien (nach `generate`) ohne Fehler und ohne neue Warnungen aus ihnen. Beleg: Lauf im Validierungsprotokoll.

## Dialog

### Runde 1
**Adversary:** Testlauf selbst: `./scripts/sim.sh sim-unit AccountStateTests` Exit 0, 13 Tests, 0 Fehlschlaege; parametrisierte Faelle aus dem xcresult (7 Anmelde-, 4 Abmelde-, 6 Loesch-Argumente) alle Passed (docs/artifacts/feat-615-s4b2-sitzung/adversary-test-output.txt). Keine Warnungen aus AccountState/SessionStore im Log. Diff der Testdatei (Compile-Fehler-Fix): nur Aufspaltung in lokale Variablen `data` und `first`, Aussage unveraendert (gleiche #require, gleiche Erwartungen); nicht abgeschwaecht.
Pruefung je AC gegen Code:
- AC-1/2: init liest einmal via storedToken, Lesefehler -> nil -> signedOut (LooseEnds/Claude/AccountState.swift:29, LooseEnds/Claude/AccountState.swift:132). Tests pruefen null Requests.
- AC-3/4/5: beginSignIn Guard LooseEnds/Claude/AccountState.swift:34, Nonce vor Statuswechsel erzeugt (LooseEnds/Claude/AccountState.swift:35), `nonce = nil` vor dem await (LooseEnds/Claude/AccountState.swift:45). Test vergleicht Nonce.hash(Body-Nonce)==Rueckgabe, 43 Zeichen, Schluesselmenge exakt drei.
- AC-6/7: save vor `status = .signedIn` (LooseEnds/Claude/AccountState.swift:54-55); Speicherfehler -> signedOut, Ablage leer (Test mit failNext(save:)).
- AC-8: signInStatus LooseEnds/Claude/AccountState.swift:141; CancellationError -> signedOut, lastProblem nie gesetzt.
- AC-9: cancelSignIn Guard LooseEnds/Claude/AccountState.swift:64; Test ruft es im Haken waehrend der Anfrage auf: wirkungslos, Ergebnis T2 gespeichert.
- AC-10/11: clear + signedOut vor dem await (LooseEnds/Claude/AccountState.swift:77-84), Haken-Transport prueft Ablage und Status zum Anfragezeitpunkt, vier Antworten parametrisiert. Loeschfehler geloggt, Anfrage trotzdem gesendet.
- AC-12/13/14: deleteAccount LooseEnds/Claude/AccountState.swift:91-112; dropSession loescht nur bei gleichem Token (LooseEnds/Claude/AccountState.swift:118); Test staleUnauthorized ersetzt T1 durch T2 im Haken, T2 bleibt, signedIn. Loeschen-Tabelle deckt 401/503/offline/500/invalid/cancel plus Folgeversuch.
- AC-15: signingIn/deleting sperren completeSignIn, deleteAccount, signOut (LooseEnds/Claude/AccountState.swift:71). Test mit Haken, genau 1 Request.
- AC-16: grep `print(`/`try?` ueber beide Dateien: keine Treffer. Alle 8 logger-Zeilen gesichtet (LooseEnds/Claude/AccountState.swift:57,79,86,108,116,127,136,147): nur Typname des Fehlers bzw. ServiceError-Fallname (rejected(Int) traegt nur den Statuscode), nie Token/Nonce/Body. Marker-Test deckt status, lastProblem, AccountError.
- AC-17: Namensliste gegen origin/main zeigt nur die geaenderte Testdatei, weil die beiden Produktdateien noch untracked sind; Dateimenge sonst genau die drei der Spec, nichts unter Shared/, server/, project.yml. Laengste Funktion deleteAccount 22 Zeilen; alle unter 50. LooseEnds/Claude/SessionStore.swift 61 Zeilen, Mutex statt @unchecked Sendable.
- AC-18: voller Lauf 1231 bestanden/13 uebersprungen und Build laut Entwickler; nicht erneut gefahren (Klassenlauf bei mir gruen, Test-Ziel baut).
Befunde:
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Claude/AccountState.swift:117
  Description: dropSession behandelt einen Lesefehler der Ablage in der 401-Pruefung wie "kein Token" und gibt signedOut zurueck, obwohl die Ablage das Token weiter halten kann. Kein Test deckt diesen Zweig (kein failNext(load:) im Loesch-Test).
  Spec requirement: AC-14 — Lesefehler in dieser Pruefung ist nicht ausdruecklich geregelt; AC-12 behandelt "nicht lesbar" analog als signedOut.
  Conflict: Konsistent mit AC-12 und dem Entwicklervermerk, aber ungetestet; ein Lesefehler koennte ein vorhandenes Token als abgemeldet anzeigen.
  Remediation: Test fuer failNext(load:) im Haken der 401-Antwort ergaenzen; Verhalten in der Spec festschreiben (nichts wird geloescht, daher sicher).
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Claude/AccountState.swift:72
  Description: signOut ohne lesbares Token (und deleteAccount LooseEnds/Claude/AccountState.swift:93) setzt status auf signedOut, laesst lastProblem aber unveraendert; aus signedIn mit lastProblem .retryLater bleibt .retryLater stehen.
  Spec requirement: AC-11 — verlangt nur Status signedOut und null Anfragen; AC-10 verlangt lastProblem nil nur fuer den Zweig mit Token.
  Conflict: Kein Spec-Verstoss; die UI in 4c koennte eine veraltete Problemanzeige im Zustand signedOut sehen.
  Remediation: lastProblem = nil in den Kurzzweigen setzen oder in 4c nur bei signedIn lesen.
**Implementierer:** Festlegungen zu F001 und F002 sind spec-konform (Lesefehler = kein Token, null Anfragen); Nachschaerfen, kein Blocker.

### Runde 2
**Adversary:** Zweiter Angriff auf die Randfaelle. (a) "Erst speichern, dann signedIn": status wird erst nach `store.save` gesetzt (LooseEnds/Claude/AccountState.swift:54-55), im Fehlerfall nie signedIn. (b) Nonce vor Request verbraucht: LooseEnds/Claude/AccountState.swift:45 liegt vor `client.signIn` (LooseEnds/Claude/AccountState.swift:48); auch bei CancellationError kein zweiter Request moeglich. (c) signOut waehrend signingIn/deleting: Guard LooseEnds/Claude/AccountState.swift:71, im Doppelaufruf-Test wirkungslos belegt. (d) Alles @MainActor, signingIn/deleting sperren Reentrancy; signOut setzt Status vor dem Logout-await, die spaete Dienstantwort aendert nichts (LooseEnds/Claude/AccountState.swift:83-87). (e) CancellationError: signIn -> signedOut ohne Problem; delete -> signedIn ohne Problem; logout -> nichts; alle getestet. (f) Der Nonce-Guard allein wird nur im Doppelaufruf-Test (Status signingIn, nonce nil) geprueft, das genuegt. (g) clear-Fehler nach erfolgreichem Loeschen: clearStore loggt, Status signedOut (LooseEnds/Claude/AccountState.swift:101-102); vorgemerkte Festlegung, spec-nah (Konto existiert nicht mehr, naechster Aufruf liefert 401). (h) Swift 6: Mutex<Contents>, SessionStoring: Sendable, AccountState @MainActor, keine Warnungen. (i) SessionStoreError.injected traegt keinen Wert.
Kein neuer Befund ueber F001/F002 hinaus; Tests nicht abgeschwaecht; alle ACs mit Test oder Beleg abgedeckt.
**Implementierer:** keine Einwaende. Festlegungen (Lesefehler in 401-Pruefung -> signedOut; clear-Fehler nach Erfolg geloggt, signedOut) sind spec-konform.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Claude/AccountState.swift:29
  Evidence: init liest Ablage einmal, signedIn nur bei vorhandenem Token, kein Request; Test gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Claude/AccountState.swift:132
  Evidence: storedToken faengt Lesefehler, loggt Typnamen, gibt nil; Test gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/AccountState.swift:34
  Evidence: Guard auf drei erlaubte Zustaende, sonst notPossibleNow ohne Zustandsaenderung.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/AccountState.swift:48
  Evidence: sendet open.raw, beginSignIn gibt fresh.hashed zurueck; Test prueft Hash-Gleichheit und Koerperschluessel.
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Claude/AccountState.swift:44
  Evidence: Guard Status+Nonce, nonce = nil vor Request.
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Claude/AccountState.swift:54
  Evidence: save vor status = .signedIn.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Claude/AccountState.swift:56
  Evidence: Speicherfehler -> signedOut, Ablage leer.
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Claude/AccountState.swift:141
  Evidence: Abbildung unauthorized/unavailable/cancel/default; Tabelle mit 7 Faellen gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Claude/AccountState.swift:64
  Evidence: Guard signingIn und offene Nonce; waehrend der Anfrage wirkungslos.
  Status: CONFIRMED
Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Claude/AccountState.swift:77
  Evidence: clear und signedOut vor client.logout; Haken-Test, vier Antworten.
  Status: CONFIRMED
Confirmation:
  AC: AC-11
  Code reference: LooseEnds/Claude/AccountState.swift:72
  Evidence: kein Token -> signedOut ohne Request; clear-Fehler geloggt, Logout gesendet.
  Status: CONFIRMED
Confirmation:
  AC: AC-12
  Code reference: LooseEnds/Claude/AccountState.swift:92
  Evidence: Guard signedIn; kein Token -> signedOut ohne Request; Erfolg -> clear, signedOut.
  Status: CONFIRMED
Confirmation:
  AC: AC-13
  Code reference: LooseEnds/Claude/AccountState.swift:103
  Evidence: unauthorized/cancel/uebrige Fehler getrennt abgebildet; Tabelle gruen mit Folgeversuch.
  Status: CONFIRMED
Confirmation:
  AC: AC-14
  Code reference: LooseEnds/Claude/AccountState.swift:118
  Evidence: guard stored == token vor clear; Test mit Tokenwechsel T1 -> T2.
  Status: CONFIRMED
Confirmation:
  AC: AC-15
  Code reference: LooseEnds/Claude/AccountState.swift:71
  Evidence: Status-Sperren; Doppelaufruf-Test genau eine Anfrage.
  Status: CONFIRMED
Confirmation:
  AC: AC-16
  Code reference: LooseEnds/Claude/AccountState.swift:153
  Evidence: caseName nur Fallname; grep print( und try? leer; alle logger-Zeilen gesichtet; Marker-Test gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-17
  Code reference: LooseEnds/Claude/SessionStore.swift:18
  Evidence: drei Dateien laut Spec, keychain-frei, Funktionen unter 50 Zeilen, Mutex-Ablage.
  Status: CONFIRMED
Confirmation:
  AC: AC-18
  Code reference: LooseEndsTests/AccountStateTests.swift:5
  Evidence: Klassenlauf gruen, Test-Ziel baut; voller Lauf laut Entwickler 1231 bestanden, 0 fehlgeschlagen, 13 uebersprungen (nicht wiederholt).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine verdaechtigen Zeilen; die Felder `status`, `lastProblem`, `nonce` werden nur in AccountState.swift geschrieben, jeweils unter dem Guard der Methode (Bedingung davor: siehe Runde 1), und jeder Weg hat einen Test (Test fuer diesen Weg: je AC in Runde 1 benannt; einzige Luecke F001).

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: 13 Testfaelle (mit 17 Argumentfaellen) bestanden, 0 failed, 0 uebersprungen in AccountStateTests
Edge cases: All checked, two LOW notes (F001, F002), none broken
Regressions: None found
Checklist: 18/18 points proven

## Geprüfte Dateien

- sha256:029d08357eb04090f98160129d630202fddcc2d0fc71101804076bb57eccd82a  LooseEnds/Claude/AccountState.swift
- sha256:e03d8f445a4026efb869fbc01ffacb9c8691e92b79bd0030a51e3ab1596ef1d7  LooseEnds/Claude/SessionStore.swift
- sha256:f46af69419d0ab9284c8cc5e7f96177137b3e4aecddb36ff24964ded1879f737  LooseEndsTests/AccountStateTests.swift

## Prüfbasis

- base: 3f7d51385b643f2590e26d49c3448c0908f90718
- blob:9448f465d6a5fe3ebbff0554afd28e3d799c9785  LooseEnds/Claude/AccountState.swift
- blob:7947843a6018393c67484d77191288930f044baf  LooseEnds/Claude/SessionStore.swift
- blob:784e68b2830d25a1818b8b18da95230f3eeb55c3  LooseEndsTests/AccountStateTests.swift
