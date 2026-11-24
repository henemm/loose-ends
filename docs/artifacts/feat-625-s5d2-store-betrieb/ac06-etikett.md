# AC-6 Datenschutz-Etikett nach Vorlage (app-weit)

Zeit: 2026-11-24T21:56:53+01:00

Hennings Ja: `henning-ja-etikett.md` („Ja, so eintragen“, 2026-11-24T19:51:21+01:00), Vorlage
`docs/reference/app-store-datenschutzangaben.md`. Der Eintrag liegt nach dem Ja und nach AC-5 (21:50 Uhr MEZ).

## lesen vorher

ASC-Web, App-Datenschutz, 21:53 Uhr MEZ: „Vor 25 Tagen von Henning Emmrich veröffentlicht“, Vorschau „Keine Daten
erfasst“, Datentypen „Es werden von dieser App keine Daten erfasst.“ Datenschutz-URL
`https://www.henemm.com/legal/loose-ends/privacy-policy/`.

## Eintrag (ASC-Web in Hennings Chrome, er nur Anmeldung per Passkey)

1. Datenerfassung: „Ja, wir erfassen Daten von dieser App“.
2. Datentypen angekreuzt, Gegenprobe der Kästchen per Seitenabfrage: genau „Sonstige Benutzerinhalte“, „Benutzer-ID“,
   „Geräte-ID“; nichts sonst.
3. Je Typ: Zweck nur „App-Funktionalität“ (Werbung Dritter, eigene Werbung, Analyse, Produktpersonalisierung, Sonstige
   Zwecke leer); „Ja, … mit der Identität des Benutzers verknüpft“; Tracking „Nein, wir verwenden keine … für
   Tracking-Zwecke“; „Veröffentlichen“. Reihenfolge: Sonstige Benutzerinhalte, Benutzer-ID, Geräte-ID (21:54–21:56 Uhr MEZ).

## Gegenprobe (Seite neu geladen, 21:56 Uhr MEZ)

Seitentext, wörtlich:
```
Vor ein paar Sekunden von Henning Emmrich veröffentlicht
Mit dir verknüpfte Daten
Die folgenden Daten werden möglicherweise erfasst und mit deiner Identität verknüpft:
Benutzerinhalte
Kennungen
Von dieser App werden 3 Datentypen erfasst: Sonstige Benutzerinhalte, Benutzer-ID, Geräte-ID
Sonstige Benutzerinhalte: Verwendet für App-Funktionalität / Mit der Identität des Benutzers bzw. der Benutzerin verknüpft
Benutzer-ID: Verwendet für App-Funktionalität / Mit der Identität des Benutzers bzw. der Benutzerin verknüpft
Geräte-ID: Verwendet für App-Funktionalität / Mit der Identität des Benutzers bzw. der Benutzerin verknüpft
```
Bildschirmfotos, geöffnet und beschrieben:
- `ac06-etikett-vorschau.jpg`: Vorschau der Produktseite mit genau einem Block „Mit dir verknüpfte Daten“ (Benutzerinhalte,
  Kennungen); kein Block „Zum Tracking verwendete Daten“ und kein Block „Nicht mit dir verknüpfte Daten“; darunter
  „3 Datentypen erfasst: Sonstige Benutzerinhalte, Benutzer-ID, Geräte-ID“.
- `ac06-etikett-typen.jpg`: die drei Typen je mit „Verwendet für App-Funktionalität“ und „Mit der Identität … verknüpft“.

## Abgleich mit der Vorlage, Punkt für Punkt

| Vorlage | ASC (deutsch) | verknüpft | Tracking | Zweck | Ergebnis |
|---|---|---|---|---|---|
| Identifiers › User ID | Kennungen › Benutzer-ID | ja | nein | App-Funktionalität | gleich |
| Identifiers › Device ID | Kennungen › Geräte-ID | ja | nein | App-Funktionalität | gleich |
| User Content › Other User Content | Benutzerinhalte › Sonstige Benutzerinhalte | ja | nein | App-Funktionalität | gleich |

Bewusst nicht angegebene Typen der Vorlage (Kontaktinfo, Standort, Kontakte, Fotos und Videos, Diagnose, Nutzungsdaten)
stehen nicht im Etikett. Abweichungen: keine.
