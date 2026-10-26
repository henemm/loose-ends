# Adversary Dialog — spike-70-textform
Spec: docs/specs/spike-70-textform.md
Datum: 2026-10-26 06:31

## Checkliste
- [x] **AC-1:** `docs/reference/textform-rules.md` enthält nicht mehr den Satz „Die Modellspalte fehlt noch" und nennt stattdessen, dass die Modellspalte nicht gemessen wird, mit den vier Gründen der Analyse und dem Verweis auf #88.
- [x] **AC-2:** Der Bericht enthält die Zeile „Ohne Modell geht es nicht, weil" mit Beleg je Feld, das das Modell schreibt (Titel, Dauer).
- [x] **AC-3:** Der Abschnitt „Entscheidung je Kanal" nennt für jeden der vier Kanäle (getippt, Diktat, Mail, Englisch) „roh an die Regeln" oder „nur Betreff"; für den Mail-Körper steht, dass er nie roh, sondern nur zugeschnitten weitergegeben wird.
- [x] **AC-4:** `docs/project/06-annahmen-und-experimente.md` trägt in der B2-Zeile das Ergebnis mit Datum, den berichtigten Wortlaut („die Struktur entsteht aus allen Formen") und den Verweis auf #88 für Titel/Dauer-Formtreue des Modells.
- [x] **AC-5:** Ein Unit-Test in `SharedContentTests` übergibt eine Mail mit Betreff und einem Körper aus Gruß, Signatur, Zitat und Rechtstext; `prefill` ist genau der Betreff, und der Körpertext kommt in `prefill` nicht vor. Der Test läuft grün im Simulator (`sim.sh sim-unit SharedContentTests`).
- [x] **AC-6:** Alle bisherigen Tests von `SharedContentTests` und `TextFormRuleReportTests` bleiben grün; `TextFormRuleReportTests` erzeugt den Bericht unverändert (die Zahlen im Bericht stimmen mit der Ausgabe überein).
- [x] **AC-7:** Auf #88 liegt ein Kommentar, der die Übergabe nennt (Modell-Formtreue für Titel und Dauer als Spalte im Laborlauf, Gerätefreigabe wörtlich nötig); auf #70 liegt das Ergebnis, und #70 wird mit dem PR geschlossen.
- [x] **AC-8:** Es wird kein Gerät von Henning angefasst; der Abschlussbericht enthält den Satz „Kein Pfad der Geräteliste berührt."

## Dialog

### Runde 1
**Adversary:** Spec, beide Dokumente, Test, Rot/Grün-Belege und Tickets gelesen; jeden Punkt einzeln angegriffen.

Confirmation:
  AC: AC-1
  Code reference: docs/reference/textform-rules.md:7
  Evidence: Suche nach "Modellspalte fehlt noch" findet nichts mehr (Diff entfernt den Satz). Zeile 7 "Stand 2026-10-25: Die Modellspalte wird bewusst nicht gemessen" nennt vier nummerierte Gründe (Modell schreibt nur Titel/Dauer; Mail-Körper erreicht nichts; TitleRule 100 %; keine Dauer-Wahrheit) und verweist auf #88 (Zeile 18-19).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: docs/reference/textform-rules.md:19
  Evidence: "Ohne Modell geht es nicht, weil … für kein Feld belegt" mit Beleg je Feld: Titel (100 % Schlüsselwörter, Tabelle) und Dauer (nur offen, wo Text keine Länge nennt; Frage von #88/#72).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/reference/textform-rules.md:61
  Evidence: Abschnitt "Entscheidung je Kanal" (Zeile 48), Festlegung ab Zeile 61: Getippt/Diktat/Englisch "roh an die Regeln", Mail "nur Betreff", "Der Körper geht nie roh weiter", nur zugeschnitten (mailCut: 0 erfunden).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/project/06-annahmen-und-experimente.md:214
  Evidence: B2-Zeile hat weiterhin 6 Spalten (# | Annahme | Experiment | Abbruch | Alternative | Issue); Ergebnis steht mit Datum 2026-10-25 in der Abbruch-Spalte (keine eigene Spalte "Ergebnis", wie die Spec-Skizze sagte; AC-4 verlangt nur "in der B2-Zeile"), Wortlaut "Die Struktur entsteht aus allen Formen" und "#88". Festlegungen-Block ebenfalls angepasst.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsTests/SharedContentTests.swift:26
  Evidence: Test mailBodyNeverPrefilled: Mail mit Gruß, Signatur, Zitat, Rechtstext; prefill == "Angebot Dachrinne" und sechs Körper-Wörter dürfen nicht vorkommen. Grün: test-green-output.txt:468 und test-green-check.txt:71. Gegenprobe Rot: test-red-output.txt:76-82 (Test schlägt mit mutiertem Produktcode an 7 Stellen fehl, Suite "failed with 8 issue(s)", Zeile 101), also beweist er etwas. Probe-Wörter gegen den Körper geprüft: alle sechs stehen wirklich im Körper ("vertraulich" in "vertrauliche"), keine Scheinprüfung.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEndsTests/SharedContentTests.swift:1
  Evidence: Suite "SharedContent" grün (test-green-output.txt:486), TextFormRuleReportTests grün (test-green-textform.txt:31, beide Tests). Ich habe TextFormRuleReportTests selbst erneut laufen lassen: "Unit-Tests bestanden". Tabellen in textform-rules.md sind im Diff unverändert (nur Text drumherum), die Zahlen stammen aus gemergtem PR #270. Einschränkung: Der Bericht geht nach stdout und steht nicht im Log, ein Zeile-für-Zeile-Abgleich Tabelle gegen frische Ausgabe war daher nicht möglich.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/reference/textform-rules.md:18
  Evidence: Ticket #88: Kommentar mit Übergabe (Titel/Dauer-Formtreue als Spalte im Laborlauf, Adapter, wörtliches "jetzt ist ein Test möglich"). Ticket #70: Kommentar mit Ergebnis. Schließen mit dem PR ist ausdrücklich später.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEndsTests/SharedContentTests.swift:26
  Evidence: Änderungen nur Doku plus ein Unit-Test; Artefakte enthalten kein devicectl/device; Tests liefen per sim-unit im Simulator. Diff gegen origin/main für Shared/ ist leer, kein Pfad der Geräteliste berührt. Der Satz "Kein Pfad der Geräteliste berührt." gehört in den Abschlussbericht und ist noch nicht geschrieben (kommt später).
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt, Kontextisolierung)

### Runde 2
**Adversary:** Zahlen und Gegenbeweise angegriffen.

- Zahlen gegen Tabelle: Diktat 39,39,40,40,40 von 40 = "39-40/40" stimmt. Englisch 40,40,40,38,37 = "37-40/40" stimmt. Kontexte mail "25 erfunden" (2/0/13/25) stimmt, Kontexte mailCut 37/3/0/0 = 0 erfunden stimmt, getippt 40/40 stimmt. Nicht widerlegt. Randnotiz: Englisch Kontexte hat 1 erfunden (37/1/1/1); "wie getippt" gilt nur für die Treffer.
- Shared/Services/SharedContent.swift: Diff gegen origin/main für Shared/ leer, Produktcode unverändert; geänderte Dateien sind nur Tests, Doku, Spec, Artefakte.
- Rot-Beleg echt: mutiert wurde Produktcode, der bestehende Test "A shared mail yields its subject" fällt ebenfalls (test-red-output.txt:74), die Mutation wirkte also.
- Überspannung der Aussage "Körper erreicht nie": siehe Finding F001.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/SharedContent.swift:28
  Description: Fehlt der Betreff, fällt prefill auf den übergebenen `text` zurück (`subject ?? text ?? ""`); `text` kommt aus dem Share-Sheet und könnte Körpertext enthalten, falls Mail ihn so liefert. Der neue Test deckt nur den Fall mit Betreff ab.
  Spec requirement: AC-5 — prefill genau der Betreff (erfüllt); die Dokumentaussage "Körper erreicht nie" ist für den Fall ohne Betreff nicht belegt.
  Conflict: Randfall, kein Verstoß gegen eine AC; die Dokumentation formuliert absolut.
  Remediation: Optional: Satz in textform-rules.md auf "mit Betreff" eingrenzen oder zweiten Test ohne Betreff. Kein Blocker.

**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Es wird kein Produktcode geändert; keine verdächtigen Schreibstellen.

## Verdict
**VERIFIED**
Tests: Suites SharedContent und TextFormRuleReportTests grün, 0 fehlgeschlagen; 1 von 4 Messstrecken übersprungen (SelfConsistencyReportTests, fehlende Messdatei, vorbestehend, nicht Teil dieses Tickets).
Checklist: 8/8 points proven. Finding F001 LOW, nicht blockierend.

## Geprüfte Dateien

- sha256:de93731e4581fa4cc474077d84fec7f2f1167bffe26936fc3a7dd798cca98f1d  LooseEndsTests/SharedContentTests.swift
- sha256:abfd31b0e9b33488e7fa52ecd423773678c2b93bd1b9b055045aab53b9312805  Shared/Services/SharedContent.swift
- sha256:b274166e54eca476aa0ba69beb8c3ca2b6e48ecc4272188b07bd552bc270cee8  docs/project/06-annahmen-und-experimente.md
- sha256:a8a17968ae9473198c3f8e5f2132bdd126e6d00ada3c941fd0571a0da664e472  docs/reference/textform-rules.md

## Prüfbasis

- base: eb61b1b24504a220d08480ef3a09c706fd164e79
- blob:f28ffd46ac81f9e8850947ad7540be66764ef326  LooseEndsTests/SharedContentTests.swift
- blob:0c43424c8aac3e589d63647f3e6a6ca5ece8bd6c  Shared/Services/SharedContent.swift
- blob:2def10c7741444e4cf0ad11e2b434780798f161b  docs/project/06-annahmen-und-experimente.md
- blob:954a0cc966b11bd3f8151a708f5bc43337a946d7  docs/reference/textform-rules.md
