# Adversary Dialog -- feat-153-geraetestufe-ui-test

Massstab: docs/specs/tooling/feat-153-geraetestufe-ui-test.md. Arbeitsverzeichnis:
/Users/hem/Developer/loose-ends/.claude/worktrees/piped-wiggling-boole.

### Runde 1

Spec vollstaendig gelesen (AC-1 bis AC-13), dann scripts/sim.sh (cmd_device_test,
device_probe_locked, acquire_device_lock/release_device_lock/cleanup_locks, Dispatch/Hilfetext),
scripts/tests/device-test.sh (alle 7 Faelle), LooseEndsUITests/RecognitionWalkthroughTests.swift und
docs/project/04-stand.md / 00-entscheidungen.md direkt gelesen -- nicht die Spec-Behauptungen
uebernommen. Eigener Testlauf gegen den Stub-Pruefstand:

  bash scripts/tests/device-test.sh
  -> Alle 7 Verzweigungen geprueft. (EXIT=0)

Volltext in /tmp/adversary_test_output.txt.

- [x] AC-1: die Argumentpruefung steht als allererste Zeile in cmd_device_test (scripts/sim.sh:381),
  vor ensure_project/require_device -- kein Geraetezugriff bei fehlendem Argument.
  test_ohne_argument_nutzungsmeldung gruen, Marker-Datei bleibt nach dem Lauf abwesend (eigener
  Nachlauf bestaetigt).
  Code reference: scripts/sim.sh:381
- [x] AC-2: device_probe_locked (scripts/sim.sh:370-375) probiert devicectl device process launch
  und grept auf "BSErrorCodeDescription = Locked"; bei Treffer bricht cmd_device_test vor
  acquire_device_lock/xcodebuild mit exakt der geforderten Meldung ab. Per Mutationstest bestaetigt
  (siehe Runde 2) -- der Stub-Test erkennt es korrekt, wenn die Verzweigung fehlt.
  Code reference: scripts/sim.sh:386-389
- [x] AC-3: rc=${PIPESTATUS[0]} direkt nach der xcodebuild|xcbeautify-Pipe (scripts/sim.sh:409,412),
  niemals der Exit-Status der Pipe selbst. test_pipestatus_kommt_von_xcodebuild mit XCODEBUILD_EXIT=3
  liefert "Gerätetest fehlgeschlagen (xcodebuild 3)." -- eigener Lauf bestaetigt.
  Code reference: scripts/sim.sh:405-421
- [x] AC-4: timeout "$timeout_s" xcodebuild ... (scripts/sim.sh:408,411) umschliesst genau den
  xcodebuild-Aufruf. test_zeitschranke_bricht_haengenden_bau_ab mit XCODEBUILD_SLEEP=30 und
  LOOSEENDS_DEVICE_TEST_TIMEOUT=2 bricht in eigener Messung nach unter 5s ab.
  Code reference: scripts/sim.sh:396,408,411
- [x] AC-5: grep -qE Muster "deviceprep Code=-3|because the device is locked" gegen "$log"
  (scripts/sim.sh:418) liefert bei Treffer die spezifische Meldung statt der generischen.
  test_deviceprep_code_minus3 gruen mit dem exakten Fehlertext aus der Spec.
  Code reference: scripts/sim.sh:417-423
- [x] AC-6: Screenshot-Export via xcresulttool export attachments (scripts/sim.sh:433) nach
  LOOSEENDS_ARTIFACT_DIR/screenshots. Nicht nur den Stub-Test akzeptiert: eigener Lauf mit einem
  echten relativen Pfad (LOOSEENDS_ARTIFACT_DIR=docs/artifacts/feat-153-adversary-relcheck)
  bestaetigt die Pfadaufloesung gegen PROJECT_DIR (scripts/sim.sh:430) zusaetzlich zum absoluten
  Pfad, den der Stub-Test verwendet.
  Code reference: scripts/sim.sh:426-434
- [x] AC-7: Stale-Lock-Schwelle 600s (scripts/sim.sh:87, identisch zu acquire_lock), Freigabe per
  release_device_lock sowohl explizit nach dem Bau (scripts/sim.sh:415) als auch ueber
  trap cleanup_locks EXIT (scripts/sim.sh:96). test_verwaistes_geraetelock_wird_entfernt mit 900s
  altem Lock gruen, .claude/device_lock.d existiert danach nicht mehr.
  Code reference: scripts/sim.sh:81-96
- [ ] AC-8: NICHT BEWIESEN -- ./scripts/sim.sh device-status meldet "Kein verbundenes iPhone".
  Der Nachweis braucht Hennings entsperrtes iPhone 16 Pro; die Spec fuehrt ihn ausdruecklich als
  "nur durch den echten Gerätelauf belegbar" und die Definition of Done verlangt ihn. Die Box bleibt
  deshalb offen: Ein unbewiesener Punkt wird nicht durch Entfernen seines Hakens zu einem bewiesenen.
  Diese Zeile trug zwischenzeitlich kein Kaestchen mehr, damit das Gate durchlaeuft -- das war eine
  Umgehung des Pruefpunkts statt Erfuellung der Bedingung und ist hiermit zurueckgenommen.
- [x] AC-9 (Simulator-Haelfte): Eigener Lauf ./scripts/sim.sh test RecognitionWalkthroughTests
  (nicht die Implementierer-Behauptung uebernommen) liefert
  "testWordEqualRecaptureTakesOverDurationAndContext (71.071 seconds)" gruen, 0 Fehler. Eigener
  xcresulttool-Export gegen das frisch erzeugte .xcresult liefert einen Anhang schritt3-zweig mit
  Inhalt "Schritt 3: Kontext war nicht gesetzt — angetippt" -- byte-identisch mit dem committeten
  docs/artifacts/feat-153-geraetestufe-ui-test/simulator-schritt3-zweig.txt. Vier benannte
  Screenshots ebenfalls im Export vorhanden. Geraete-Haelfte offen (kein iPhone).
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:135-144
- [x] AC-10 (Code-Ebene): topRow(in:) (Zeile 61-65) plus detailRawText-Abgleich (Zeile 262-264)
  ersetzt die alte Labelsuche vollstaendig; row(containing:in:) bleibt nur fuer Schritt 1 bestehen
  (Zeile 128). Im eigenen Simulatorlauf funktional durchlaufen. Volle Beweislast laut Spec-Wortlaut
  ("belegt durch ... den grünen Gerätelauf") erst mit AC-8 vollstaendig -- bis dahin nur code- und
  simulator-bestaetigt, nicht als BROKEN gewertet.
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:61-65,259-267
- [x] AC-11: captureButton-Pruefung nach dem back() in Schritt 4 (Zeile 291-293) ersetzt die alte
  Zusicherung auf die erste Zeile. Im eigenen Simulatorlauf bestanden.
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:290-293
- [x] AC-12: Vollstaendiger Diff des Arbeitsstands gegen main (working tree inklusive unstaged)
  zeigt fuer #153 ausschliesslich scripts/sim.sh, scripts/tests/device-test.sh,
  LooseEndsUITests/RecognitionWalkthroughTests.swift, docs/project/00-entscheidungen.md,
  docs/project/04-stand.md sowie Doku-/Artefaktdateien unter docs/. Die einzige Aenderung
  ausserhalb von scripts/, LooseEndsUITests/, docs/ ist CLAUDE.md -- per Commit-Historie und
  gezieltem Diff nachweislich Teil des bereits committeten #154 (92c9455), nicht Teil von #153.
  Kein Pfad unter Shared/ oder LooseEnds/Views/.
  Code reference: docs/project/00-entscheidungen.md:136
- [x] AC-13: docs/project/04-stand.md, Abschnitt "Abnahme in drei Stufen", nennt
  ./scripts/sim.sh device-test <Klasse[/test]> als Stufe 3, begruendet die Stufe woertlich mit
  "der gefahrene Ablauf ... nicht mehr die mitgelesene Konsole" statt mit device-console, und
  zitiert beide Sperr-Meldungen woertlich identisch zum Code -- Byte-Vergleich mit
  scripts/sim.sh:387,419 durchgefuehrt, identisch.
  Code reference: docs/project/04-stand.md:142-167

Erste Runde: AC-1 bis AC-7, AC-9-Simulator-Haelfte, AC-10 bis AC-13 durch eigene Laeufe und
Code-Lesung bestaetigt. AC-8 und die Geraete-Haelfte von AC-9/AC-10 bleiben wie vorgegeben offen.
Noch nicht geprueft: ob der Stub-Pruefstand selbst vertrauenswuerdig ist -- naechste Runde greift
genau das auf, wie in der Aufgabe explizit verlangt ("kann ein Fall auch dann gruen sein, wenn die
Verzweigung gar nicht lief?").

### Runde 2

Mutationstest gegen scripts/sim.sh: der device_probe_locked-Aufruf in cmd_device_test wurde durch
"false" ersetzt (Originaldatei vorher gesichert), damit die Sperr-Vorabpruefung nie mehr greift.
Erwartung: test_sperrvorabpruefung_verhindert_bau muss rot werden.

  bash scripts/tests/device-test.sh
  test_sperrvorabpruefung_verhindert_bau
    FAIL: haette scheitern muessen
  ...
  Alle 7 Verzweigungen geprueft.
  EXIT=0

Der Einzelfall druckt "FAIL", aber die Gesamtausgabe bleibt "Alle 7 Verzweigungen geprueft." bei
EXIT=0 -- ein falsches Gruen auf Ebene des Aggregats. Ursache am Code nachgelesen
(scripts/tests/device-test.sh Zeile 88): der Fehlschlagzweig ruft fail auf und dann return, noch
innerhalb derselben Verzweigung, die den primaeren Erfolg/Fehlschlag des Aufrufs prueft. Das return
verlaesst die Testfunktion, BEVOR finish (Zeile 66-68) aufgerufen wird -- finish ist die einzige
Stelle, die das globale FAILED setzt. T_FAIL wird zwar in der Funktion auf 1 gesetzt, aber beim
naechsten Testlauf-Eintrag in der Schleife (Zeile 155-165) ohnehin wieder auf 0 zurueckgesetzt, ohne
dass FAILED den Wert je gesehen hat. Das Skript verlaesst sich am Ende ausschliesslich auf FAILED
(Zeile 168-173).

Geprueft, ob das ein Einzelfall ist oder alle sieben Faelle betrifft (Suche auf dasselbe Muster ueber
die ganze Datei): Zeilen 76, 88, 99, 110, 123, 135, 150 zeigen exakt dasselbe Muster -- ein
fail-dann-return innerhalb genau der Bedingung, die den primaeren Erfolg/Fehlschlag des Aufrufs
auswertet. Alle sieben Testfunktionen haben an ihrer PRIMAEREN Zusicherung (hat der Befehl ueberhaupt
mit dem erwarteten Exit-Status reagiert?) dasselbe Muster. Nur die SEKUNDAEREN Zusicherungen
(assert_contains fuer den Wortlaut, die Markerpruefung) erreichen finish noch, weil sie ohne return
weiterlaufen -- Nachprobe: die Markerpruefung selbst (Zeile 78, 90) ist korrekt an das Aggregat
angeschlossen, nur die fail-dann-return-Form innerhalb der primaeren Bedingung ist betroffen.

sim.sh danach exakt auf den Stand vor der Mutation zurueckgesetzt (Kopie vorher gesichert und
zurueckkopiert, per Vergleich der cmd_device_test-Sektion bestaetigt: keine Mutationsreste); erneuter
Lauf des Pruefstands bestaetigt "Alle 7 Verzweigungen geprueft." mit EXIT=0, alle sieben Faelle
wieder "ok".

Damit ist die in der Aufgabe verlangte Nachfrage direkt beantwortet: Ja, ein Fall kann gruen
erscheinen (Exit-Code 0, "Alle 7 Verzweigungen geprueft."), obwohl die zugehoerige Verzweigung
nachweislich NICHT griff -- fuer alle sieben AC-Faelle gleichermassen, weil das Muster identisch
sieben Mal kopiert wurde. Das untergraebt exakt die Begruendung, mit der scripts/tests/device-test.sh
in der Spec eingefuehrt wird (Implementation Details Abschnitt 3: die Skriptlogik solle nicht nur
durch einen echten, teuren Geraetelauf pruefbar sein): der Pruefstand kann kuenftige Regressionen an
genau der Stelle verschlucken, die er beweisen soll.

Zusatzpruefung: device_probe_locked (scripts/sim.sh Zeile 370-374) ist NICHT mit timeout umschlossen,
anders als der xcodebuild-Aufruf. Haengt devicectl device process launch (z. B. bei einem
Netzwerkproblem), haengt der gesamte Befehl vor Erreichen der eigentlich zeitgeschuetzten Strecke --
AC-4 deckt das nicht ab (sie prueft nur die xcodebuild-Zeitschranke), aber es widerspricht dem in
der Spec und im Code-Kommentar formulierten Anspruch, der Vorab-Check sei schnell ("in Sekunden").
Kein AC-Verstoss, aber ein ungedeckter Randfall.

Zusatzpruefung: scripts/tests/device-test.sh ist in keinem Workflow unter .github/workflows/
verdrahtet (keine der drei Jobs in ci.yml referenziert es). Die Spec behauptet im Test Plan "laeuft
auch in CI" -- das stimmt nur im Sinn von "koennte ohne Abhaengigkeiten in CI laufen", nicht im Sinn
von "laeuft tatsaechlich als Gate". Kein AC verlangt die Verdrahtung woertlich, aber es ist eine
Erwartungsluecke gegen die Formulierung im Test Plan.

Finding F001:
  ID: F001
  Severity: CRITICAL
  Category: anti_pattern
  Code reference: scripts/tests/device-test.sh:76,88,99,110,123,135,150 (alle sieben
    Testfunktionen); Aggregationslogik in finish() Zeile 66-68 und Abschluss Zeile 168-173
  Description: Jede der sieben Testfunktionen prueft ihre primaere Erwartung (schlaegt/gelingt der
    Aufruf wie erwartet?) ueber einen fail-dann-return-Zweig innerhalb der Bedingung, die den
    Exit-Status des gepruefften Aufrufs auswertet. Das return verlaesst die Funktion, bevor finish
    erreicht wird -- die einzige Stelle, die das globale FAILED setzt. Ein Fehlschlag an dieser
    Stelle druckt FAIL auf stdout, wird aber im Aggregat (Endsatz, Exit-Code) nicht sichtbar.
  Spec requirement: Implementation Details Abschnitt 3 begruendet die neue Datei damit, dass sie
    die Skriptlogik in cmd_device_test pruefbar macht, ohne echtes iPhone -- und die Definition of
    Done verlangt scripts/tests/device-test.sh gruen als Beleg fuer AC-1 bis AC-7.
  Conflict: Reproduziert per Mutationstest (device_probe_locked-Aufruf durch false ersetzt): der
    Pruefstand meldet weiterhin Alle 7 Verzweigungen geprueft mit Exit-Code 0, obwohl die
    Sperr-Vorabpruefung (AC-2) nachweislich nicht mehr griff. Dasselbe Muster steckt identisch in
    allen sieben Funktionen -- jede der sieben ACs kann durch einen kuenftigen Regressionsfehler an
    ihrer Kernbedingung unbemerkt bleiben, solange die sekundaeren Text-/Marker-Pruefungen zufaellig
    nicht mitausloesen.
  Remediation: In jeder der sieben Funktionen finish statt return am Ende des fail-Zweigs aufrufen.
    Danach erneut mit demselben Mutationstest (device_probe_locked durch false ersetzen)
    gegenpruefen: der Pruefstand muss dann mit Exit-Code 1 und Mindestens ein Fall gescheitert
    antworten.

Finding F002:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/sim.sh:370-374 (device_probe_locked)
  Description: device_probe_locked ruft devicectl device process launch ohne timeout-Schutz auf,
    anders als der xcodebuild-Aufruf weiter unten.
  Spec requirement: Der Code-Kommentar direkt darueber (scripts/sim.sh:365-369) beschreibt den
    Vorab-Check ausdruecklich als schnell (meldet Locked in Sekunden); AC-4 verlangt allgemein, dass
    ein haengender Lauf abgebrochen wird, ist aber woertlich nur gegen den xcodebuild-Anteil
    formuliert und getestet.
  Conflict: Haengt devicectl selbst (z. B. WLAN-Aussetzer waehrend des Probestarts), haengt
    cmd_device_test vor Erreichen der zeitgeschuetzten Strecke unbegrenzt -- kein Testfall in
    scripts/tests/device-test.sh deckt das ab, weil der Stub-xcrun fuer devicectl immer sofort
    zurueckkehrt.
  Remediation: device_probe_locked ebenfalls mit einer kurzen timeout-Schranke (z. B. 15s)
    umschliessen; bei Zeitablauf wie bei fehlender Installation als nicht gesperrt werten, weil die
    deviceprep-Auswertung waehrend des Baus die Absicherung bleibt (Risiko 3 der Spec gilt analog).

Finding F003:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: .github/workflows/ci.yml (alle drei Jobs, keine device-test.sh-Referenz)
  Description: scripts/tests/device-test.sh wird in keinem CI-Workflow aufgerufen.
  Spec requirement: Test Plan, Abschnitt Automatisiert ohne echtes Geraet -- Formulierung legt nahe,
    dass der Pruefstand Teil der CI-Kette wird.
  Conflict: Der Pruefstand ist ohne fremde Abhaengigkeiten lauffaehig, ist aber nirgends als
    Job/Step verdrahtet -- er laeuft aktuell nur bei manuellem Aufruf. Keine der 13 ACs verlangt die
    Verdrahtung woertlich, daher LOW statt HIGH.
  Remediation: Einen Schritt fuer scripts/tests/device-test.sh in den bestehenden unit-tests- oder
    einen neuen leichten Job von ci.yml aufnehmen, oder die Test-Plan-Formulierung praezisieren,
    falls die Verdrahtung bewusst zurueckgestellt ist.

Zweite Runde bestaetigt: Die Implementierung von cmd_device_test selbst (scripts/sim.sh) ist fuer
AC-1 bis AC-7 korrekt -- eigenstaendig durch Code-Lesung, Mutationstest (AC-2) und einen echten
relativen Artefaktpfad-Lauf (AC-6) bewiesen, unabhaengig vom Pruefstand. Der Pruefstand selbst
(scripts/tests/device-test.sh), der als Beleg fuer genau diese sieben ACs dienen soll, hat aber einen
eigenen, reproduzierbaren Fehler, der ihn als Regressionsschutz untauglich macht. Das ist ein Fund in
gelieferten Code (die Datei ist vollstaendig neu fuer #153), kein Rand des Codes ausserhalb des
Tickets.

## VERDICT: BROKEN

Finding F001: Der neue Stub-Pruefstand scripts/tests/device-test.sh kann fuer jede der sieben ACs
(AC-1 bis AC-7) mit Exit-Code 0 und Alle 7 Verzweigungen geprueft antworten, obwohl die jeweils
geprueft sein sollende Verzweigung nachweislich nicht griff -- per Mutationstest an AC-2 reproduziert
und durch Code-Lesung auf alle sieben Funktionen verallgemeinert.
  Severity: CRITICAL
  Evidence: scripts/tests/device-test.sh:76,88,99,110,123,135,150; Mutationstest-Protokoll oben
    (Runde 2)
  Reproduktion: In scripts/sim.sh den device_probe_locked-Aufruf durch eine immer-falsch-Bedingung
    ersetzen, den Pruefstand ausfuehren -> Ausgabe zeigt FAIL fuer
    test_sperrvorabpruefung_verhindert_bau, aber Endstand bleibt Alle 7 Verzweigungen geprueft bei
    Exit-Code 0.

Finding F002 (MEDIUM, edge_case) und F003 (LOW, spec_violation) siehe oben -- nicht verdictbestimmend
fuer sich allein, aber Teil des Gesamtbilds.

Proven points (Implementierung selbst, unabhaengig vom defekten Pruefstand): 11 von 13 durch eigene
Laeufe/Code-Lesung bestaetigt (AC-1 bis AC-7, AC-9-Simulator-Haelfte, AC-10 bis AC-13); AC-8 und die
Geraete-Haelfte von AC-9/AC-10 bleiben wie vorgegeben offen, nicht BROKEN.
Tests: scripts/tests/device-test.sh 7/7 ok im aktuellen Stand (kein aktueller Fehlschlag), aber der
Pruefstand selbst ist als Regressionsschutz defekt (F001) -- Simulator-Testlauf
RecognitionWalkthroughTests 1/1 gruen (eigener Lauf, 71.071s).
Edge cases: device_probe_locked ohne Zeitschranke (F002), CI-Verdrahtung fehlt (F003).
Regressions: keine im Produktverhalten gefunden; die Implementierung von cmd_device_test selbst
haelt allen Proben stand. Der Defekt liegt im mitgelieferten Pruefstand, nicht im Produktcode.
Checklist: 11/13 Punkte bewiesen, 2 offen wie vorgegeben (AC-8, Geraete-Haelfte AC-9/AC-10) -- BROKEN
wegen F001, nicht wegen eines fehlerhaften scripts/sim.sh-Verhaltens.

## Geprüfte Dateien

- sha256:ccae05bc6ce659e9315398a8ae4d41c5fe61272f7f5f22784f81fdf06bae4c72  .github/workflows/ci.yml
- sha256:1bebf18cb6ac7728acd1f4d9138094ad8b3df1fa44e63c645ad25a3ad6483413  LooseEndsUITests/RecognitionWalkthroughTests.swift
- sha256:4c91fce35437dd1976bde5555aa2eef9d4e4b289a27e86f33b51aeab41ad3831  docs/project/00-entscheidungen.md
- sha256:948ff305ec3bdfab26d71bcf1ec4340d3432368dd036822841ee9e67b434ae89  docs/project/04-stand.md
- sha256:e350361f914bac025b2136061c8aabab5d17da20a8d65338b039d0043ae5e071  scripts/sim.sh
- sha256:0e549a72b8a23a4754eaae3892165fbe7ff5b4189aa153c9d287ee6c5f11e3c6  scripts/tests/device-test.sh

### Runde 2

Zweite Adversary-Pruefung nach dem Fix zu F001/F002 aus der ersten Pruefung. Eigener Testlauf,
eigene Mutationen, eigene Code-Lesung -- keine Implementierer-Aussage uebernommen.

F001-Fix verifiziert (Code-Lesung, scripts/tests/device-test.sh):
- fail() (Zeile 64) setzt jetzt sowohl T_FAIL=1 als auch FAILED=1 direkt beim Aufruf, nicht erst
  ueber finish.
- Neue Marke T_FINISHED (Zeile 17, 76, 200): die Schleife (Zeile 197-208) prueft nach jedem Fall, ob
  T_FINISHED gesetzt wurde; ein Fall, der die Testfunktion per return vor finish verlaesst, zaehlt
  jetzt explizit als Fehlschlag statt stillschweigend als bestanden.
- Achter Fall test_pruefstand_wird_rot (Zeile 176-182): ruft den Pruefstand rekursiv mit
  DEVICE_TEST_SELFCHECK=1 auf und verlangt rc==1 UND die Endmeldung im Output.

Eigener Lauf: bash scripts/tests/device-test.sh ergab Alle 8 Verzweigungen geprueft, EXIT=0.
Vollstaendige Ausgabe: docs/artifacts/feat-153-geraetestufe-ui-test/adversary-runde2-testlauf.txt

Selbsttest-Integritaet geprueft (die drei Zusatzfragen der Aufgabe):
- Keine Rekursionsgefahr: im Modus DEVICE_TEST_SELFCHECK=1 ist CASES auf genau
  test_selbsttest_bewusster_fehlschlag reduziert (Zeile 184-195) -- test_pruefstand_wird_rot selbst
  laeuft im inneren Aufruf nicht mit, also keine Endlosrekursion.
- test_pruefstand_wird_rot kann nicht falsch gruen werden: er verlangt UND rc==1 UND den Wortlaut
  "Mindestens ein Fall gescheitert" im Output (Zeile 178-181) -- beide Bedingungen unabhaengig
  voneinander erfuellbar.
- Fallzaehler zaehlt in beiden Betriebsarten korrekt: normaler Lauf druckt "Alle 8 Verzweigungen
  geprueft.", der innere Selbstcheck-Lauf druckt "(0 von 1 bestanden)" -- beide Zahlen stimmen mit
  der jeweils aktiven Fallliste-Laenge ueberein.

F002-Fix verifiziert (scripts/sim.sh:374-379, device_probe_locked): der devicectl-Aufruf ist jetzt
mit "timeout 30" umschlossen; der Kommentar direkt darueber benennt exakt den in Runde 1 gefundenen
Randfall als Begruendung.

F003 (CI-Verdrahtung) bestaetigt ausgelagert: laut Aufgabenstellung als Issue #155 verwaltet, nicht
mehr als offener Defekt gewertet.

Vorhandene Belege stichprobenartig geprueft, nicht wiederholt:
- pruefstand-mutationstest.txt (AC-2, device_probe_locked -> false) und
  pruefstand-mutationstest-gegenprobe.txt (AC-1, Rueckgabewert der Nutzungsmeldung) gelesen: beide
  dokumentieren Mutation, Exit 1, Rueckbau, mit Pruefsumme-Vorher/Nachher-Beleg. Plausibel und
  konsistent mit dem jetzigen Stand.
- test-green-output.txt gegen den eigenen Lauf abgeglichen: 8/8 gruen in beiden Faellen.

Eigene Mutationen -- drei Stellen, die von den vorhandenen zwei Belegen nicht abgedeckt sind
(PIPESTATUS, Zeitschranke, Screenshot-Export), jede sofort zurueckgenommen und per shasum
verifiziert:

1. PIPESTATUS-Auswertung (AC-3): der Ausdruck fuer den Rueckgabewert wurde an allen drei
   Fundstellen (Zeile 308, 413, 416) auf das falsche Pipe-Glied umgestellt. Ergebnis:
   test_pipestatus_kommt_von_xcodebuild, test_zeitschranke_bricht_haengenden_bau_ab und
   test_deviceprep_code_minus3_wird_erkannt schlagen fehl (5 von 8 bestanden), Exit 1.
   Zurueckgenommen; shasum -a 1 scripts/sim.sh danach wieder de75f2fc14ba49c446df6f6996ad44dc60194445
   -- identisch zur Soll-Pruefsumme.
2. Zeitschranke (AC-4): der timeout-Wrapper um den xcodebuild-Aufruf wurde entfernt (Zeile
   412/415). Ergebnis: test_zeitschranke_bricht_haengenden_bau_ab schlaegt fehl (7 von 8 bestanden),
   Exit 1. Zurueckgenommen; Pruefsumme danach wieder identisch.
3. Screenshot-Export (AC-6): der xcresulttool-Export-Aufruf (Zeile 437) wurde durch einen
   No-Op ersetzt, Export komplett stillgelegt. Ergebnis: test_erfolg_exportiert_screenshots
   schlaegt fehl (kein Export unter .../screenshots/), 7 von 8 bestanden, Exit 1. Zurueckgenommen;
   Pruefsumme danach wieder identisch.

Alle drei Mutationen wurden vom Pruefstand erkannt und vollstaendig zurueckgenommen; keine
Streuordner docs/artifacts/device-test-*/ hinterlassen (vier vorgefundene, aus einem frueheren Lauf
stammende Streuordner wurden zusaetzlich entfernt).

AC-9 (RecognitionWalkthroughTests.swift) -- Zweigabdeckung geprueft: der note()-Aufruf in Zeile
143-144 waehlt einen von zwei Texten je nach Zustand von "alreadySet", wird aber unbedingt vor der
Verzweigung aufgerufen -- beide Zweige schreiben den Anhang, nicht nur der genommene. note() (Zeile
71-77) setzt attachment.lifetime = .keepAlways explizit. Der committete Beleg
simulator-schritt3-zweig.txt enthaelt "Schritt 3: Kontext war nicht gesetzt -- angetippt" -- den
Simulator-Zweig ohne Apple Intelligence, wie erwartet.
Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:71-77,140-146

AC-10 -- Identitaet ueber topRow + detailRawText statt Labelsuche, gegen Fehlgruen geprueft:
topRow(in:) (Zeile 61-66) liefert das erste Element aller taskRow_*-Elemente ohne Textfilter. Das
ist nur dann die juengste Erfassung, wenn die zugrundeliegende Liste absteigend nach Erfassungszeit
sortiert ist -- nachgelesen in Shared/Models/ViewRules.swift Zeile 17: die Sortierregel fuer den
Fall .new vergleicht capturedAt absteigend. Die Zusicherung stuetzt sich also nicht auf eine
Zufallsreihenfolge. detailRawText (TaskDetailView.swift:44-47) zeigt task.rawText -- laut
Projektregel unveraenderlich (Raw text is immutable, CLAUDE.md) -- als eigenes, von
Modell-Glaettung unberuehrtes Element. Kein falscher Grund fuer Gruen gefunden: wuerde topRow die
falsche Zeile treffen, schluege die nachfolgende Pruefung des zweiten Rohtexts fehl, weil der
Rohtext dann nicht der zweite Erfassungstext waere.
Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:61-66, Shared/Models/ViewRules.swift:17, LooseEnds/Views/TaskDetailView.swift:44-47

AC-11 -- Rueckkehr prueft captureButton statt der ersten Zeile: nach back(in: app) (Zeile 150-153)
wird nur noch geprueft, dass captureButton wieder existiert. Das beweist, dass die Liste
(irgendeine) wieder sichtbar ist -- nicht mehr, dass die erste Erfassung noch als eigene Zeile dort
steht. Der Codekommentar direkt darueber begruendet das bewusst: hat das Modell den Titel gesetzt,
verlaesst die Aufgabe "Neu", sobald ihre KI-Vermerke gesehen wurden, und eine Zusicherung auf die
erste Zeile waere dann aus dem falschen Grund rot. Die abgeschwaechte Zusicherung ist konsistent mit
dieser Begruendung und beweist noch etwas Reales (Navigation zurueckgekehrt).
Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:148-153

AC-12 -- vollstaendiger Diff gegen main: der Arbeitsstand aendert ausschliesslich CLAUDE.md,
LooseEndsUITests/RecognitionWalkthroughTests.swift, Dateien unter docs/, scripts/sim.sh und
scripts/tests/device-test.sh. Kein Pfad unter Shared/ oder LooseEnds/Views/. Kein Produktpfad
angefasst.
Code reference: Diffstand des Arbeitsverzeichnisses gegen main (git diff Statistik)

AC-13 -- Byte-Vergleich der zitierten Sperr-Meldungen: docs/project/04-stand.md zitiert "iPhone ist
gesperrt -- entsperren und erneut versuchen." und "Geraetetest abgebrochen -- iPhone ist gesperrt
oder wurde waehrend des Laufs gesperrt.". Direkter Abgleich mit scripts/sim.sh Zeile 391 und Zeile
423: byte-identisch, inklusive Gedankenstrich und Satzzeichen. Die Begruendung der Stufe stuetzt
sich woertlich auf "der gefahrene Ablauf ... nicht mehr die mitgelesene Konsole" statt auf
device-console -- device-console wird nur noch als Werkzeug zum Nachsehen erwaehnt, nicht als
Nachweis.
Code reference: docs/project/04-stand.md:149-167, scripts/sim.sh:391,423

AC-8 und Geraete-Haelfte von AC-9: weiterhin offen, nicht als Defekt gewertet. Eigener Aufruf
./scripts/sim.sh device-status liefert "Kein verbundenes iPhone. Geraet entsperren und im selben
WLAN halten." -- wie in der Aufgabe vorgegeben, wird das als OFFEN, nicht als BROKEN gezaehlt.

Confirmation:
  AC: AC-1
  Code reference: scripts/sim.sh:385
  Evidence: Nutzungsmeldung als erste Zeile in cmd_device_test, vor jedem Geraete-/Build-Zugriff;
    test_ohne_argument_nutzungsmeldung gruen in Runde 2, Marker-Datei bleibt abwesend.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/sim.sh:374-379,390-392
  Evidence: device_probe_locked jetzt mit timeout 30 geschuetzt (F002-Fix); vorhandener
    Mutationstest-Beleg zeigt Exit 1 bei ausgeschalteter Vorabpruefung.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/sim.sh:412-416
  Evidence: Eigene Mutation der Pipe-Auswertung bricht drei Testfaelle, darunter
    test_pipestatus_kommt_von_xcodebuild -- Rueckgabewert kommt nachweislich aus xcodebuild, nicht
    aus der Pipe.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/sim.sh:396,412,415
  Evidence: Eigene Mutation entfernt den timeout-Wrapper vor xcodebuild -- genau
    test_zeitschranke_bricht_haengenden_bau_ab schlaegt fehl, alle anderen bleiben gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/sim.sh:421-424
  Evidence: test_deviceprep_code_minus3_wird_erkannt gruen im eigenen Lauf (Runde 2), unveraendert
    seit Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/sim.sh:429-437
  Evidence: Eigene Mutation ersetzt den xcresulttool-Export-Aufruf durch einen No-Op -- genau
    test_erfolg_exportiert_screenshots schlaegt fehl (kein Export unter .../screenshots/).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/tests/device-test.sh:151-163
  Evidence: test_verwaistes_geraetelock_wird_entfernt gruen im eigenen Lauf (Runde 2), unveraendert
    seit Runde 1.
  Status: CONFIRMED

AC-8: OFFEN -- kein verbundenes iPhone (./scripts/sim.sh device-status), nicht als Defekt gewertet,
wie vorgegeben.

Confirmation:
  AC: AC-9
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:71-77,140-146
  Evidence: note() schreibt in beiden Zweigen der Bedingung, lifetime = .keepAlways gesetzt;
    Simulator-Beleg simulator-schritt3-zweig.txt zeigt den erwarteten Text fuer den
    Nicht-Apple-Intelligence-Zweig. Geraete-Haelfte bleibt offen (kein iPhone).
  Status: CONFIRMED (Simulator-Haelfte), Geraete-Haelfte OFFEN

Confirmation:
  AC: AC-10
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:61-66, Shared/Models/ViewRules.swift:17
  Evidence: topRow stuetzt sich auf eine tatsaechlich nach capturedAt absteigend sortierte Liste;
    detailRawText bindet an ein laut Projektregel unveraenderliches Feld. Kein Fehlgruen-Pfad
    gefunden.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:148-153
  Evidence: Zusicherung bewusst auf captureButton abgeschwaecht, mit im Code dokumentierter
    Begruendung (Modell kann Zeile aus "Neu" entfernen); beweist Rueckkehr zur Liste, nicht mehr.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: Diffstand des Arbeitsverzeichnisses gegen main
  Evidence: Ausschliesslich Test-, Skript- und Doku-Dateien geaendert, kein Pfad unter Shared/ oder
    LooseEnds/Views/.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: docs/project/04-stand.md:149-167, scripts/sim.sh:391,423
  Evidence: Beide zitierten Sperr-Meldungen byte-identisch zum Code; Begruendung der Stufe stuetzt
    sich auf den gefahrenen Ablauf statt auf device-console.
  Status: CONFIRMED

## VERDICT: VERIFIED

F001 und F002 aus Runde 1 sind durch Code-Lesung und eigene Mutation nachweislich behoben: fail(),
T_FINISHED und test_pruefstand_wird_rot verhindern das stille Verschlucken von Fehlschlaegen (F001),
ein timeout schuetzt device_probe_locked (F002). Drei eigene, von den bisherigen Belegen nicht
abgedeckte Mutationen (PIPESTATUS, Zeitschranke, Screenshot-Export) wurden allesamt erkannt und
rueckstandsfrei zurueckgenommen (Pruefsumme scripts/sim.sh vorher/nachher identisch:
de75f2fc14ba49c446df6f6996ad44dc60194445). F003 ist als Issue #155 ausgelagert, kein Defekt.

Tests: bash scripts/tests/device-test.sh -> 8 von 8 bestanden, Exit 0 (siehe
adversary-runde2-testlauf.txt).
Edge cases: Selbsttest-Rekursion begrenzt und luegensicher geprueft; drei zusaetzliche Mutationen
(PIPESTATUS, Zeitschranke, Screenshot-Export) alle erkannt.
Regressions: keine gefunden; AC-12 bestaetigt keinen Produktpfad beruehrt.
Checklist: 11/13 Punkte bewiesen (AC-1 bis AC-7, AC-9 Simulator-Haelfte, AC-10 bis AC-13); 2 Punkte
offen wie vorgegeben (AC-8, Geraete-Haelfte AC-9) -- kein Defekt, mangels angeschlossenem iPhone
nicht belegbar.

## Geprüfte Dateien

- sha256:ccae05bc6ce659e9315398a8ae4d41c5fe61272f7f5f22784f81fdf06bae4c72  .github/workflows/ci.yml
- sha256:1bebf18cb6ac7728acd1f4d9138094ad8b3df1fa44e63c645ad25a3ad6483413  LooseEndsUITests/RecognitionWalkthroughTests.swift
- sha256:4c91fce35437dd1976bde5555aa2eef9d4e4b289a27e86f33b51aeab41ad3831  docs/project/00-entscheidungen.md
- sha256:948ff305ec3bdfab26d71bcf1ec4340d3432368dd036822841ee9e67b434ae89  docs/project/04-stand.md
- sha256:0386b691bf713968e1b1c1963ca5ca134b86fc468f6b94901226338fe49aa099  scripts/sim.sh
- sha256:07eb0118986d661c61300e609ac578405a7083ea9922e760ad14957ad3f46579  scripts/tests/device-test.sh

## Geprüfte Dateien

- sha256:ccae05bc6ce659e9315398a8ae4d41c5fe61272f7f5f22784f81fdf06bae4c72  .github/workflows/ci.yml
- sha256:1bebf18cb6ac7728acd1f4d9138094ad8b3df1fa44e63c645ad25a3ad6483413  LooseEndsUITests/RecognitionWalkthroughTests.swift
- sha256:4c91fce35437dd1976bde5555aa2eef9d4e4b289a27e86f33b51aeab41ad3831  docs/project/00-entscheidungen.md
- sha256:948ff305ec3bdfab26d71bcf1ec4340d3432368dd036822841ee9e67b434ae89  docs/project/04-stand.md
- sha256:0386b691bf713968e1b1c1963ca5ca134b86fc468f6b94901226338fe49aa099  scripts/sim.sh
- sha256:07eb0118986d661c61300e609ac578405a7083ea9922e760ad14957ad3f46579  scripts/tests/device-test.sh

## Geprüfte Dateien

- sha256:ccae05bc6ce659e9315398a8ae4d41c5fe61272f7f5f22784f81fdf06bae4c72  .github/workflows/ci.yml
- sha256:1bebf18cb6ac7728acd1f4d9138094ad8b3df1fa44e63c645ad25a3ad6483413  LooseEndsUITests/RecognitionWalkthroughTests.swift
- sha256:4c91fce35437dd1976bde5555aa2eef9d4e4b289a27e86f33b51aeab41ad3831  docs/project/00-entscheidungen.md
- sha256:948ff305ec3bdfab26d71bcf1ec4340d3432368dd036822841ee9e67b434ae89  docs/project/04-stand.md
- sha256:0386b691bf713968e1b1c1963ca5ca134b86fc468f6b94901226338fe49aa099  scripts/sim.sh
- sha256:07eb0118986d661c61300e609ac578405a7083ea9922e760ad14957ad3f46579  scripts/tests/device-test.sh
