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
