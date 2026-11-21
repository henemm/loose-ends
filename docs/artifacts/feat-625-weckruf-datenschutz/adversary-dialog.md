# Adversary Dialog — feat-625-weckruf-datenschutz
Spec: docs/specs/feat-625-schnitt-4-weckruf-datenschutz.md
Datum: 2026-11-21 21:01

## Checkliste
- [x] **AC-1:** GIVEN `docs/reference/datenschutz-entwurf.md` WHEN der deutsche Abschnitt „Wenn du die Verbindung zu Claude nutzt“ gelesen wird THEN steht der Absatz „Weckruf.“ nach „Kennung dieser Installation.“ und vor „Wo.“ im freigegebenen Wortlaut, mit den Aussagen: Gerätetoken nach Anmeldung und bei Start, Inhalt der Meldung (Token, Art des Systems, Kennung), höchstens zehn Geräte, stille Mitteilung über APNs nach neuem Auftrag, fester Inhalt ohne Aufgabeninhalt und nichts Sichtbares, höchstens eine je Gerät in 15 Minuten, vier Löschwege, „Abmelden“ löscht es nicht und das Gerät kann weiter still geweckt werden.
- [x] **AC-2:** GIVEN der Absatz aus AC-1 WHEN er mit `PushWakeUp.swift`, `DeviceRegistration.swift`, `ServiceClient.swift` (`putDevice`), `008_device_tokens.sql`, `devices.ts`, `apns.ts`, `mcp.ts` (`storeOrder`) und `auth.ts` (`logout`) verglichen wird THEN hat jede Aussage einen Beleg und keine einen Gegenbeleg (Beleg `aussagen.txt`: je Aussage Datei und Fundstelle).
- [x] **AC-3:** GIVEN der Entwurf WHEN „Kennung dieser Installation.“, „Löschen.“ und „Was Apple dabei übernimmt“ gelesen werden THEN trägt der Kennungs-Absatz den angefügten Satz zum Weckruf (alle übrigen Sätze unverändert), der Löschsatz nennt das Gerätetoken, und „Was Apple dabei übernimmt“ steht auf „fünf Stellen“ mit dem Punkt „Push-Mitteilungen“, jeweils im freigegebenen Wortlaut.
- [x] **AC-4:** GIVEN der Abschnitt „English“ im Entwurf WHEN er mit dem deutschen verglichen wird THEN enthält er den Absatz „Wake-up.“, den angefügten Kennungs-Satz, den geänderten Löschsatz und den neuen Punkt in Abschnitt 6 („In five places“) im englischen Wortlaut oben, ohne Zusätze und Kürzungen und ohne Änderung der Nummerierung; „Last updated“ trägt das Veröffentlichungsdatum.
- [x] **AC-5:** GIVEN der Entwurf WHEN „Beleg im Code“ gelesen wird THEN stehen nach der Zeile „Auftrag, Ergebnis und Kennung werden mit dem Konto gelöscht“ die elf Zeilen der Beleg-Tabelle oben, und jede Dateiangabe nennt eine Datei, die im Repo existiert (Beleg `belege-pfade.txt`: Pfadliste mit Existenzprüfung).
- [x] **AC-6:** GIVEN der Entwurf WHEN „Offen, nicht belegt“ und der Statuskopf gelesen werden THEN fehlt der Punkt „Weckruf (Push-Token)“ samt dem Satz „Im Text ist der Weckruf deshalb nicht beschrieben“, der Punkt „Die vier Apple-Punkte“ heißt „Die fünf Apple-Punkte“, und beide Statuskopf-Abschnitte (de, en) nennen die Freigabe des Nachtrags (Datum der Spec-Freigabe) und die Veröffentlichung (Datum und Website-PR, nach dem Merge eingetragen).
- [x] **AC-7:** GIVEN `scripts/test_datenschutz_text.py` WHEN `python3 scripts/test_datenschutz_text.py` und der CI-Befehl `python -m unittest discover -s scripts -p 'test_*.py'` laufen THEN sind sie grün; die Anker aus dem Testplan stehen in `ANCHORS` (de und en), der alte Löschanker ist durch den neuen ersetzt, `STALE` enthält „Im Text ist der Weckruf deshalb nicht beschrieben“, und die `WAKE`-Prüfung samt Gegenprobe ist vorhanden.
- [x] **AC-8:** GIVEN das ergänzte Skript und der unveränderte Entwurf WHEN es läuft THEN ist es rot, und `red.txt` zeigt die fehlenden Anker und den vorhandenen STALE-Satz; nach der Änderung zeigt `green.txt` den grünen Lauf des CI-Befehls.
- [x] **AC-9:** GIVEN `CLAUDE.md` WHEN der Datenschutz-Absatz unter „Build“ gelesen wird THEN ersetzt ein Satz „Seit [Datum der Veröffentlichung] beschreibt der Text auch den Weckruf (Gerätetoken, stille Mitteilung; Verweis auf diese Spec)“, mit dem tatsächlichen Datum eingesetzt, den Satz „der Weckruf-Absatz (Push-Token) folgt mit #795 S5c-2“; alle übrigen Sätze des Absatzes bleiben unverändert (Diff), `LEAccountEnabled` bleibt bis #625 aus.
- [x] **AC-10:** GIVEN die Freigabe des Wortlauts und der gemergte `loose-ends`-PR WHEN der PR in `henemm/henemm-website` die Seiten `content/legal/loose-ends/privacy-policy/_index.md` und `…/privacy-policy-en/_index.md` ändert THEN enthalten beide die Änderungen aus AC-1, AC-3 bzw. AC-4 im freigegebenen Wortlaut, „Stand“ bzw. „Last updated“ ist das Veröffentlichungsdatum, und die Seiten enthalten nicht „Beleg im Code“ und „Offen, nicht belegt“; erst danach wird der Website-PR gemergt.
- [x] **AC-11:** GIVEN der gemergte und ausgelieferte Website-PR WHEN `curl -sS -o seite.html -w '%{http_code}'` beide Seiten abruft THEN ist der Code je 200, und `DATENSCHUTZ_LIVE=1 python3 scripts/test_datenschutz_text.py` ist grün (Kernaussagen, alle Anker, Abschnittstitel, keine veralteten Sätze, keine internen Abschnitte); Beleg `live.txt` mit Codes und Treffern. Die bei Apple gesetzte Datenschutz-URL bleibt unverändert.
- [x] **AC-12:** GIVEN die veröffentlichten Seiten und der Entwurf WHEN die Abschnitte verglichen werden THEN stimmen die Kernsätze der neuen und geänderten Absätze nach Normalisierung der Anführungszeichen wörtlich überein (Beleg `vergleich.txt`).
- [x] **AC-13:** GIVEN der Diff beider PRs WHEN er geprüft wird THEN enthält er weder `project.yml` noch eine `Info.plist` noch `PrivacyInfo.xcprivacy` noch Dateien unter `LooseEnds/`, `Shared/`, `server/`, und `LEAccountEnabled` ist weiterhin `false` (Beleg `schalter.txt`: Dateiliste und Zeile aus `project.yml`).

## Dialog

### Runde 1
**Adversary:** Ich glaube nichts auf Zuruf. (1) Wortlaut: ich habe jeden Blockzitat-Absatz der Spec (acht Stück: Weckruf, Kennungs-Zusatz, Löschsatz, Mitteilungs-Punkt, je de und en) maschinell, nach Normalisierung von Leerraum und Fettdruck, gegen den Entwurf geprüft: alle acht stehen wörtlich darin. Position: „Weckruf.“ (Zeile 116) liegt zwischen „Kennung“ und „Wo.“, „Wake-up.“ (Zeile 335) ebenso; „An fünf Stellen“ (48) und „In five places“ (381); Nummerierung en unverändert (Diff). (2) Website-PR #82 (offen): Diff gegen den Entwurf gelesen, de und en tragen dieselben Sätze, „Stand: 21. November 2026“ und „Last updated: November 21, 2026“, keine Abschnitte „Beleg im Code“ oder „Offen, nicht belegt“. (3) Code selbst gegriffen: PushWakeUp.swift:107-117 (Anfrage bei Wechsel auf signedIn, beim Start eingeschlossen, nichts beim Abmelden), ServiceClient.swift:107-113 (Körper nur token und environment, Kopf X-Device), 008_device_tokens.sql (UNIQUE token, CASCADE, updated_at), devices.ts:29-40 (Token wandert, MAX_DEVICES 10 = geschriebene Zeile plus neun neueste), apns.ts:13/18/20/58 (fester BODY, MIN_GAP 15 min, drei DROP-Fälle, background, Priorität 5), mcp.ts:125 (Weckruf nur bei „stored“), auth.ts:100 (logout nur endSession; per grep kein weiteres DELETE auf device_tokens außer putDevice und dropToken), accounts.ts:124 (DELETE accounts, Kaskade). Kein Gegenbeleg gefunden. (4) Eigener Lauf `python3 scripts/test_datenschutz_text.py -v`: 24 Tests, OK, 1 übersprungen (LiveTests.test_live_pages, ohne DATENSCHUTZ_LIVE), Datei adversary-test-output.txt. green.txt: 794 Tests, OK (skipped=1); red.txt: fünf Fehlschläge, darunter STALE-Satz, fehlende Anker und WAKE-Wörter. (5) schalter.txt und project.yml:86: LEAccountEnabled: false, keine verbotenen Pfade in beiden Dateilisten.
**Implementierer:** Belege liegen vor; die Veröffentlichungs-Teile folgen nach beiden Zusammenführungen.

### Runde 2
**Adversary:** Frühe Einigkeit ist verdächtig, deshalb Gegenproben. (a) Veraltete Sätze: grep nach Token und Gerätetoken im Entwurf zeigt keinen Satz, der dem Weckruf widerspricht (Zeile 110 „Werbekennung“ betrifft die Kennung, Zeile 217 „Abgleich per stiller Mitteilung“ ist der bestehende CloudKit-Beleg). Der Offen-Punkt zum Weckruf samt „Im Text ist der Weckruf deshalb nicht beschrieben“ ist weg; „Die fünf Apple-Punkte“ steht (237); STALE enthält den Satz (Skript:32), WAKE (Skript:106) mit Gegenproben, alter Löschanker ersetzt (Diff). (b) CLAUDE.md-Diff: nur der Satz „folgt mit #795 S5c-2“ ersetzt, übrige Sätze unverändert; ABER Zeile 187 behauptet „Seit 2026-11-21 beschreibt der Text auch den Weckruf“, während die Website-Seite noch den alten Text zeigt (PR #82 offen), und der Statuskopf (Entwurf 17 und 259) nennt die Freigabe, aber keine Veröffentlichung mit Datum und Website-PR; AC-6 verlangt beides, der zweite Teil ist erst danach belegbar (F001). (c) Kantenfall Drossel: das 15-Minuten-Fenster lebt im Speicher des Dienstprozesses (apns.ts:109-111); nach einem Neustart des Dienstes kann innerhalb von 15 Minuten ein weiterer Weckruf folgen, der Text sagt „höchstens eine“ ohne Vorbehalt (F002). (d) Im Arbeitsbaum liegt untracked docs/artifacts/feat-966-s1-host/ (#966 verworfen); gehört nicht in den PR (F003). (e) AC-10 bis AC-12: der Website-PR ist offen und darf erst nach dem loose-ends-PR zusammengeführt werden; DATENSCHUTZ_LIVE und der Vergleich mit den veröffentlichten Seiten sind jetzt nicht belegbar, einen Live-Beleg erfinde ich nicht. AC-10 ist für den Inhalt des PR-Diffs belegt (Wortlaut, Datum, keine internen Abschnitte), nicht für die Reihenfolge.
**Implementierer:** F001 wird nach der Veröffentlichung mit tatsächlichem Datum und PR-Nummer nachgetragen; AC-10 bis AC-12 werden danach mit live.txt und vergleich.txt nachgezogen.

### Runde 3
**Adversary:** Nichts aus der Übergabe geglaubt, alles selbst abgerufen. (1) Reihenfolge: `gh pr view 979` mergedAt 2026-11-21T22:32:27Z, `gh pr view 82 -R henemm/henemm-website` mergedAt 2026-11-21T22:32:47Z, also 20 Sekunden danach (AC-10 Reihenfolge); Dateien des Website-PR: nur `content/legal/loose-ends/privacy-policy/_index.md` und `privacy-policy-en/_index.md`. (2) Eigener curl: beide Seiten 200; „Stand: 21. November 2026“ und „Last updated: November 21, 2026“ stehen im HTML; „Beleg im Code“ und „Offen, nicht belegt“ je 0 Treffer. (3) Stichprobe per grep auf den frisch geholten Seiten: „höchstens eine solche Mitteilung in 15 Minuten“ (de, 1 Treffer), „Push-Mitteilungen“ (de) und „Push notifications“ (en) vorhanden; der englische 15-Minuten-Satz bricht im HTML mitten im Satz um (Treffer erst mit Umbruchtoleranz „at most one such notification per“), kein Fehlen. (4) Eigener Lauf `DATENSCHUTZ_LIVE=1 python3 scripts/test_datenschutz_text.py -v`: 24 Tests, OK, 0 übersprungen, LiveTests.test_live_pages ok; Ausgabe in adversary-test-output.txt überschrieben. (5) vergleich.txt gelesen: 27 Sätze, 0 Abweichungen, 4 Prüfungen auf interne Abschnitte, ERGEBNIS GLEICH; live.txt trägt Abrufzeit 22:36:04Z nach beiden Merges und beide 200. (6) `git diff` im Arbeitsbaum: in datenschutz-entwurf.md nur die zwei Veröffentlichungszeilen (de 19-20, en 262-263) mit Datum 2026-11-21 und henemm-website#82; kein Diff an scripts/ (0 Treffer PRIVACY_URL_EN), kein Repo-Variablen-Bezug: die bei Apple gesetzte URL ist unberührt. (7) F001: CLAUDE.md:187 „Seit 2026-11-21“ ist durch die Veröffentlichung am 2026-11-21 gedeckt. (8) Gegenprobe zu früher Einigkeit: F002 (Drossel im Speicher) bleibt, ist vom Text freigegeben und LOW; F003 bleibt, der feat-966-Ordner ist weiterhin untracked und nur gezielt hinzuzufügen.
**Implementierer:** Veröffentlichungszeilen nachgetragen, live.txt und vergleich.txt nach beiden Merges erzeugt.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: CLAUDE.md:187
  Description: CLAUDE.md sagt „Seit 2026-11-21 beschreibt der Text auch den Weckruf“, und der Entwurf (Zeile 17, 259, 263) trägt 2026-11-21 als Stand; die Website-Seite zeigt den Text erst nach der Veröffentlichung von henemm-website#82 (offen). Der Statuskopf nennt keine Veröffentlichung mit Datum und Website-PR.
  Erledigt in Runde 3: henemm-website#82 gemergt 2026-11-21T22:32:47Z (nach loose-ends#979, 22:32:27Z); Seiten live mit Stand 21. November 2026; Statuskopf trägt Datum und PR; CLAUDE.md:187 ist gedeckt.
  Spec requirement: AC-6 und AC-9 — Veröffentlichung mit Datum und Website-PR im Statuskopf, Datum der Veröffentlichung in CLAUDE.md
  Conflict: Bis zur Veröffentlichung ist „Seit …“ nicht wahr; fällt sie auf einen anderen Tag, stimmen CLAUDE.md, „Stand“ und „Last updated“ nicht mit dem Veröffentlichungsdatum überein.
  Remediation: Nach der Veröffentlichung Datum prüfen, wenn nötig in Entwurf, CLAUDE.md und PR #82 angleichen; Veröffentlichungszeile (Datum, PR #82) in beide Statuskopf-Abschnitte eintragen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apns.ts:111
  Description: Das 15-Minuten-Fenster je Gerät wird im Speicher des Prozesses gehalten (minGapMs, Zustand je ENV:token); ein Neustart des Dienstes setzt es zurück.
  Spec requirement: AC-1 — „höchstens eine je Gerät in 15 Minuten“
  Conflict: Nach einem Neustart sind innerhalb von 15 Minuten zwei Mitteilungen möglich; der Text nennt keinen Vorbehalt. Wirkung gering (stille Mitteilung ohne Inhalt).
  Remediation: Hinnehmen oder „im Normalbetrieb“ ergänzen; der Wortlaut ist freigegeben, also nur auf Hennings Wunsch.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: docs/artifacts/feat-625-weckruf-datenschutz/belege-pfade.txt:24
  Description: Im Arbeitsbaum liegt untracked docs/artifacts/feat-966-s1-host/ (aus dem verworfenen #966), die belege-pfade.txt selbst als nicht zu diesem Schnitt gehörig benennt.
  Spec requirement: AC-13 — Diff enthält nur die Dateien dieses Schnitts
  Conflict: Mit einem Sammel-Hinzufügen käme fremder Inhalt in den PR.
  Remediation: Nur gezielt die Pfade dieses Schnitts hinzufügen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: docs/reference/datenschutz-entwurf.md:116
  Evidence: Absatz „Weckruf.“ zwischen „Kennung“ und „Wo.“, zeichengleich zur Spec (maschineller Vergleich), alle geforderten Aussagen enthalten.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Claude/PushWakeUp.swift:107
  Evidence: Eigene Stichprobe: Anfrage bei Wechsel auf signedIn, nichts beim Abmelden; ServiceClient.swift:107 Körper token/environment, Kopf X-Device; devices.ts:29 Token wandert, MAX_DEVICES 10; apns.ts:13,18,20 fester Inhalt, 15 min, drei Löschfälle; mcp.ts:125 nur bei neu gespeichert; auth.ts:100 logout nur endSession; 008_device_tokens.sql CASCADE. Kein Gegenbeleg (Vorbehalt F002).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/reference/datenschutz-entwurf.md:48
  Evidence: „An fünf Stellen“, Punkt „Push-Mitteilungen“ (Zeile 57), Kennungs-Zusatzsatz und Löschsatz mit Gerätetoken wörtlich wie in der Spec; übrige Sätze laut Diff unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/reference/datenschutz-entwurf.md:335
  Evidence: „Wake-up.“, Zusatzsatz, Löschsatz, „In five places“ (381) und Push-Punkt wörtlich wie die Spec; Nummerierung unverändert; „Last updated: November 21, 2026“ (263), Veröffentlichung noch nicht eingetreten (F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: docs/reference/datenschutz-entwurf.md:191
  Evidence: Elf neue Tabellenzeilen (191-201) nach „Auftrag, Ergebnis und Kennung werden mit dem Konto gelöscht“; alle Dateien existieren (belege-pfade.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_datenschutz_text.py:106
  Evidence: ANCHORS de/en, STALE (Zeile 32), WAKE mit Gegenproben vorhanden; eigener Lauf 24 Tests OK, 1 übersprungen (adversary-test-output.txt); CI-Befehl laut green.txt 794 OK, 1 übersprungen.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_datenschutz_text.py:32
  Evidence: red.txt: 5 Fehlschläge, darunter vorhandener STALE-Satz und fehlende Anker; green.txt: grüner CI-Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: CLAUDE.md:187
  Evidence: Nur der Satz zum Weckruf ersetzt, übrige Sätze unverändert, LEAccountEnabled bleibt aus; das eingesetzte Datum ist noch nicht durch eine Veröffentlichung gedeckt (F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: project.yml:86
  Evidence: LEAccountEnabled: false; beide Dateilisten (loose-ends und PR #82) ohne verbotene Pfade.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: docs/reference/datenschutz-entwurf.md:19
  Evidence: Beide Statusköpfe (de 19-20, en 262-263) nennen Freigabe 2026-11-21 und Veröffentlichung 2026-11-21 mit henemm-website#82; „Die fünf Apple-Punkte“ (237) und fehlender Offen-Punkt zum Weckruf aus Runde 2 unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: docs/artifacts/feat-625-weckruf-datenschutz/vergleich.txt:34
  Evidence: Website-PR #82 ändert genau die zwei Seiten, gemergt 22:32:47Z nach #979 (22:32:27Z); Seiten tragen Stand 21. November 2026 / Last updated: November 21, 2026 (eigener curl), keine internen Abschnitte (0 Treffer), alle 27 Sätze gleich.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/artifacts/feat-625-weckruf-datenschutz/live.txt:2
  Evidence: Eigener curl beide 200; eigener Lauf DATENSCHUTZ_LIVE=1 24 Tests OK, 0 übersprungen (adversary-test-output.txt); kein Diff an Skript oder Repo-Variable PRIVACY_URL_EN, Apple-URL unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: docs/artifacts/feat-625-weckruf-datenschutz/vergleich.txt:33
  Evidence: 27 Sätze der Blockzitate stehen in Entwurf und Live-Seite, 0 Abweichungen; Stichprobe per grep (15-Minuten-Satz de, Push-Mitteilungen/Push notifications) bestätigt.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Alle 13 Punkte sind belegt. Die Reihenfolge der Spec (loose-ends-PR, danach Website-PR) wurde eingehalten, die Live-Seiten tragen den freigegebenen Wortlaut, F001 ist erledigt, F002 und F003 bleiben LOW.

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: 24 passed, 0 failed, 0 übersprungen (DATENSCHUTZ_LIVE=1 test_datenschutz_text.py, eigener Lauf); CI-Befehl laut green.txt 794 OK
Edge cases: All checked, only LOW findings F002, F003 remain
Regressions: None found
Checklist: 13/13 points proven

## Geprüfte Dateien

- sha256:28aabadb35d07c6c9050f64b165f48c5832c9ccd0cb0930ac3044d39e4e58c9b  CLAUDE.md
- sha256:b30c6f8f9066fd2c00ca07a28ebc23748301dc7ee9a6eabdc70a165bb5c94a86  LooseEnds/Claude/PushWakeUp.swift
- sha256:fad8770f671f4d466716940130427c6f055f6a924612f8d0e7d926053bbadb72  docs/artifacts/feat-625-weckruf-datenschutz/belege-pfade.txt
- sha256:3516fec511bfdad4989d4f819d858a0c4cba984c912478a31eef67dbe28dca26  docs/artifacts/feat-625-weckruf-datenschutz/live.txt
- sha256:22bbd4136459fa13409156495fdf78568a54504750a33743df624a869ef04c04  docs/artifacts/feat-625-weckruf-datenschutz/vergleich.txt
- sha256:c89bf08c4b985772e3aa7485ec76d2531a875d60abe46a12acaab235698018fc  docs/reference/datenschutz-entwurf.md
- sha256:76723455325bd9f1043ceed36f6c30b79b8c724f899cb87301114a5eda91f201  project.yml
- sha256:c9eff1e7c14a98313a8cf927174b03408712c43e41bbc9741a12637f57accbe4  scripts/test_datenschutz_text.py
- sha256:7a9b8c32dca78fe4320942bc14d45fefc6c60ec17e3cc5e619fbe3f996af6afe  server/src/apns.ts

## Prüfbasis

- base: e347ed7414e80445b1827ad1cb4653d09da2803d
- blob:7a85ed19615574f4acb0665e679d3373d805be16  CLAUDE.md
- blob:961781e2f7ed5c11c6d45104876e2c367d08e31e  LooseEnds/Claude/PushWakeUp.swift
- blob:5a66e7a14fe710e6ee5724de0b2f7aa18640a3c2  docs/artifacts/feat-625-weckruf-datenschutz/belege-pfade.txt
- blob:885a7b6da88ebbce515c451531d207662da3bdfc  docs/artifacts/feat-625-weckruf-datenschutz/live.txt
- blob:c51a1a874711e34f2f51b9a37be0d5a2657fe450  docs/artifacts/feat-625-weckruf-datenschutz/vergleich.txt
- blob:56b3aa1a0ab732a133a43b7cba930a1c94b4306e  docs/reference/datenschutz-entwurf.md
- blob:d398b6ffd451eae24842b9223b8d794f988c85f8  project.yml
- blob:15966d44b96c8cd95386a8de209a36d078152027  scripts/test_datenschutz_text.py
- blob:535817a5128bf6135817343f4d7231d0abb125f4  server/src/apns.ts
