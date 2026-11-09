# Validierungsprotokoll: feat-615-s4c-konto (Schnitt 4c-1, Refs #615)

Datum: 2026-11-09 · Stand: `bbed8ed` · Basis: `0e8d144` (merge-base origin/main)

## Test Results

- Voller Unit-Lauf `./scripts/sim.sh sim-unit`: grün (RC 0), 0 fehlgeschlagen. Übersprungen, einzeln:
  - `RawSentenceReportTests`: fehlt `loose-ends-rawtexts.json` (Messstrecke, gitignored)
  - `SelfConsistencyReportTests`: fehlt `selfconsistency-run.json` (Messstrecke)
  - `TextFormModelReportTests`: fehlt `textform-run.json` (Messstrecke)
  - Latenzschutz #274 (2 Tests): de_DE-Spracherkennung im Simulator nicht verfügbar
  Alle fünf sind vorbestehend und unabhängig von diesem Schnitt.
- `./scripts/sim.sh build`: RC 0. `./scripts/sim.sh mac-build`: RC 0. Keine Warnung aus `AccountSection.swift`,
  `AccountWiring.swift`, `SettingsView.swift`, `LooseEndsApp.swift`.
- `./scripts/sim.sh test-proof AccountSettingsTests`: 7 gesamt, 7 bestanden, 0 fehlgeschlagen, 0 übersprungen
  (iPhone 17, iOS 27.2, Beleg `simulator-run.txt`, 15:36).
- `./scripts/sim.sh test-proof SettingsSmokeTests`: 1/1 bestanden (Regression). Danach wurde der Beleg mit
  `AccountSettingsTests` neu erzeugt, damit `simulator-run.txt` diesen Schnitt belegt.
- `python3 scripts/test_catalog_languages.py`: OK.

## Spec Compliance (AC-1 … AC-15)

Abgleich durch eigenen Lesedurchgang und den Haiku-Spec-Check. AC-1 bis AC-11 durch die Tests oben, AC-12 Skript.
Anmerkungen ohne Code-Folge:
- AC-4: Seit iOS 26 zeichnet die Popover-Form des `confirmationDialog` den `.cancel`-Knopf nicht; der Test tippt
  dann neben den Dialog (Systemverhalten, Abbrechen wirkt, angemeldet bleibt stehen).
- AC-10: Der Test zählt einen eigenen Transport (Spec: „eigener Zähler im Test“) und prüft `forApp` mit
  `--ui-testing` getrennt; erfüllt.
- Abweichung: schlägt `beginSignIn` fehl, kann der Apple-Dialog trotzdem erscheinen (bleibt folgenlos, Guard in
  `completeSignIn`). Mit Knopf im Zustand `signedOut` praktisch unerreichbar; gehört mit F001 (Apple-Knopf
  verschwindet während `signingIn`) in die Prüfung von 4c-2 auf dem echten Weg.
- `AccountSection` bekommt `AccountState` als Init-Parameter statt aus der Umgebung; ohne Folgen.

### AC-5 Quelltext-Beleg `.destructive`
`grep -n 'destructive\|\.red' LooseEnds/Views/AccountSection.swift` → nur
`121: Button("Delete account", role: .destructive) {`

### AC-12 Stichprobe Katalog (de)
Alle 18 neuen Schlüssel mit de; Wortlaut gleich der Spec-Liste (u. a. „Melde dich mit Apple an, damit Claude …
verlässt nichts dieses Gerät.“, „Angemeldet mit Apple“, „Dieses Gerät“, „Abmelden“, „Konto löschen …“,
„Konto löschen?“, „Dieses Apple-Konto ist für Claude noch nicht freigegeben.“, „Der Dienst ist gerade nicht
erreichbar. Versuch es später noch einmal.“). Zusätzlich „Mit Apple anmelden“ für den Testknopf.

### AC-13 Grenze und Stil
`git diff --name-only origin/main -- . ':!docs' ':!.claude'`:
CLAUDE.md, LooseEnds/App/LooseEndsApp.swift, LooseEnds/Claude/AccountWiring.swift,
LooseEnds/Resources/Localizable.xcstrings, LooseEnds/Views/AccountSection.swift, LooseEnds/Views/SettingsView.swift,
LooseEndsTests/AccountSectionTests.swift, LooseEndsUITests/AccountSettingsTests.swift — genau die Spec-Liste.
`print(`: kein Treffer. `try?`: kein Treffer. Längste Funktion `signedInRows` 32 Zeilen. Logger-Zeilen nennen nur
Fehlertypen, kein Token, keine Nonce.

### AC-14 Doku
`grep -n 'AccountWiring' CLAUDE.md` → `452: `AccountWiring` (S4c-1): `forApp` builds the one `AccountState` …`;
`AccountSection` in `LooseEnds/Views` steht in Zeile 456.

### AC-15 Screenshots (geöffnet und beschrieben)
- abgemeldet: unter „iCloud sync“ der Kopf „Claude“, Knopf mit Apple-Symbol „Sign in with Apple“ in Akzent,
  Hinweis „Sign in with Apple so Claude can read your open tasks … nothing leaves this device.“, darunter „Calendar“.
- angemeldet: „Signed in with Apple“ / „This device“, „Sign out“ und „Delete account …“ in Akzent, Hinweis
  „Claude sees your open tasks. Signing out disconnects only this device. …“.
- Dialog: Popover „Delete account?“, Meldung „Claude will no longer see your tasks. Your tasks in the app stay as
  they are.“, roter Knopf „Delete account“ (einzige rote Stelle).
- nicht freigegeben: Knopf bleibt, Hinweis „This Apple account is not yet cleared for Claude.“
- später nochmal: Knopf bleibt, Hinweis „The service can't be reached right now. Try again later.“

## Regression Check
Keine Regressionen: voller Unit-Lauf grün, `SettingsSmokeTests` grün.

## Scope Check
- Dateien außerhalb `docs/`: 8 (5 Produkt inkl. Katalog, 2 Test, CLAUDE.md), wie in der Spec angekündigt und bei der
  Freigabe bestätigt.
- LoC Produkt (ohne `.xcstrings`): +303/−3 (AccountSection 184, AccountWiring 77, SettingsView +36/−3,
  LooseEndsApp +6); davon reine Codezeilen ohne Leer- und Kommentarzeilen in den neuen Dateien 157 + 60.
  **Über dem Spec-Schätzwert (≈ 210) und über ±250.** Ursache: die Apple-Verdrahtung, der Testknopf und die
  Mac-Variante der Zeilen in `AccountSection` sind breiter als geschätzt. Kein Fremd-Inhalt, keine Datei außerhalb
  der Spec; ein Teilen nach der Implementierung brächte nichts. Festgehalten, damit 4c-2 knapper geschätzt wird.
- Tests: +314 (Grenze 500). Katalog: +20/−1 (zählt nicht).

## Nachtrag CI (PR #889)
UI Smoke in der CI: `CalendarTargetTests.testSettingsShowDefaultCalendarRow` und
`testDefaultCalendarIsStampedOnSwitchOn` rot („Settings should offer the default calendar“). Lokal nachgestellt
(`./scripts/sim.sh test CalendarTargetTests`: 2 von 3 rot). Ursache: die Einstellungsliste erzeugt Zeilen erst beim
Hineinscrollen; die neue Gruppe „Claude“ schiebt `defaultCalendarRow` unter den ersten Bildschirm, der Test wartete
nur. Korrektur nur im Test: beide Stellen nutzen die vorhandene `scrollUntilVisible` (#305). Danach lokal 3/3 grün.
Kein Produktcode geändert.

## Stufe 3
Kein Pfad der Geräteliste berührt.

## Result: PASS
