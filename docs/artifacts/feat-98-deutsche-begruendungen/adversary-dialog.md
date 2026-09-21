# Adversary Dialog — #98 Deutsche Begruendungstexte der Terminregel

Datum: 2026-09-21
Geprueft: Branch feat-95-parser-in-app, Worktree issue-67-messbericht,
HEAD 02b2129 plus unstaged Aenderung an LooseEnds/Resources/Localizable.xcstrings.
Spec: docs/specs/enrichment/feat-98-deutsche-begruendungen.md

### Runde 1 — Behauptungen sammeln, erste Beweisfuehrung

### Frage 1: Existieren die neun Katalog-Eintraege tatsaechlich, und wo?

Beweis (eigener Befehl): Versionsvergleich der Katalogdatei gegen den letzten Commit.
Ergebnis: neun neue Top-Level-Eintraege im strings-Objekt, jeder mit
extractionState=translated und localizations.de.stringUnit.state=translated.

Bewertung: nicht ausreichend allein — Text und Byte-Exaktheit noch nicht geprueft. Weiter in Runde 2.

### Frage 2: Ist der RED-Zustand echt belegt oder nur behauptet?

Beweis: docs/artifacts/feat-98-deutsche-begruendungen/test-red-output.txt (bereits im letzten Commit
02b2129 enthalten) zeigt: Suite "Regelschritt: Faelligkeitsdatum" failed after 0.023 seconds with
9 issue(s), 9x "Expectation failed: translated != key" fuer den neuen AC-1-Test.

Gegenprobe (eigener Befehl): Katalogstand zum RED-Commit ausgelesen (Version zum Commit-Zeitpunkt)
und mit json geparst -> 125 Top-Level-Keys, keiner davon einer der neun DueDateRule-Saetze.
Bestaetigt: der RED-Lauf fand tatsaechlich in einem Katalog ohne diese Eintraege statt.

Bewertung: AC-2 (RED-Haelfte) belegt.

### Frage 3: Ist GREEN nur Behauptung des Builders oder selbst nachvollzogen?

Erste Antwort (Artefakt des Builders): test-green-output.txt (unstaged) zeigt den AC-1-Test gruen und
"Test Succeeded" am Ende. Nicht akzeptiert ohne eigenen Lauf — eigener Lauf folgt in Runde 2.

### Runde 2 — Eigene Nachpruefung, Grenzfaelle, AC-5-Widerspruch

### Eigener Testlauf (unabhaengig vom Builder-Artefakt)

Befehl (selbst ausgefuehrt, im aktuellen — unveraenderten — Arbeitsverzeichnis mit der modifizierten
Localizable.xcstrings): ./scripts/sim.sh unit DueDateRuleTests

Xcodebuild-Log (DerivedData/LooseEnds-session-default/xcodebuild.log), selbst gelesen nach
Prozessende:
```
Suite "Regelschritt: Faelligkeitsdatum" started.
Test "Alle neun Begruendungssaetze sind im deutschen Bundle uebersetzt (#98, AC-1)" passed after 0.063 seconds.
Suite "Regelschritt: Faelligkeitsdatum" passed after 0.128 seconds.
Test run with 8 tests in 1 suite passed after 0.128 seconds.
** TEST SUCCEEDED **
```
→ GREEN unabhaengig bestaetigt, nicht nur behauptet. AC-1 und AC-2 (GREEN-Haelfte) damit belegt.

Kontrollfrage: Wurde zwischen RED- und GREEN-Lauf der Test selbst veraendert? Status-Abfrage des
Arbeitsverzeichnisses zeigt nur Localizable.xcstrings als veraendert (plus unbezogene .claude/ und
das neue Artefakt), DueDateRuleTests.swift ist seit dem RED-Commit 02b2129 unveraendert. → AC-2
vollstaendig belegt, "ohne dass der Test selbst veraendert wurde" stimmt.

### AC-3: Anfuehrungszeichen-Exaktheit / Duplikat-Check, selbst reproduziert

1. ./scripts/sim.sh generate selbst ausgefuehrt → Katalog-Datei davor/danach byte-identisch (Diff
   liefert keinen Unterschied). Der Projektgenerator loest also keine Neuextraktion aus
   (erwartungsgemaess, das passiert erst beim Build).
2. Der oben unabhaengig ausgefuehrte Build (sim.sh unit, kompiliert die App inkl.
   "Compile XCStrings Localizable.xcstrings") hat die Neuextraktion tatsaechlich durchlaufen. Danach
   erneut geprueft:
   - python3 -m json.tool Localizable.xcstrings → JSON weiterhin valide.
   - Key-Zaehlung per Skript → weiterhin 134 Top-Level-Keys (125 + 9), keine zusaetzlichen entstanden.
   - grep -c auf alle vier anfuehrungszeichen-kritischen Keys (weekdayEitherNext, endOfMonth,
     weekend, monthRange) → je genau 1 Vorkommen.
   - Gegenprobe auf eine denkbare Fehlkopie (gerade Anfuehrungszeichen statt typografischer) →
     0 Vorkommen, also kein verwaister Duplikat-Key.
   → AC-3 durch eigenen Build und eigene Zaehlung belegt, nicht nur durch den Bericht des Builders.

### AC-4: Wortlaut-Vergleich, byte-exakt per Skript (nicht nur Augenschein)

Eigenes Python-Skript liest Localizable.xcstrings, vergleicht fuer jeden der neun Keys den
localizations.de.stringUnit.value gegen die Tabelle aus der Spec (inkl. der deutschen
Anfuehrungszeichen als Unicode-Escapes). Ergebnis:
```
True translated translated 'Aus einer Tagesangabe in der Notiz.'
True translated translated 'Aus dem Wochentag in der Notiz.'
True translated translated 'Aus einem Wochentag der naechsten Woche in der Notiz.'
True translated translated 'Aus „naechsten“ plus Wochentag in der Notiz: die Folgewoche.'
True translated translated 'Aus „Ende des Monats“ in der Notiz.'
True translated translated 'Aus dem Tag des Monats in der Notiz.'
True translated translated 'Aus „Wochenende“ in der Notiz: Samstag.'
True translated translated 'Aus „naechsten Monat“ in der Notiz: der Erste des Monats.'
True translated translated 'Aus Tag und Monat in der Notiz.'
ALL MATCH: True
```
Zusaetzlich per Regex die neun Original-Schluessel direkt aus Shared/Enrichment/DueDateRule.swift
extrahiert und mit den Katalog-Keys sowie den Test-Keys verglichen — identisch, byte-exakt
(inklusive der englischen Anfuehrungszeichen). → AC-4 vollstaendig belegt.

### AC-5: Kritische Pruefung des "konsistent mit den 125 vorhandenen Eintraegen"

Woertliche AC-5-Anforderung geprueft: alle neun neuen Eintraege tragen extractionState=translated →
bestaetigt (Feld-Zaehlung im geaenderten Katalog liefert 9, alle mit Wert "translated").

Kritische Gegenprobe wie angeordnet: Traegt der bestehende Katalogstand (die 125 Eintraege vor dieser
Aenderung) ueberhaupt ein extractionState-Feld?
```
Katalogstand zum letzten Commit ausgelesen -> 125 Eintraege, 0 mit extractionState-Feld
```
Befund: Nein. Keiner der 125 bestehenden Katalog-Eintraege traegt ein extractionState-Feld — weder
mit Wert translated noch mit einem anderen Wert. Die Formulierung in AC-5 "konsistent mit den 125
vorhandenen Eintraegen" ist damit durch den Katalog selbst widerlegt: die neun neuen Eintraege sind
gerade nicht strukturell konsistent mit den 125 bestehenden, sondern tragen ein Feld, das sonst im
gesamten Katalog nicht vorkommt.

Das ist — wie in der Aufgabenstellung erwartet — ein Widerspruch in der Spec selbst, keine
Fehlimplementierung: Die Implementierung hat exakt das gebaut, was AC-5 woertlich verlangt
(extractionState=translated auf allen neun neuen Eintraegen). Nur die eingeklammerte
Zusatzbehauptung ueber "Konsistenz" ist falsch. Da Build, alle Tests und AC-3 (keine Duplikate nach
Neuextraktion, selbst durch einen echten Build verifiziert) gruen bleiben, blockt dieser Befund laut
Vorgabe NICHT den Gesamt-Verdict VERIFIED. Er wird trotzdem als Finding gemeldet, weil er die Spec
fuer kuenftige Tickets angreifbar macht (falsche Praemisse ueber den Bestandskatalog) und weil unklar
ist, ob Xcode den Wert "translated" fuer extractionState ueberhaupt als gueltigen Wert kennt oder ihn
nur stillschweigend ignoriert (kein bekannter Praezedenzfall im Katalog, keine Internetrecherche dazu
durchgefuehrt — reine Beobachtung aus den Daten, keine Ursachenanalyse, da ausserhalb des
Pruefauftrags).

### AC-6: Woertliche Diff-Anforderung vs. Intention geprueft

Woertliche Anforderung: Der Versionsvergleich HEAD gegen den Hauptzweig ausserhalb von
Localizable.xcstrings und DueDateRuleTests.swift muss leer sein.

Eigener Befehl (Dateiliste des Versionsvergleichs gegen den Hauptzweig):
```
LooseEndsTests/DueDateRuleTests.swift
docs/artifacts/feat-98-deutsche-begruendungen/test-red-output.txt
docs/briefings/feat-98-deutsche-begruendungen.md
docs/context/feat-98-deutsche-begruendungen.md
docs/specs/enrichment/feat-98-deutsche-begruendungen.md
```
Plus unstaged: LooseEnds/Resources/Localizable.xcstrings (geaendert), das neue
test-green-output.txt-Artefakt (neu, nicht nachverfolgt).

Befund: Woertlich genommen ist AC-6 nicht erfuellt — der Diff ausserhalb der beiden genannten Dateien
ist nicht leer, er enthaelt die Spec selbst, das Briefing, den Analyse-Kontext und den
RED-Testlauf-Bericht. Das widerspricht der eigenen Formulierung der AC, da diese Dateien zwingend
Teil jedes Workflow-Durchlaufs sind (Spec/Briefing/Kontext werden von den vorgelagerten Phasen
erzeugt, test-red-output.txt ist explizit im Test Plan als Artefakt gefordert). Der AC-Titel "Kein
Produktcode geaendert" und die Purpose-Zeile "Kein Produktcode aendert sich" zeigen die eigentliche
Absicht klar.

Gezielte Gegenprobe auf die Absicht (kein Produktcode): Versionsvergleich beschraenkt auf die
Verzeichnisse Shared/ und LooseEnds/, ohne Localizable.xcstrings → leer. Kein einziges
Swift-Produktmodul (Shared/Enrichment, Shared/Persistence, Shared/Services, LooseEnds/Views, etc.)
ist veraendert; einzige Produktdatei-Aenderung ist der reine Ressourcen-Katalog
Localizable.xcstrings. DueDateRule.swift, TaskDetailView.swift, FieldEditorView.swift — alle laut
Spec explizit als "bleiben unangetastet" genannt — sind per gezieltem Vergleich bestaetigt
unveraendert (leerer Diff).

Bewertung: inhaltlich (kein Produktcode geaendert) VERIFIED, aber die AC-6-Formulierung selbst
("Diff ist leer") ist zu eng und wuerde bei woertlicher Auslegung jede Spec-getriebene
Ticket-Abwicklung dieses Projekts als Verstoss werten — auch das ein Spec-Wortlaut-Fehler, kein
Implementierungsfehler. Als Finding gemeldet (MEDIUM, spec_violation der Formulierung, nicht der
Substanz), blockt nicht.

## Gesamtbewertung je AC

| AC | Status | Belegt durch |
|----|--------|---------------|
| AC-1 | CONFIRMED | eigener sim.sh unit DueDateRuleTests-Lauf, xcodebuild.log gelesen, Test gruen |
| AC-2 | CONFIRMED | RED: test-red-output.txt (im Commit enthalten, Katalogstand zum Zeitpunkt gegengeprueft: 125 Keys, keiner der 9); GREEN: eigener Lauf; Testdatei nachweislich unveraendert |
| AC-3 | CONFIRMED | eigener Projekt-Regenerierungslauf + eigener Build; Key-Zaehlung (134 gesamt, je 1 pro kritischem Key, 0 Duplikate mit geraden Anfuehrungszeichen) |
| AC-4 | CONFIRMED | eigenes Python-Skript, byte-exakter Vergleich aller 9 Werte + Quellkeys aus DueDateRule.swift |
| AC-5 | CONFIRMED (mit Finding F001) | woertliche Anforderung erfuellt (9/9 extractionState=translated); Zusatzbehauptung "konsistent mit 125 vorhandenen" durch Daten widerlegt — Spec-Widerspruch, kein Implementierungsfehler, blockt laut Auftrag nicht |
| AC-6 | CONFIRMED (mit Finding F002) | Substanz (kein Produktcode geaendert) bestaetigt durch gezielten Vergleich der Produktverzeichnisse; woertliche "Diff ist leer"-Formulierung nicht erfuellt wegen zwingender Workflow-Artefakte — Spec-Formulierung zu eng |

## Structured Findings

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: docs/specs/enrichment/feat-98-deutsche-begruendungen.md:135-137 (AC-5) vs.
    LooseEnds/Resources/Localizable.xcstrings (Katalogstand vor der Aenderung, Commit 02b2129,
    125 Eintraege, 0x extractionState)
  Description: AC-5 behauptet, die neun neuen extractionState=translated-Felder seien "konsistent
    mit den 125 vorhandenen Eintraegen". Keiner der 125 bestehenden Katalog-Eintraege traegt jedoch
    ein extractionState-Feld. Die Implementierung erfuellt die woertliche AC (9/9 neue Eintraege mit
    dem Feld), aber die Konsistenzbehauptung der Spec selbst ist falsch.
  Spec requirement: AC-5 — extractionState "translated", "konsistent mit den 125 vorhandenen
    Eintraegen"
  Conflict: Die Praemisse "konsistent mit den 125 vorhandenen Eintraegen" ist durch den Katalog
    widerlegt; die neun neuen Eintraege sind strukturell die einzigen mit diesem Feld im gesamten
    Katalog.
  Remediation: AC-5-Formulierung in der Spec korrigieren (z. B. "abweichend von den 125 vorhandenen
    Eintraegen, die kein extractionState-Feld tragen") oder das Feld bei den neun neuen Eintraegen
    weglassen, falls es kein gueltiger Xcode-Wert ist — nicht durch dieses Ticket zu entscheiden, da
    rein editoriell und Tests/Build nicht beeinflussend.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/specs/enrichment/feat-98-deutsche-begruendungen.md:138-140 (AC-6);
    Dateiliste des Versionsvergleichs HEAD gegen Hauptzweig (eigener Lauf, siehe oben) zeigt 5
    Dateien ausserhalb der genannten zwei, keine davon Produktcode
  Description: AC-6 verlangt woertlich, dass der Versionsvergleich ausserhalb von
    Localizable.xcstrings und DueDateRuleTests.swift leer ist. Tatsaechlich enthaelt der Diff
    zusaetzlich die Spec-, Briefing- und Kontext-Dokumente sowie den RED-Testlauf-Bericht — alles
    Workflow-Pflichtartefakte, kein Produktcode.
  Spec requirement: AC-6 — "ist der Diff leer"
  Conflict: Woertlich nicht erfuellbar, ohne die vom eigenen Prozess (Spec/Briefing/Kontext/
    Artefakte) geforderten Dateien wegzulassen; der AC-Titel und die Purpose-Zeile ("kein
    Produktcode aendert sich") zeigen, dass die Absicht enger gemeint war als der Wortlaut.
  Remediation: AC-6 praezisieren auf "ausserhalb von Localizable.xcstrings, DueDateRuleTests.swift
    und den Standard-Workflow-Dokumenten (docs/specs, docs/briefings, docs/context,
    docs/artifacts) ist der Diff leer" oder gleich auf "kein Swift-Produktcode unter Shared/ oder
    LooseEnds/ (ausser Localizable.xcstrings) geaendert" umformulieren.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: LooseEndsTests/DueDateRuleTests.swift:131-152
  Evidence: eigener Testlauf ./scripts/sim.sh unit DueDateRuleTests, xcodebuild.log:
    "Test \"Alle neun Begruendungssaetze sind im deutschen Bundle uebersetzt (#98, AC-1)\" passed
    after 0.063 seconds." — Bundle.main -> de.lproj -> localizedString(forKey:value:table:) fuer
    alle neun Keys weicht vom Key ab.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: docs/artifacts/feat-98-deutsche-begruendungen/test-red-output.txt (im Commit
    02b2129 enthalten); LooseEndsTests/DueDateRuleTests.swift (unveraendert seit 02b2129, Status
    des Arbeitsverzeichnisses bestaetigt)
  Evidence: RED-Lauf zeigt 9 Issues bei fehlenden Katalog-Eintraegen (Katalogstand zum Zeitpunkt
    verifiziert: 125 Keys, keiner der neun); GREEN-Lauf (eigener Testlauf, s. AC-1) nach
    Katalog-Ergaenzung, Testdatei nachweislich unveraendert.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Resources/Localizable.xcstrings (Zeilen 130-138 im modifizierten Stand)
  Evidence: eigener Projekt-Regenerierungslauf (Katalog byte-identisch danach) + eigener Build
    (sim.sh unit, loest "Compile XCStrings" aus); Katalog danach weiterhin 134 Top-Level-Keys, jeder
    der vier anfuehrungszeichen-kritischen Keys exakt 1x, 0 Vorkommen einer Variante mit geraden
    Anfuehrungszeichen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Resources/Localizable.xcstrings (Zeilen 130-138);
    Shared/Enrichment/DueDateRule.swift:44-55
  Evidence: eigenes Python-Skript vergleicht alle neun de-Werte byte-exakt gegen die Tabelle in
    "Implementation Details" der Spec — ALL MATCH: True.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Resources/Localizable.xcstrings (Zeilen 130-138, extractionState=
    translated in allen 9 neuen Eintraegen)
  Evidence: Feld-Zaehlung im geaenderten Katalog = 9, alle mit Wert "translated". Woertliche AC
    erfuellt. (Die Zusatzbehauptung ueber Konsistenz mit dem Bestand ist per F001 widerlegt, blockt
    laut Aufgabenstellung nicht.)
  Status: CONFIRMED (mit Finding F001, spec-seitig, nicht implementierungsseitig)

Confirmation:
  AC: AC-6
  Code reference: Versionsvergleich beschraenkt auf Shared/ und LooseEnds/, ohne
    Localizable.xcstrings (leer)
  Evidence: kein Swift-Produktmodul veraendert; einzige Produktdatei-Aenderung ist der reine
    Ressourcen-Katalog. DueDateRule.swift, TaskDetailView.swift, FieldEditorView.swift bestaetigt
    unveraendert. (Die woertliche "Diff ist leer"-Formulierung ist per F002 zu eng, blockt analog zu
    F001 nicht, da sie nur Workflow-Pflichtartefakte betrifft, keinen Produktcode.)
  Status: CONFIRMED (mit Finding F002, spec-seitig, nicht implementierungsseitig)

## Test-Zusammenfassung

- Eigener Lauf ./scripts/sim.sh unit DueDateRuleTests: 8 Tests, 8 bestanden, 0 fehlgeschlagen,
  "TEST SUCCEEDED".
- test-green-output.txt (Builder-Artefakt, voller Suite-Lauf): "Test Succeeded", keine
  fehlgeschlagenen Suiten ausser der zuvor als RED erwarteten (im GREEN-Lauf gruen).
- test-red-output.txt (im Commit enthalten): erwartungsgemaess 9 Issues in genau dem neuen Test,
  alle anderen Suiten gruen.
- python3 -m json.tool Localizable.xcstrings: valide, sowohl vor als auch nach eigenem Build.

## Regressionen

Keine gefunden. DueDateRule.swift, EnrichmentDraft.swift, EnrichmentWriter.swift, Revision.swift,
TaskDetailView.swift, FieldEditorView.swift — alle wie in der Spec zugesichert unveraendert (leerer
Diff gegen den Hauptzweig fuer jede dieser Dateien). Keine anderen Suiten im vollen Testlauf zeigen
neue Fehlschlaege.

## VERDICT

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: eigener Lauf 8/8 bestanden (DueDateRuleTests inkl. neuer AC-1-Test); voller Suite-Lauf laut
Builder-Artefakt gruen, RED-Artefakt zeigt den erwarteten Vorher-Zustand.
Edge cases: Anfuehrungszeichen-Exaktheit nach echtem Build geprueft (nicht nur nach der reinen
Projekt-Regenerierung), Katalog-JSON-Validitaet geprueft, Byte-Vergleich aller 9 Uebersetzungen und
aller 9 Original-Keys.
Regressionen: keine.
Checklist: 6/6 Punkte belegt (AC-1 bis AC-4 ohne Einschraenkung; AC-5 und AC-6 woertlich erfuellt,
mit je einem dokumentierten, nicht-blockierenden Spec-Formulierungsfehler — F001, F002 — der laut
Aufgabenstellung explizit nicht VERIFIED verhindert, solange Build/Tests/AC-3 gruen bleiben, was sie
sind).
Empfehlung: F001 und F002 als redaktionelle Korrektur an der Spec nachziehen (kein Produktcode-,
Test- oder Katalog-Fix noetig).
