---
entity_id: feat-601-schreibzeile
type: feature
created: 2026-10-21
updated: 2026-10-21
status: approved
workflow: feat-601-schreibzeile
---

# Spec: #601 Schreibzeile unter „Neu“, die Schublade

## Approval

- [x] Approved (Henning, 2026-10-21, AskUserQuestion und Chat): Form 2 „Schublade“, „Setze es sorgsam in maximaler Ästhetik
  um. Verwende viel Sorgfalt beim Finden der richtigen Animation.“ Entwurf: https://claude.ai/artifact/R8C6iLGAHXHrMqBvuyU6Zs

## Purpose

Henning: „Ich möchte auf iOS, iPadOS und macOS auf der Startseite einen Eingabeschlitz haben, in den man ganz natürlich
Aufgaben eingeben kann. Per Enter wird die Aufgabe abgeschickt, erscheint darüber, und man kann die nächste eingeben.“
Und: „Nach einer Pause muss alles in Neu liegen und die Startseite wieder clean sein; dem User muss klar sein, dass es
nicht verschwunden, sondern in Neu ist. Solange es nicht in Neu ist, darf Neu es nicht zählen.“

**Rein regelbasiert.** Return speichert über `CaptureService` wie das Blatt; die Regeln lesen den Satz im Nachholpass
(`ContentView` stößt ihn bei jeder neuen Aufgabe an); das Modell wie bisher. Beim Tippen wird nichts erkannt.

## Entscheidungen (Henning, 2026-10-21)

| Frage | Entscheidung |
|---|---|
| Ort | Direkt unter dem Knopf „Neu“ („N zu prüfen“), über „Jetzt“; iPhone, iPad und Mac gleich. Kein Kasten, kein Mikrofon. |
| Wann wird es Aufgabe | Mit Return, sofort. Darum zählt die Zahl sofort und ehrlich, und die Zeile zeigt das Sortierte („Fr.“ am Rand). |
| Darüber erscheinen | Der Knopf klappt beim ersten Return zur Schublade auf: Kopf mit Zahl, darunter die Zeilen dieser Sitzung (älteste oben), die Schreibzeile als letzte Zeile. Cursor bleibt. |
| Aufhören | Tastatur weg, Tipp auf den Satz des Tages, Escape (Mac), Seitenwechsel, Hintergrund: die Schublade faltet sich in den Knopf. Kein Timer, kein Entwurf. |
| Korrektur | Tipp auf eine Zeile öffnet das Detail (kein Editieren in der Zeile). |
| Verworfen | Form 1 „Tablett“ (Entwürfe mit Timer), Schreibleiste unten, Eingang als Liste; „Zuletzt erfasst“ rechts auf dem Mac entfällt. |

## Bewegung

Eine weiche Kurve, 0,4 s, keine Feder (`.smooth`): Papier, kein Gummi. Aufklappen: die Tönung des Knopfs geht in den
Körper über (Knopf 12 % → Körper 6 %), der Pfeil dreht nach unten, die neue Zeile steigt von der Schreibzeile in ihren
Platz. Die Zahl wechselt als Ziffer (`numericText`), der Rand leuchtet 0,8 s in Akzent. Zuklappen: die Zeilen gleiten
nach oben unter den Kopf, die Tönung zieht sich in den Knopf zurück. Reduzierte Bewegung: nur Überblenden, 0,2 s.
VoiceOver: „In Neu abgelegt: <Titel>“.

## Source

| Datei | Änderung |
|---|---|
| `Shared/Models/InboxDrawer.swift` | NEU: reine Logik, `didCapture`, `close`, `rows(in:)` |
| `LooseEnds/Views/InboxDrawerView.swift` | NEU: eine Zeile der Startliste: Kopf, Zeilen, Schreibzeile, Bewegung, Fokus, Aufhören |
| `LooseEnds/Views/StartPage.swift` | Schublade statt Kastenfeld; ⌘N setzt den Cursor in die Zeile |
| `LooseEnds/Views/SidebarView.swift` | iPhone: Schublade unter dem Satz des Tages; Tipp auf den Satz beendet die Eingabe; Scrollen legt die Tastatur weg |
| `LooseEnds/Views/StartZones.swift` | `InboxBar` entfällt (der Kopf der Schublade) |
| `LooseEnds/Views/SideColumnView.swift`, `Shared/Models/SideColumn.swift` | „Zuletzt erfasst“ entfällt |
| `LooseEndsTests/InboxDrawerTests.swift` | NEU: Return zählt sofort, Reihenfolge, Zuklappen beendet die Sitzung, Erledigtes und Gelöschtes verlassen die Schublade |
| `LooseEndsUITests/InboxDrawerSmokeTests.swift`, `MacDetailClickTests.swift` | iPhone: Return öffnet, Tipp daneben faltet; Mac: Return öffnet, Cursor bleibt, Escape faltet |

## Acceptance

- **AC-1:** Return in der Zeile legt eine Aufgabe an (Rohtext wie getippt), leert die Zeile, behält den Cursor; die Zahl in „Neu“ zählt sie sofort.
- **AC-2:** Beim ersten Return klappt der Knopf zur Schublade auf; jede weitere Zeile erscheint unter der vorigen, über der Schreibzeile; die Zeile zeigt Titel per Regel, Datum am Rand.
- **AC-3:** Tastatur weg, Tipp auf den Satz des Tages, Escape, Seitenwechsel oder Hintergrund faltet die Schublade; die Zahl bleibt; die Aufgaben stehen in „Neu“.
- **AC-4:** Ein leeres Return tut nichts. Ein Tipp auf eine Zeile öffnet ihr Detail.
- **AC-5:** Reduzierte Bewegung: keine Verschiebung, nur Überblenden. VoiceOver meldet die Ablage.
- Kein Pfad der Geräteliste berührt.
