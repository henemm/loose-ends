# AC-5 Bildschirmaufnahme für Apples Prüfer, Anhang an iOS und Mac

Zeit: 2026-11-24T21:50:17+01:00

## Aufnahme

- Aufgenommen von Henning selbst auf seinem iPhone 16 Pro mit der iOS-Bildschirmaufnahme, Loose Ends 1.0.2 (142) aus
  TestFlight; Claude hat sein iPhone nicht angerührt und nur in der Sitzung um die Aufnahme gebeten.
- Datei: `~/Downloads/ScreenRecording_11-24-2026 20-07-30_1.MP4` (182,5 s, HEVC 1206×2622, 85,9 MB), aufgenommen
  2026-11-24 20:07–20:10 Uhr MEZ. Ergänzend Hennings Bildschirmfoto `~/Downloads/Bildschirmfoto 2026-11-24 um 20.11.06.png`
  (20:11 Uhr MEZ) mit der Rückfrage „Konto löschen?“, die in der Aufnahme nur einen Augenblick steht.
- Erste Aufnahme `ScreenRecording_11-24-2026 20-02-14_1.MP4` (20:02 Uhr MEZ) verworfen: sie zeigte weder Erfassen noch
  Anmelden noch Konto löschen, dafür einen älteren privaten Claude-Chat. Sie wird nicht hochgeladen.

## Von Claude geöffnet und beschrieben (Einzelbilder alle 3 s, Ende alle 0,5 s)

1. 20:07 TestFlight-Liste: „Loose Ends 1.0.2 (142)“, Öffnen.
2. Einstellungen › Claude, abgemeldet: „Mit Apple anmelden“ getippt, Apples Blatt „Melde dich mit deinem Apple Account bei
   ‚Loose Ends‘ an“, Face ID, „Anmelden …“, danach angemeldet.
3. Erfassen per Sprache: „Dieses ist eine neue Testaufgabe“, Fertig; die Aufgabe steht unter „Neu“ und wird geöffnet
   (Detail „Noch nicht sortiert“ mit + Notiz, + Fällig, + Ort, …), Menü der Aufgabe gezeigt.
4. 20:08 Claude-App, neuer leerer Chat: „Was habe ich heute noch für Aufgaben?“ → „Loose Ends geladen“, `get_view` zeigt
   „Jetzt 4“ und „Fällig 4“ mit den Aufgaben der App.
5. „Gibt es eine Testaufgabe?“ → „Loose Ends durchsucht“, Antwort nennt „Dieses ist eine neue Testaufgabe“.
6. „Bitte erinnere mich daran die heute noch zu löschen“ → Claude fragt nach der Art und Uhrzeit (21:00), setzt das
   Fälligkeitsdatum über Loose Ends; zurück in der App steht die Testaufgabe unter „Jetzt 5“ mit 21:00.
7. 20:10 Einstellungen › Claude: „Angemeldet mit Apple · Dieses Gerät“, „Konto löschen …“ getippt, danach steht wieder
   „Mit Apple anmelden“ (abgemeldet, Konto gelöscht); die Rückfrage „Konto löschen? Claude sieht deine Aufgaben dann nicht
   mehr. Deine Aufgaben in der App bleiben, wie sie sind.“ zeigt das Bildschirmfoto.

Sichtbare private Angaben: Titel echter Aufgaben (Namen von Bekannten) und eine Kalender-Adresse; nur für Apples Prüfer,
von Henning so freigegeben („das muss reichen“, 2026-11-24 20:12 Uhr MEZ).

## Anhang

Hochgeladen wird eine verkleinerte Fassung derselben Aufnahme, weil das Upload-Werkzeug des Browsers höchstens 10 MB
annimmt: `LooseEnds-1.0.2-Review.mp4` (ffmpeg, H.264 zwei Durchgänge, 600×1304, 24 fps, 360 kbit/s, ohne Ton, 182,5 s,
8,2 MB, 2026-11-24 20:17 Uhr MEZ). Inhalt und Länge unverändert; Einzelbild bei 175 s geöffnet, Text der Einstellungen
lesbar.

Das Bildschirmfoto wird nicht angehängt, damit je Plattform genau ein Anhang steht; die Rückfrage steht in der Aufnahme.

Angehängt im ASC-Web in Hennings Chrome (er nur Anmeldung per Passkey), Abschnitt „Informationen zur App-Prüfung“ › Anhang,
zuerst iOS-App 1.0.2, dann macOS-App 1.0.2; vorher stand an beiden Versionen kein Anhang („Datei auswählen (optional)“).
Danach zeigte die Seite je Version den Dateinamen, „Sichern“ blieb ausgegraut (Apple übernimmt den Anhang sofort).

Gegenprobe `asc-review-notes aktion=lesen` (nur GET): https://github.com/henemm/loose-ends/actions/runs/45484822730,
21:50 Uhr MEZ, Ergebnis `success`:
```
version IOS 1.0.2 id=78834df9-0492-4265-b821-95bad8a68060 state=PREPARE_FOR_SUBMISSION
version MAC_OS 1.0.2 id=8eb2d4b5-ddbe-47e9-b0a2-965db40e402c state=PREPARE_FOR_SUBMISSION
IOS notizen gesetzt bytes=2514
IOS anhang name=LooseEnds-1.0.2-Review.mp4 groesse=8216773 assetDeliveryState=COMPLETE
MAC_OS notizen gesetzt bytes=417
MAC_OS anhang name=LooseEnds-1.0.2-Review.mp4 groesse=8216773 assetDeliveryState=COMPLETE
```
Je Plattform genau ein Anhang. Die Notizen sind noch die von 1.0.1 (übernommen); sie setzt AC-8.
