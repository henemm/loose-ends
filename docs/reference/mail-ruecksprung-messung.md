# Mail-Rücksprung über die Teilen-Erweiterung (Spike #24)

Stand 2026-10-08. Gerät: Hennings iPhone 16 Pro, iOS 27.0, Prüfbau „LE Prüfbau“. Beobachtet von Henning
von Hand; die Messzeile (`SharedContent.probeLine`) war erst im zweiten Durchgang im Prüfbau, und dessen
Datei kam nicht mehr zum Einsatz (Henning brach den Gerätelauf ab: „das hat nichts mit meiner Zeit zu
tun“). **Es gibt deshalb keine Typkennungen aus dem Log, nur die Beobachtungen und die Recherche.**

## Ergebnis: unzuverlässig — Teilen aus Mail liefert nie eine `message:`-URL

| Weg in Mail | Was ankommt | `message:`-URL / Message-ID | Quelle |
|---|---|---|---|
| Ganze Mail teilen | gibt es nicht (kein Teilen-Knopf für eine Nachricht) | – | Henning; Recherche |
| Text markieren → Teilen | Text | nein, „Source“ bleibt leer | Henning |
| Drucken → Teilen | Link auf eine PDF-Datei in der Erweiterung (file://) | nein; „Source“ erscheint, ist nicht anklickbar | Henning; Recherche |

Hinweis zur Deutung der letzten Zeile: Dass es eine Datei-URL der Druckausgabe ist, folgt aus der
Recherche (Drucken → Teilen erzeugt ein PDF) und Hennings Beobachtung „Link, aber nicht anklickbar“.
Die Typkennung selbst ist nicht gemessen.

Rücksprung selbst (AC-3): nicht gemessen, weil nie eine `message:`-URL ankam. Aus der Recherche: Ein
`message:`-Link öffnet auf iOS verlässlich, wenn die Mail im Postfach liegt; am Mac erscheint ein
Fehlerdialog (NSHipster). Gelöschte Mail / entferntes Konto bleiben unbelegt.

## Recherche (2026-10-08)

- Auf iOS lässt sich eine Mail nur durch Ziehen aus Mail in eine andere App verlinken
  ([NSHipster](https://nshipster.com/message-id/)).
- „Drucken → Teilen“ erzeugt eine PDF der Mail ([Sweet Setup](https://thesweetsetup.com/print-pdf-using-mail-ios/)).
- Nicht belegt für iOS 26/27: ob Mail etwas Weiteres an Teilen-Erweiterungen gibt. Hennings Beobachtung
  auf iOS 27.0 zeigt: nein.

## Fallback (Entscheidung)

1. Datei-Links aus Mail werden **nicht** als Quelle gespeichert und nicht als Titelvorschlag benutzt
   (`SharedContent.make`, Tests `fileLinkDropped`, `fileLinkWithText`). Vorher: toter „Source“-Link und
   ein Dateipfad als Titel.
2. „Source“ erscheint weiterhin nur bei gesetzter `sourceURL`. Web- und `message:`-Links bleiben Quelle.
3. Der Rücksprung aus dem Teilen heraus ist **kein** Weg mehr. Er wird nicht mit Betreff-Text vorgetäuscht.
4. Folgeticket: andere Wege zu einem echten Rücksprung (Ziehen aus Mail in die App, Siri-Bildschirminhalt
   über #25). Das Muss „Rücksprung“ in der User-Story bleibt offen, bis eines davon belegt ist.
