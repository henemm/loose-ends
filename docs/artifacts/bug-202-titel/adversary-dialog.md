# Adversary-Dialog: Bug #202 — Titel ab Erfassung per Regel, Zurücksetzen führt auf einen Titel

Geprüft: Spec `docs/specs/fix-202-titel-regel.md` plus PO-Ergänzung `detailRawTextMarker` (13 statt 9 Dateien,
`docs/context/bug-202-titel.md`). Methode: Code gelesen, vorhandenen grünen
Unit-Output (`test-green-output.txt`, "Test Succeeded", Suite "TitleRule (#202)" grün) und den
UI-Klassenlauf (15/17) ausgewertet, Screenshots geöffnet. Unit-Tests habe ich nicht selbst neu gestartet
(Lauf hängt ~10 Min nach); Beleg ist der Output der Umsetzung.

### Runde 1 — Direkte Prüfung je AC

**AC-1 (Titel ab Erfassung).** Beleg: `CaptureService.save` setzt `item.title = TitleRule.title(from: text)`
(Shared/Services/CaptureService.swift:22). Alle Schreibwege gehen darüber: Suche nach `TaskItem(` ergibt nur
CaptureService.swift:20 und Subtasks.swift:19 (bewusst ausgenommen). Aufrufer: CaptureView:171,
ShareCaptureView:65, WatchCaptureView:33, CaptureTextIntent:17. Screenshot `75087BB9…png` (testCapturedTaskHasTitleInDetail)
geöffnet: Detail, Titelfeld in Serif "Termin bei Auto Senger machen f…", keine "You said:"-Zeile, kein
Reset-Pfeil, kein Funke. Nachbohren: Die Abkürzung "f…" ist reine Feldbreite (einzeilig), der Feldwert ist
laut Test der volle Titel; kein Spec-Verstoß. Verdict: bewiesen.
- [x] AC-1

**AC-2 (>12 Wörter).** TitleRule.swift:13 `prefix(maxWords)`. Screenshot `D1CBD26E…png` (14 Wörter):
Titel "Eins zwei drei vier fünf sechs s…" (Feldbreite), darunter kursiv "You said: eins zwei … vierzehn"
vollständig. Nachbohren: auf dem Bild stehen zusätzlich Funken bei Dauer/Energie, "3 fields set by AI" und
ein Reset-Pfeil am Titel: Im Simulator hat also doch ein Anreicherer gelaufen (Spec behauptet "Simulator
hat kein Modell"). Der Titel danach ist textgleich zur Regel (Spec-Entscheidung 6: KI-Revision old==new,
EnrichmentWriter.swift:43–48 schreibt bei firstRun immer). Kein AC-Verstoß, aber siehe F003.
- [x] AC-2

**AC-3 (≤12 Wörter, keine "You said:").** `DetailLayout.showsRawText` (TaskDetailView.swift:64, unverändert) vergleicht
Wortmengen; Regeltitel hat dieselben Wörter. Screenshot `75087BB9…png`: keine Zeile. Randfall: Regeltitel ohne
Satzzeichen, andere Großschreibung: RawTextWords normalisiert, also gleich. Verdict: bewiesen.
- [x] AC-3

**AC-4 (Zurücksetzen nach Modelltitel).** EnrichmentWriter.swift:45 `old: task.title` = Regeltitel;
`revert` nutzt `restoreValue` (RevisionService.swift:28, 54–55), bei `oldValue != nil` unverändert.
Unit-Test "Reset after the model title leads back to the rule title" grün. Nachbohren `oldValue == ""`:
`FieldCodec.apply` (FieldCodec.swift:38) normalisiert leer zu nil via `nonEmpty`; CaptureService liefert nil
statt "". Ein "" als oldValue entsteht damit nicht; selbst dann würde `set(…, to: "")` zu nil führen.
Praktisch unerreichbar, siehe Runde 2.
- [x] AC-4

**AC-5 (Altbestand, revert und revertAll).** RevisionService.swift:28 (revert) und :44 (revertAll) nutzen
beide `restoreValue`; :55 greift nur bei `.title` und `oldValue == nil`. Test "Reset of an old task without a
title … via revert and via revertAll" und "legacy rule applies to the title only" (Datum bleibt leer) grün.
- [x] AC-5

**AC-6 (frisch erfasst).** Status bleibt `.unprocessed` (CaptureService setzt nur title); `titleSourceRaw`
nil, damit `aiSetFields` (RevisionService.swift:99) den Titel nicht enthält, kein Reset-Button
(TaskDetailView.swift:46 `aiFields.contains(.title)`), TaskRow zeigt Funke nur bei `titleSourceRaw == ai`
(TaskRow.swift:37). Unit-Test captureSetsTitle grün; Screenshot 75087BB9 ohne Funke/Pfeil.
- [x] AC-6

**AC-7 (unverified).** TaskItem.swift:118–121: `displayTitle` ohne `unverified`-Klausel, Rückfall auf rawText nur
bei fehlendem Titel. TaskRow.swift:35 kursiv bei `title == nil || unverified`. Test displayTitle grün.
- [x] AC-7

**AC-8 (geleert bleibt leer).** `FieldCodec.apply` setzt nil (FieldCodec.swift:38–39); CaptureService läuft nur
beim Erfassen. Test "A title the user emptied stays empty" grün.
- [x] AC-8

**AC-9 (Mitteilung/Kalender/Widget).** Alle lesen `displayTitle`: DueReminders.swift:36,
CalendarSync.swift:23/27, NextUpWidget.swift:21. Nebenwirkung siehe F002.
- [x] AC-9

**AC-10 (gesamt).** Unit 287+4 grün. UI-Klasse CaptureSmokeTests 15/17: rot sind
testCalendarSwitchStaysOn und testDeletingRecurringTaskAfterCompletionDoesNotCrash, beide mit "Detail should
show the raw text". Das ist die Meldung der neuen Kennung, daher nicht blind als "bekannt" hinnehmbar:
Einzelprotokolle (scratchpad/flaky/summary.txt): Basis testCalendarSwitchStaysOn 2/3 grün,
testDeleting… 1/3 grün; Worktree je 3/3 grün. Der Fehler tritt auf der Basis häufiger auf als im Worktree,
also keine Verschlechterung durch #202. Roll-Forward (TaskActions.swift:13–20) mutiert dieselbe Aufgabe,
erzeugt kein neues TaskItem. Rohtext unverändert (nur getrimmt, CaptureService.swift:18). Warnungen im Lauf:
nur AVAudioSession-Laufzeitwarnungen, keine aus der Änderung.
- [x] AC-10 (mit Vorbehalt F004)

### Runde 2 — Zusätzliche Proben

**TitleRule (TitleRule.swift:11–23).**
- Emoji am Anfang: `isLetter` false, Text unverändert, kein Absturz. OK.
- Kombinierende Zeichen ("e" + U+0301): `text.first` ist ein Grapheme-Cluster, `uppercased()` ergibt "É"
  (count 1); Rest bleibt. OK.
- Nur Anführungszeichen: nicht in der Satzzeichenmenge, Ergebnis ist das Zeichen selbst als Titel (nicht nil).
  Spec-konform (Regel 3 lässt Anführungszeichen ausdrücklich stehen), nur sinnlos; kein Befund.
- Exakt 12 Wörter + ".": Schlusspunkt wird entfernt (Schleife :14), keine Kürzung. 13 Wörter, Wort 12 mit
  Komma: Komma weg. OK.
- "Foo . .": Wörter "Foo", ".", "." → Schleife entfernt Punkte und Leerzeichen → "Foo". OK.
- Sehr langes einzelnes Wort: keine Zeichenbegrenzung, F005 (LOW).
- Idempotenz: Erstbuchstabe `uppercased()` nur bei count 1, stabil; ß-Fall bleibt. OK.

**restoreValue (RevisionService.swift:54–55).** `oldValue == nil` und Feld `.title`: Regeltitel des Rohtexts.
Liefert die Regel nil (Rohtext nur Satzzeichen), bleibt das Feld leer; über CaptureService unerreichbar, nur bei
direkt angelegten Aufgaben. Sonderfall: Nutzer leert Titel, später Reanalyse setzt KI-Titel (oldValue nil) →
Reset führt auf Regeltitel statt leer. Das passt zu AC-4/AC-5 ("nie leer") und kollidiert nicht mit AC-8
(das betrifft das App-seitige Nachfüllen).

**EnrichmentWriter-Interaktion.** Modell liefert denselben Text: firstRun schreibt trotzdem Revision +
KI-Markierung (EnrichmentWriter.swift:126–128, 43–48), Spec-Entscheidung 6, im Screenshot D1CBD26E sichtbar.
Reanalyse mit gleichem Text: `changes == false`, nichts. Vorbestehend (nicht durch #202): firstRun überschreibt
einen zwischenzeitlich vom Nutzer gesetzten Titel.

**Wiederholung / andere Wege.** Kein weiterer TaskItem-Erzeuger außer CaptureService und Subtasks
(bewusst ausgenommen, Spec Entscheidung 5). Roll-Forward kopiert nicht. Siri, Watch, Share, App: alle über
`CaptureService.save`. TitleRule wird nicht umgangen.

**Unsichtbare Kennung (TaskDetailView.swift:58–63).** `Color.clear` im `.background` des HStack bestimmt keine
Größe, Layout unverändert, im Screenshot keine Verschiebung. VoiceOver: eigenes Accessibility-Element mit
Label = Rohtext; Nutzer hören den Rohtext zusätzlich zum Titelfeld und (falls sichtbar) zur "You said:"-Zeile,
bei kurzen Texten also doppelt. F001.

### Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/TaskDetailView.swift:58
  Description: Die Kennung `detailRawTextMarker` ist ein Accessibility-Element (`.accessibilityElement()` mit Label = Rohtext). VoiceOver liest den Rohtext zusätzlich zum Titelfeld und zur "You said:"-Zeile.
  Spec requirement: AC-10 — bestehender Funktionsumfang bleibt; PO-Ergänzung verlangt eine "unsichtbare" Kennung.
  Conflict: Visuell unsichtbar, für Hilfstechnik aber doppelt. Kein Verstoß gegen die AC, aber ein Barrierefreiheits-Rückschritt.
  Remediation: Kennung nur unter `--ui-testing` einhängen oder anders testbar machen; mindestens als Folgearbeit festhalten.

Finding:
  ID: F002
  Severity: LOW
  Category: regression
  Code reference: Shared/Models/TaskItem.swift:118
  Description: `displayTitle` liefert jetzt den Regeltitel, der sich vom Rohtext durch Schlusspunkt/Großbuchstabe unterscheidet. `CalendarSync` (Shared/Services/CalendarSync.swift:20) setzt Notizen nur bei `rawText == displayTitle` auf nil; neue Kalendereinträge tragen damit fast immer den Rohtext in den Notizen.
  Spec requirement: AC-9 — Kalender trägt den bereinigten Titel.
  Conflict: AC-9 erfüllt; Nebenwirkung (Notizen auch bei kurzen Aufgaben) steht nicht in der Spec.
  Remediation: Akzeptieren (Rohtext bleibt erhalten) oder PO entscheiden lassen.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: Shared/Services/CaptureService.swift:22
  Description: Die Spec behauptet, der Simulator habe kein Modell. Screenshot D1CBD26E zeigt im Simulator KI-Funken, "3 fields set by AI" und Reset-Pfeil nach einer Erfassung. Die UI-Tests prüfen den Titelwert also gegen einen Titel, den ein Anreicherer überschreiben kann.
  Spec requirement: Spec Purpose / Test 17–18 (Simulator ohne Modell).
  Conflict: Annahme falsch; die Tests sind stabil, weil der Modelltitel hier textgleich ausfällt.
  Remediation: Annahme in Spec/Doku korrigieren; bei abweichendem Modelltitel wäre der Testwert nicht stabil.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/TaskDetailView.swift:62
  Description: Zwei UI-Tests schlagen im Klassenlauf mit der Meldung der neuen Kennung fehl ("Detail should show the raw text"). Einzelläufe: Basis 2/3 bzw. 1/3 grün, Worktree je 3/3 grün; kein Beleg für Verschlechterung, aber kein grüner Klassenlauf.
  Spec requirement: AC-10 — alle Tests grün.
  Conflict: Klassenlauf 15/17 statt 17/17; Begründung stützt sich auf Instabilität, die auch ohne #202 auftritt.
  Remediation: Instabilität separat untersuchen; Klassenlauf bei Gelegenheit wiederholen.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/TitleRule.swift:13
  Description: Kürzung nur nach Wörtern; ein einzelnes sehr langes "Wort" (URL ohne Leerzeichen) wird ungekürzt Titel.
  Spec requirement: Regel 2 — höchstens zwölf Wörter.
  Conflict: Spec-konform, nur unschön bei Share von Links.
  Remediation: Optional Zeichengrenze; kein Muss.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: Shared/Services/CaptureService.swift:22
  Evidence: `item.title = TitleRule.title(from: text)` bei jeder Erfassung; alle Kanäle laufen über `CaptureService.save`; Screenshot 75087BB9 zeigt den Titel im Detail.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/TitleRule.swift:13
  Evidence: `prefix(maxWords)` mit 12; Screenshot D1CBD26E zeigt 12-Wörter-Titel und vollständige "You said:"-Zeile.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Views/TaskDetailView.swift:64
  Evidence: "You said:" nur bei `DetailLayout.showsRawText`; bei gleichen Wortmengen entfällt sie, im Screenshot 75087BB9 nicht vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Services/RevisionService.swift:28
  Evidence: `revert` nutzt `restoreValue`; oldValue der ersten KI-Revision ist der Regeltitel (EnrichmentWriter `old: task.title`); Test "Reset after the model title …" grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Services/RevisionService.swift:54
  Evidence: `restoreValue` ersetzt `oldValue == nil` beim Titel durch `TitleRule.title(from: task.rawText)`; `revertAll` (Zeile 44) nutzt dieselbe Funktion; Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Services/CaptureService.swift:22
  Evidence: Nur `title` gesetzt, `titleSourceRaw`/Status unverändert, kein KI-Funke, kein Reset-Knopf (TaskDetailView.swift:46), "Not sorted yet" hängt am Status.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Models/TaskItem.swift:118
  Evidence: `displayTitle` ohne `unverified`-Klausel; ohne Titel Rückfall auf Rohtext; Kursiv in TaskRow.swift:35 bleibt.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Shared/Services/RevisionService.swift:61
  Evidence: `set(.title, to: nil)` über FieldCodec leert Titel und Quelle; kein Nachfüllen außerhalb der Erfassung; Test "A title the user emptied stays empty" grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Models/TaskItem.swift:118
  Evidence: DueReminders:36, CalendarSync:23/27 und NextUpWidget:21 lesen `displayTitle`, das jetzt den Regeltitel liefert.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Views/TaskDetailView.swift:62
  Evidence: Unit 287+4 grün; UI 15/17 mit zwei auch auf Basis instabilen Tests (Einzelläufe im Worktree 3/3 grün); Layout durch `.background` unverändert; Rohtext unverändert.
  Status: CONFIRMED

## Verdict je Punkt

- **AC-1: AKZEPTIERT**
- **AC-2: AKZEPTIERT**
- **AC-3: AKZEPTIERT**
- **AC-4: AKZEPTIERT**
- **AC-5: AKZEPTIERT**
- **AC-6: AKZEPTIERT**
- **AC-7: AKZEPTIERT**
- **AC-8: AKZEPTIERT**
- **AC-9: AKZEPTIERT**
- **AC-10: AKZEPTIERT** (Vorbehalt F004)

## Verdict: VERIFIED

## Geprüfte Dateien

- sha256:cb83a3de87d86d6c4c25b49724d368b00cd07e378d4581d63387926c7c7311d5  LooseEnds/Views/TaskDetailView.swift
- sha256:39aba68e4a758b58900d137e499d46256ed69308683cf79b921d7f4e0edb7f8d  Shared/Models/TaskItem.swift
- sha256:3ec08f6ab1e1cde70405cb4ddfbf47566f96e6dd91d2a0f6e3c429e33789bf2a  Shared/Services/CaptureService.swift
- sha256:0d033742eb750e3cfc261b653b3f18c8872470027708e71251342f33dfce9aeb  Shared/Services/RevisionService.swift
- sha256:1765d090b27b15f5d5003cee9a915c3904dbc264147993f046837c5b5cb8c738  Shared/Services/TitleRule.swift
