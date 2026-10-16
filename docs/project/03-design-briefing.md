# Design-Briefing für Claude Design

> Erstellt: 2026-09-16
> Status: Bereit für Claude Design
> Voraussetzung: `01-user-story.md` (approved), `02-datenmodell-und-ansichten.md`

Dieses Dokument ist in sich vollständig. Es setzt die anderen Dokumente nicht voraus,
verweist aber auf sie, wo Details stehen.

## Das Produkt in drei Sätzen

Ein Textfeld, das alles annimmt: Aufgabe sagen oder tippen, fertig. Dahinter ein stiller
Sekretär, der jede Eingabe einmal in Struktur übersetzt (Titel, Fälligkeit, Wichtigkeit,
Dringlichkeit, Dauer, Energie, Kontexte, Personen, Projekt, Abhängigkeit) und jede Änderung
sichtbar und rückgängig machbar hält. Vorne wenige berechnete Ansichten, die zur Situation
passen: im Garten, fünf Minuten Zeit, wartet schon lange.

## Design-Leitbild

- Minimalistisch, wenige Farben, iOS-nativ, so nah wie möglich am aktuellen Apple-Paradigma
  (Liquid Glass). Keine Custom-Widgets, keine eigenen Controls, wo ein Systemcontrol existiert.
- Die KI ist unsichtbar, bis sie etwas verändert hat. Dann ist sie ein dezentes Zeichen, kein Banner.
- Nichts ist Pflicht. Kein Formular, kein leeres Feld, das nach Eingabe ruft.
- Die App plant nicht. Sie zeigt. Kein Timer, kein Kalender-Raster, kein Coach.
- SF Symbols, Systemschriften, Dynamic Type, Dark Mode, Englisch und Deutsch (Textlängen).
- Farbbudget (ADR-14): Akzent heißt tippbar, Rot heißt Zeitdruck, Grau trägt Hierarchie, Grün nur beim Erledigen. Jeder Screen muss in Graustufen funktionieren.
- Zeichen sind ausschließlich SF Symbols, als Outline wo es eine gibt (Henning, 2026-10-12, #350). Keine Emojis, keine Schriftzeichen als Symbol, keine eigenen Bilder. Ausgenommen ist nur der Faden aus dem Logo (Knoten, loser Faden, #180): Er ist Marke, kein Bedienzeichen.

## Plattformen

| Plattform | Rolle | Layout |
|-----------|-------|--------|
| iPhone | Primär. Erfassen, Ansichten, Detail. | Ein Navigationsmodell, siehe offene Frage 1 |
| Mac | Gleichwertig, dieselben Views. | NavigationSplitView: Sidebar mit Ansichten, Liste, Detail |
| iPad | Wie Mac. | NavigationSplitView |
| Watch | Nur Erfassung per Sprache. | Ein Screen plus Bestätigung, Complication |
| Widgets | "Als nächstes" lesen, Control für Erfassung. | Small, Medium, Control-Center-Button |

Ein Code für alle: Was auf dem iPhone ein Screen ist, ist auf dem Mac eine Spalte.

## Screens und Flows

### 1. Erfassungs-Szene (Quick Capture)

Der wichtigste Screen. Erreichbar über Control Center, Action Button, App-Button, Mac-Hotkey.

- Öffnet ohne Tab, ohne Ladezustand. Mikrofon hört sofort, Wellenform zeigt es.
- Ein Textfeld, das den erkannten Text live zeigt und tippbar ist.
- Ein Button: Fertig. Kein Datum, keine Liste, keine Priorität, kein Tag.
- Nach Fertig: kurze Bestätigung, Szene schließt. Die Aufgabe erscheint in "Neu".
- Aus Mail (Teilen-Menü): dieselbe Szene, Textfeld vorbefüllt mit Betreff, Mail-Link angeheftet.
- Mac: schwebendes Panel, Hotkey öffnet, Enter sendet, Escape schließt.

### 2. Startscreen: Ansichten

Der Einstieg zeigt die Ansichten, nicht eine Aufgabenliste.

Systemansichten als Kacheln mit Zähler: Als nächstes, Neu, Fällig, Schnell, Alt, Wartet, Wiederkehrend, Geparkt.
Darunter Projekte (mit „Neues Projekt“), dann Kontexte, zuletzt eine Zeile „Erledigt“.
Darunter Kontexte (Startset: Computer, Telefon, Haus, Garten, Unterwegs, Besorgung, alle löschbar)
und Projekte. Erfassungs-Button ist auf jedem Screen an derselben Stelle erreichbar.

**Nachgeschärft (Henning, 2026-10-05):** Der Bildschirm öffnete auf einer Spalte meist leerer
Einträge. Seitdem stehen Als nächstes, Neu und Fällig immer da; Schnell, Alt, Wartet,
Wiederkehrend und Geparkt nur, solange sie eine Aufgabe haben. Projekte und Kontexte sind
einklappbare Gruppen, eingeklappt per Vorgabe; eingeklappt zeigen sie, wie viele es sind.
Anlegen, Umbenennen und Löschen bleiben in der aufgeklappten Gruppe.

**Startbildschirm in Zonen (Henning, 2026-10-12, #368, ersetzt #299):** Auf dem iPhone steht oben eine Eingangsleiste
für „Neu“, nur solange dort etwas wartet. Darunter „Jetzt“: überfällig, heute fällig und vorgemerkt, jede Aufgabe einmal, die
ersten fünf, der Rest hinter „N weitere“. Die Ansichten folgen darunter. Die Zahl am App-Symbol zählt dieselbe Menge. Die
Ansichten „Fällig“ (sieben Tage) und „Als nächstes“ bleiben unverändert.

**Überschrift (Henning, 2026-10-15, #426):** Über „Jetzt“ steht eine große Zeile in New York (30 pt, medium, leicht eng, #433), das Datum klein am Knoten darüber.
Jeden Tag der eine Satz, der auffällt (Regelleiter in `StartHeadline`), ab 16 Uhr ein Rückblick auf das Erledigte, wenn etwas
erledigt ist. Kein Lob, keine Serien, nie ein Satz über Nichterledigtes.

**Inhaltsverzeichnis (Henning, 2026-10-15, #421, ersetzt Chips und Raster aus #368):** Unter „Jetzt“ steht „Inhalt“ wie die erste
Seite eines Notizbuchs: Ansichtsnamen in New York, Punktlinie, Zahl klein in SF, drei Gruppen mit Abstand statt Karten
(Ansichten mit „Schnell“, dann Tags und Projekte, dann Alle offenen und Erledigt). Tags und Projekte mit Aufgaben folgen
ihrer Zeile als Wörter in Akzent, aufrecht mit grauen Kommas wie ein Satz (#433), ein Tipp öffnet die Liste; ein Tipp auf „Etiketten“ oder „Projekte“ öffnet deren
eigene Seite (Henning, 2026-10-15, #428): alle Einträge im selben Stil, auch leere, ein Tipp öffnet die Liste, langes Drücken
benennt um, Wischen löscht nach Rückfrage, unten „Neues Etikett“ bzw. „Neues Projekt“. Auf der Startseite klappt nichts mehr
auf. Bewusste Ausnahme von #180 Regel 2, nur auf diesen Seiten. iPad und Mac behalten die einklappbaren Gruppen der
Seitenleiste. Entwurf: https://claude.ai/artifact/AppBHrhym57SBMURaQck5P

Berechnungsregeln der Ansichten stehen in `02-datenmodell-und-ansichten.md`.

### 3. Ansicht (Aufgabenliste)

Eine Liste. Jede Zeile:

- Titel (oder Rohtext, wenn ungeprüft, dann visuell als Rohtext erkennbar).
- Wichtigkeit und Dringlichkeit erscheinen in der Zeile nur, wenn hoch: als schwarze Glyphen (Fahne, Blitz) am Anfang der Merkmalzeile, ohne Text, ohne Farbe, nie als Emoji. Im Detail als Wörter (Niedrig, Mittel, Hoch). Beide bestimmen außerdem die Sortierung.
- **Randspalte (Henning, 2026-10-15, #424):** Links am Rand steht die eine Zeit, die zählt, wie im Tagebuch: Uhrzeit oder „Heute“ (rot), „Gestern“/„Vor N Tagen“ bei verpasster Uhrzeit (rot), „Seit gestern“ (grau, #414), „Morgen“, Wochentag, Datum, ohne Fälligkeit die Dauer. Kein Kreis vor der Aufgabe; Unteraufgaben ohne Kreis, erledigt mit feinem grauem Haken. Das Datum fällt aus der Merkmalzeile.
- Höchstens drei kleine Merkmale, Rangfolge: Zustand (wartet), Fälligkeit, Dauer, Kontext, Person. In einer Kontext-Ansicht entfällt der Kontext. Der Rest ist im Detail. Eine Zeile ist nie höher als Titel plus eine Merkmalzeile, auch wenn alle Attribute gepflegt sind.
- KI-Marker (Variante C): Merkmale, die die KI gesetzt hat, sind akzentgetönt, bis der Nutzer sie gesehen hat. Ein geänderter Titel trägt zusätzlich den Funken.
- Blockiert-Zeichen, wenn eine andere Aufgabe vorher erledigt werden muss.
- Wisch rechts: Erledigt. Wisch links: Zu "Als nächstes" oder daraus entfernen. In "Alt": Wisch links parkt.
  In "Neu" (dem Eingang) heißt Wisch rechts „Passt“ mit dem Daumen (`hand.thumbsup`; der Haken gehört allein dem Erledigen, #349) und bestätigt nur, was die KI sortiert hat; Erledigt
  gibt es dort nur im Halten-Menü, und „Muss angesehen werden“ hat keinen Wisch (Henning, 2026-10-11, #318).
- Halten: Vorschau plus Menü mit Als nächstes, Erledigt, Verschieben (Morgen, Wochenende, nächste Woche, Datum), Parken, Löschen.
- Nur "Als nächstes" ist manuell sortierbar (Drag). Alle anderen Ansichten haben feste Sortierung.
- Leerzustand je Ansicht in einem Satz, ohne Illustration.

### 4. Aufgaben-Detail

- Oben der Titel, editierbar. Darunter, klein, der Rohtext, nicht editierbar.
- Abgeleitete Felder als kompakte Zeilen: Fälligkeit, Wichtigkeit, Dringlichkeit, Dauer, Energie,
  Kontexte, Projekt, Wiederholung, "Im Kalender anzeigen". (Personen entfielen mit #301.)
- Jedes Feld, das die KI gesetzt hat, trägt ein kleines Zeichen. Tipp darauf: Vorher, Nachher,
  Begründung in einem Satz, Button "Zurücksetzen".
- Leere Felder sind leer, keine Platzhalter, die zur Eingabe drängen.
- Bereich "Blockiert durch": Liste der Aufgaben, die vorher erledigt sein müssen.
- Bereich "Unteraufgaben": eine Ebene, abhakbar, per Textfeld ergänzbar (siehe offene Frage 3).
- Bereich "Quelle": Link zurück zur Mail, wenn vorhanden.
- Tipp auf ein getöntes Merkmal: Popover mit Vorher, Nachher, Begründung, „Zurücksetzen“ (Wert vor der KI) und „Ändern“ (Picker). Beides ist eine Korrektur.
- „Anzeigen“ neben „n Felder von der KI gesetzt“ öffnet das Änderungen-Sheet (Screen 5) mit allen Einträgen und „Alle zurücksetzen“.
- Menü hinter „…“: Änderungen anzeigen, Neu analysieren, Als nächstes, Parken, Löschen (rot, mit Rückfrage, nicht rückgängig). „Neu analysieren“ ist die einzige zweite Verarbeitung und deshalb versteckt.

**Aus „Neu“ geöffnet (Henning, 2026-10-12, #349).** Der Haken oben rechts erledigt, liest sich in
einer Prüfansicht aber als „OK“. Deshalb steht dort, aus „Neu“ geöffnet, das Wort „Passt“ (Akzent,
hervorgehoben), und „Erledigt“ steht im Menü „…“. Unter dem Titel sagt eine Zeile, warum die Aufgabe
in „Neu“ ist: was umformuliert oder gesetzt wurde, „Titel nicht geprüft“ oder „Noch nicht sortiert“.
Öffnen allein bestätigt dort nichts; „Passt“ markiert die Änderungen als gesehen, nimmt einen
ungeprüften Titel an und führt zurück in die Liste. Eine unsortierte Aufgabe hat kein „Passt“, sie
verlässt „Neu“, sobald sie sortiert ist. Aus jeder anderen Ansicht gilt Öffnen weiter als gesehen.
Konzept mit Mockups: https://claude.ai/artifact/259uebtk5zCWHEzSydAjco

**Kein Haken in der Leiste (Henning, 2026-10-15, #435).** Auch außerhalb von „Neu“ liest sich der Haken oben rechts als
„Fertig, schließen“ und erledigte Aufgaben aus Versehen. Die Leiste zeigt nur „…“ (aus „Neu“ dazu „Passt“); „Erledigen“
ist der erste Eintrag im Menü „…“. Verlassen wird die Detailansicht über „Zurück“.

**Register statt Formular (Henning, 2026-10-15, #438, Epic #437).** Die Detailansicht folgt der Startseite: Titel in New York
medium, darunter der gesagte Satz als ein durchlaufender Satz hinter einem kleinen „GESAGT“. Felder als Registerzeilen:
Name klein in SF grau in fester Spalte, Wert in New York (Inhalt), kein Pfeil, die ganze Zeile öffnet den Editor. Fälligkeit in
Worten („Heute, 14:30“), rot bei Zeitdruck wie die Randspalte. Abschnittsköpfe wie die Zonenköpfe der Startseite.
Entwurf: https://claude.ai/artifact/HD818Gm9YorDsjN7uFy9z5

**Wortleiste und Schnellwahl (Henning, 2026-10-15, #440).** Leere Felder stehen unter den gesetzten als eine Zeile Wörter
in Akzent („+ Fällig  + Wichtigkeit  + Projekt …“); ein Tipp öffnet den Editor, „Detail hinzufügen“ entfällt. Der Editor der
Fälligkeit beginnt mit Schnellwahl: Heute, Morgen, Wochenende, Nächste Woche, dann Ohne Uhrzeit, 9, 12, 15, 18 Uhr; die
Uhrzeit schließt den Editor. „Morgen 15 Uhr“ braucht drei Griffe statt sechs. Schalter und Rad bleiben für alles andere.

### 5. Revisions-Sheet

Vom KI-Marker aus: Liste aller Änderungen an dieser Aufgabe, neueste oben.
Je Eintrag: Feld, alt, neu, wer (KI oder Nutzer), wann, Begründung. Je Eintrag "Zurücksetzen".
Nach dem Öffnen gilt der Marker als gesehen.

### 6. Projekt-Ansicht

Projekte sind Listen und später die Einheit fürs Teilen. Zeigt Aufgaben des Projekts,
optional manuell sortiert, mit Unteraufgaben eingerückt oder eingeklappt.
Hier entscheidet sich, ob Hierarchie gut aussieht (offene Frage 3).
**Entschieden (Henning, 2026-10-05, #28):** eingeklappt. Eine Aufgabe mit Unteraufgaben trägt vorn
einen Pfeil und in der Merkmalzeile ihren Fortschritt („2/5“); der Pfeil klappt die Unteraufgaben
eingerückt darunter auf, ein Tipp hakt eine ab wie im Detail.

### 7. Kontexte und Projekte verwalten

Eine Liste zum Umbenennen, Löschen, Neuanlegen. Keine Farben, keine Icons je Kontext in Version 1.

### 8. Watch

Ein Screen: Mikrofon-Button, Diktat, Bestätigung. Complication öffnet direkt das Diktat.
Kein Lesen, kein Abhaken in Version 1.

### 9. Widgets und Control

- Small: die oberste Aufgabe aus "Als nächstes".
- Medium: die obersten drei.
- Control Center: ein Button, der die Erfassungs-Szene öffnet.

### 10. Mitteilung

Eine Art: „Heute fällig“ am Fälligkeitstag. Halten zeigt drei Aktionen, keine öffnet die App:
Erledigt, Als nächstes, Morgen.

### 11. Ansichten Alt, Geparkt, Erledigt

„Alt“ zeigt das Alter je Zeile und wie oft verschoben, Wisch links parkt. „Geparkt“ ist die einzige
Ansicht, die geparkte Aufgaben zeigt, Wisch rechts aktiviert. „Erledigt“ ist nach Tagen gruppiert,
Wisch rechts holt zurück.

### 12. Onboarding

Drei Schritte, überspringbar: Siri-Zugriff, Mitteilungen, Startset der Kontexte ansehen.
Hinweis, wenn Apple Intelligence auf dem Gerät nicht verfügbar ist (dann gibt es keine Veredelung).

## Zustände, die das Design zeigen muss

| Zustand | Bedeutung | Sichtbar durch |
|---------|-----------|----------------|
| Ungeprüft | KI war sich beim Titel nicht sicher | Rohtext-Optik, in "Neu" |
| Unverarbeitet | Veredelung steht noch aus (offline, Modell nicht verfügbar) | Dezenter Hinweis, in "Neu" |
| KI hat geändert | Ungesehene KI-Revisionen | Marker an der Zeile und am Feld |
| Blockiert | Wartet auf andere Aufgabe | Zeichen an der Zeile, ausgeblendet in "Als nächstes" |
| Geparkt | Bewusst beiseitegelegt | Nur in "Geparkt" sichtbar |
| Überfällig | Fälligkeit mit Uhrzeit vorbei | Datum in Rot, der einzige Rotton |
| Weitergetragen | Fälligkeit ohne Uhrzeit, Tag vorbei (#414) | Grau „Seit gestern“ / „Seit N Tagen“ statt Datum |
| Wiederkehrend | Rückt nach Erledigung weiter | Zeichen an der Zeile, Ansicht "Wiederkehrend" |
| Aus Mail | Hat Quell-Link | Zeichen im Detail |

**Etiketten statt Kontexte (Henning, 2026-10-15, #420).** Sichtbar heißt ein Kontext überall „Etikett“ (englisch „Tag“), mit dem
Etikett-Zeichen (`tag`) in Zeile, Detail und Startseite. Nicht „Tag“ im Deutschen: das liest sich als Kalendertag („Diesen Tag löschen?“). Im Code und im Datenmodell bleibt `TaskContext`.

## Tonalität

Ruhig, knapp, vertrauensvoll. Die App erklärt sich nicht, sie zeigt.
Texte in Englisch (Basis) und Deutsch. Keine Ausrufezeichen, keine Gamification, keine Motivationssprüche.

## Nicht gestalten

Timer, Fokusmodus, Kalender-Raster, Tagesplanung, Charts, Coach, Standortkarten (ein Ort wird über die
Suche gewählt, ohne Karte, #226),
Sharing-Flows, freie Suche in natürlicher Sprache.

## Offene Fragen an Claude Design

1. **Navigationsmodell iPhone.** Startscreen mit Ansichten wie in Erinnerungen, oder Tab-Leiste
   mit drei Tabs (Ansichten, Als nächstes, Erfassen)? Welche Variante hält die Erfassung am kürzesten?
2. **KI-Marker.** Wie sieht ein Zeichen aus, das man bemerkt, aber das nicht drängt, und das
   in der Zeile und am einzelnen Feld funktioniert?
3. **Hierarchie.** Wie zeigen wir Unteraufgaben und Projekte so, dass es eine Ebene bleibt,
   aber sich nicht nach Checkliste anfühlt? Das war die Bedingung des PO für Hierarchie überhaupt.
   **Beantwortet (2026-10-05, #28):** eingeklappt, per Pfeil aufklappbar — siehe Screen 6.
4. **Ungeprüft.** Wie unterscheidet sich Rohtext von Titel, ohne dass die Zeile hässlich wird?
5. **Mac.** Reicht NavigationSplitView mit Sidebar, oder braucht die Erfassung ein eigenes Panel-Design?

## Technischer Rahmen für das Design

- SwiftUI, ein Multiplattform-Target. Alles, was gezeichnet wird, muss mit Systemkomponenten gehen.
- Accessibility-Identifier folgen dem Muster `camelCaseButton`, `taskRow_<uuid>`, `contextTile_<uuid>`.
- Dynamic Type bis XXL, VoiceOver für alle Aktionen inklusive Zurücksetzen.
- Deployment Target iOS 27, macOS 27, watchOS 27. Apple Intelligence ab iPhone 15 Pro.

**Anhänge (Henning, 2026-10-15, #442).** Unter der Notiz ein Abschnitt „Anhänge“: Fotos und Dateien anhängen, Tipp zeigt sie (Quick Look), Wischen löscht nach Rückfrage, höchstens 50 MB je Anhang. „Scan“ (iPhone und iPad) öffnet die Dokumentkamera des Systems: mehrere Seiten werden ein PDF (JPEG, 150 dpi). Das Teilen-Menü folgt.
