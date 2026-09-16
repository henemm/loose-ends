# User Story: Nachfolger-App (Arbeitstitel: Capture)

> Erstellt: 2026-09-16
> Status: Approved (Henning, 2026-09-16)
> Produkt: Nachfolger von FocusBlox

## JTBD Statement

**When** mir irgendwo etwas einfällt oder etwas per Mail hereinkommt, das ich erledigen muss,
**I want to** es in einem Satz loswerden, ohne ein Feld auszufüllen, und es später nach dem
Kriterium wiederfinden, das gerade zu meiner Situation passt (im Garten, fünf Minuten Zeit,
wartet schon lange),
**So that** mein Kopf frei ist und ich in jeder Situation das Richtige tun kann, ohne eine
Liste zu pflegen.

## Kontext

### Die Situation

Aufgaben entstehen nicht am Schreibtisch. Sie entstehen beim Spaziergang, an der Kasse, beim
Lesen einer Mail, im Gespräch. In diesem Moment ist Zeit für genau einen Satz. Jedes Feld,
das die App in diesem Moment verlangt (Datum, Liste, Priorität, Tag), kostet die Erfassung.
Also wird sie weggelassen, und die Aufgabe ist weg.

Später, wenn Zeit zum Erledigen ist, ist die Frage nie "was steht auf meiner Liste", sondern
"was passt jetzt": Ich bin im Garten, was kann ich hier tun. Ich habe zehn Minuten, was ist schnell.
Was liegt schon ewig herum. Worauf warte ich. Diese Fragen beantwortet keine manuell gepflegte Liste.

### Das Problem heute

- Apple Erinnerungen versteht Sprache bei der Eingabe, aber danach passiert nichts mehr.
  Keine Dauer, keine Energie, kein Kontext, kein Alter, keine Abhängigkeit.
- Todoist parst bei der Eingabe und bietet Vorschläge, aber in der Cloud, im Abo, ohne Apple-Tiefe.
- Things parst nur Daten und hat keine Intelligenz.
- FocusBlox hat die Attribute, verlangt sie aber vom Nutzer und will planen statt zeigen.
- Alle gemeinsam: Der Nutzer ist Eingabe, Motor und Wartungscrew.

### Alternativen

- Erinnerungen weiter nutzen: Kein Kontext, kein Lernen, keine berechneten Ansichten.
- FocusBlox weiterbauen: Falsches Produkt, siehe Entscheidungslog.
- Notizen-App: Keine Struktur, kein Abhaken, keine Ansichten.

## Dimensionen

### Funktional

- Erfassung in einem Satz über Siri, Watch, Control Center, Teilen-Menü, Mail, Textfeld in der App
- Stille Veredelung genau einmal nach der Erfassung: Titel, Fälligkeit, Wichtigkeit, Dringlichkeit,
  Dauer, Energie, Kontexte, Personen, Projekt, Abhängigkeit
- Lernen aus alten Aufgaben und aus Korrekturen
- Jede KI-Änderung sichtbar an der Aufgabe und pro Feld rückgängig machbar
- Berechnete Ansichten: Als nächstes, Neu, Fällig, Schnell, Alt, Wartet, Wiederkehrend, Geparkt, Erledigt, je Kontext, je Projekt
- Parken aus „Alt“ heraus, Mitteilung am Fälligkeitstag mit drei Aktionen
- Manuelle Sortierung nur in "Als nächstes"
- Projekte als Listen, Unteraufgaben eine Ebene tief
- Einfache Wiederholung
- Rücksprung zur Quell-Mail
- Terminierte Aufgabe optional im Kalender anzeigen

### Emotional

- **Beim Erfassen:** Erleichterung. Gesagt, weg, vergessen dürfen.
- **Beim Öffnen:** Vertrauen. Die App hat verstanden, was ich meinte, und ich sehe, was sie getan hat.
- **Beim Erledigen:** Passung. Was ich sehe, passt zu dem, wo ich bin und wie viel Kraft ich habe.
- **Nicht:** Bevormundung. Die KI entscheidet, aber ich habe das letzte Wort, und das kostet einen Wisch.

### Sozial

- Version 1: rein persönlich.
- Später: Projekte als Listen mit anderen teilen.

## Die Veredelungs-Schleife (Herzstück)

1. Rohtext kommt an. Er bleibt für immer unverändert gespeichert.
2. Die App sucht die ähnlichsten alten Aufgaben und gibt sie dem Modell als Beispiele mit.
3. Das Modell liefert Attribute mit Konfidenz. Unter der Schwelle bleibt ein Feld leer.
4. Ist der Titel unsicher, bleibt die Aufgabe "ungeprüft" und zeigt den Rohtext.
5. Jede gesetzte Eigenschaft wird als Revision protokolliert. Die Aufgabe trägt einen Marker.
6. Der Nutzer tippt den Marker: Vorher und Nachher. Ein Wisch stellt ein Feld zurück.
7. Das Zurückstellen ist eine Korrektur und damit ein Beispiel für die nächste Aufgabe.

## Erfolgskriterien

- [ ] Ich erfasse eine Aufgabe per Siri, Watch oder Control Center in unter fünf Sekunden ohne die App zu sehen
- [ ] "Abrechnung erstellen" bekommt nach drei manuellen Zuordnungen den Kontext "Computer" automatisch
- [ ] Ich sehe an jeder Aufgabe, ob und was die KI verändert hat, und stelle es mit einem Wisch zurück
- [ ] Ich öffne "Garten" und sehe nur, was ich dort tun kann
- [ ] Ich öffne "Schnell" und alles darin dauert unter fünfzehn Minuten
- [ ] Ich öffne "Alt" und erkenne, was ich seit Wochen vor mir herschiebe
- [ ] Blockierte Aufgaben tauchen in "Als nächstes" nicht auf
- [ ] Eine Aufgabe aus einer Mail bringt mich mit einem Tipp zurück zur Mail
- [ ] Die Oberfläche ist auf iPhone und Mac dieselbe Codebasis
- [ ] Die App ist auf Englisch und Deutsch bedienbar

## Abgeleitete Features

| Feature | Priorität | Status |
|---------|-----------|--------|
| Erfassung: Siri via Reminders-App-Schema | Must | Offen |
| Erfassung: Watch mit Diktat | Must | Offen |
| Erfassung: Control Center in Erfassungs-Szene mit sofortigem Mikrofon | Must | Offen |
| Erfassung: Textfeld in der App | Must | Offen |
| Erfassung: Teilen-Menü und Siri aus Mail, Rücksprung | Must | Offen |
| Veredelung mit Retrieval-Beispielen und Konfidenzschwelle | Must | Offen |
| Revisionen, Marker, Rückgängig pro Feld | Must | Offen |
| Ansichten: Als nächstes, Neu, Fällig, Schnell, Alt, Wartet, Kontext | Must | Offen |
| Gesten: Wisch Erledigt, Wisch Als nächstes, Halten-Menü mit Verschieben | Must | Offen |
| Parken und Geparkt-Ansicht | Must | Offen |
| Mitteilung am Fälligkeitstag mit Erledigt, Als nächstes, Morgen | Must | Offen |
| Erledigt-Ansicht mit Zurückholen | Must | Offen |
| Projekte als Listen | Must | Offen |
| Unteraufgaben, eine Ebene | Should | Offen |
| Wiederholung einfach, Ansicht "Wiederkehrend" | Should | Offen |
| Abhängigkeiten erkennen (PCC-Modell) | Should | Offen |
| Kalender anzeigen | Should | Offen |
| FocusBlox-Korpus als Startwissen und Eval-Datensatz | Should | Offen |
| Widgets: Als nächstes | Could | Offen |
| Freie Frage in natürlicher Sprache | Could, Experiment | Offen |

---
*Ermittelt im Briefing-Dialog am 2026-09-16*
