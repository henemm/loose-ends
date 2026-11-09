# Adversary Dialog — feat-615-s4c-konto
Spec: docs/specs/feat-615-schnitt-4c1-konto-gruppe.md
Datum: 2026-11-09 15:21

## Checkliste
- [x] **AC-1:** Abgemeldet: Öffnen der Einstellungen (Zahnrad) zeigt die Gruppe `accountSection` mit dem Kopf „Claude“, dem Anmelden-Knopf `accountAppleButton` und dem Hinweis „Melde dich mit Apple an, damit Claude deine offenen Aufgaben lesen und neue anlegen kann. Ohne Anmeldung verlässt nichts dieses Gerät.“ (englisch in der Testsprache en); die Gruppe liegt unter der iCloud-Zeile `iCloudSyncRow` und über den Kalender-Zeilen (Vergleich der y-Position der Elemente). Test: `testSignedOutShowsGroupBelowICloud` (UI).
- [x] **AC-2:** Anmelden: Tippen auf `accountAppleButton` führt (Ersatz zugelassen) zu `accountSignedInRow` mit „Angemeldet mit Apple“ und „Dieses Gerät“, zu den Zeilen `accountSignOutRow` („Abmelden“) und `accountDeleteRow` („Konto löschen …“) und zum Hinweis „Claude sieht deine offenen Aufgaben. Abmelden trennt nur dieses Gerät. Konto löschen entfernt alles, was der Dienst für Claude von dir aufbewahrt.“; `accountAppleButton` ist verschwunden. Test: `testSignInShowsSignedInRows` (UI).
- [x] **AC-3:** Abmelden ohne Rückfrage: Tippen auf `accountSignOutRow` führt ohne Dialog zurück in den Abgemeldet-Zustand aus AC-1 (Knopf und Hinweis wieder da, Angemeldet-Zeilen weg). Test: `testSignOutNeedsNoConfirmation` (UI).
- [x] **AC-4:** Löschen, Abbrechen: Tippen auf `accountDeleteRow` zeigt den Dialog mit Titel „Konto löschen?“, der Meldung „Claude sieht deine Aufgaben dann nicht mehr. Deine Aufgaben in der App bleiben, wie sie sind.“ und den Knöpfen „Konto löschen“ und „Abbrechen“; „Abbrechen“ schließt ihn, `accountSignedInRow` bleibt stehen. Test: `testDeleteCancelKeepsSignedIn` (UI).
- [x] **AC-5:** Löschen, Bestätigen: im Dialog „Konto löschen“ führt zum Abgemeldet-Zustand (Knopf und Hinweis wie AC-1); die Angemeldet-Zeilen sind weg. Der Knopf im Dialog trägt die Systemrolle `.destructive` (Quelltext-Beleg im Validierungsprotokoll: Rot kommt nur dort vor). Test: `testDeleteConfirmSignsOut` (UI).
- [x] **AC-6:** „Nicht freigegeben“: mit `--ui-testing-account-not-allowed` führt Tippen auf `accountAppleButton` zurück in den Zustand mit Knopf und dem Hinweis „Dieses Apple-Konto ist für Claude noch nicht freigegeben.“; es erscheinen keine Angemeldet-Zeilen. Test: `testNotAllowedShowsItsSentence` (UI).
- [x] **AC-7:** „Später nochmal“: mit `--ui-testing-account-retry-later` führt Tippen auf `accountAppleButton` zu Knopf und Hinweis „Der Dienst ist gerade nicht erreichbar. Versuch es später noch einmal.“; ein zweiter Tipp ist möglich (der Knopf steht noch). Test: `testRetryLaterShowsItsSentence` (UI).
- [x] **AC-8:** Abbildung `Layout`: für jede Zeile der Tabelle (`signedOut`, `signingIn`, `signedIn` ohne und mit Problem `retryLater`, `deleting`, `notAllowed`, `retryLater`) liefert `AccountSection.layout(status:problem:)` genau die Felder der Tabelle; insbesondere zeigt `signingIn` und `deleting` nie den Apple-Knopf und nie die Angemeldet-Zeilen mit Aktionen (kein zweites Tippen möglich), `notAllowed` und `retryLater` zeigen den Knopf. Test: „account: layout je status“ (Unit, tabellengetrieben).
- [x] **AC-9:** Schalter: `AccountWiring.isEnabled` ist falsch bei fehlendem Info-Schlüssel, bei `false`, bei falschem Typ (z. B. Text) und wahr bei `true` im Info-Wörterbuch; mit `--ui-testing` in den Argumenten ist es immer wahr. `forApp` liefert bei „aus“ `nil` (kein `AccountState`, keine Ablage gelesen) und ist in der Einstellungsansicht ohne `AccountState` ohne Gruppe. `serviceURL` fällt bei fehlendem, leerem und ungültigem Wert auf `https://loose-ends.henemm.com` zurück und nimmt sonst den Info-Wert. Test: „account: wiring schalter und adresse“ (Unit).
- [x] **AC-10:** Kein Netzaufruf ohne Tippen: `forApp` mit `--ui-testing` und ein gezählter Ersatz-Transport (eigener Zähler im Test, `AccountState.init` und das Berechnen des `Layout` für alle Zustände) lösen **null** Anfragen aus; der Zähler steigt erst mit `completeSignIn`. Test: „account: init sendet nichts“ (Unit).
- [x] **AC-11:** Ersatz-Transport: `UITestTransport` antwortet je Ausgang laut Festlegung (zugelassen: 200 mit `sessionToken`; `not-allowed`: 401; `retry-later`: 503; Abmelden und Löschen 204) und trägt kein Netz; `ServiceClient` bildet die Antworten auf Token, `ServiceError.unauthorized` und `ServiceError.unavailable` ab. Test: „account: ersatz-transport ausgaenge“ (Unit).
- [x] **AC-12:** Texte: alle neuen Schlüssel haben de und en; `python3 scripts/test_catalog_languages.py` ist grün. Der deutsche Wortlaut stimmt mit der Liste „Texte“ dieser Spec überein (Beleg: Stichprobe der Schlüssel im Validierungsprotokoll). Beleg: Lauf des Skripts.
- [x] **AC-13:** Grenze und Stil: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `LooseEnds/Views/AccountSection.swift`, `LooseEnds/Claude/AccountWiring.swift`, `LooseEnds/Views/SettingsView.swift`, `LooseEnds/App/LooseEndsApp.swift`, `LooseEnds/Resources/Localizable.xcstrings`, `LooseEndsTests/AccountSectionTests.swift`, `LooseEndsUITests/AccountSettingsTests.swift` und `CLAUDE.md` (kein `project.yml`, keine Entitlements, keine `Info.plist`, nichts unter `Shared/`, `server/`, `.github/`, `scripts/`); `grep -nE 'print\(' ` in den beiden neuen Quelldateien ohne Treffer; keine Funktion über 50 Zeilen; kein Token und keine Nonce in einer Logzeile. Beleg: einmalig in `/60-validate` im Validierungsprotokoll, kein Test gegen `origin/main`.
- [x] **AC-14:** Doku: der Eintrag „`LooseEnds/Claude`“ in `CLAUDE.md` nennt `AccountWiring` (Schalter `LEAccountEnabled` Fallback aus, `LEServiceURL`, Ersatz unter `--ui-testing`) und `AccountSection` in `LooseEnds/Views`. Beleg: `grep -n 'AccountWiring' CLAUDE.md` im Validierungsprotokoll.
- [x] **AC-15:** Regression und Abnahme: `./scripts/sim.sh sim-unit` (alle Unit-Tests) grün; `./scripts/sim.sh build` und `./scripts/sim.sh mac-build` bauen ohne Fehler und ohne neue Warnungen aus den geänderten oder neuen Dateien; `./scripts/sim.sh test-proof AccountSettingsTests` grün mit maschinellem Beleg; die vorhandenen `SettingsSmokeTests` bleiben grün. Beleg: Läufe im Validierungsprotokoll samt geöffneten und beschriebenen Screenshots der Zustände abgemeldet, angemeldet, Dialog, „nicht freigegeben“, „später nochmal“.

## Dialog

### Runde 1
**Adversary:** Ich behaupte, die Umsetzung ist falsch. Layout-Tabelle: `AccountSection.layout` (AccountSection.swift:19-30) gegen die Spec-Tabelle Zeile für Zeile verglichen; alle 7 Zeilen stimmen, Unit-Test tabellengetrieben grün. `isEnabled` (AccountWiring.swift:11-17): Text "YES" und `Int 1` als NSNumber scheitern an der CFBoolean-Prüfung (falsch), Bool true ist wahr; `--ui-testing` immer wahr. `serviceURL` (AccountWiring.swift:20-28): leer, ohne Host, nicht-http(s) und falscher Typ fallen zurück. `forApp` (AccountWiring.swift:31-39) liest bei „aus“ nichts und baut nichts. Kein Netz ohne Tippen: `AccountState.init` liest nur die Ablage, `body` und `Layout` sind rein; Test zählt 0 Anfragen bis `completeSignIn`. Einbau: Mac nach `syncSection` vor Notifications (SettingsView.swift:55), iOS nach `syncSection` vor `calendarSection` (SettingsView.swift:84); Umgebung in Hauptfenster (LooseEndsApp.swift:144) und Settings-Szene (LooseEndsApp.swift:174), einmal gebaut (LooseEndsApp.swift:55). Rot: nur `role: .destructive` (AccountSection.swift:121), kein `.red` in der Datei. Kein print, kein `try?`; Logs nennen nur Fehlertypen. Dateigrenze: nur die genannten Dateien plus Tests und CLAUDE.md, nichts in project.yml, Info.plist, Entitlements, Shared, server, scripts, .github. Katalog: alle 18 neuen Schlüssel haben de und en (translated), deutscher Wortlaut stimmt Wort für Wort mit der Spec-Liste überein (Stichprobe aller Schlüssel); `test_catalog_languages.py` 8 OK (eigener Lauf). Eigener Unit-Lauf AccountSectionTests 4/4 grün. UI-Test-Diff: `reveal` scrollt nur; keine Assertion wurde entfernt oder abgeschwächt. Der Vergleich iCloud-y gegen Kopf-y wurde sogar vor das Scrollen gezogen (strenger, korrekt), `assertSignedOut` ruft jetzt `reveal` auf, die Prüfungen von Label, Hittable und Abwesenheit bleiben. Screenshots geöffnet: abgemeldet (iCloud-Zeile, Kopf „Claude“, Knopf mit Apple-Symbol, Intro-Hinweis, darunter Calendar), angemeldet (Zeile „Signed in with Apple / This device“, Sign out, Delete account … beide in Akzent, Hinweis), Dialog (Titel, Meldung, rotes „Delete account“; ein Abbrechen-Knopf ist auf dem Bild nicht zu sehen, auf iPhone dieser Popover-Form ist Abbrechen das Tippen daneben, der Test fand ihn aber), nicht freigegeben und später nochmal (Knopf bleibt, jeweiliger Satz). Bekannte Auffälligkeit: `onRequest` (AccountSection.swift:161-168). Schlägt `beginSignIn` fehl, bleibt der Status `signedOut`, der Apple-Dialog erscheint trotzdem, aber ohne Nonce. Gegenprüfung: `completeSignIn` (AccountState.swift:44) kehrt wegen `status == .signingIn`-Guard zurück, `cancelSignIn` (AccountState.swift:63) ist wirkungslos, es geht keine Anfrage hinaus und der Zustand hängt nicht in `signingIn`. Das ist sicher, aber still: der Nutzer sieht einen Dialog, der folgenlos bleibt. Ausfallwege: `Nonce()` (Zufallsquelle) oder `notPossibleNow`, der bei sichtbarem Knopf nicht erreichbar ist.
**Implementierer:** Bestätigt; Gegenpunkte: Spec forderte „kein Dialog“, der Button lässt das nicht zu, daher nur Log; Sicherheit über die Guards von `AccountState`.

### Runde 2
**Adversary:** Tiefer: (a) `onRequest` setzt `status = .signingIn`; `layout` blendet den Apple-Knopf daraufhin aus (AccountSection.swift:59 mit Tabelle). Das `SignInWithAppleButton` wird damit aus der Hierarchie entfernt, während sein ASAuthorizationController noch den Dialog zeigt. Entfernt SwiftUI den Besitzer des Controllers, kann dessen Completion ausbleiben; dann bliebe die Gruppe dauerhaft bei „Anmelden …“ ohne Abbruchmöglichkeit (`signingIn` zeigt weder Knopf noch Zeilen). Das ist im Simulator nicht belegbar (Testknopf ersetzt den Apple-Knopf); ob die Completion trotzdem kommt, ist unbelegt. Spec nennt den echten Weg selbst als erst in 4c-2 belegt und die Gruppe ist in jedem echten Bau verborgen (Fallback aus, AccountWiring.swift:11-17). (b) Zweiter Tipp: im Zustand signingIn nicht möglich (Knopf weg). (c) `isEnabled` bei `LEAccountEnabled` als Text "true" aus der Info.plist: falsch, richtig laut Spec. (d) `serviceURL` akzeptiert `http://`; bei Info-Wert aus dem Bau kontrolliert, nur Hinweis für 4c-2. (e) Testwarnung „main actor-isolated property 'value'“ in AccountSettingsTests.swift:58, aus einer unveränderten Zeile (`spoken`), nicht neu. (f) Funktionen alle unter 50 Zeilen (längste `signedInRows` ca. 30). (g) CLAUDE.md-Eintrag nennt AccountWiring (CLAUDE.md:452) und AccountSection mit Fallback aus, LEServiceURL, Ersatz.
**Implementierer:** (a) in 4c-2 beim Gerätelauf gezielt prüfen; Abhilfe wäre, den Knopf bei signingIn sichtbar aber deaktiviert zu lassen oder ein Zeitlimit mit cancelSignIn. Kein Eingriff in 4c-1, da Spec-Tabelle den Zustand so vorgibt.

## Befunde

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEnds/Views/AccountSection.swift:161
  Description: `request` ruft `beginSignIn()` und setzt damit `signingIn`; `body` (AccountSection.swift:59) blendet danach den `SignInWithAppleButton` aus, der den Apple-Dialog noch hält.
  Spec requirement: AC-8 — signingIn zeigt nie den Apple-Knopf; zugleich fordert die Spec den echten Weg mit onRequest/beginSignIn.
  Conflict: Fällt die Completion beim Entfernen des Knopfs aus, bleibt der Zustand in `signingIn` ohne Ausweg. Im Simulator nicht belegbar.
  Remediation: In 4c-2 auf dem Gerät gezielt prüfen; sonst Knopf bei signingIn sichtbar halten (deaktiviert) oder Zeitlimit mit cancelSignIn.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Claude/AccountWiring.swift:23
  Description: `serviceURL` lässt `http` zu, auch für den echten Client.
  Spec requirement: AC-9 — leer/ungültig fällt zurück; http wird nicht ausgeschlossen.
  Conflict: Kein Verstoß; ein Info-Wert mit http würde Tokens unverschlüsselt senden. Wert kommt aus dem Bau.
  Remediation: In 4c-2 für Nicht-Debug-Baus nur https annehmen.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/Views/SettingsView.swift:229
  Description: Beim Fehler von `beginSignIn` (AccountSection.swift:166) erscheint der Apple-Dialog trotzdem, ohne Folge (Guards in AccountState verhindern Anfrage und Hängen). Spec sagte „kein Dialog“, technisch nicht erzwingbar.
  Spec requirement: Echter Apple-Weg — bei Fehler von beginSignIn kein Dialog.
  Conflict: Nur stille Folgenlosigkeit; sicher, kein Defekt.
  Remediation: Optional Hinweis anzeigen; Abweichung im Abschlussbericht nennen.

## Bestätigungen

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-4, AC-6, AC-7
  Code reference: LooseEnds/Views/AccountSection.swift:57
  Evidence: View zeichnet nur Layout; UI 7/7 grün (maschineller Beleg), Screenshots geöffnet und passend.
  Status: CONFIRMED

Confirmation:
  AC: AC-5, AC-8
  Code reference: LooseEnds/Views/AccountSection.swift:121
  Evidence: Dialogknopf mit role .destructive, kein weiteres Rot; layout:19 gleich der Tabelle.
  Status: CONFIRMED

Confirmation:
  AC: AC-9, AC-10, AC-11
  Code reference: LooseEnds/Claude/AccountWiring.swift:11
  Evidence: isEnabled/serviceURL/forApp/UITestTransport wie Spec; 4/4 Unit-Tests im eigenen Lauf grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12, AC-13, AC-14, AC-15
  Code reference: LooseEnds/App/LooseEndsApp.swift:55
  Evidence: Umgebung in beiden Szenen (144, 174), Katalog 8 OK, Dateigrenze eingehalten, CLAUDE.md:452; Mac-Einbau SettingsView.swift:55 und iOS :84 per Quelltext (mac-build nicht erneut gelaufen, Beleg aus Phase 6).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Begründung: 15/15 Punkte belegt, Tests 4 Unit + 7 UI grün, 0 übersprungen in den eigenen Läufen. Keine kritischen oder hohen Befunde. Offen als MEDIUM F001 (echter Apple-Weg, Knopf verschwindet bei signingIn): im Simulator nicht belegbar, Spec verschiebt den echten Weg nach 4c-2, die Gruppe ist in jedem echten Bau verborgen, daher kein Blocker; in 4c-2 gezielt prüfen.

## Geprüfte Dateien

- sha256:c7695d6c4a8989a690bd265adc8df1265d8de796669afc1af6f0e1875d6c0266  LooseEnds/App/LooseEndsApp.swift
- sha256:7f2f11b4cc15042c73c713d38e2832b70ee0841a27d25ebd74e038bf3a7144b7  LooseEnds/Claude/AccountWiring.swift
- sha256:6cabe8ee91616a13c2adbb5e5d278007ac6c9621027e15d7a7762a7b37b4b902  LooseEnds/Views/AccountSection.swift
- sha256:7fa2db1a44c0bc2418948c304f65d606c67866f55cbaa672ca42054aabcad84e  LooseEnds/Views/SettingsView.swift

## Prüfbasis

- base: 0e8d14493931e7e29b0ea09e0d20a656012a1a85
- blob:01737d7d8df6e325a5ead8275e92c8b697af26d9  LooseEnds/App/LooseEndsApp.swift
- blob:44a5bbe59252cff5e7c9a57496614d7283c93ca4  LooseEnds/Claude/AccountWiring.swift
- blob:06f31f10cdd7859906458bf236fd3618288f3f00  LooseEnds/Views/AccountSection.swift
- blob:a60920e134b4fd24ef1803244b043675d3364b94  LooseEnds/Views/SettingsView.swift
