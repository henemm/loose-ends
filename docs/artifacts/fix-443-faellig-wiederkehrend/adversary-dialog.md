# Adversary Dialog — fix-443-faellig-wiederkehrend
Spec: docs/specs/fix-443-faellig-wiederkehrend.md
Datum: 2026-10-16 14:14

## Checkliste
- [x] **AC-1:** Given eine wöchentlich wiederkehrende Aufgabe, die nach heute fällig ist (morgen, in 7 Tagen oder nach dem Abschließen eine Woche weiter) / When `ViewRules.tasks(for: .due, …)` gebildet wird / Then enthält die Liste die Aufgabe nicht. Belegt durch Unit-Test in `DueTodayTests`.
- [x] **AC-2:** Given eine wiederkehrende Aufgabe fällig heute 19:00 oder gestern / When `.due` gebildet wird / Then ist sie enthalten (die Regel von #455 bleibt). Belegt durch Unit-Test.
- [x] **AC-3:** Given im Simulator eine neu erfasste Aufgabe mit Wiederholung „Weekly“, einmal abgeschlossen / When die Ansicht „Fällig“ geöffnet wird / Then zeigt sie die Aufgabe nicht, und „Wiederholend“ zeigt sie weiterhin. Belegt durch UI-Test samt Screenshots.
- [x] **AC-4:** Given der UI-Test aus AC-3 läuft auf dem unveränderten Stand / When er rot wird / Then ist die Ursache im Wiederholungs-Pfad mit diesem Lauf belegt und nach dem Fix derselbe Lauf grün; wird er sofort grün, ist #443 durch #455 erledigt und das Ticket mit diesem Beleg geschlossen, ohne Änderung an Produktcode.

## Dialog

### Runde 1
**Adversary:**
Beweisanforderung und Pruefung je AC (nur lesend, keine Laeufe):

- AC-1 (Unit, morgen / +7 / nach complete nicht in .due): AKZEPTIERT.
  Code reference: LooseEndsTests/DueTodayTests.swift:78 (Test `repeatingTaskDueOnlyOnItsDay`).
  Der Test setzt zuerst `dueIDs() == [tonight, overdue, rolling]`, schliesst dann alle drei ab und erwartet `isEmpty`;
  `tomorrow`/`nextWeek` sind im Vorher-Zustand ausgeschlossen. Keine Tautologie: die Zusicherung nennt die exakte Menge.
  Regel: Shared/Models/ViewRules.swift:202 (`dueDate < Mitternacht morgen`), TaskActions.swift:13 rollt via `nextDueDate`.
  Beleg: unit-red.txt:269 zeigt den Test gruen (Dateiname "red" irrefuehrend, der Test war nie rot).
  Nachfrage (nicht blockierend): Randfall nicht belegt: bei Basis `.fromDueDate` bleibt eine mehr als 7 Tage ueberfaellige Aufgabe nach einem Abschluss weiter ueberfaellig (nach Regel korrekt, ungetestet) - in Runde 2 als "gewollt" bestaetigen.
- AC-2 (heute 19:00 / gestern in .due): AKZEPTIERT.
  Code reference: LooseEndsTests/DueTodayTests.swift:93 (`tonight`, `overdue`, `rolling` in der Erwartungsmenge). Zeit fest ueber `Self.now` (12.03.2026 10:00 Berlin), keine Zeitabhaengigkeit. Grenze 00:00 morgen (strikt `<`) nicht eigens getestet, nur Hinweis.
- AC-3 (UI, Weekly, einmal abgeschlossen, Faellig leer, Wiederholend zeigt): AKZEPTIERT mit Hinweis.
  Code reference: LooseEndsUITests/CaptureSmokeTests.swift:534 (`testWeeklyTaskIsNotDueUntilItsDay`), Hilfe `assertDueViewHoldsNoTask` ab :593.
  Echter Bedienweg (Erfassen, Editor Weekly, Menue Complete), keine vorgesetzten Daten. Screenshots geoeffnet: 782D678F... und B7272E84... zeigen "Due" mit "Nothing due today." (vor und nach Abschluss); 405306CD... zeigt "Repeating" mit "Oct 30 Fußnagel behandeln". Oct 30 bei heute 16.10. = Erstdatum +7 (23.10.), nach Abschluss +7 (30.10.): ein Datum war wirklich gesetzt, der leere Due-Screen ist also keine Folge eines fehlenden Datums. Der Test assertiert das Datum aber nicht; der Vor-Abschluss-Screenshot zeigt es nicht. Ohne Datum waere "Due leer" trivial.
  ui-run.txt:21 gruen, 1 Test, 0 Fehler.
- AC-4 (sofort gruen => durch #455 erledigt, kein Produktcode): AKZEPTIERT.
  Code reference: Diff gegen origin/main beruehrt nur LooseEndsTests/DueTodayTests.swift und LooseEndsUITests/CaptureSmokeTests.swift, kein Produktcode. UI-Lauf auf unveraendertem Stand gruen (ui-run.txt:21); Regelcode ViewRules.swift:202-206 passt zur Erklaerung der Screenshots durch den alten 7-Tage-Vorlauf.
  Nachfrage: Dass Hennings Build vor dem Merge von #455 liegt, steht nur in der Spec - im Ticket mit Buildnummer belegen.

Offene Fragen:
1. Soll der UI-Test das gesetzte Faelligkeitsdatum vor dem Abschluss belegen, damit "Due leer" nicht trivial sein kann?
2. Ueberfaellige Wiederholung (> 7 Tage, .fromDueDate) bleibt nach einem Abschluss in Faellig - gewollt?
3. Buildnummer aus Hennings Meldung gegen den Merge-Zeitpunkt von #455 im Ticket belegen.
4. unit-red.txt im Ticket als "gruen, nie rot" kennzeichnen.
**Implementierer:**

### Runde 2
**Adversary:**
Antworten nachgeprueft, nicht geglaubt:
1. Datum vor Abschluss: Code reference: LooseEnds/Views/FieldEditorView.swift:515 - `applyRepeat` setzt bei neuer Regel ohne Datum `rule.firstDueDate()`. Shared/Models/RepeatRule.swift:48-52 liefert Anker `now` +7 Tage (Weekly ohne Wochentage, Zeile 28). TaskActions.swift:17 rollt von `previousDue` um weitere 7. Haette kein Datum vorher existiert, laege nach Abschluss heute+7 = 23.10.; der Screenshot zeigt 30.10. Damit ist belegt: Datum 23.10. war vorher gesetzt, Due leer ist nicht trivial. AKZEPTIERT (Testluecke bleibt, durch Rechnung plus Screenshot geschlossen).
2. Ueberfaellige Wiederholung bleibt in Faellig: nach #455 "heute und ueberfaellig" gewollt, ausserhalb #443. AKZEPTIERT.
3. gh pr view 455: mergedAt 2026-10-15T20:43:39Z bestaetigt; Issue 2026-10-15T12:45Z davor. Meldung stammt aus der Zeit vor dem Merge, Mo 19.10. = 3 Tage nach 16.10. passt zum alten 7-Tage-Vorlauf. AKZEPTIERT.
4. unit-red.txt als "gruen, nie rot" kennzeichnen: AKZEPTIERT.
Code reference: LooseEndsTests/DueTodayTests.swift:78
Code reference: LooseEndsUITests/CaptureSmokeTests.swift:534
Keine weiteren Nachfragen. AC-1 bis AC-4 bewiesen; nur Tests ergaenzt, kein Produktcode.
**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: Unit-Test und UI-Test gruen laut Belegdateien (unit-red.txt:269, ui-run.txt:21); von mir nicht erneut gelaufen.
Edge cases: geprueft, keine gebrochen (ueberfaellige Wiederholung >7 Tage bleibt nach #455-Regel in Faellig, ausserhalb #443).
Regressions: keine (kein Produktcode geaendert).
Checklist: 4/4 points proven

## Geprüfte Dateien

- sha256:16c2758ec837365b80920f743fbae644ce5e34d12e106eace929944cf7133afc  LooseEndsTests/DueTodayTests.swift
- sha256:ce3ec79ec54d4f73d542f5faf871af16c8801944735a9357818a2211048658cf  LooseEndsUITests/CaptureSmokeTests.swift

## Prüfbasis

- base: 27dc50574dd9ab90f1b2150f95cf7bbb3695a7d7
- blob:caa6f722a5304fd55e665f22a16f0ba72616b16d  LooseEndsTests/DueTodayTests.swift
- blob:e5c289d4cd4eea0d73bec8e76c35fd6b1ca4b090  LooseEndsUITests/CaptureSmokeTests.swift
