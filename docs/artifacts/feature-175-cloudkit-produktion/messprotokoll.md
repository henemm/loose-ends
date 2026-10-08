# #175 Messprotokoll

## S0 — Schema-Stand Development und Production (2026-10-08)

Abgelesen in der CloudKit Console (Container `iCloud.com.henning.looseends`, Team XK87E2B3VR), in Hennings
angemeldetem Chrome, nur lesend. Kein Management-Token angelegt: Die Console zeigt beide Umgebungen direkt.

### Production

Nur der System-Typ `Users` (7 Felder). **Kein einziger App-Typ.** Das Schema wurde nie ausgerollt (O2 beantwortet:
nein). Beleg: `s0-production-record-types.jpg`.

Folge (R2): Eine TestFlight-Fassung kann heute weder lesen noch schreiben. Ihre Daten blieben nur lokal.

### Development

Record Types: `CDMR` (9 Felder), `CD_Revision` (16), `CD_TaskContext` (11), `CD_TaskItem` (40), `Users` (7).
Die Seitenleiste zeigt „Record Types – Modified“, „Indexes – Modified“: Änderungen seit dem letzten (nie erfolgten)
Deploy.

Abgleich gegen `LooseEndsSchema.models`:

| Modell | In Development | Fehlt |
|---|---|---|
| `TaskItem` | 34 Datenfelder | `sourceURL`, `parkedAt`, `calendarEventID`, `repeatRule`, `place`, `placeSourceRaw`, `placeRemindedAt`, `peopleSourceRaw`, `peopleConfidence`, Verweise `project`, `parent` |
| `Revision` | vollständig (`id`, `task`, `fieldRaw`, `oldValue`, `newValue`, `authorRaw`, `reason`, `createdAt`, `seenAt`) | — |
| `TaskContext` | vorhanden (11 Felder) | Einzelabgleich nicht nötig, Typ existiert |
| `Project` | **fehlt ganz** | ganzer Typ |
| `CompletionRecord` | **fehlt ganz** | ganzer Typ |
| `SavedView` | **fehlt ganz** | ganzer Typ |

Ursache (bekannt, R10): Development legt Typen und Felder nur an, wenn ein Datensatz sie mit einem Wert schreibt.
Henning hat nie ein Projekt, eine Ansicht, eine Wiederholung, einen Ort oder einen geparkten Eintrag synchronisiert.

### Entscheidung

Ein Deploy von heute würde dieses Teil-Schema nach Production bringen. TestFlight scheiterte dann an jedem dieser
Felder und Typen, sobald einer davon zum ersten Mal einen Wert hat. **S1 (Schema-Initialisierer) ist nötig.**
Ein Deploy ist erst nach S1 sinnvoll.

## S1 — Schema-Initialisierer (2026-10-08)

**Lauf:** `./scripts/sim.sh mac-schema-init` auf diesem Mac. Das ist ein signierter macOS-Debug-Bau der
**Hauptkennung** `com.henning.looseends` (Team XK87E2B3VR, Container `iCloud.com.henning.looseends`, Development).
Es ist weder Hennings Alltags-App noch der Prüfbau. Ausgabe: `s1-mac-schema-init.txt`, Ende: „Schema-Initialisierung
erfolgreich (Exit 0)“.

**Ergebnis in der Console (Development), Beleg `s1-development-record-types.jpg`:**

| Typ | Felder vorher (S0) | Felder nachher |
|---|---|---|
| `CDMR` | 9 | 9 |
| `CD_CompletionRecord` | fehlte | 13 |
| `CD_Project` | fehlte | 16 |
| `CD_Revision` | 16 | 23 |
| `CD_SavedView` | fehlte | 19 |
| `CD_TaskContext` | 11 | 14 |
| `CD_TaskItem` | 40 | 74 |

`CD_TaskItem` enthält jetzt alle elf Felder, die in S0 fehlten: `CD_sourceURL`, `CD_parkedAt`, `CD_calendarEventID`,
`CD_repeatRule` (BYTES), `CD_place` (BYTES), `CD_placeSourceRaw`, `CD_placeRemindedAt`, `CD_peopleSourceRaw`,
`CD_peopleConfidence`, `CD_project`, `CD_parent`. Dazu kommen Felder, die Core Data selbst anlegt: die
`…_ckAsset`-Begleitfelder für lange Texte und `CD_moveReceipt`. Die zusammengesetzten Angaben `place` und
`repeatRule` liegen je als ein einziges Byte-Feld vor, nicht aufgeteilt.

**Auffälligkeit:** Nach dem Erfolg meldete Core Data zwei Fehler auf den Wegwerf-Speicher:
`SQLite error code:6922, 'disk I/O error'` und `no such table: ANSCKEVENT`. Eine Suche nach der wörtlichen Meldung
fand keinen Fallbericht. `ANSCK…` sind die internen Tabellen des Abgleichs
([Forum 811823](https://developer.apple.com/forums/thread/811823)). Erklärung: Der Ordner wurde gelöscht, während der
Container noch lebte, und der Abgleich schrieb danach noch sein Ereignis. Für das Schema hat das keine Folgen.
Korrektur: Den Speicher vor dem Löschen vom Container lösen.

**Zweiter Lauf nach der Korrektur** (`s1-mac-schema-init-2.txt`): Exit 0, **null** Core-Data-Fehlermeldungen (vorher 6).
Die Erklärung ist damit bestätigt. Das Schema in Development blieb unverändert vollständig, der Lauf lässt sich also
gefahrlos wiederholen.

## S2 — Deploy nach Production (2026-10-08)

Henning gab den Deploy am 2026-10-08 ausdrücklich frei („ja, deployen“). Der Dialog „Confirm Deployment“ listete
7 × „Create … type“ (CDMR, CD_CompletionRecord, CD_Project, CD_Revision, CD_SavedView, CD_TaskContext, CD_TaskItem),
nichts zu ändern oder zu löschen. Rückmeldung: „Changes Deployed — The schema is deployed to Production.“

Abgleich danach (Beleg `s2-production-record-types.jpg`): Production zeigt dieselben Typen mit denselben Feldzahlen
wie Development: CDMR 9, CD_CompletionRecord 13, CD_Project 16, CD_Revision 23, CD_SavedView 19, CD_TaskContext 14,
CD_TaskItem 74, Users 7. Die Schema-Einträge in Production sind gesperrt (Schloss), „Deploy Schema Changes“ ist
ausgegraut: Es gibt keine offenen Änderungen mehr.

## S3 — Sicherung und TestFlight-Lauf (2026-10-08)

**Sicherung (AC-9):** `xcrun devicectl device copy from --device 00008140-00111D582681801C --domain-type
appGroupDataContainer --domain-identifier group.com.henning.looseends --source "Library/Application Support"`
nach `~/Documents/LooseEnds-Sicherung-2026-10-08` (2,0 MB: `LooseEnds.store` 598 016 B, `-wal` 1 507 952 B, `-shm`,
`.LooseEnds_SUPPORT`, `LooseEnds_ckAssets`). Nur gelesen, auf dem iPhone nichts verändert.

**Ausgangsstand für O1** (gezählt in einer Kopie der Sicherung): 18 Aufgaben, davon 12 offen
(11 aktiv, 1 neu) und 6 erledigt; 7 Kontexte.

**TestFlight-Lauf:** Run 37740713520 vom `main`-Stand `35b2863` (2026-10-08 06:59 UTC). Der Schema-Initialisierer ist
nicht drin, das schadet nicht: Er steht nur in Debug-Bauten, die Release-Fassung ist dieselbe.

## S4 — Messung O1 und Abgleich auf zwei Geräten (2026-10-08)

Henning installierte Build 19 aus TestFlight auf dem iPhone 16 Pro **über** die Xcode-Fassung (nicht gelöscht) und
auf dem iPad. Laut Henning war Loose Ends **vorher nie auf dem iPad installiert**. Das iPad hatte also keinen lokalen
Speicher, alles dort kam über CloudKit Production. Fotos von Henning, von mir geöffnet und beschrieben:

| Beleg | Gerät, Uhrzeit | Sichtbar |
|---|---|---|
| `s4-iphone-start-1029.png` | iPhone, 10:29 | „1 zum Durchsehen, 1 vorgemerkt“; Als nächstes: „Termin beim Hautarzt für OP“; Als nächstes 1, Neu 1, Fällig 1, Schnell 2, Projekte 1, Kontexte 13, Erledigt 6 |
| `s4-ipad-start-1029.png` | iPad, 10:29 | dieselben Zahlen und dieselbe Aufgabe „Termin beim Hautarzt für…“: Als nächstes 1, Neu 1, Fällig 1, Schnell 2, Projekte 1, Kontexte 13, Erledigt 6 |
| `s4-ipad-neu-abgleich-1031.png` | iPad, 10:31 | Neu 2: „Abgleichtest 175 Kaktus gießen“ (30 Min.) und „Wäsche waschen“ |

**O1 beantwortet: ja.** Die TestFlight-Fassung hat Hennings bestehende Aufgaben aus dem lokalen Speicher des iPhones
nach Production hochgeladen. Das frisch installierte iPad zeigt sie vollständig, mit identischen Zahlen in allen
Listen, darunter 6 erledigte (Sicherung: 6 erledigt). Damit widerspricht die Messung der Vermutung aus R8 („beide
Fassungen gleichen nicht ab“). R8 beschreibt den Fall, dass beide Fassungen **nebeneinander** laufen. Hier wurde die
Xcode-Fassung ersetzt.

**AC-11 belegt:** „Abgleichtest 175 Kaktus gießen“, um 10:29–10:31 auf dem iPhone erfasst, erscheint um 10:31 auf dem
iPad unter Neu.

**AC-12:** O1 = ja, ein Umzugs-Ticket entfällt. Hennings Daten sind in Production angekommen. Development bleibt Archiv.

**Auffälligkeit Kontexte:** Beide Geräte zeigen **13 Kontexte**, die Sicherung hatte 7. Wahrscheinlich sind
Standard-Kontexte zusätzlich angelegt oder doppelt geliefert worden. Das gehört zu #269 und ist dort vermerkt.

**Nebenbefund Spracheingabe:** In Build 19 liefert die eingebaute Spracheingabe auf beiden Geräten keinen Text. Die
Wellenform erscheint. Build 19 ist die erste Fassung mit #64. Das hat mit #175 nichts zu tun und läuft als eigenes
Ticket #274.

## Folgetickets (AC-14)

- #268 Schutzschranke: TestFlight hält an, wenn Production das Modell nicht kennt (S5, R11)
- #269 Kontext-Dubletten in CloudKit Production ansehen (#157/#163), nach S4
- #274 Spracheingabe liefert keinen Text mehr (Nebenbefund aus S4, nicht Teil von #175)
