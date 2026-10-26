# Abnahme vor der Einladung: Prüfliste der TestFlight-Fassung (#176)

Diese Liste belegt, dass die TestFlight-Fassung als Nutzer funktioniert, bevor externe Tester eingeladen werden
(benutzen, nicht nur bauen; Henning, 2026-09-27). Jeder Alltagsschritt steht mit Bedienweg, Quelle in der User Story und
Status darin; was Henning in einem bestätigten Build schon gesehen hat, ist mit Ticket und Buildnummer belegt. Nur die
Lücken spielt er durch, gebündelt im Abschnitt „Prüfblock“ am Ende, und die Liste bleibt die Vorlage für jede weitere
Einladungswelle.

**Geltungsbereich:** Die Liste gilt für die Builds der Spalte `Build`; ältere Belege werden bei Zweifel als Lücke geführt.
Vor jeder Einladungswelle wird sie auf den aktuellen Build bezogen durchgegangen. Die Testgruppe in App Store Connect
gehört nicht hierher, sondern zu #342 Teil 3.

**Geräteregel (zwingend):** Kein Schritt dieser Liste startet, installiert, misst oder liest etwas auf Hennings Geräten
(iPhone, iPad, Watch, Mac als Zielgerät), auch nichts Lesendes. Gerätepunkte stehen als „wartet auf Hennings Wort
‚jetzt ist ein Test möglich‘“: Erst nach diesem wörtlichen Satz, und nur für diesen einen Durchgang, geht der Prüfblock als
TestFlight-Build raus. Eine Ankündigung ist keine Frage, eine frühere Freigabe gilt nicht weiter.

**Status** (genau einer je Zeile):

- `belegt`: Henning hat den Schritt in einem Build bestätigt. Beleg nennt das Ticket, Build die Buildnummer; ein
  Bildschirmfoto oder Protokoll steht zusätzlich als Pfad in Backticks (`docs/artifacts/176-abnahme/<datei>`).
- `Lücke`: kein bestätigter Beleg im Ticketverlauf für den aktuellen Stand. Beleg und Build stehen auf `–`.
- `wartet auf Hennings Wort`: Rückmeldung aus TestFlight, gemergt, aber unbestätigt; läuft im Prüfblock erst nach
  „jetzt ist ein Test möglich“. Beleg und Build `–`, bis seine Rückmeldung da ist.

Ein Status wechselt nur auf `belegt`, wenn Ticket und Build aus einer echten Rückmeldung stammen; nichts wird von Hand
gesetzt. Abweichungen aus dem Prüfblock werden je eigenes Ticket. Geprüft wird die Form mit
`python3 scripts/test_abnahme_liste.py`.

## Prüfliste

| Nr | Schritt | Bedienweg | Quelle | Status | Beleg | Build |
|----|---------|-----------|--------|--------|-------|-------|
| S01 | Erfassung per Text (iPhone) | Startseite „+“, Satz tippen, „Fertig“; die Aufgabe steht in „Neu“ (`CaptureSmokeTests.testCapturedTaskShowsUpInNew`) | User Story, Funktional: Erfassung über Textfeld in der App | Lücke | – | – |
| S02 | Erfassung per Sprache (iPhone), nur Mikrofonrecht | Startseite „+“, sprechen; höchstens der Mikrofon-Dialog erscheint, „Ich höre …“, der Text kommt (#293) | Funktionsübersicht, Erfassung: Live-Spracherkennung mit Wellenform | belegt | #293 (Rückmeldung in PR #666, `docs/artifacts/feat-293-nur-mikrofon/testflight-ac10.txt`) | 112 |
| S03 | Veredelung: Titel vom Modell mit Zeitgrenze | Satz erfassen, kurz warten; die Aufgabe bekommt wie bisher ihren Titel, ein hängender Modellaufruf endet nach 25 s | User Story, Funktional: Stille Veredelung genau einmal nach der Erfassung | belegt | #534 | 107 |
| S04 | Veredelung: Datum aus Regel, Kontexte und Dauer bei Wiedererkennung | „Morgen Zahnarzt anrufen“ erfassen: Fälligkeit morgen; denselben Satz noch einmal erfassen: Kontexte und Dauer der ersten Aufgabe (`RecognitionWalkthroughTests`) | User Story, Erfolgskriterium: Kontext nach drei manuellen Zuordnungen automatisch | Lücke | – | – |
| S05 | Veredelung: Dauer-Regel | „20 Minuten Rasen mähen“ erfassen; im Detail steht die Dauer aus dem Text | Funktionsübersicht, Veredelung | belegt | #673 | 115 |
| S06 | Ansichten und Startseite | Startseite: Zahl über „Jetzt“, „Neu“, „Fällig“; Projekte und Kontexte aufklappen und öffnen (`StartScreenInteractionTests`) | User Story, Funktional: Berechnete Ansichten | Lücke | – | – |
| S07 | Erledigt mit Rücknahme, Parken | Zeile nach rechts wischen, innerhalb von drei Sekunden auf die Zeile tippen: bleibt; Halten-Menü „Parken“: Aufgabe unter „Geparkt“ (`CaptureSmokeTests.testUndoInsideTheDoneWindowKeepsTheTask`) | Funktionsübersicht, Liste: Erledigt drei Sekunden abbrechbar, Parken | Lücke | – | – |
| S08 | Mitteilung „Heute fällig“ | Aufgabe für heute; zur eingestellten Zeit kommt die tägliche Mitteilung „Heute fällig“ (`DueNotificationTapTests`) | User Story, Funktional: Mitteilung am Fälligkeitstag mit drei Aktionen | belegt | #580 | 114 |
| S09 | Teilen-Menü | Aus Safari einen Link, aus Notizen Text, eine Mail, ein Foto und eine Datei an Loose Ends teilen; die Aufgabe steht in „Neu“ | User Story, Funktional: Erfassung über Teilen-Menü | belegt | #580 | 114 |
| S10 | Kalender-Schalter | Detail, Schalter „Im Kalender anzeigen“ an; Termin im Kalender „Loose Ends“, Schalter bleibt an (`CaptureSmokeTests.testCalendarSwitchStaysOn`) | User Story, Funktional: Terminierte Aufgabe optional im Kalender anzeigen | Lücke | – | – |
| S11 | Watch-Diktat mit Rücksprung | Watch-App öffnen, Feld tippen, diktieren, „Fertig“; Bestätigung, danach wieder das leere Feld (`WatchCaptureUITests`) | User Story, Funktional: Erfassung über Watch | belegt | #409 | 64 |
| S12 | Watch-Komplikation | Zifferblatt, Komplikation „Loose Ends“ wählen: Knoten; antippen öffnet die Erfassung | User Story, Erfolgskriterium: Erfassung per Watch ohne die App zu sehen | belegt | #355 (Abschlusskommentar 2026-10-18: Komplikation wird regelmäßig genutzt) | 57 |
| S13 | Widget „Als nächstes“ | Widget „Next up“ auf den Home-Bildschirm legen; es zeigt die Aufgaben aus „Als nächstes“ | User Story, Abgeleitete Features: Widgets „Als nächstes“ | Lücke | – | – |
| S14 | Control Center | Kurzbefehle-Steuerelement „Aufgabe erfassen“ im Kontrollzentrum antippen, Satz sagen; die Aufgabe steht in „Neu“ | User Story, Erfolgskriterium: Erfassung per Control Center in unter fünf Sekunden | Lücke | – | – |
| S15 | iPad: Seitenleiste und Startseite | iPad quer: Seitenleiste mit den Ansichten, Startseite rechts; hoch: dieselben Zonen wie auf dem iPhone (`StartScreenInteractionTests.testIndexMarksTheOpenListOnIPadOnly`) | User Story, Erfolgskriterium: Oberfläche auf iPhone und Mac dieselbe Codebasis | Lücke | – | – |
| S16 | Mac aus TestFlight: Fenstergröße | In TestFlight auf dem Mac macOS wählen, installieren; Fenster nicht kleiner als 760 × 520 | User Story, Erfolgskriterium: Oberfläche auf iPhone und Mac dieselbe Codebasis | belegt | #480 | 106 |
| S17 | Mac aus TestFlight: nur Mikrofonrecht | Mac, Erfassung öffnen, sprechen; höchstens der Mikrofon-Dialog, der Text kommt (#293) | Funktionsübersicht, Erfassung: Live-Spracherkennung | Lücke | – | – |
| S18 | Ortserinnerung: Ankommen und Erledigt | Aufgabe mit Ort (Zuhause), App schließen, am Ort ankommen: Mitteilung; „Erledigt“ in der Mitteilung erledigt die Aufgabe (#240, `PlaceNotificationTapTests`) | Funktionsübersicht, Mitteilung | belegt | #240 (PR #447, Gerätebefund Runde 5) | 61 |
| S19 | Modelltitel hängt keinen Satz einer erledigten Aufgabe an (#607) | „Cider kaltstellen“ erfassen, nachdem eine andere Aufgabe erledigt wurde; der Titel enthält kein Wort der erledigten Aufgabe | User Story, Emotional: Vertrauen, die App hat verstanden, was ich meinte | wartet auf Hennings Wort | – | – |
| S20 | Zahl auf dem App-Icon gleich der Zahl über „Jetzt“ (#584) | Startseite: Zahl über „Jetzt“ ablesen, App verlassen; das App-Icon zeigt dieselbe Zahl (`StartNumberTests.testNumberOverNowIsTheNumberOfRows`) | CLAUDE.md, Grundregel: Eine Zahl überall (#637) | wartet auf Hennings Wort | – | – |
| S21 | Schreibzeile auf der Startseite (#601) | Startseite iPhone, iPad, Mac: in die Zeile unter „Neu“ tippen, Return; die Aufgabe steht darüber, der Cursor bleibt (`InboxDrawerSmokeTests`) | Funktionsübersicht, Schreibzeile | wartet auf Hennings Wort | – | – |
| S22 | Löschen mit Unteraufgaben (#605) | Aufgabe mit einer Unteraufgabe löschen; die Aufgabe ist weg, die Unteraufgabe steht als eigene Zeile (`CaptureSmokeTests.testDeletingATaskLiftsItsSubtask`) | User Story, Funktional: Unteraufgaben eine Ebene tief | wartet auf Hennings Wort | – | – |
| S23 | Mac aus TestFlight: Listentasten | Mac, eine Liste öffnen; Pfeile wählen eine Zeile, Leertaste erledigt (`MacKeyboardTests`) | User Story, Erfolgskriterium: Oberfläche auf iPhone und Mac dieselbe Codebasis | Lücke | – | – |

## Prüfblock

Alle Zeilen mit `Lücke` oder `wartet auf Hennings Wort` in einem TestFlight-Build. Ausgelöst wird er erst nach Hennings
wörtlichem „jetzt ist ein Test möglich“; vorher ist der Build gebaut und startklar. Der folgende Text geht als „Was testen“
in den Build (S01 bis S23 bezeichnen die Zeilen oben):

> **Was testen (Abnahme vor der Einladung, #176)**
>
> - S01: Auf der Startseite „+“ tippen, „Brot kaufen“ schreiben, „Fertig“. Die Aufgabe steht in „Neu“.
> - S04: „Morgen Zahnarzt anrufen“ erfassen: fällig morgen. Denselben Satz noch einmal: dieselben Tags und dieselbe Dauer wie beim ersten Mal.
> - S06: Startseite ansehen: Zahl über „Jetzt“, „Neu“, „Fällig“; ein Projekt und einen Tag aufklappen und öffnen.
> - S07: Eine Zeile nach rechts wischen und gleich auf die Zeile tippen: Sie bleibt. Lange drücken, „Parken“: Sie steht unter „Geparkt“.
> - S10: Im Detail „Im Kalender anzeigen“ einschalten. Der Termin steht im Kalender „Loose Ends“, der Schalter bleibt an.
> - S13: Das Widget „Next up“ auf den Home-Bildschirm legen. Es zeigt deine Aufgaben aus „Als nächstes“.
> - S14: Im Kontrollzentrum „Aufgabe erfassen“ antippen und einen Satz sagen. Die Aufgabe steht in „Neu“.
> - S15: Auf dem iPad quer: Seitenleiste links, Startseite rechts. Hochkant: dieselben Bereiche wie auf dem iPhone.
> - S17: Auf dem Mac die Erfassung öffnen und sprechen. Höchstens die Frage nach dem Mikrofon, dann dein Text.
> - S19: Eine Aufgabe erledigen, dann „Cider kaltstellen“ erfassen. Der Titel enthält nichts aus der erledigten Aufgabe.
> - S20: Zahl über „Jetzt“ ablesen und die App verlassen. Das App-Icon zeigt dieselbe Zahl.
> - S21: Auf der Startseite (iPhone, iPad und Mac) in die Zeile unter „Neu“ schreiben, Return. Die Aufgabe steht darüber, du kannst gleich weiterschreiben.
> - S22: Eine Aufgabe mit Unteraufgabe löschen. Die Aufgabe ist weg, die Unteraufgabe steht als eigene Aufgabe da.
> - S23: Auf dem Mac in einer Liste mit den Pfeiltasten eine Zeile wählen, Leertaste: Die Aufgabe ist erledigt.
>
> Was anders aussieht: kurz schreiben, welche Nummer, und ein Bildschirmfoto dazu.

Nach der Rückmeldung wird jede bestätigte Zeile `belegt` mit Ticket und Build; jedes Bildschirmfoto wird geöffnet und in
einem Satz beschrieben, bevor der Haken fällt.
