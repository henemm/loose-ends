# Treue von Datum und Titel (Issue #67)

| | |
|---|---|
| Gerät | iPhone17,1, iOS 27.0 |
| Messtage | 2026-09-20, 2026-09-25 |
| Korpus | 319 Sätze; ausgewertet: 139 mit Datum, 172 ohne Datum als Kontrolle |
| Fehlversuche | 23, davon gedrosselt: 11 |
| Sekunden je Satz | 8.8 |

Gemessen hat die Labor-App auf dem iPhone, in Scheiben über mehrere Sitzungen. Jeder Satz
wird gegen den Tag ausgewertet, an dem er gemessen wurde; mehrdeutige Formulierungen
(„am Wochenende", „nächsten Freitag") lassen mehrere Tage gelten. Der Regelparser rechnet
gegen den festen Bezugstag Do 12.03.2026 (Europe/Berlin), damit der Bericht an jedem Tag
gleich ausfällt (#99, #148); bis dahin rechnete er gegen den Tag des Laufs, daher die
anderen Daten unter „Was danebenging“. `NSDataDetector` ist die deterministische
Alternative aus dem Issue, auf denselben Sätzen.

## Datum

| Messung | Modell | NSDataDetector | Regelparser |
|---|---|---|---|
| Exakt getroffen | 49.6 % von 139 | 67.6 % von 139 | 99.3 % von 139 |
| Feld leer gelassen statt geraten | 2 | 41 | 1 |
| Erfundene Daten bei Sätzen ohne Datum | 95.3 % von 172 | 0.0 % von 172 | 0.0 % von 172 |

`NSDataDetector` rechnet immer gegen die echte Uhr und lässt sich auf keinen Bezugstag festlegen; je nach Wochentag des Laufs traf er 65.5 % bis 68.3 %. Die Spalte ist der eingefrorene Stand vom 2026-09-25 und wird nicht neu berechnet (#148).

### Nach Art des Ausdrucks

| Ausdruck | Sätze | Modell exakt | Leer gelassen | Regelparser exakt |
|---|---|---|---|---|
| Wochenende | 8 | 0.0 % | 0 | 100.0 % |
| nächste Woche <Tag> | 7 | 0.0 % | 0 | 100.0 % |
| Wochentag | 27 | 18.5 % | 0 | 96.3 % |
| bis zum N. | 9 | 22.2 % | 0 | 100.0 % |
| nächster <Tag> | 9 | 22.2 % | 0 | 100.0 % |
| festes Datum | 6 | 33.3 % | 0 | 100.0 % |
| in N Tagen / morgen | 56 | 76.8 % | 2 | 100.0 % |
| Monatsende | 11 | 81.8 % | 0 | 100.0 % |
| nächster Monat | 6 | 100.0 % | 0 | 100.0 % |

**Uhrzeit:** 57.1 % exakt bei 21 Sätzen mit Uhrzeit.

**Uhrzeit Regelparser:** 100.0 % exakt bei 24 Sätzen mit Uhrzeit.

## Nach Bedingung gemessen

| Bedingung | Sätze mit Datum | Exakt |
|---|---|---|
| hintergrund, akku | 1 | 100.0 % |
| hintergrund, akku, fair | 2 | 50.0 % |
| inaktiv, akku | 2 | 100.0 % |
| vordergrund, akku | 20 | 30.0 % |
| vordergrund, akku, fair | 30 | 56.7 % |
| vordergrund, akku, serious | 10 | 60.0 % |
| vordergrund, strom | 2 | 50.0 % |
| vordergrund, strom, fair | 22 | 54.5 % |
| vordergrund, strom, serious | 50 | 46.0 % |

Laufen die Zeilen auseinander, hängt die Qualität an Vordergrund, Strom oder Wärme — dann gilt die Gesamtzahl oben nicht.

## Nach Bauform

| Bauform | Sätze | Datum exakt | Datum erfunden | Titel ohne erfundene Fakten | Regel: Datum exakt | Regel: Datum erfunden | Regel: Titel |
|---|---|---|---|---|---|---|---|
| standard | 188 | 47.1 % von 102 | 95.3 % von 86 | 100.0 % | 100.0 % von 102 | 0.0 % von 86 | 100.0 % |
| stichwort | 12 | 50.0 % von 2 | 100.0 % von 10 | 100.0 % | 100.0 % von 2 | 0.0 % von 10 | 100.0 % |
| ich-satz | 11 | 33.3 % von 3 | 100.0 % von 8 | 100.0 % | 100.0 % von 3 | 0.0 % von 8 | 100.0 % |
| nebensatz | 11 | 100.0 % von 3 | 87.5 % von 8 | 100.0 % | 100.0 % von 3 | 0.0 % von 8 | 100.0 % |
| frage | 11 | 0.0 % von 1 | 90.0 % von 10 | 100.0 % | 100.0 % von 1 | 0.0 % von 10 | 100.0 % |
| diktat | 12 | 60.0 % von 5 | 100.0 % von 7 | 91.7 % | 100.0 % von 5 | 0.0 % von 7 | 100.0 % |
| zeit-hinten | 11 | 54.5 % von 11 | – | 100.0 % | 100.0 % von 11 | – | 100.0 % |
| zwei-aufgaben | 11 | 50.0 % von 2 | 100.0 % von 9 | 100.0 % | 100.0 % von 2 | 0.0 % von 9 | 100.0 % |
| denglisch | 11 | 50.0 % von 2 | 88.9 % von 9 | 100.0 % | 100.0 % von 2 | 0.0 % von 9 | 100.0 % |
| tippfehler | 11 | 50.0 % von 2 | 88.9 % von 9 | 100.0 % | 50.0 % von 2 | 0.0 % von 9 | 100.0 % |
| praefix | 11 | 75.0 % von 4 | 100.0 % von 7 | 100.0 % | 100.0 % von 4 | 0.0 % von 7 | 100.0 % |
| diktat-name | 11 | 50.0 % von 2 | 100.0 % von 9 | 100.0 % | 100.0 % von 2 | 0.0 % von 9 | 100.0 % |

„standard“ ist die Form der ersten 203 Sätze (Zeitangabe, Objekt, Verb); die übrigen sind Hennings Formen aus seinen FocusBlox-Rohsätzen.

## Gewichtet nach Hennings Verteilung

Gewichte: Angabe Henning, nicht nachgezählt (Angabe Henning aus 108 FocusBlox-Rohsätzen, nicht nachgezählt). Gewichtet wird je Kriterium über zwei Gruppen, nie über die zwölf Bauformen und nie über Kreuzzellen; ist eine Gruppe leer, entfällt die Gesamtzahl.

- **Stichwort:** 1/3 der Sätze. Titel = 1/3 × Anteil(Bauform stichwort) + 2/3 × Anteil(alle übrigen Bauformen zusammen).
  Zählung an 287 FocusBlox-Titeln, Stand 2026-10-24: 73.5 % mit höchstens 3 Wörtern (Titel, keine Rohsätze; Zählskript nicht im Repo, Zahlen nicht nachzählbar).
- **Zeitangabe:** 12 % der Sätze. Datum = 0,12 × Anteil(Datum exakt, Sätze mit Datum) + 0,88 × Anteil(kein Datum erfunden, Sätze ohne Datum).
  Zählung an 287 FocusBlox-Titeln, Stand 2026-10-24: 0.3 % mit Zeitangabe über den Regelparser, 1 von 287 (Titel, keine Rohsätze; Zählskript nicht im Repo, Zahlen nicht nachzählbar). Titel enthalten Zeitangaben kaum, die Zahl ist deshalb keine Gegenprobe der 12 % der Rohsätze.

| Kriterium | Modell | Regel |
|---|---|---|
| Titel ohne erfundene Fakten | 99.8 % | 100.0 % |
| Datum richtig behandelt | 10.0 % | 99.9 % |

| Gruppe | Gewicht | Modell | Regel |
|---|---|---|---|
| Titel: Bauform stichwort | 0.33 | 12 von 12 | 12 von 12 |
| Titel: alle übrigen Bauformen | 0.67 | 298 von 299 | 307 von 307 |
| Datum: Sätze mit Datum (exakt) | 0.12 | 69 von 139 | 138 von 139 |
| Datum: Sätze ohne Datum (kein Datum erfunden) | 0.88 | 8 von 172 | 172 von 172 |

| Bauform | Gewicht |
|---|---|
| stichwort | 1/3 (Angabe Henning, nicht nachgezählt) |
| standard | kein Gewicht |
| ich-satz | kein Gewicht |
| nebensatz | kein Gewicht |
| frage | kein Gewicht |
| diktat | kein Gewicht |
| zeit-hinten | kein Gewicht |
| zwei-aufgaben | kein Gewicht |
| denglisch | kein Gewicht |
| tippfehler | kein Gewicht |
| praefix | kein Gewicht |
| diktat-name | kein Gewicht |

Die Formen ohne Gewicht zählen beim Titel zusammen als „alle übrigen Bauformen“ (2/3). Für das Datum zählt das Merkmal Zeitangabe, keine Bauform.

Fußnoten:
- Die Titel-Regel misst alle Sätze des Korpus (307 plus 12), das Modell ohne die 8 Wiederholungssätze (299 plus 12); die Zahlen von Modell und Regel sind nicht aus denselben Sätzen gebildet.
- In „Nach Bauform“ ist „Datum erfunden“ die Erfindungsquote (kleiner ist besser); hier zählt „kein Datum erfunden“ die Treffer (größer ist besser).

## Titel

| Messung | Anteil |
|---|---|
| Entitäten aus dem Rohtext erhalten (404 geprüft) | 84.7 % |
| Titel ohne erfundene Fakten (Zahlen, verdrehte Namen) | 99.7 % von 311 |
| Titel ganz ohne Fremdwörter | 62.7 % |

Erfundene Fakten sind das Abbruchkriterium. Fremdwörter zeigen nur, wie stark das Modell
umformuliert; umformulieren ist erlaubt, solange nichts erfunden wird.

## Abbruchkriterien aus #67

| Kriterium | Grenze | Gemessen | Ergebnis |
|---|---|---|---|
| Datum exakt | ≥ 95 % | 49.6 % | **gerissen** |
| Erfundene Daten | ≤ 2 % | 95.3 % | **gerissen** |
| Titel mit erfundenen Fakten | ≤ 2 % | 0.3 % | gehalten |

## Was danebenging

### Falsches Datum (70)

- `Übermorgen das Auto in die Werkstatt bringen` → 2026-09-21 statt 2026-09-22
- `Übermorgen um 9 Uhr die Zählerstände durchgeben` → 2026-09-21 statt 2026-09-22
- `Am Montag die Bewerbung abschicken` → 2026-09-24 statt 2026-09-21
- `Am Mittwoch Blumen für Andrea besorgen` → 2026-09-24 statt 2026-09-23
- `Donnerstag die Fahrräder zum Service bringen` → 2026-09-21 statt 2026-09-24
- `Am Freitag den Bericht an die Geschäftsführung geben` → 2026-09-22 statt 2026-09-25
- `Samstag den Keller aufräumen` → 2026-09-23 statt 2026-09-26
- `Am Sonntag den Braten für 6 Personen vorbereiten` → 2026-09-21 statt 2026-09-20
- `Freitag um 15:30 Rückruf bei Dr. Behrens` → 2026-09-22 statt 2026-09-25
- `Nächsten Montag die Reifen wechseln lassen` → 2026-09-24 statt 2026-09-21
- `Nächsten Mittwoch den Antrag bei der Stadt einreichen` → 2026-09-24 statt 2026-09-23
- `Nächsten Freitag den Zuschuss beantragen` → 2026-09-29 statt 2026-09-25
- `Nächste Woche Freitag die Steuererklärung einreichen` → 2026-09-22 statt 2026-09-25
- `Nächste Woche Dienstag den Kundentermin bestätigen` → 2026-09-26 statt 2026-09-22
- `Nächste Woche Montag den Urlaubsantrag stellen` → 2026-09-25 statt 2026-09-21
- `Nächste Woche Mittwoch die Tickets für Hamburg buchen` → 2026-09-21 statt 2026-09-23
- `Kommenden Freitag die Tonne an die Straße stellen` → 2026-09-22 statt 2026-09-25
- `In 14 Tagen den Termin beim Amt bestätigen` → 2026-09-30 statt 2026-10-04
- `In 21 Tagen läuft die Garantie ab, Beleg suchen` → 2026-09-20 statt 2026-10-11
- `In vier Wochen den Vertrag kündigen` → 2026-09-20 statt 2026-10-18
- `Bis zum 3. den Vertrag kündigen` → 2026-09-23 statt 2026-10-03
- `Bis zum 15. die Unterlagen einreichen` → 2026-09-15 statt 2026-10-15
- `Bis zum 8. die Zählerkarte abgeben` → 2026-09-28 statt 2026-10-08
- `Am Wochenende die Garage aufräumen` → 2026-09-22 statt 2026-09-20
- `Am Wochenende die Fotos von Kreta sortieren` → 2026-09-23 statt 2026-09-20

### Datum erfunden (164)

- `Die Glühbirne im Flur wechseln` → 2026-09-21
- `Rückruf bei der Werkstatt wegen des Kostenvoranschlags` → 2026-09-20
- `Neue Filter für den Staubsauger bestellen` → 2026-09-20
- `Mit Andrea über den Umzug sprechen` → 2026-09-20
- `Den Gartenschlauch reparieren` → 2026-09-20
- `Dringend die Festplatte sichern` → 2026-09-21
- `So schnell wie möglich das Passwort ändern` → 2026-09-20
- `Irgendwann den Dachboden entrümpeln` → 2026-09-20
- `Bald mal wieder die Bremsen prüfen lassen` → 2026-09-20
- `Idee: einen Wasserfilter für die Küche anschaffen` → 2026-09-21
- `Rezept für Linsensuppe von Oma aufschreiben` → 2026-09-20
- `Das Regal im Arbeitszimmer anbohren` → 2026-09-20
- `Preise für eine neue Waschmaschine vergleichen` → 2026-09-20
- `Den Ölstand im Auto kontrollieren` → 2026-09-20
- `Fahrradschloss ersetzen, der Schlüssel klemmt` → 2026-09-20
- `Frau Kowalski wegen der Nebenkosten anschreiben` → 2026-09-25
- `Die Steuerbescheide der letzten Jahre sortieren` → 2026-09-20
- `Einen Platz im Fitnessstudio anfragen` → 2026-09-20
- `Notiz: der Drucker zieht kein Papier ein` → 2026-09-20
- `Die Nachbarn wegen des Zauns ansprechen` → 2026-09-20
- `Ein Geschenk für Svens Geburtstag überlegen` → 2026-09-20
- `Die Fotos vom Handy auf die Festplatte kopieren` → 2026-09-20
- `Bei der VHS nach einem Spanischkurs fragen` → 2026-09-21
- `Den Rasenmäher zur Reparatur geben` → 2026-09-20
- `Wasserhahn im Bad tropft, Dichtung kaufen` → 2026-09-20

### Falsche Uhrzeit (9)

- `Morgen früh um 7:30 den Hund zum Tierarzt` → – statt 07:30
- `Übermorgen um 9 Uhr die Zählerstände durchgeben` → – statt 09:00
- `Freitag um 15:30 Rückruf bei Dr. Behrens` → – statt 15:30
- `Heute um halb zwölf beim Arzt anrufen` → 12:00 statt 11:30
- `Montag 9 Uhr Teamrunde vorbereiten` → – statt 09:00
- `Morgen Mittag um 12 die Bestellung für 3 Kisten Wasser aufgeben` → – statt 12:00
- `Morgen 18:45 die Kinder vom Training abholen` → – statt 18:45
- `also morgen um halb acht die kinder zur schule bringen` → – statt 07:30
- `Morgen das Standup auf 10 Uhr verschieben` → – statt 10:00

### Regelparser danebenging (1)

- `Am Freitga den Zählerstand melden` → – statt 2026-03-13 · Wochentag

### Entität verloren (62)

- `Morgen um 14 Uhr Rückruf bei der Sparkasse` → „Rückruf um 14 Uhr“ ohne Sparkasse
- `Am Dienstag um 8 Uhr das Angebot verschicken` → „Versenden um 8 Uhr“ ohne Angebot
- `Am 20. den Beitrag überweisen` → „Überweisung am 20. stellen“ ohne Beitrag
- `Neue Filter für den Staubsauger bestellen` → „Neue Filter bestellen“ ohne Staubsauger
- `Den Ölstand im Auto kontrollieren` → „Ölstand überprüfen“ ohne Auto
- `Fahrradschloss ersetzen, der Schlüssel klemmt` → „Schlüssel reparieren“ ohne Fahrradschloss
- `Frau Kowalski wegen der Nebenkosten anschreiben` → „Frau Kowalski um Kosten bitten“ ohne Nebenkosten
- `Notiz: der Drucker zieht kein Papier ein` → „Papier einheften“ ohne Drucker
- `Die Nachbarn wegen des Zauns ansprechen` → „Nachbarn um Spionieren bitten“ ohne Zauns
- `Bei der VHS nach einem Spanischkurs fragen` → „Nach Spanischkurs fragen“ ohne VHS
- `Wasserhahn im Bad tropft, Dichtung kaufen` → „Dichtung kaufen“ ohne Wasserhahn
- `Order new filters for the vacuum cleaner` → „Order new filters vacuum“ ohne vacuum cleaner
- `Talk to Miriam about the move` → „Talk to Miriam“ ohne move
- `Mit Herrn Özdemir den Liefertermin klären` → „Mit Herrn Özdemir Termin vereinbaren“ ohne Liefertermin
- `Mit Herrn Bloch über die Kündigung reden` → „Mit Herrn Bloch sprechen“ ohne Kündigung
- `Rechnung 4711 bei der Buchhaltung reklamieren` → „Rechnung 4711 reklamieren“ ohne Buchhaltung
- `3 Kisten Mineralwasser bestellen` → „3 Kisten bestellen“ ohne Mineralwasser
- `1,5 Liter Farbe für das Treppenhaus kaufen` → „Farbe für das Treppenhaus kaufen“ ohne 1,5
- `Zwei Tickets für Gleis 9 umbuchen` → „Zwei Tickets umbuchen“ ohne 9
- `Die Police 30021988 auf die neue Adresse ändern` → „Adresse bei Polizei 30021988 ändern“ ohne Police
- `Termin bei Fielmann für neue Gläser` → „Termin bei Fielmann vereinbaren“ ohne Gläser
- `Ersatzteil bei Miele nachbestellen` → „Nachteil bei Miele bestellen“ ohne Ersatzteil
- `Bei der AOK die Bescheinigung anfordern` → „Bescheinigung anfordern“ ohne AOK
- `Die Fahrkarte für die Deutsche Bahn stornieren` → „Bahn-Ticket stornieren“ ohne Fahrkarte
- `Remind Tom about the parking permit` → „Tell Tom about permit“ ohne parking permit

### Fakt erfunden (1)

- `kundennummer äh acht acht drei vier zwei notieren` → „Kundennummer 88342 notieren“ erfindet 88342