---
entity_id: feat-226-ortserinnerungen
type: feature
created: 2026-10-06
updated: 2026-10-06
status: draft
workflow: feat-226-ortserinnerungen
---

# #226 Ortserinnerungen: User Story, Analyse, Entwurf

Vorbereitung für die Spec. Nichts davon ist gebaut. Henning hat die Produktfragen am 2026-10-06
beantwortet (letzter Abschnitt). Daraus wird als Nächstes die Spec für Schnitt 1.

## Approval

- [ ] User Story und Entwurf freigegeben (Henning)
- [x] Produktfragen F1–F7 beantwortet (Henning, 2026-10-06)

## User Story

> Als Henning möchte ich einer Aufgabe einen Ort geben – „beim Baumarkt“, „wenn ich nach Hause
> komme“, „wenn ich das Büro verlasse“ –, damit mein iPhone mich genau dort erinnert, ohne dass ich
> die App öffne oder an die Aufgabe denken muss.

**Warum jetzt:** Henning, 2026-10-06: „Ort als eigenes Feature vorher bauen.“ Die Siri-Erfassung
(#25) liefert über das Reminders-Schema einen `locationTrigger`. Ohne Ortsfeld ginge diese Angabe
verloren, und #25 wird erst ausgeliefert, wenn alle Siri-Angaben gespeichert werden.

**Erfolg, aus Hennings Sicht:**
- Er gibt einer Aufgabe in zwei Tippern einen Ort und wählt „Ankommen“ oder „Verlassen“.
- Kommt er dort an (oder geht er weg), erscheint eine Mitteilung mit dem Titel der Aufgabe. Die
  App muss dafür nicht laufen.
- Aus der Mitteilung hakt er die Aufgabe ab, ohne die App zu öffnen.
- Ein Ort, den Siri mitschickt, landet genauso an der Aufgabe.

## Widerspruch zu einer bestehenden Entscheidung

Drei Stellen im Projekt schließen genau dieses Feature aus:

- **ADR-Antwort 14** (`docs/project/00-entscheidungen.md`): „Keine Standort-Berechtigung. ‚Garten‘
  ist Kontext (Tag), nicht Ort.“
- **„Bewusst nicht in Version 1“**: „Standort“.
- **Design-Briefing** (`docs/project/03-design-briefing.md`, „Nicht gestalten“): „Standortkarten“.

Die Entscheidung vom 2026-10-06 hebt das auf. Die Spec ändert alle drei Stellen und nennt den Grund.
**„Garten“ bleibt ein Kontext.** Ein Ort ist etwas anderes: ein Punkt auf der Karte, an dem
erinnert wird. Ein Kontext ist ein Etikett, nach dem gefiltert wird. Henning hat zugestimmt (F1).

## Was die Plattform hergibt (mit Quellen)

| Frage | Befund | Quelle |
|---|---|---|
| Was liefert Siri? | `locationTrigger` mit `place: GeoToolbox.PlaceDescriptor` (Adresse und/oder Koordinate, dazu ein Name) und `event`: `arrive` oder `depart`. **Keinen Radius.** | [locationTrigger](https://developer.apple.com/documentation/appintents/appschema/remindersentity/locationtrigger), [locationTriggerEvent](https://developer.apple.com/documentation/appintents/appschema/remindersenum/locationtriggerevent), [PlaceDescriptor](https://developer.apple.com/documentation/geotoolbox/placedescriptor/placerepresentation) |
| Wie wird zugestellt? | `UNLocationNotificationTrigger`: Das System überwacht den Bereich und stellt die Mitteilung selbst zu. Die App muss nicht laufen. | [UNLocationNotificationTrigger](https://developer.apple.com/documentation/usernotifications/unlocationnotificationtrigger) |
| Welche Berechtigung? | Nur **„Beim Verwenden der App“**. „Immer“ ist nicht nötig, weil das System überwacht. | ebenda, Abschnitt „Important“ |
| Wie viele Orte gleichzeitig? | Höchstens **20 Bereiche je App**. | [Monitoring the user’s proximity](https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions) |
| Wie pünktlich? | Nicht sofort an der Grenze. Das System prüft erst, ob man wirklich angekommen oder weggegangen ist. | ebenda |
| Mac? | `UNLocationNotificationTrigger` gibt es nur für iOS, iPadOS und watchOS. Der Mac stellt nichts zu. | Verfügbarkeit in der Quelle oben |
| Watch? | Mitteilungen des iPhones erscheinen auf der Watch. Dafür ist nichts zu bauen. | Systemverhalten |

**Regeln vor dem Modell:** Ein Ort wird nie geraten. Er kommt von Henning (Auswahl im Detail) oder
von Siri. Einen Ort aus dem Rohtext erkennen („wenn ich beim Bauhaus bin“) ist nicht Teil dieses
Tickets. Henning, 2026-10-06 (F5): eigenes Ticket. Gemessen auf 319 erfassten Sätzen (Treue-Korpus
samt FocusBlox-Rohsätzen): genau einer nennt eine Ortsbedingung („Wenn ich morgen in der Stadt bin …“),
und „in der Stadt“ ist kein Punkt auf der Karte.

## Entwurf: so sieht es aus

### Detail einer Aufgabe

Ein eigener Abschnitt „Ort“ unter dem Kalender-Schalter. Er ist gebaut wie der Kalender-Abschnitt:
eine Zeile, darunter bei Bedarf ein grauer Hinweis.

```
┌────────────────────────────────────────┐
│ Ort                                    │
│ 📍 Bauhaus, Hamburg-Altona        ›   │   ← Akzentfarbe, tippbar
│ [ Ankommen | Verlassen ]               │   ← Segment, Vorgabe: Ankommen
│ Erinnert, wenn du ankommst.            │   ← grau
└────────────────────────────────────────┘
```

Ohne Ort zeigt die Zeile nur „Ort hinzufügen“. Ein Tipp öffnet ein Blatt:

```
┌────────────────────────────────────────┐
│ Abbrechen        Ort                   │
│ 🔍 Adresse oder Name                   │
│ ➤  Aktueller Ort                       │
│ ⌂  Zuhause                             │   ← gemerkte Orte, falls festgelegt
│ ▣  Arbeit                              │
│ ───────────────────────────────────    │
│ Bauhaus  · Hamburg-Altona              │   ← Treffer der Kartensuche
│ Bauhaus  · Hamburg-Wandsbek            │
└────────────────────────────────────────┘
```

**Zuhause und Arbeit** (Henning, 2026-10-06): Ohne Zugriff auf Kontakte kennt die App sie nicht.
Henning legt sie einmal selbst fest: Bei jedem Treffer und bei „Aktueller Ort“ gibt es „Als Zuhause
merken“ und „Als Arbeit merken“. Danach stehen sie oben im Blatt. Ändern lassen sie sich auf dem
gleichen Weg.

Ein Wischen nach links auf die Ortszeile entfernt den Ort. Jede Änderung ist eine Revision mit
Autor `.user`, wie bei jedem anderen Feld.

**Hinweise in der Ortszeile, grau:**
- Standort nicht erlaubt: „Standort ist in den Einstellungen aus. Der Ort ist gespeichert, erinnert
  aber nicht.“
- Mehr als 20 Orte: „Wird gerade nicht überwacht: mehr als 20 Orte offen.“ (siehe Planung unten)
- Auf dem Mac: „Erinnert auf iPhone und Watch.“

**Liste:** Ein kleines Ortszeichen (grau, `location`) in der Merkmalzeile, wie das Zeichen für
Wiederholung (F7).

**Karte:** Es gibt keine Karte. Das Briefing schließt Standortkarten aus, und für die Auswahl reicht
die Suche. Der Radius ist fest 150 m und wird nicht angezeigt (F6).

### Die Mitteilung

```
Loose Ends
Dübel und Schrauben kaufen
Du bist bei Bauhaus.
[ Erledigt ]  [ Als nächstes ]
```

„Morgen“ aus der Fällig-Mitteilung entfällt, denn ein Ort hat keinen Tag (F4).

### Berechtigung

Gefragt wird erst, wenn Henning zum ersten Mal einen Ort setzt, und nicht im Onboarding. Die Frage
ist „Beim Verwenden der App“. Lehnt er ab, bleibt der Ort trotzdem gespeichert, und die Ortszeile
zeigt den Hinweis oben. Der Text in `Info.plist` (`NSLocationWhenInUseUsageDescription`):
„Only for tasks you give a place: your iPhone reminds you when you arrive or leave. Loose Ends
never tracks where you go.“

## Verhalten, das die Spec festlegt

1. **Fälligkeit und Ort zugleich:** Beide erinnern, jede für sich, wie in Apples Erinnerungen.
2. **Erledigt, geparkt, gelöscht:** Die Ortsüberwachung endet. Wiederhergestellt: Sie beginnt wieder.
3. **Wiederkehrende Aufgabe mit Ort:** Nach dem Abhaken rückt sie weiter und erinnert am Ort wieder.
   Ohne Abhaken erinnert sie nur einmal (`repeats: false`) (F3).
4. **Mehr als 20 Orte:** Überwacht werden die 20 wichtigsten. Die Reihenfolge ist „Als nächstes“
   zuerst, dann nach Fälligkeit, dann die neuesten. Die übrigen zeigen den Hinweis. Nichts fällt
   still weg.
5. **Siri ohne Koordinate** (nur Adresse): Die Adresse wird einmal per Geocoding in eine Koordinate
   umgewandelt. Gelingt das nicht, lehnt Siri sichtbar ab („Ort nicht gefunden“), und es entsteht
   keine Aufgabe. So hält es #25 auch bei den anderen Angaben.
6. **Sync:** Der Ort reist über CloudKit mit. Jedes iPhone plant seine Ortserinnerungen selbst.

## Datenmodell

Neue optionale Felder am `TaskItem`. Das ist eine additive CloudKit-Änderung, die Produktion ist
noch nicht ausgerollt (#175):

| Feld | Typ | Zweck |
|---|---|---|
| `placeName` | `String?` | Anzeigename („Bauhaus, Hamburg-Altona“) |
| `placeLatitude`, `placeLongitude` | `Double?` | Mittelpunkt |
| `placeRadius` | `Double?` | Meter. Fehlt er, gilt die Vorgabe (150 m). |
| `placeEventRaw` | `String?` | `arrive` / `depart` |
| `placeSourceRaw` | `String?` | `.user` oder `.rule` (Siri), wie bei jedem abgeleiteten Feld |

Für Zuhause und Arbeit kommt ein eigenes kleines Modell `SavedPlace` dazu (Art `home`/`work`, Name,
Koordinate). Es reist über CloudKit mit. Gibt es von einer Art mehrere (CloudKit kann Doppel spät
liefern), gewinnt der älteste Eintrag auf allen Geräten gleich, wie bei den Kontexten (#157).

Dazu kommt `RevisedField.place`, codiert als JSON in `FieldCodec`, wie die Wiederholregel. Der Ort
wird dabei als **ein** Feld revidiert, denn Name, Koordinate und Ereignis gehören zusammen.

## Schnitte

Das Ticket ist für die 250-Zeilen-Grenze zu groß. Vorschlag in vier Schnitten, jeder mit eigenem PR:

| # | Inhalt | Geräteliste? | Wo baubar |
|---|---|---|---|
| 1 | Datenfelder, `SavedPlace`, `RevisedField.place`, Codec, reine Planung `PlaceReminders.plan` (20er-Grenze, Reihenfolge, Ausschluss erledigt/geparkt) samt Unit-Tests | nein (`Shared/Models`, `Shared/Services`, `Shared/Notifications`) | Cloud |
| 2 | Abbildung Siri-`locationTrigger` → Ortsfeld (rein, wie #224) samt Unit-Tests | nein | Cloud |
| 3 | Detail: Ortszeile, Suchblatt mit Zuhause/Arbeit, Segment, Hinweise, Ortszeichen in der Liste; Berechtigungstext | **ja** (`project.yml`, `Info.plist`) | Mac + Gerät |
| 4 | Zustellung: `UNLocationNotificationTrigger` in `LooseEnds/Notifications`, Aktionen Erledigt/Als nächstes | **ja** (`LooseEnds/Notifications/`) | Mac + Gerät |

Die DoD des Tickets („auf dem Gerät nachgewiesen“) erfüllen erst die Schnitte 3 und 4. Der Nachweis
verlangt einen echten Ortswechsel mit „LE Prüfbau“, denn der Simulator kann einen Ort nur
vortäuschen.

## Antworten von Henning (2026-10-06)

| # | Frage | Antwort |
|---|---|---|
| F1 | Standort-Berechtigung | Ja, „Beim Verwenden der App“, gefragt beim ersten Ort, nicht im Onboarding. ADR 14 wird in der Spec neu gefasst. |
| F2 | Ort wählen | Suche (Adresse oder Geschäft) und „Aktueller Ort“, ohne Kontakte. Zuhause und Arbeit legt Henning einmal selbst fest. |
| F3 | Wiederkehrend mit Ort | Einmal erinnern bis zum Abhaken; nach dem Abhaken erinnert sie dort wieder. |
| F4 | Knöpfe der Mitteilung | Erledigt und Als nächstes. |
| F5 | Ort aus dem Rohtext | Eigenes Folgeticket, nicht Teil von #226 (Messung: 1 von 319 Sätzen). |
| F6 | Radius | Fest 150 m. |
| F7 | Ortszeichen in der Liste | Ja, grau. |
