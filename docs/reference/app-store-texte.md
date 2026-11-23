# App-Store-Texte

Texte der App-Store-Version in App Store Connect, je Sprache ein Abschnitt (#842 Schnitt 3). `scripts/asc_version_texts.py
texte` schreibt sie über den Handlauf `asc-version-texts`, nur in die eine Version je Plattform im Zustand
PREPARE_FOR_SUBMISSION, nur bei Abweichung und nur für die Sprachen dieser Datei. Die Beschreibung steht zwischen zwei
Zeilen mit drei Backticks; Grenzen: Beschreibung 4000 Zeichen, Werbetext 170 Zeichen, Schlüsselwörter 100 Zeichen ohne
Leerzeichen nach Kommas, Neu in dieser Version 4000 Zeichen. Seit #984 (Wortlaut für 1.0.2, von Henning freigegeben am
2026-11-23) stehen beide Sprachen vollständig hier, auch Beschreibung, Schlüsselwörter und Support-URL von `de-DE`; die
Werte von `de-DE`, die sich nicht ändern, sind wortgleich aus der veröffentlichten Version 1.0.1 übernommen.

**Gestaltung ist mindestens gleichrangig zur Funktion** (Henning, 2026-11-23, #984: „‚Ästhetisch‘ ist mir sehr wichtig bei
der Entwicklung der App gewesen … die Ästhetik ist mindestens genauso wichtig.“). Jede Fassung dieser Texte und der
Produktseite auf henemm.com nennt die Gestaltung früh und eigenständig (Werbetext, Einleitung, eigener Abschnitt), konkret
an dem, was die App ausmacht (Papier, Randspalte, Farbbudget, Knoten), nie als Floskel. Fremde Marken (Claude) stehen nie in
den Schlüsselwörtern (Richtlinie 2.3.7), im Werbetext und in der Beschreibung schon.

## en-US

Beschreibung:
```
Say it in one sentence – Loose Ends takes care of the rest.

Tasks show up on the go: on a walk, at the checkout, while reading an email. Loose Ends captures them in a single sentence, without a form to fill in. The app then works out what is in your sentence and later shows you just what fits your situation right now. And it looks like a page from a good notebook: calm, clear and made with care.

BEAUTIFUL LIKE A NOTEBOOK
• Paper, not a form: your tasks sit on the page in calm type, the time in the margin like a diary
• Few colors, each with a meaning: red only for time pressure, green only at the moment you complete
• One sentence sits above your day. No praise, no streaks, no pressure
• Completing a task ties a small knot
• Light and dark, the same page on every device

CAPTURE IN ONE SENTENCE
• Type or dictate – in the app, on Apple Watch, with widgets, the Action button and Shortcuts
• Share sheet: turn text, links, emails, photos and files straight into a task
• Your original sentence is always kept unchanged

THE APP SORTS IT FOR YOU
• Due date, duration, importance and context are recognized from your sentence
• Fixed rules first, Apple Intelligence on your device only where language understanding is needed
• Learns from your choices: tag a sentence once, and it knows next time

YOU HAVE THE LAST WORD
• Every change is visible on the task
• Every field can be reset on its own

VIEWS THAT FIT THE MOMENT
• Now, New, Due, Quick, Old, Waiting, Parked, Completed
• By tag ("Garden", "Computer") and by project
• Repeating tasks and subtasks

REMINDS YOU AT THE RIGHT TIME – AND PLACE
• Notification on the due day with Complete, Next up, Tomorrow
• Reminder on arriving at a place (iPhone, iPad)
• Optionally add dates to your calendar

WITH CLAUDE, IF YOU LIKE
• Sign in with Apple in Settings and add Loose Ends to Claude as a connector
• Ask Claude what's on today, plan your day together or turn an email into tasks
• Claude captures, completes, reschedules and adds steps. It cannot delete anything
• Every change runs on your device, and the task shows you what Claude changed

EVERYWHERE YOU ARE
• iPhone, iPad, Mac and Apple Watch
• Sync through your private iCloud

PRIVATE
Analysis runs on your device. Your tasks live in your iCloud. Only if you connect Claude is a copy of your open tasks kept on our server in Germany: titles and fields, never your original sentence, notes or attachments. "Delete account" in the app removes it.
```

Schlüsselwörter: to-do,todo,reminders,dictation,list,GTD,context,notes,planner,inbox,watch,projects,due,capture
Support-URL: https://www.henemm.com/footer-information/contact/
Werbetext: Say it in one sentence. Loose Ends sorts it on your device and shows it to you on a calm page, like a good notebook. New: plan your day with Claude.
Neu in dieser Version: Loose Ends now works with Claude. Sign in with Apple under Settings › Claude and add Loose Ends to Claude as a connector. Claude can then read your tasks, capture new ones, complete them and plan your day with you. Every change runs on your device, and Claude cannot delete anything. Also: tasks you type keep exactly your title. The widget is up to date as soon as you open the app. On the Mac, the menu bar window opens again with one click.

## de-DE

Beschreibung:
```
Sag es in einem Satz – Loose Ends kümmert sich um den Rest.

Aufgaben entstehen unterwegs: beim Spaziergang, an der Kasse, beim Lesen einer Mail. Loose Ends nimmt sie in einem einzigen Satz auf, ohne dass du ein Feld ausfüllst. Danach erkennt die App selbst, was in deinem Satz steckt, und zeigt dir später genau das, was gerade zu deiner Situation passt. Und sie sieht dabei aus wie eine Seite aus einem guten Notizbuch: ruhig, klar und mit Sorgfalt gestaltet.

SCHÖN WIE EIN NOTIZBUCH
• Papier statt Formular: Deine Aufgaben stehen in ruhiger Schrift auf der Seite, die Zeit am Rand wie im Tagebuch
• Wenige Farben, jede mit Bedeutung: Rot nur bei Zeitdruck, Grün nur im Moment des Erledigens
• Über dem Tag steht ein Satz. Kein Lob, keine Serien, kein Druck
• Beim Erledigen zieht sich ein kleiner Knoten zu
• Hell und dunkel, auf jedem Gerät dieselbe Seite

ERFASSEN IN EINEM SATZ
• Tippen oder diktieren – in der App, auf der Apple Watch, über Widgets, Aktionstaste und Kurzbefehle
• Teilen-Menü: Texte, Links, Mails, Fotos und Dateien direkt als Aufgabe übernehmen
• Dein Originalsatz bleibt immer unverändert erhalten

DIE APP SORTIERT FÜR DICH
• Fälligkeit, Dauer, Wichtigkeit und Kontext werden aus deinem Satz erkannt
• Feste Regeln zuerst, Apple Intelligence auf deinem Gerät nur dort, wo Sprachverständnis nötig ist
• Lernt aus deinen Zuordnungen: Was du einmal einem Kontext gibst, erkennt sie beim nächsten Mal

DU BEHÄLTST DAS LETZTE WORT
• Jede Änderung ist an der Aufgabe sichtbar
• Jedes Feld lässt sich einzeln zurückstellen

ANSICHTEN, DIE ZUR SITUATION PASSEN
• Jetzt, Neu, Fällig, Schnell, Alt, Wartet, Geparkt, Erledigt
• Je Kontext („Garten", „Computer") und je Projekt
• Wiederkehrende Aufgaben und Unteraufgaben

ERINNERT ZUR RICHTIGEN ZEIT – UND AM RICHTIGEN ORT
• Mitteilung am Fälligkeitstag mit Erledigt, Als nächstes, Morgen
• Erinnerung beim Ankommen an einem Ort (iPhone, iPad)
• Termine optional im Kalender

MIT CLAUDE, WENN DU WILLST
• Melde dich in den Einstellungen mit Apple an und füge Loose Ends in Claude als Connector hinzu
• Frag Claude, was heute ansteht, plane mit Claude deinen Tag oder lass eine Mail in Aufgaben zerlegen
• Claude legt an, hakt ab, verschiebt und ergänzt Teilschritte. Löschen kann Claude nichts
• Jede Änderung läuft auf deinem Gerät, und du siehst an der Aufgabe, was Claude geändert hat

ÜBERALL DABEI
• iPhone, iPad, Mac und Apple Watch
• Abgleich über deine private iCloud

PRIVAT
Die Auswertung läuft auf deinem Gerät. Deine Aufgaben liegen in deiner iCloud. Nur wenn du Claude verbindest, liegt eine Abschrift deiner offenen Aufgaben auf unserem Server in Deutschland: Titel und Angaben, nie dein Originalsatz, deine Notizen oder Anhänge. „Konto löschen“ in der App entfernt sie.
```

Schlüsselwörter: Aufgaben,To-do,Todo,Erinnerungen,Diktat,Liste,GTD,Kontext,Notizen,Planer,Inbox,Watch,Projekte,Fällig
Support-URL: https://www.henemm.com/footer-information/contact/
Werbetext: Sag es in einem Satz. Loose Ends ordnet es auf deinem Gerät und zeigt es dir ruhig wie eine Seite im Notizbuch. Neu: Plane deinen Tag mit Claude.
Neu in dieser Version: Loose Ends arbeitet jetzt mit Claude zusammen. Melde dich in den Einstellungen unter „Claude“ mit Apple an und füge Loose Ends in Claude als Connector hinzu. Dann kann Claude deine Aufgaben lesen, neue anlegen, abhaken und deinen Tag mit dir planen. Jede Änderung läuft auf deinem Gerät, löschen kann Claude nichts. Außerdem: Getippte Aufgaben behalten genau deinen Titel. Das Widget ist aktuell, sobald du die App öffnest. Auf dem Mac öffnet sich das Fenster in der Menüleiste wieder mit einem Klick.
