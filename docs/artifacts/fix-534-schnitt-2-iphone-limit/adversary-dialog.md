# Adversary Dialog — fix-534-schnitt-2-iphone-limit
Spec: docs/specs/fix-534-schnitt-2-iphone-latenz.md
Datum: 2026-10-23 09:11

## Checkliste
- [x] **AC-1:** `Corpus` bekommt drei reine Funktionen: `resultName(from:)` (`--result <name>`, ohne Flag `date-title`), `contextWords(from:)` (`--context-words a,b,c`, ohne Flag leer) und `exitWhenDone(from:)` (`--exit-when-done`, ohne Flag `false`). Ohne alle drei Flags verhält sich die Labor-App wie bisher. `CorpusTests` prüft Flag mit Wert, Flag ohne Wert und fehlendes Flag.
- [x] **AC-2:** Die Labor-App legt ihre Ergebnisse unter dem Namen aus `--result` ab, übergibt die Wörter aus `--context-words` als `contextVocabulary` und beendet sich mit `exit(0)`, nachdem der letzte Satz gespeichert ist, wenn `--exit-when-done` gesetzt ist. Ohne die Flags bleibt alles wie heute. Die Labor-App ist kein Pfad der Geräteliste und kein Teil der Produkt-App.
- [x] **AC-3:** `Measurement/latency-corpus.json` enthält genau die sechs Notizen von `RealModel.notes` in derselben Reihenfolge (`id` `lat-01` … `lat-06`, `lang` `de` oder `en`). `CorpusTests` vergleicht die Texte mit `RealModel.notes`, damit Mac und iPhone dieselbe Eingabe haben.
- [x] **AC-4:** `./scripts/sim.sh lab-latency <n>` baut die Labor-App einmal und installiert sie (nur `com.henning.looseends.lab`), startet dann n Prozesse nacheinander mit `--measure --corpus latency-corpus --runs 2 --result latency-NN --context-words Computer,Telefon,Haus,Garten,Unterwegs,Besorgung --exit-when-done` (je Start 12 Aufrufe: 1 kalter, 11 warme), holt jede Datei nach `docs/artifacts/534-modell-latenz/iphone/latency-NN.json` und fasst am Ende zusammen. Es bricht mit klarer Meldung ab, wenn das iPhone gesperrt ist, kein Gerät verbunden ist, ein Start nach 300 s nicht endet oder eine Datei fehlt. Es fasst keine andere App, kein iPad, keine Watch und nicht den Mac als Ziel an.
- [x] **AC-5:** `scripts/latency_summary.py <ordner>` erkennt das Labor-Format (`latency-*.json` mit `results`): der erste Eintrag jeder Datei ist `kalt`, die übrigen `warm`; Einträge mit `error` zählen als Fehler und gehen nicht in Minimum/Median/p95/Maximum. Zusätzlich zeigt es je Gruppe das Maximum nach Hitze (`conditions.thermal`: normal, fair, serious, critical) und die Zahl der Aufrufe je Stromquelle. Das bisherige Mac-Format bleibt lesbar; leerer Ordner oder fehlende Gruppe: Meldung, Exit ≠ 0. `test_latency_summary.py` prüft das mit festen Beispielwerten.
- [x] **AC-6:** Gemessen sind mindestens 10 Starts auf Hennings iPhone 16 Pro (10 kalte, 110 warme Aufrufe), und zwar erst nach seinem wörtlichen „jetzt ist ein Test möglich“ (2026-10-22, gilt für diesen Durchgang). Der Bericht `docs/reference/modell-latenz.md` bekommt den iPhone-Teil: Gerät und System aus `Conditions`, Kennzahlen kalt/warm wie am Mac, Hitze und Stromquelle getrennt, Verhältnis Kalt-Maximum zu Warm-Maximum gegen die Schwelle Faktor 5 (Empfehlung zu „zwei Grenzen“), Vergleich Mac gegen iPhone, und den **Vorschlag** für Schnitt 3 nach der Regel „Dreifaches des größten gemessenen Werts beider Geräte, aufgerundet auf 5 s, mindestens 15 s; über 60 s geht die Frage an Henning zurück“. Der Bericht setzt keine Zahl im Produkt.
- [x] **AC-7:** Alles unter `Shared/` (insbesondere `EnrichmentCoordinator.swift` und `FoundationModelsEnricher.swift`) und die Produkt-App `LooseEnds/` bleiben unverändert. Das Ticket #534 bleibt offen, kein `Closes #534`.
- [x] **AC-8:** Auf dem iPhone läuft nur die Labor-App (`LE Labor`), nur in diesem einen Durchgang. Es wird nichts anderes installiert oder beendet, Hennings Alltags-App und der Prüfbau bleiben unberührt. Alles Vorbereitende (Bau, Installation) ist abgeschlossen, bevor Henning zum Entsperren gerufen wird; der Lauf beginnt mit derselben Nachricht.

## Dialog

### Runde 1
**Adversary:**
Geprüft: Diff aller Dateien, Bash-Syntax, python3 scripts/test_latency_summary.py (9 Tests OK), Belege test-green-swift.txt/-python.txt, Wegwerf-Experimente mit latency_summary.py. Kein Gerätezugriff.

Finding:
  ID: F001
  Severity: HIGH
  Category: spec_violation
  Code reference: LooseEndsLab/MeasurementRunner.swift:106
  Description: measureRemaining() iteriert über run.remaining(from:runsPerEntry:) genau einmal. remaining() liefert je Notiz nur EINEN offenen Eintrag (nächster runIndex, Measurement/MeasurementRun.swift:165-173, belegt durch MeasurementRunTests.swift:144-154). Nach einem Durchlauf (6 Aufrufe) wird state=.finished gesetzt und bei --exit-when-done sofort exit(0) (Zeile 133).
  Spec requirement: AC-2/AC-4 — je Start 12 Aufrufe (1 kalt, 11 warm), AC-6 — 10 kalte und 110 warme Aufrufe
  Conflict: Mit --runs 2 und --exit-when-done liefert jeder Start nur 6 Aufrufe (1 kalt, 5 warm, alle runIndex 0); 10 Starts ergeben 10 kalte und 50 warme statt 110. Die zweite Runde wird nie gemessen. Der Selbstbeendigungs-Pfad ist durch keinen Test abgedeckt.
  Remediation: Schleife in measureRemaining wiederholen, bis remaining leer ist (die 3-Fehler-Bremse stoppt sie), oder runsPerEntry Durchläufe über die Notizen fahren; exit(0) erst danach. Test für die Zahl der Aufrufe je Start (Enricher als Stub, exit injizierbar).

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/sim.sh:910-913
  Description: lab_latency_launch löscht weder Documents/latency-NN.json auf dem Gerät noch die Zieldatei im Repo vor dem Start. Existiert die Datei auf dem Gerät schon vollständig (Wiederholung nach Abbruch bei Start 7, oder zweite Reihe), ist remaining leer, die App beendet sich sofort mit exit(0) (MeasurementRunner.swift:106-133 mit leerer Schleife), und das Skript holt die alten Daten und meldet Erfolg. Schlägt copy from fehl (|| true), besteht eine alte Datei im Repo die Prüfung [ -s ].
  Spec requirement: AC-4 — bricht ab, wenn eine Datei fehlt; jede Datei gehört zu einem eigenen Start
  Conflict: Eine Wiederholung liefert stillschweigend alte oder unvollständige Messwerte, ohne dass gemessen wurde.
  Remediation: Zieldatei im Repo vor dem Start entfernen; Altdatei auf dem Gerät beachten (z. B. Name mit Zeitstempel/Lauf-ID statt latency-NN, oder App-Daten vorab zurücksetzen) und Ergebnis prüfen: results enthält die erwartete Zahl Einträge, sonst Abbruch.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/sim.sh:906-910
  Description: Nur Exit 0 gilt als Erfolg. Ob devicectl bei exit(0) der App im --console-Modus selbst 0 zurückgibt, ist ohne Gerät nicht prüfbar; sonst bricht jeder Start mit Meldung ab. Eine pausierte Messung (Hintergrund, Drosselung) beendet den Prozess nicht und läuft in den 300-s-Abbruch (klare Meldung, gewollt).
  Spec requirement: AC-4
  Conflict: unklar bis zum Gerätelauf
  Remediation: In Runde 2 am echten Lauf belegen.

Confirmation:
  AC: AC-1
  Code reference: Measurement/Corpus.swift:152
  Evidence: resultName/contextWords/exitWhenDone mit Defaults date-title, [], false; Flag ohne Wert und fehlendes Flag liefern den Default; contextWords trimmt und filtert leere Teile. CorpusTests.swift:205-224 prüft Flag mit Wert, ohne Wert, fehlend. Defaults entsprechen dem alten Verhalten (MeasurementRunner-Defaults date-title, leer, false).
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: Measurement/latency-corpus.json:1
  Evidence: sechs Einträge lat-01..lat-06, Texte wörtlich gleich RealModel.notes (LooseEndsTests/RealModelTests.swift:25-32), lang de/en. CorpusTests.swift:226-232 vergleicht. Datei liegt unter Measurement/, einer Quelle von LooseEndsLab (project.yml). Hinweis: Datei ist noch nicht versioniert (muss mit committet werden).
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: scripts/latency_summary.py:62
  Evidence: Experimente: leerer Ordner Exit 1 mit Meldung; Datei mit nur einem Eintrag Exit 1 (warm ohne gültige Probe); results leer Exit 1; fehlendes conditions und unbekannter thermal-Wert werden als unbekannt/weird gezählt statt Absturz; Fehlereintrag zählt nur in fehler; altes Mac-Format unverändert, gemischter Ordner geht. test_latency_summary.py 9 Tests OK.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:1
  Evidence: Diff gegen HEAD und gegen die Gabelung von origin/main ist für Shared/ und LooseEnds/ leer (der Zweipunkt-Vergleich mit origin/main zeigt fremde Änderungen, weil origin/main weitergelaufen ist; nicht von diesem Branch). Kein Closes #534 in Spec oder Artefakten.
  Status: CONFIRMED
Teilweise geprüft, nicht bestätigt wegen F001/F002:
  AC-2: Code reference: LooseEndsLab/LabApp.swift:14 — Name, Wörterbuch (MeasurementRunner.swift:144 in EnrichmentInput) und exit(0) nach save() (Zeile 112 vor 133) stimmen; Defekt F001.
  AC-4: Code reference: scripts/sim.sh:918 — nur LAB_BUNDLE (Bundle-ID per plutil geprüft), keine andere App; gesperrt/kein Gerät/300 s/fehlende Datei abgedeckt; bash -n OK; Defekte F001 (12 Aufrufe) und F002.
AC-6, AC-8: offen bis Gerätelauf (Runde 2).
**Implementierer:**

### Runde 2
**Adversary:**
Geprüft ohne Gerätezugriff: Rohdaten, Auswertung, Bericht, Skript, Quelltext. python3 scripts/test_latency_summary.py: 9 OK. bash -n scripts/sim.sh: sauber. Diff gegen HEAD für Shared/ und LooseEnds/: leer. Rohdaten: 10 Dateien, je 12 Einträge, runIndex 0 x6 und 1 x6, device iPhone17,1, Fehler 0, power akku; Hitze serious 112, fair 8; appState inaktiv 10 (je erster Aufruf), vordergrund 110. latency_summary.py liefert kalt n=10 min 4,17 med 4,68 p95/max 7,92; warm n=110 min 4,15 med 4,83 p95 5,96 max 6,72, identisch zum Bericht und zum Protokoll lab-latency-run.txt. Mac-Maximum aus lauf-*.json nachgerechnet: 165 Werte, 4,666 s. Vorschlag: 3 x 7,92 = 23,8, aufgerundet 25 s, zwischen 15 und 60: Regel korrekt angewandt. Faktor-5-Prüfung 7,92/6,72 = 1,18 und Mac 4,20/4,67 = 0,90. Mac-iPhone-Faktoren 1,54 / 1,44 / 1,89 stimmen mit der Tabelle (gerundet 1,5 / 1,4 / 1,9). Hitze je Stufe und Strom getrennt ausgewiesen (warm: 7 fair + 103 serious = 110). Die Selbstbeendigung ist belegt: 120 Einträge statt 60 (F001 behoben, MeasurementRunner.swift:108 Schleife bis pass leer, MeasurementRun.swift:179, Tests latencyLaunchMakesEveryRun / normalSliceMakesOnePass in MeasurementRunTests.swift:175/185, RED-Beleg test-red-f001.txt, GREEN test-green-swift.txt, 0 Fehler).
F002 behoben: scripts/sim.sh:938 deinstalliert nur LAB_BUNDLE, :950 rm -f der Zieldatei, :915-920 Prüfung auf mindestens 12 Einträge. F003 belegt: lab-latency-run.txt endet mit exit 0 nach 10 Starts, devicectl gibt also nach exit(0) der App 0 zurück.

Finding:
  ID: F004
  Severity: MEDIUM
  Category: spec_violation
  Code reference: scripts/sim.sh:931-943
  Description: cmd_lab_latency baut, deinstalliert und installiert die Labor-App selbst, im selben Aufruf, der danach die Starts macht. Der Lauf wurde nach lab und lab-fetch gestartet, also lag Bau und Neuinstallation (Deinstallation leerte den Container der Labor-App) nach dem Rufen in der Nachricht, wenn auch nur wenige Sekunden (inkrementeller Bau). Das iPhone musste dafür schon entsperrt sein.
  Spec requirement: AC-8 — Alles Vorbereitende (Bau, Installation) ist abgeschlossen, bevor Henning gerufen wird
  Conflict: AC-4 verlangt, dass lab-latency selbst baut und installiert; AC-8 verlangt, dass beides vor dem Rufen fertig ist. Beides zugleich ist mit einem einzigen Befehl nicht erfüllbar; die Spec widerspricht sich. Die Umsetzung folgt AC-4, die Abweichung von AC-8 ist klein (Sekunden), aber real.
  Remediation: Spec klären (AC-8 auf Bau außerhalb der Wartezeit lockern) oder lab-latency eine Option geben, die Bau und Installation überspringt. Beim nächsten Gerätelauf getrennt vorbereiten.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: Measurement/results/date-title.json:427
  Description: lab-fetch hat die Ergebnisdatei date-title.json der Labor-App (alte Logzeilen vom 2026-10-05, 9 Einträge hinzu) über die versionierte Datei geschrieben. Das ist ein Nebeneffekt außerhalb des Tickets (nur Logzeilen vom Gerät, keine Messergebnisse), er steht im Diff gegen HEAD.
  Spec requirement: AC-7 / Scoping — keine Seiteneffekte außerhalb des Tickets
  Conflict: Unbeabsichtigte Änderung einer versionierten Datei; harmlos, aber nicht Teil von Schnitt 2.
  Remediation: Vor dem Commit auf den Stand von HEAD zurücksetzen, nicht mitcommitten.

Bewertung AC-8: Auf dem Gerät wurden nur LAB_BUNDLE bzw. dessen Container angefasst: sim.sh:831 (LAB_BUNDLE), :840 install der Labor-App, :851-853 copy from mit --domain-identifier LAB_BUNDLE, :902 launch LAB_BUNDLE, :913-914 copy from LAB_BUNDLE, :934 Bundle-Prüfung vor der Installation, :938 uninstall LAB_BUNDLE. Alltags-App und Prüfbau (andere Kennungen) kommen in keinem devicectl-Aufruf vor. Die Deinstallation leerte den Container der Labor-App, nachdem date-title.json gesichert war; das ist Teil der Labor-App und gedeckt durch AC-8 (nur die Labor-App). Der erste Satz von AC-8 ist erfüllt, der zweite (Reihenfolge) nur mit der Abweichung aus F004. Daher AC-8 nicht abgehakt.

Confirmation:
  AC: AC-2
  Code reference: LooseEndsLab/LabApp.swift:14
  Evidence: Name, Wörterbuch und exit(0) nach dem letzten gespeicherten Satz (LooseEndsLab/MeasurementRunner.swift:108-139, Schleife bis leer); am Gerät belegt: 12 Einträge je Datei, Dateiname latency-NN.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: scripts/sim.sh:925
  Evidence: nur LAB_BUNDLE, 300-s-Grenze, gesperrt/fehlende Datei/zu wenige Einträge brechen ab; Lauf exit 0 mit 10 Dateien unter docs/artifacts/534-modell-latenz/iphone.
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: scripts/latency_summary.py:62
  Evidence: 10 kalte und 110 warme Aufrufe nachgerechnet, Bericht docs/reference/modell-latenz.md stimmt in allen Zahlen, Vorschlag 25 s nach Regel, keine Produktzahl gesetzt (Diff Shared/ LooseEnds/ leer).
  Status: CONFIRMED
Confirmation:
  AC: AC-1
  Code reference: Measurement/Corpus.swift:152
  Evidence: unverändert seit Runde 1; Tests grün.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: Measurement/MeasurementRun.swift:179
  Evidence: Änderung nur unter Measurement/ und LooseEndsLab/; Shared/ und LooseEnds/ ohne Diff.
  Status: CONFIRMED
**Implementierer:**
F004: Henning hat die Abweichung (lab-latency baute vor dem Start noch einmal inkrementell, AC-4 gegen AC-8) am 2026-10-23 per Auswahl "In Ordnung, abschließen" akzeptiert; AC-8 daher abgehakt, Override mit Begründung gesetzt. F005: Measurement/results/date-title.json auf den Stand von HEAD zurückgesetzt, git status zeigt dort keine Änderung.

## Herkunft der Vorbedingungen

Es ist kein Sprachprofil konfiguriert (`precondition_origins.default_lang`); config.yaml und openspec.yaml setzen es nicht, es wurde keine Tabelle angehängt. Kein verdächtiger Schreibort geprüft.

## Verdict

VERDICT: AMBIGUOUS

Ambiguous findings (require human review):
  F004: AC-4 (lab-latency baut und installiert selbst) und AC-8 (alles Vorbereitende vor dem Rufen) widersprechen sich in der Spec; die Umsetzung folgt AC-4, die Abweichung betrug Sekunden.
  F005 (LOW): date-title.json durch lab-fetch verändert, vor dem Commit zurücksetzen.

Proven points: 8/8 (AC-8 durch PO-Entscheidung zu F004 abgehakt)
Tests: alle bestanden, 0 fehlgeschlagen; übersprungen laut Beleg einzeln benannt: 1 Messstrecke (SelfConsistencyReportTests, Datei fehlt) und 2 Sprach-Latenztests (Sprache nicht unterstützt); python 9 OK
Recommendation: F004 per override-ambiguous mit Begründung entscheiden, F005 vor dem Commit zurücksetzen.

## Geprüfte Dateien

- sha256:34c1a12e3f0c0f68500c3fc3924f86966fdc0055cca5a2d70ebb1a0bbde8c0e6  LooseEndsLab/LabApp.swift
- sha256:5e06e0025b318361e44fe005e0d8c794cf89c8e622946fdcdf5701856f973676  LooseEndsLab/MeasurementRunner.swift
- sha256:24184cfdddfc5ef611d15e87cce0a1ed69a03e6514cf57a3048b7c8a67735399  Measurement/Corpus.swift
- sha256:e1a1dffdd8663c4cf57931d09bd5213b17152686f900cbfab0d988cee9388843  Measurement/MeasurementRun.swift
- sha256:7f19c9a1702a96f8b538a9742abff24b8e41ffbebb8b3d1415f382a13f2f1f41  Measurement/latency-corpus.json
- sha256:dd8aa32fd29f8e9255f7165f91789d306a3886828c33fa27d8840ba79598dce4  Measurement/results/date-title.json
- sha256:a007c5864ca62f7f72ed0e131c781faba4dbea6cb29bf5fc657131417fddb835  Shared/Enrichment/EnrichmentCoordinator.swift
- sha256:3513a4301a2a03d98fed233b965d7f9bd09b81a5409f0665b9096072cdcfa113  scripts/latency_summary.py
- sha256:893fa522184515b27166955d29691e803bd2c73559b6dc233a69fdcb7b5b20c2  scripts/sim.sh

## Prüfbasis

- base: b8e656ae939473ffcab59812c6a7af5800327485
- blob:95e3a5cff83461358d4c721f721fdacba40560a6  LooseEndsLab/LabApp.swift
- blob:893cdf969609c78ffe611d2849e6f9528a1cf437  LooseEndsLab/MeasurementRunner.swift
- blob:e27c1746ce5781d705fac90e9dcd34cd53f0652d  Measurement/Corpus.swift
- blob:ed61eef280b5fbf0b0e5bb42d19683e81ff37dbc  Measurement/MeasurementRun.swift
- blob:965f999c7064a747602c72a85a25fdeaa9127b64  Measurement/latency-corpus.json
- blob:1cc1f0caad6612307ff48e7e67d27a5307a68480  Measurement/results/date-title.json
- blob:203114fb1c54337dbdd62625e5ac30be428ba57d  Shared/Enrichment/EnrichmentCoordinator.swift
- blob:095cd9c71abcf3b265867fc8a1f365d1d03850ea  scripts/latency_summary.py
- blob:d0f692cbedf88394dba43bcbfacfcaec75f96820  scripts/sim.sh

## Geprüfte Dateien

- sha256:34c1a12e3f0c0f68500c3fc3924f86966fdc0055cca5a2d70ebb1a0bbde8c0e6  LooseEndsLab/LabApp.swift
- sha256:5e06e0025b318361e44fe005e0d8c794cf89c8e622946fdcdf5701856f973676  LooseEndsLab/MeasurementRunner.swift
- sha256:24184cfdddfc5ef611d15e87cce0a1ed69a03e6514cf57a3048b7c8a67735399  Measurement/Corpus.swift
- sha256:e1a1dffdd8663c4cf57931d09bd5213b17152686f900cbfab0d988cee9388843  Measurement/MeasurementRun.swift
- sha256:7f19c9a1702a96f8b538a9742abff24b8e41ffbebb8b3d1415f382a13f2f1f41  Measurement/latency-corpus.json
- sha256:dd8aa32fd29f8e9255f7165f91789d306a3886828c33fa27d8840ba79598dce4  Measurement/results/date-title.json
- sha256:a007c5864ca62f7f72ed0e131c781faba4dbea6cb29bf5fc657131417fddb835  Shared/Enrichment/EnrichmentCoordinator.swift
- sha256:3513a4301a2a03d98fed233b965d7f9bd09b81a5409f0665b9096072cdcfa113  scripts/latency_summary.py
- sha256:893fa522184515b27166955d29691e803bd2c73559b6dc233a69fdcb7b5b20c2  scripts/sim.sh

## Prüfbasis

- base: b8e656ae939473ffcab59812c6a7af5800327485
- blob:95e3a5cff83461358d4c721f721fdacba40560a6  LooseEndsLab/LabApp.swift
- blob:893cdf969609c78ffe611d2849e6f9528a1cf437  LooseEndsLab/MeasurementRunner.swift
- blob:e27c1746ce5781d705fac90e9dcd34cd53f0652d  Measurement/Corpus.swift
- blob:ed61eef280b5fbf0b0e5bb42d19683e81ff37dbc  Measurement/MeasurementRun.swift
- blob:965f999c7064a747602c72a85a25fdeaa9127b64  Measurement/latency-corpus.json
- blob:1cc1f0caad6612307ff48e7e67d27a5307a68480  Measurement/results/date-title.json
- blob:203114fb1c54337dbdd62625e5ac30be428ba57d  Shared/Enrichment/EnrichmentCoordinator.swift
- blob:095cd9c71abcf3b265867fc8a1f365d1d03850ea  scripts/latency_summary.py
- blob:d0f692cbedf88394dba43bcbfacfcaec75f96820  scripts/sim.sh
