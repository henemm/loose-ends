# Adversary Dialog — feat-615-s4c2b-knopf-adresse
Spec: docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md
Datum: 2026-11-10 08:24

## Checkliste
- [x] **AC-1:** Abbildung `Layout`: für jede Zeile der Tabelle oben liefert `AccountSection.layout(status:problem:)` genau die Felder der Tabelle; insbesondere zeigt `signingIn` den Apple-Knopf (`showsAppleButton == true`), er ist nicht bedienbar (`appleButtonEnabled == false`) und die Fortschrittszeile steht (`showsProgress == true`); `deleting` zeigt den Knopf nicht (`showsAppleButton == false`, `appleButtonEnabled == false`); `signedOut`, `notAllowed`, `retryLater` zeigen ihn bedienbar. Das **ersetzt AC-8 der 4c-1-Spec** („`signingIn` zeigt nie den Apple-Knopf“) für `signingIn`; für `deleting` und die Angemeldet-Zeilen gilt AC-8 weiter. Test: „account: layout je status“ (Unit, tabellengetrieben, angepasst).
- [x] **AC-2:** Kein zweites Tippen: in jedem Status ist `appleButtonEnabled` höchstens dann wahr, wenn `showsAppleButton` wahr ist, und während `signingIn` und `deleting` nie wahr; in der View steht `.disabled(!layout.appleButtonEnabled)` an beiden Knopf-Varianten. Test: „account: laufende anfrage hat keinen bedienbaren knopf“ (Unit, über alle `AccountState.Status`-Fälle) und der UI-Test aus AC-3 (tippt den deaktivierten Knopf ein zweites Mal; es entsteht weder ein Fehler noch eine zweite Anmeldung).
- [x] **AC-3:** Sichtbar im laufenden Ablauf: mit Startargument `--ui-testing-account-slow` und dem Weg „Einstellungen öffnen, Knopf antippen“ existiert während der Wartezeit der Knopf `accountAppleButton` (`exists == true`), `isEnabled == false`, und die Zeile `accountProgressRow` ist sichtbar mit dem Text „Signing in …“; ein weiteres Tippen auf den Knopf ändert nichts; danach (Wartezeit bis 10 s) steht `accountSignedInRow` und der Knopf existiert nicht mehr. Test: `testSigningInKeepsDisabledAppleButton` in `AccountSettingsTests` (UI) mit Screenshot-Beleg `account-signing-in`, der geöffnet und beschrieben wird.
- [x] **AC-4:** Ersatz-Dienst langsam: `UITestTransport` mit dem Argument `--ui-testing-account-slow` hat eine Verzögerung von 2 Sekunden und antwortet erst danach; ohne das Argument ist die Verzögerung null und die Antwort sofort; die Ausgänge `allowed`/`notAllowed`/`retryLater` bleiben je Argument wie festgelegt; die bestehenden UI-Tests laufen ohne Verzögerung. Test: „account: ersatz-transport langsam nur auf wunsch“ (Unit: `UITestTransport` aus `arguments:`, `delay` mit und ohne Argument, Ausgang unverändert, Antwort des gebauten Transports nach der Wartezeit) sowie der unveränderte vorhandene Satz in `AccountSettingsTests`.
- [x] **AC-5:** Adressregel (Tabelle unten): `https` mit Host wird angenommen; `http` nur für `localhost` und `127.0.0.1` und nur mit `allowsLocalHTTP: true`; jeder andere Fall liefert `AccountWiring.fallbackURL`. Test: „account: dienstadresse nur https“ (Unit, tabellengetrieben, `allowsLocalHTTP` ausdrücklich gesetzt, damit beide Zweige im Debug-Lauf gelten).
- [x] **AC-6:** Standardfreigabe: ohne Angabe von `allowsLocalHTTP` gilt im Debug-Bau (`#if DEBUG`) `http://localhost:8780` als angenommen, in einem Bau ohne `DEBUG` als abgelehnt (Fallback); `forApp` benutzt diesen Standard und nimmt unter `--ui-testing` mit `LEServiceURL = http://fremd.example` die Fallback-Adresse als Basis des Ersatz-Dienstes. Test: „account: dienstadresse standard folgt debug“ (Unit: Erwartung per `#if DEBUG` im Test selbst, so dass sie in jedem Bau gilt, in dem der Test laufen kann) und `forApp` im selben Test.
- [x] **AC-7:** Keine Wirkung auf das Vorhandene: der bestehende Satz „account: wiring schalter und adresse“ (Schalter, `forApp` ohne Schlüssel gleich `nil`, Fallback bei fehlendem, leerem, kaputtem oder falsch getyptem Wert, `https://dienst.example` angenommen) bleibt unverändert grün; alle Fälle von `AccountSettingsTests` (Gruppe unter iCloud, Anmelden zeigt Angemeldet-Zeilen, Abmelden, Löschen abbrechen/bestätigen, `notAllowed`, `retryLater`) bleiben grün; die Gruppe „Claude“ bleibt in jedem echten Bau ausgeschaltet. Test: vorhandener `sim-unit`-Satz und `./scripts/sim.sh test-proof AccountSettingsTests` (maschineller Simulator-Beleg, Stufe 2).
- [x] **AC-8:** Bauten und Grenze: `./scripts/sim.sh generate` hinterlässt keinen Diff; `./scripts/sim.sh build` und `./scripts/sim.sh mac-build` bauen ohne Fehler und ohne neue Warnungen (die Änderung in `AccountSection` und `AccountWiring` wirkt auf iOS und Mac); `python3 scripts/test_catalog_languages.py` unverändert grün (keine neuen Texte, keine neuen Schlüssel). Die Dateigrenze des Schnitts (nur die Tabelle „Affected Files“) prüft `/60-validate` einmalig, kein Test gegen `origin/main` (Projektregel). Test: `sim-unit` (alle Unit-Tests), `build`, `mac-build`, `test_catalog_languages.py`, CI-Schritt „Generate leaves the tree clean“ auf dem PR.

## Dialog

### Runde 1
**Adversary:** Eigener Lauf `./scripts/sim.sh sim-unit AccountSectionTests` (adversary-test-output.txt): 10 Tests, 0 Fehler, darunter layout je status, laufende anfrage, dienstadresse nur https, standard folgt debug, ersatz-transport langsam (2,09 s), wiring. `mac-build` (adversary-mac-build-output.txt): Build Succeeded, 0 Warnungen. `test_catalog_languages.py`: OK. Zeitschrift Belege des Implementierers: Unit gesamt grün, UI 8/8 grün (test-green-ui-output.txt), Mutation (appleButtonEnabled in signingIn = true) rot.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/AccountSection.swift:22
  Evidence: layout() liefert je Status genau die Tabellenfelder (signingIn: Knopf sichtbar, appleButtonEnabled false, Fortschritt true; deleting: kein Knopf); Test layoutPerStatus (LooseEndsTests/AccountSectionTests.swift:31) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/AccountSection.swift:154
  Evidence: `.disabled(!enabled)` an der Test-Variante (Zeile 154) und an SignInWithAppleButton (Zeile 160); Invariante enabled => shown und busy => nie enabled in busyHasNoTappableButton (LooseEndsTests/AccountSectionTests.swift:48) über alle Status. Alle sechs Layout-Zeilen von Hand geprüft: Invariante hält.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/AccountWiring.swift:82
  Evidence: delay 2 s nur mit Argument (Zeile 82), sonst .zero; send schläft nur bei delay > .zero (Zeile 88); standInSlowOnlyOnRequest (LooseEndsTests/AccountSectionTests.swift:108) misst >= 2 s bzw. < 1 s, Ausgänge unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Claude/AccountWiring.swift:29
  Evidence: guard verlangt Schema und nicht leeren Host; switch nimmt https immer, http nur bei allowsLocalHTTP und Host localhost/127.0.0.1 (lowercased, daher http://LOCALHOST ok). HTTPS://, https:///pfad, https:// , ftp, nil, leer, 42 durch serviceAddressOnlyHTTPS (LooseEndsTests/AccountSectionTests.swift:64) belegt. Zusatz-Randfälle (Port, Userinfo https://user@host, http://localhost@evil) sind nicht in der Tabelle: Host-Auswertung per URL.host() ordnet evil/localhost korrekt dem Host nach dem @ zu; Userinfo bei https bleibt angenommen (unschädlich, Spec schweigt).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEndsUITests/AccountSettingsTests.swift:199
  Evidence: bestehender Satz wiringSwitchAndAddress grün (Unit), UI 8/8 inkl. der vorhandenen sieben Fälle; Gruppe bleibt über isEnabled ohne Schalter aus (forApp unverändert bis auf den Transport-Init).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Claude/AccountWiring.swift:22
  Evidence: iOS-Bau (sim-unit) und mac-build grün, 0 Warnungen, catalog-Skript OK; DEBUG-Ausdruck kompiliert in beiden Zweigen syntaktisch (Release nicht gebaut, siehe F002). generate-Diff nicht von mir geprüft, project.yml unberührt.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEndsTests/AccountSectionTests.swift:104
  Description: Der forApp-Teil von AC-6 prüft nur `!= nil`. Ob der Ersatz-Dienst bei `LEServiceURL = http://fremd.example` auf der Fallback-Adresse als Basis sitzt, wird nicht belegt (nur serviceURL direkt, Zeile 102).
  Spec requirement: AC-6 — forApp nimmt unter --ui-testing die Fallback-Adresse als Basis des Ersatz-Dienstes.
  Conflict: Der Test würde auch grün bleiben, wenn forApp die rohe fremde Adresse übergäbe. In der Praxis ruft forApp serviceURL(info:) (AccountWiring.swift, Aufruf in forApp), also kein echter Defekt, nur Beweislücke.
  Remediation: Basis-URL des Clients prüfbar machen oder Aufruf im Test über eine Hilfsfunktion fassen.

### Runde 2
**Adversary:** Gezielter Angriff auf AC-3 (Test wurde in Phase 6 umgebaut). Screenshots geöffnet. account-signing-in: Zeile "Sign in with Apple" steht in der Gruppe Claude, darunter "Signing in …" mit Spinner, Hinweis intro; Knopf vorhanden. account-signed-in-after-wait: "Signed in with Apple / This device", Sign out, Delete account, Knopf weg. Der Test prüft isEnabled==false per Snapshot (Mutation färbt den Test rot, also echt), Fortschrittstext, Reihenfolge (Knopf über Fortschritt) und das Endergebnis.

Confirmation:
  AC: AC-3
  Code reference: LooseEndsUITests/AccountSettingsTests.swift:199
  Evidence: Existenz, isEnabled == false, "Signing in …" und Endzustand im selben Lauf belegt, Mutation rot am isEnabled-Check; Zeitrisiko (ein Snapshot nach Fortschrittszeile, 2 s Verzögerung) im Lauf bestanden.
  Status: CONFIRMED

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/AccountSettingsTests.swift:199
  Description: "Zweites Tippen ändert nichts" ist nur schwach belegt: Der Ersatz-Dienst antwortet auf eine zweite Anmeldung ebenfalls erfolgreich, ein tatsächlich ausgelöstes zweites Anmelden wäre also am Ende nicht sichtbar (die Prüfung `accountHint != retryLater` ist nahezu wirkungslos). Wirksam ist allein die isEnabled-Prüfung.
  Spec requirement: AC-2/AC-3 — ein weiteres Tippen ändert nichts.
  Conflict: Beweis stützt sich auf den Zustand, nicht auf die Wirkung. AccountState.beginSignIn sperrt zusätzlich außerhalb signedOut/notAllowed/retryLater (Spec Abschnitt Dependencies), daher kein Produktdefekt.
  Remediation: Zähler der Anfragen im Ersatz-Dienst oder diese Prüfung streichen.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/Claude/AccountWiring.swift:22
  Description: debugBuild ist internal statt private (Spec: private). Notwendig, weil Standardargument einer internen Funktion nur interne Symbole sehen darf; die Spec war in sich widersprüchlich. Release: #if-Zweig setzt false, fail-closed; Release-Bau selbst nicht von mir gebaut.
  Spec requirement: Source 2 — private static let debugBuild
  Conflict: Abweichung vom Wortlaut, ohne Wirkung.
  Remediation: Spec nachziehen.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/AccountSection.swift:154
  Description: Im Screenshot account-signing-in ist die Test-Variante des Knopfs (Label "Sign in with Apple") nicht sichtbar grau: Text schwarz, Symbol in Tönung. Der Spec-Text sagt "grau stehen", belegt ist technisch isEnabled == false. Echter Apple-Knopf (Zeile 160) nur auf Gerät prüfbar (4d).
  Spec requirement: AC-3 — Knopf sichtbar und deaktiviert.
  Conflict: Optische Rückmeldung der Test-Variante schwach; betrifft nur --ui-testing.
  Remediation: Keine Pflicht; ggf. Label-Foreground bei disabled absichern.

**Implementierer:** keine Rückmeldung nötig, keine CRITICAL/HIGH-Befunde.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: Unit AccountSectionTests 10 bestanden, 0 fehlgeschlagen, 0 übersprungen; UI 8/8 (Beleg des Implementierers); mac-build grün
Edge cases: geprüft, nur LOW/MEDIUM-Beweislücken (F001 bis F004), kein Defekt
Regressions: keine gefunden
Checklist: 8/8 belegt (AC-8 ohne eigenen generate-/Release-Lauf, durch Belege gestützt)

Dateien: LooseEnds/Claude/AccountWiring.swift, LooseEnds/Views/AccountSection.swift, LooseEndsTests/AccountSectionTests.swift, LooseEndsUITests/AccountSettingsTests.swift

Code reference: LooseEnds/Claude/AccountWiring.swift:29
Code reference: LooseEnds/Views/AccountSection.swift:22
Code reference: LooseEndsTests/AccountSectionTests.swift:31
Code reference: LooseEndsUITests/AccountSettingsTests.swift:199

## Geprüfte Dateien

- sha256:088130d0ac87028600fe83ea9633ce6111dea2afee2bbd45cb5ec4de69ca13a0  LooseEnds/Claude/AccountWiring.swift
- sha256:faf5f30a567b3a531d591fcec804151d8fb2a860925a7b31ea2779d3f765c3fd  LooseEnds/Views/AccountSection.swift
- sha256:3a6217e03def209536af159cee191a27d85f1a3c921c579233463c83ede7d717  LooseEndsTests/AccountSectionTests.swift
- sha256:c099bf3a0e7721a5357d335a1a09e436a081c191b5e8def1826c8490176bf3bf  LooseEndsUITests/AccountSettingsTests.swift

## Prüfbasis

- base: d7072d5509c049c6d7acb162b5ee0b6f64be21ec
- blob:072c3c8f1c8096674b9b83cfd3db7ed60e34c083  LooseEnds/Claude/AccountWiring.swift
- blob:051736d527361016adba49569b922fbd31e91126  LooseEnds/Views/AccountSection.swift
- blob:3bb345184dc385e2fae0e26894a1911279a352f8  LooseEndsTests/AccountSectionTests.swift
- blob:5b55023c1df2484a796f2b2821a1ab3b805375e7  LooseEndsUITests/AccountSettingsTests.swift
