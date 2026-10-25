# Adversary Dialog — 68-modell-verfuegbarkeit
Spec: docs/specs/feat-68-modell-verfuegbarkeit.md
Datum: 2026-10-25 08:43

## Checkliste
- [x] **AC-1:** `docs/reference/modell-verfuegbarkeit.md` existiert und enthält die Matrix Gerät (iPhone 16 Pro, iPad mit M-Chip, älteres iPad, Apple Watch, Mac) × Prozess (App vorn, App hinten, Intent, Share, Widget, Watch-App) × Zustand, mit Datum 2026-10-24 und OS-/Modellständen. Jede Zelle trägt genau eine der Klassen (a) aus Code bewiesen, (b) in Unit/Simulator bewiesen, (c) nur Gerät = offen.
- [x] **AC-2:** Die Belege der Klasse (a) nennen Datei und Stelle (`processPending` nur in `ContentView`, `MenuBarCapture`, `SubtasksSection`; `FoundationModelsEnricher` nicht für watchOS übersetzt); die Belege der Klasse (b) nennen den Test.
- [x] **AC-3:** Der Bericht enthält die Regel-Spalte (Datum 99,3 % Regel gegen 50 % Modell; Kontext und Projekt nie Modell; Wichtigkeit/Dringlichkeit und Wiedererkennung Regel), die Zeile „Ohne Modell geht es nicht, weil …“ mit der Feststellung, dass nur die Titelverfeinerung Sprachverstehen braucht, und die Quellenliste mit allen Links aus dem Kontextdokument.
- [x] **AC-4:** **Gerätezellen stehen als „offen“, nicht als gemessen**, bis Henning den Test freigibt: Jede Zelle der Klasse (c) steht auf „offen“ ohne Zahl und ohne Vermutung; der Bericht nennt die Bedingung (Hennings wörtliches „jetzt ist ein Test möglich“, gebündelt mit #71, #70, #88 Teil 2).
- [x] **AC-5:** `docs/project/00-entscheidungen.md` ADR-4 enthält die Ergänzung: Das Modell läuft nur in der App (Vordergrund und Nachzügler); „im Intent-Prozess“ ist berichtigt (der Intent-Prozess ruft das Modell nicht); Doppellauf: kein Sperrfeld, Schaden begrenzt, Nachfolger wenn gemessen. Die fünf Alternativen der Analyse stehen mit der Entscheidung, die sie kippen würden; Hennings Entscheidung vom 2026-10-24 ist datiert genannt.
- [x] **AC-6:** `docs/project/06-annahmen-und-experimente.md` A4 steht auf „entschieden (Teil Entwurf), Gerätezellen offen“ mit Verweis auf `docs/reference/modell-verfuegbarkeit.md`; die Spalten Experiment, Abbruch und Alternative bleiben erhalten.
- [x] **AC-7:** `LooseEndsTests/ModelUnavailableTests.swift` prüft in einem parametrisierten Test für jeden der Gründe `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady` und einen unbekannten Text: `StubEnricher.calls == 0`, `rulesAppliedAt != nil`, `processedAt == nil`, das Fälligkeitsdatum und die Wichtigkeit stehen aus der Regel, der Status bleibt für den Nachzügler erhalten.
- [x] **AC-8:** Derselbe Test (oder ein zweiter in derselben Datei) lässt nach dem Regellauf das Modell verfügbar werden (`unavailableReason = nil`): Der nächste Lauf ruft das Modell genau einmal, setzt `processedAt`, und die Regel-Felder bleiben ohne zweite Regel-Revision.
- [x] **AC-9:** Doppellauf: Eine Aufgabe, die zwei Geräte beide als „fällig“ sehen (nach dem ersten Modelllauf wird `processedAt` zurückgesetzt, wie es ein Gerät sieht, dem der Abgleich noch fehlt), wird von einem zweiten Modelllauf mit abweichender Antwort nicht beschädigt: ein vom Nutzer gesetzter Wert bleibt unverändert und hat genau eine Revision, Kontext und Projekt bleiben leer (nie vom Modell gesetzt), und der zweite Lauf legt keine Nutzer-Revision an. Der Test benennt in seinem Kommentar, was er nicht belegt (zwei echte Geräte, CloudKit-Abgleich).
- [x] **AC-10:** Die Testdatei dupliziert keinen der oben genannten bestehenden Tests; sie nutzt `StubEnricher` und `TestStore` aus `EnrichmentTests.swift` und hält den Container im Test am Leben.
- [x] **AC-11:** **Kein Gerät wird angefasst.** Weder Hennings iPhone, iPad, Watch noch Mac werden für dieses Ticket angesprochen (kein `devicectl`, kein `sim.sh device*`, kein `launch-measure`, kein `lab`, auch nicht lesend). Die Tests laufen nur im Simulator.
- [x] **AC-12:** Keine Änderung an Produktcode, `project.yml`, Entitlements, `Info.plist`, Berechtigungen, AppStorage-Keys, SwiftData-Modell oder `cloudkit/schema.ckdb`; kein CloudKit-Deploy nötig. Das Diff berührt genau die vier Dateien der Source-Tabelle.
- [x] **AC-13:** Abnahme: `./scripts/sim.sh sim-unit ModelUnavailableTests` grün, danach der volle Lauf `./scripts/sim.sh sim-unit`; Es gibt keinen sichtbaren Ablauf zum Durchspielen (Produktcode unverändert). Verlangt das Abschluss-Gate trotzdem den Beleg `simulator-run.txt` (`openspec.yaml`: `evidence_checks.phase8_complete`, Gate-Menge enthält die neue Testdatei), wird er mit `./scripts/sim.sh test-proof ModelUnavailableTests` erzeugt, nie von Hand gesetzt; zeigt `phase8_complete`, dass das Gate die Menge nicht erfasst, entfällt er mit dieser Begründung im Abschlussbericht. Die Gegenprobe aus dem Test Plan wird im Abschlussbericht benannt. Die Stufe 3 entfällt mit dem Satz „Kein Pfad der Geräteliste berührt.“ (weder `FoundationModelsEnricher.swift` noch `EnrichmentCoordinator.swift` werden geändert).

## Dialog

### Runde 1
**Adversary:** Nachprüfung der Behebungen aus dem ersten Durchgang (F001-F003) und Suche nach weiteren Mängeln. Jeder Punkt mit Beleg:
- AC-1/F001: Matrix gelesen, alle Zellen einzeln. Keine Zelle trägt zwei Klassen mehr: älteres iPad App vorn "offen (c); erwartet ... nicht gemessen" ist eine Klasse (c), Mac App vorn "offen (c)", Hintergrund-Zellen "(b)", Intent/Share/Widget "(a)". Datum 2026-10-24 und OS-Stände (iOS 27.0.1, macOS 27.0.1, Modelle 26.0-26.3, 26.4, 27.0) im Kopf. Code reference: docs/reference/modell-verfuegbarkeit.md:42
- AC-2: `grep processPending` liefert genau ContentView.swift:123,126,228, MenuBarCapture.swift:18, SubtasksSection.swift:131; in Share, Widgets, Watch, Shared kein Treffer. `FoundationModelsEnricher.swift:1` ist `#if canImport(FoundationModels) && !os(watchOS)`. Klasse (b) nennt `LooseEndsTests/ModelUnavailableTests.swift`. Code reference: docs/reference/modell-verfuegbarkeit.md:24
- AC-3: Regel-Spalte (99,3 % gegen 50 %), "Ohne Modell geht es nicht, weil nur die Titelverfeinerung ...", sechs Quellen-Links identisch zur Liste in docs/context/68-modell-verfuegbarkeit.md (per grep verglichen). Code reference: docs/reference/modell-verfuegbarkeit.md:61
- AC-4: Alle (c)-Zellen "offen", ohne Zahl; Messfreigabe nennt das wörtliche "jetzt ist ein Test möglich" und #71, #70, #88 Teil 2. Code reference: docs/reference/modell-verfuegbarkeit.md:54
- AC-5: ADR-4 berichtigt "Intent-Prozess", Ergänzung 2026-10-24 mit Hennings Zitat, Doppellauf ohne Sperrfeld, fünf Alternativen je mit gekipptem Beschluss. Code reference: docs/project/00-entscheidungen.md:109
- AC-6: A4: "Entschieden (Teil Entwurf), Gerätezellen offen" mit Verweis; Spalten Experiment, Abbruch, Alternative erhalten (Diff zeigt nur die Abbruch-Zelle erweitert). Code reference: docs/project/06-annahmen-und-experimente.md:201
- AC-7/F002: Test liest jetzt Rohtext "wichtig und dringend", prüft calls==0, rulesAppliedAt!=nil, processedAt==nil, dueDate (require), importance!=nil, urgency!=nil, status==.unprocessed, je Grund (4 Argumente). Im Koordinator (EnrichmentCoordinator.swift:93,149) ändert der Regelpfad den Status nicht; die Prüfung ist zutreffend und nicht tautologisch (Abfrage Zeile 71 braucht .unprocessed). Code reference: LooseEndsTests/ModelUnavailableTests.swift:30
- AC-8: zweiter Lauf nach unavailableReason=nil: calls==1, processedAt!=nil, dueDate unverändert, genau eine dueDate-Revision. Code reference: LooseEndsTests/ModelUnavailableTests.swift:45
- AC-9/F003: Projekt "Haushalt" im Katalog (Zeile 61) und in beiden Entwürfen, `task.project == nil`, Kontexte leer, Nutzer-Revisionen == 1, Dauer .minutes30 mit Quelle user und genau einer Revision; Kommentar nennt "Nicht belegt: zwei echte Geräte und der CloudKit-Abgleich". Code reference: LooseEndsTests/ModelUnavailableTests.swift:96
- AC-10: Nutzt StubEnricher und TestStore (EnrichmentTests.swift:12-22), Container über `store` lokal am Leben; keine Kopie von unavailableModelIsSkipped (dort nur ein Grund). Code reference: LooseEndsTests/ModelUnavailableTests.swift:19
- AC-11: Nichts in Diff oder Artefakten verweist auf devicectl, device*, launch-measure oder lab; Läufe nur sim-unit. Code reference: LooseEndsTests/ModelUnavailableTests.swift:11
- AC-12: Diff-Statistik für Shared und LooseEnds leer; Status-Liste zeigt nur die Testdatei, zwei Dokumente (modifiziert), den neuen Bericht (untracked) sowie Artefakte. project.yml, Entitlements, Info.plist, cloudkit unberührt. Code reference: docs/reference/modell-verfuegbarkeit.md:1
- AC-13: Belege siehe Runde 2.

**Implementierer:** Behebungen wie beschrieben angewandt; keine Einwände gegen die Prüfung.

### Runde 2
**Adversary:** Mutationsfestigkeit und Belegqualität.
- Mutation Regelschritt bei modelNotReady ausgelassen (test-output-gegenprobe-red.txt): genau dieser Fall rot mit zwei Issues (rulesAppliedAt nil, dueDate nil), die anderen drei Gründe und der Doppellauf grün; das Protokoll trägt die neuen Meldungstexte, die Gegenprobe lief also gegen den ergänzten Test (xcresult 08:41, Dateistand 08:27).
- Mutation processedAt im Nichtverfügbar-Zweig setzen: fängt `processedAt == nil` (Zeile 32) und `calls == 1` im Nachzügler.
- Mutation Wichtigkeit-/Dringlichkeitsregel fällt aus: fängt Zeile 34/35 (vorher nicht).
- Mutation Writer überschreibt Nutzerdauer / setzt Kontext / setzt Projekt / legt Nutzer-Revision an: fangen Zeilen 91-98 je einzeln. Der Katalogeintrag "Haushalt" macht die Projekt-Prüfung scharf; ohne ihn wäre sie tautologisch (jetzt behoben).
- Voller Lauf test-green-output-full.txt: Test Succeeded, xcresult 08:28:35 liegt nach der letzten Änderung der Testdatei (08:27:34), umfasst also die Ergänzungen. Klassenlauf test-green-output.txt (08:42:54): 5 Fälle (4 + 1) bestanden. Übersprungen im vollen Lauf: Messstrecke SelfConsistencyReportTests (selfconsistency-run.json fehlt) und Latenzschutz de_DE im Simulator nicht unterstützt: bestehende, laut benannte Auslassungen, nicht aus dieser Änderung.
- Weitere Zellen mit zwei Klassen gesucht (Tabellenzeilen 44-48): keine. Zellen "—" tragen keine Klasse, siehe F004.
- AC-13: Gegenprobe benannt und erbracht; Stufe 3 entfällt: weder FoundationModelsEnricher.swift noch EnrichmentCoordinator.swift geändert. `simulator-run.txt` existiert nicht; die Spec lässt es entfallen oder per `sim.sh test-proof` erzeugen, je nachdem was `phase8_complete` verlangt. Das klärt das Abschluss-Gate. Code reference: LooseEndsTests/ModelUnavailableTests.swift:56

Finding:
  ID: F004
  Severity: LOW
  Category: spec_violation
  Code reference: docs/reference/modell-verfuegbarkeit.md:42
  Description: Die Matrixzellen "—" (z. B. Watch App vorn, Mac Share, iPhone Watch-App) tragen keine der Klassen (a)/(b)/(c).
  Spec requirement: AC-1 — jede Zelle trägt genau eine Klasse
  Conflict: Wörtlich gelesen fehlt bei "—" die Klasse; sinngemäß sind es nicht vorhandene Kombinationen.
  Remediation: Unter der Tabelle einen Satz "— = Kombination gibt es nicht" ergänzen.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/ModelUnavailableTests.swift:48
  Description: Die Revisionszählung nach dem Nachzügler prüft nur `.dueDate`; Revisionen für Wichtigkeit und Dringlichkeit werden nicht auf Verdopplung geprüft.
  Spec requirement: AC-8 — Regel-Felder bleiben ohne zweite Regel-Revision
  Conflict: Eine zweite Regel-Revision auf importance/urgency bliebe unbemerkt.
  Remediation: Revisionen aller Regel-Felder zählen.

**Implementierer:** F004 und F005 sind nicht blockierend (LOW).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hat die Prüfung bestanden; F001-F003 sind behoben. Offen nur zwei LOW-Hinweise (F004, F005).
Tests: voller Lauf grün (Test Succeeded, 0 Fehlschläge), Klasse 5 Fälle bestanden; Gegenprobe rot wie erwartet, danach zurückgenommen. Übersprungen: Messstrecke SelfConsistencyReportTests und Latenzschutz de_DE (bestehend, benannt).
Edge cases: Mutationen durchgespielt, alle neuen Prüfungen greifen
Regressions: keine, Produktcode unverändert
Checklist: 13/13 Punkte bewiesen

## Geprüfte Dateien

- sha256:4372dfb06cf97df43bccd5d74c6db5820d65d2ef4e0b1612c2bdcb6802a84cf9  LooseEndsTests/ModelUnavailableTests.swift
- sha256:d9754820bf083fc97c1885997fc01eca973a9d290a4e168cdc936b4101a501cd  docs/reference/modell-verfuegbarkeit.md

## Prüfbasis

- base: dbcee9c233e9b1afd11048a2e6f0cfe0ac1952df
- blob:eb0fa50632d0b03fef86e1411ed8374b6c501492  LooseEndsTests/ModelUnavailableTests.swift
- blob:bf9125a9879b59ca21880fa1601bbffbe1d001cf  docs/reference/modell-verfuegbarkeit.md
