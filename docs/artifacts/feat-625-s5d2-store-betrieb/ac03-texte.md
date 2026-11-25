# AC-3 Store-Texte 1.0.2 mit Marketing-Adresse (de-DE, en-US, iOS und Mac)

Zeit: 2026-11-24T18:51:09+01:00

Marketing-Adresse vor dem Lauf: `curl -s -o /dev/null -w '%{http_code}' https://www.henemm.com/loose-ends/` → `200`
(2026-11-24, 18:50 Uhr MEZ).

## lesen vorher

https://github.com/henemm/loose-ends/actions/runs/45452709590 (nur GET), Ende 18:49 Uhr MEZ. Apple hat beim Anlegen die
Texte von 1.0.1 übernommen; Marketing-URL leer, „Neu in dieser Version“ noch der Text von 1.0.1 (Auszug, je Zeile
gekürzt; Beschreibungen 1638 bzw. 1493 Zeichen):
```
  IOS de-DE Marketing-URL zeichen=0: -
  IOS de-DE Werbetext zeichen=139: Sag es in einem Satz. Loose Ends erkennt Datum, Dauer und Kontext direkt au
  IOS de-DE Neu in dieser Version zeichen=116: Loose Ends gibt es jetzt auch auf Englisch: die App und die Sto
  IOS en-US Marketing-URL zeichen=0: -
  IOS en-US Werbetext zeichen=125: Say it in one sentence. Loose Ends recognizes date, duration and tag right
  IOS en-US Neu in dieser Version zeichen=99: Loose Ends now also speaks English: the app and this store page.
  MAC_OS en-US Marketing-URL zeichen=0: -
  MAC_OS de-DE Marketing-URL zeichen=0: -
```

## texte mit Gegenprobe im selben Lauf

https://github.com/henemm/loose-ends/actions/runs/45452955650, Ende 18:51 Uhr MEZ, Ergebnis `success`:
```
version IOS 1.0.2 id=78834df9-0492-4265-b821-95bad8a68060 state=PREPARE_FOR_SUBMISSION
version MAC_OS 1.0.2 id=8eb2d4b5-ddbe-47e9-b0a2-965db40e402c state=PREPARE_FOR_SUBMISSION
en-US gesetzt: Beschreibung, Marketing-URL, Werbetext, Neu in dieser Version
de-DE gesetzt: Beschreibung, Marketing-URL, Werbetext, Neu in dieser Version
gegenprobe gleich=ja
en-US gesetzt: Beschreibung, Marketing-URL, Werbetext, Neu in dieser Version
de-DE gesetzt: Beschreibung, Marketing-URL, Werbetext, Neu in dieser Version
gegenprobe gleich=ja
zusammenfassung geschrieben=4
```
Schlüsselwörter und Support-URL waren schon gleich und wurden nicht geschrieben.

## zweiter lesen-Lauf

https://github.com/henemm/loose-ends/actions/runs/45453191636 (nur GET), Ende 18:52 Uhr MEZ, keine Abweichung
(`zusammenfassung geschrieben=0`; je Zeile gekürzt):
```
  IOS de-DE Beschreibung zeichen=2751: Sag es in einem Satz – Loose Ends kümmert sich um den Rest.
  IOS de-DE Schlüsselwörter zeichen=100: Aufgaben,To-do,Todo,Erinnerungen,Diktat,Liste,GTD,Kontext,Notizen,Planer,Inbox,
  IOS de-DE Support-URL zeichen=50: https://www.henemm.com/footer-information/contact/
  IOS de-DE Marketing-URL zeichen=34: https://www.henemm.com/loose-ends/
  IOS de-DE Werbetext zeichen=145: Sag es in einem Satz. Loose Ends ordnet es auf deinem Gerät und zeigt es dir ruhig wi
  IOS de-DE Neu in dieser Version zeichen=501: Loose Ends arbeitet jetzt mit Claude zusammen. Melde dich in den Einstell
  IOS en-US Beschreibung zeichen=2469: Say it in one sentence – Loose Ends takes care of the rest.
  IOS en-US Schlüsselwörter zeichen=94: to-do,todo,reminders,dictation,list,GTD,context,notes,planner,inbox,watch,projec
  IOS en-US Support-URL zeichen=50: https://www.henemm.com/footer-information/contact/
  IOS en-US Marketing-URL zeichen=34: https://www.henemm.com/loose-ends/
  IOS en-US Werbetext zeichen=148: Say it in one sentence. Loose Ends sorts it on your device and shows it to you on a c
  IOS en-US Neu in dieser Version zeichen=443: Loose Ends now works with Claude. Sign in with Apple under Settings › Cla
  MAC_OS en-US Beschreibung zeichen=2469: Say it in one sentence – Loose Ends takes care of the rest.
  MAC_OS en-US Schlüsselwörter zeichen=94: to-do,todo,reminders,dictation,list,GTD,context,notes,planner,inbox,watch,pro
  MAC_OS en-US Support-URL zeichen=50: https://www.henemm.com/footer-information/contact/
  MAC_OS en-US Marketing-URL zeichen=34: https://www.henemm.com/loose-ends/
  MAC_OS en-US Werbetext zeichen=148: Say it in one sentence. Loose Ends sorts it on your device and shows it to you on
  MAC_OS en-US Neu in dieser Version zeichen=443: Loose Ends now works with Claude. Sign in with Apple under Settings ›
  MAC_OS de-DE Beschreibung zeichen=2751: Sag es in einem Satz – Loose Ends kümmert sich um den Rest.
  MAC_OS de-DE Schlüsselwörter zeichen=100: Aufgaben,To-do,Todo,Erinnerungen,Diktat,Liste,GTD,Kontext,Notizen,Planer,Inb
  MAC_OS de-DE Support-URL zeichen=50: https://www.henemm.com/footer-information/contact/
  MAC_OS de-DE Marketing-URL zeichen=34: https://www.henemm.com/loose-ends/
  MAC_OS de-DE Werbetext zeichen=145: Sag es in einem Satz. Loose Ends ordnet es auf deinem Gerät und zeigt es dir ruhig
  MAC_OS de-DE Neu in dieser Version zeichen=501: Loose Ends arbeitet jetzt mit Claude zusammen. Melde dich in den Einst
```
