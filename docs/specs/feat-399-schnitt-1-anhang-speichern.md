---
entity_id: feat-399-schnitt-1-anhang-speichern
type: feature
created: 2026-10-17
updated: 2026-10-17
status: draft
workflow: feat-399-teilen-anhaenge
---

# Spec: #399 Schnitt 1 — Geteilte Anhänge: reine Regeln und Speicherweg

## Approval

- [ ] Approved (Henning)

## Purpose

Fotos und Dateien aus dem Teilen-Menü anderer Apps sollen als Anhang an einer neuen Aufgabe landen (#399,
Henning 2026-10-17: „Entwurf A“). Die Lieferung ist wegen des Limits von 250 LoC in zwei Schnitte geteilt.
**Schnitt 1** legt die Regeln und den Speicherweg an: ein Werttyp für einen geteilten Anhang vor dem Speichern, die
Titelregel für Dateien, die Fotobenennung, die Größen- und Mengenprüfung, und das Speichern der Anhänge in
`CaptureService.save`. Schnitt 1 hat **keine sichtbare Änderung**: Die Teilen-Erweiterung lädt noch nichts und
aktiviert sich weiterhin nur für Text, Link und Mail.

Der Entscheid „Entwurf A“ (Henning, 2026-10-17): Eine geteilte Datei legt immer eine **neue Aufgabe** an. Text, Link und
Mail behalten Vorrang. Bei einer Datei ohne Text ist der Dateiname (ohne Endung, lesbar gemacht) der Vorschlag. Bei nur
Fotos bleibt der Vorschlag leer; der Nutzer tippt, „Fertig“ bleibt bis dahin gesperrt (das ist die Maske in Schnitt 2).

Es ist **rein regelbasiert**; ein Sprachmodell kommt nicht vor (Regeln vor Modell).

**Schnitt 2** (eigene Teil-Spec, eigener Workflow, nicht Teil dieser Spec) liefert: Laden per `NSItemProvider` in der
Erweiterung, die Maske mit der Zeilengruppe „Anhänge“, die Aktivierungsregel in `project.yml` und die Texte. Der sichtbare
Nachweis (Simulator, TestFlight auf Hennings iPhone, Stufe 3) liegt dort.

## Source

- **Neu:** `Shared/Services/SharedAttachment.swift`
- **Geändert:** `Shared/Services/SharedContent.swift`, `Shared/Services/CaptureService.swift`,
  `Shared/Services/AttachmentKind.swift`, `CLAUDE.md`

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `AttachmentKind.maximumBytes` (50 MB) | Wiederverwendung | Eine Datei darüber wird nie gelesen. |
| `TaskAttachment(task:data:fileName:typeIdentifier:)` | Wiederverwendung | Ziel-Modell (#442), unverändert, kein Schemawechsel. |
| `AttachmentsSection.addPhoto` (Z. 98–108) | Vorbild | Fotoname „Photo <Datum numerisch, Uhrzeit kurz>.<Endung>“. |
| `SharedContent.make` / `isFileURL`-Filter (#24/#291) | Wiederverwendung | Text, Link, Mail bleiben wie sie sind; der Filter für Datei-Links bleibt. |
| `Logger` (Subsystem `com.henning.looseends`) | Wiederverwendung | Fehler beim Lesen werden geloggt, nie verschluckt. |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Services/SharedAttachment.swift` | NEU | `struct SharedAttachment: Equatable, Sendable` mit `fileURL`, `fileName`, `typeIdentifier`, `byteCount`, `status`; `enum Status { ready, tooLarge, overLimit }`; `static let maximumCount = 10`; reine Funktionen `title(fromFileName:)`, `photoFileName(typeIdentifier:at:prefix:)`, `classify(_:)`. |
| `Shared/Services/AttachmentKind.swift` | MODIFY | `static func fits(byteCount: Int) -> Bool`; `fits(_ data:)` ruft es auf. |
| `Shared/Services/SharedContent.swift` | MODIFY | Feld `attachments: [SharedAttachment]` (Vorgabe leer); `make(...)` mit zusätzlichem Parameter `attachments:` (Vorgabe leer); Prefill-Regel für Dateien. |
| `Shared/Services/CaptureService.swift` | MODIFY | `save(..., attachments: [SharedAttachment] = [], in:)` speichert bereite Anhänge einzeln. |
| `CLAUDE.md` | MODIFY | Ein Eintrag `SharedAttachment` bei `Shared/Services` unter „Where things live“. |
| `LooseEndsTests/SharedAttachmentTests.swift` | NEU | Reine Regeln. |
| `LooseEndsTests/SharedContentTests.swift` | MODIFY | Prefill-Regel mit Anhängen. |
| `LooseEndsTests/CaptureServiceTests.swift` | MODIFY | Speichern mit Anhängen im In-Memory-Container. |

Erwartet: rund 115 Zeilen Produktcode und Doku, 130 Zeilen Tests, zusammen etwa 245 LoC (Ziel ≤ 250). Fünf Dateien
Produktcode und Doku, dazu drei Testdateien. Wird die Grenze beim Bauen überschritten, wird angehalten und nachgefragt.

**Nicht angefasst:** `project.yml`, `LooseEndsShare/`, `Shared/Models/`, `cloudkit/schema.ckdb`, alle bestehenden Aufrufer
von `CaptureService.save` (App, Siri, Watch, Share). Sie kompilieren dank der Vorgabewerte unverändert.

**Kein Pfad der Geräteliste berührt.** `Shared/Services/` steht nicht auf der Liste. Die Abnahme besteht aus Stufe 1
(Tests). Stufe 2 (Simulator) entfällt mangels sichtbarer Änderung: Es gibt nichts, was der Nutzer sehen oder auslösen
könnte. Der sichtbare Nachweis liegt in Schnitt 2.

## Implementation Details

### `SharedAttachment`

```swift
struct SharedAttachment: Equatable, Sendable {
    enum Status: Equatable, Sendable { case ready, tooLarge, overLimit }
    static let maximumCount = 10

    var fileURL: URL          // Kopie in einer eigenen Temp-Datei der Erweiterung
    var fileName: String
    var typeIdentifier: String
    var byteCount: Int
    var status: Status
}
```

Die Datei wird **nicht** als `Data` gehalten: Eine Teilen-Erweiterung hat etwa 120 MB Speicher (Recherche in
`docs/context/feat-399-teilen-anhaenge.md`). Gelesen wird erst beim Einfügen in die Aufgabe, einzeln nacheinander.

**`title(fromFileName:)`**: Endung entfernen (`URL(fileURLWithPath:).deletingPathExtension`), `_` und `-` durch Leerzeichen
ersetzen, Mehrfach-Leerzeichen zu einem zusammenfassen, trimmen. „Befund_Dr-Meier.pdf“ → „Befund Dr Meier“. Bleibt nichts
übrig, ist das Ergebnis leer.

**`photoFileName(typeIdentifier:at:prefix:)`**: `"<prefix> <Datum numerisch, Uhrzeit kurz>.<Endung>"`. Die Endung ist
`UTType(typeIdentifier)?.preferredFilenameExtension`, sonst `jpg`. Das Datum wird übergeben (testbar). Der Präfix ist ein
Parameter mit Vorgabe „Photo“; die Erweiterung reicht in Schnitt 2 den lokalisierten Text durch.

**`classify(_:)`**: Eingabe eine Liste von Anhängen (Status beliebig), Ausgabe dieselbe Liste in derselben Reihenfolge.
Pro Eintrag: `byteCount` nicht in `AttachmentKind.fits(byteCount:)` → `.tooLarge`; sonst, wenn schon zehn bereite Anhänge
davor stehen → `.overLimit`; sonst `.ready`. Gezählt wird nach Position unter den nicht zu großen: Ein zu großer Anhang
verbraucht keinen der zehn Plätze. Der 11. bereite Anhang ist `.overLimit`.

### `SharedContent`

Neue Regel in `make`, nachdem Mail, `message://`-Link und Web-Link geprüft sind: Gibt es **keinen** Text, keinen
(Nicht-Datei-)Link und keine Mail, ist der Prefill `SharedAttachment.title(fromFileName:)` des ersten Anhangs mit Status
`.ready`, dessen Typ **kein Bild** ist (`UTType.conforms(to: .image)`). Gibt es nur Fotos, bleibt der Prefill leer. Alle
bisherigen Zweige bleiben wörtlich unverändert; `attachments` wird in jedem Zweig übernommen. Der `isFileURL`-Filter für
Links bleibt (#24/#291).

### `CaptureService.save`

```swift
static func save(_ rawText: String, via channel: CaptureChannel, sourceURL: URL? = nil,
                 attachments: [SharedAttachment] = [], in context: ModelContext) throws -> TaskItem
```

`CaptureError.emptyText` bleibt: Keine Aufgabe ohne Text, auch nicht mit Anhang. Nach dem Einfügen der Aufgabe, für jeden
Anhang mit Status `.ready`, nacheinander: `AttachmentKind.fits(byteCount:)` auf der Dateigröße nochmals prüfen, dann
`Data(contentsOf: fileURL)` lesen und `TaskAttachment(task:data:fileName:typeIdentifier:)` einfügen. Ein `context.save()`
am Ende wie bisher. Schlägt das Lesen fehl, wird dieser Anhang übersprungen und mit `Logger` geloggt (nur Typ und Größe,
nie Inhalt oder Dateiname), per `do/catch`, kein `try?`; Aufgabe und übrige Anhänge werden gespeichert.
`.tooLarge` und `.overLimit` werden nie gelesen und nie gespeichert. Die Funktion bleibt unter 50 LoC (Hilfsfunktion
`insert(_:for:in:)`).

## Expected Behavior

- **Input:** Eine Aufgabe mit Text und drei Anhängen (zwei bereit, einer zu groß).
- **Output:** Die Aufgabe liegt im Store, mit zwei `TaskAttachment`s in der Reihenfolge der Eingabe.
- **Ohne Anhänge:** `save` verhält sich bytegleich wie bisher.
- **Side effects:** Keine Änderung am Modell, am Schema oder an Berechtigungen. Keine neuen AppStorage-Schlüssel. Keine
  Audiodateien. Die Temp-Dateien räumt die Erweiterung auf (Schnitt 2); `save` löscht sie nicht.

## Acceptance Criteria

- **AC-1:** `SharedAttachment.title(fromFileName:)` macht aus „Befund_Dr-Meier.pdf“ den Titel „Befund Dr Meier“, fasst
  Mehrfach-Leerzeichen („a__b - c.pdf“ → „a b c“) zusammen, trimmt Ränder und liefert für „.pdf“ oder „___.pdf“ einen
  leeren Text. (Test: `SharedAttachmentTests`, Titelregel)
- **AC-2:** `SharedAttachment.photoFileName(typeIdentifier:at:prefix:)` liefert mit festem Datum, Präfix „Photo“ und
  Typ `public.heic` einen Namen, der mit „Photo “ beginnt, das numerisch formatierte Datum samt kurzer Uhrzeit enthält und
  auf „.heic“ endet; bei einem unbekannten Typ endet er auf „.jpg“. (Test: `SharedAttachmentTests`, Fotoname)
- **AC-3:** `SharedAttachment.classify(_:)` gibt Anhänge bis `AttachmentKind.maximumBytes` (inklusive genau 50 MB) als
  `.ready` zurück und jeden mit mehr Bytes als `.tooLarge`; ein zu großer Anhang belegt keinen der zehn Plätze.
  (Test: `SharedAttachmentTests`, Größe)
- **AC-4:** Bei zwölf bereiten Anhängen liefert `classify` die ersten zehn als `.ready`, den 11. und 12. als `.overLimit`,
  und die Reihenfolge der Eingabe bleibt erhalten. (Test: `SharedAttachmentTests`, Obergrenze)
- **AC-5:** `SharedContent.make` mit einem bereiten PDF-Anhang „Befund_Dr-Meier.pdf“ und ohne Text, Link und Mail ergibt
  den Prefill „Befund Dr Meier“; mit einem bereiten Foto als einzigem Anhang bleibt der Prefill leer; mit Foto und PDF
  wird der Titel des PDFs genommen; ein Anhang mit Status `.tooLarge` oder `.overLimit` liefert nie einen Prefill.
  (Test: `SharedContentTests`, Anhang-Prefill)
- **AC-6:** Text, Web-Link, `message://`-Link und Mail behalten Vorrang: Mit einem PDF-Anhang und zusätzlich einem Text
  (oder Link oder Mail) ist der Prefill derselbe wie ohne den Anhang, und `attachments` enthält das PDF trotzdem.
  Alle bestehenden Tests in `SharedContentTests` laufen unverändert grün; eine Datei-URL wird weiterhin als Link
  verworfen. (Test: `SharedContentTests`, Vorrang und Bestand)
- **AC-7:** `CaptureService.save("Befund Dr Meier", via: .share, attachments: [a, b], in:)` mit zwei bereiten Anhängen
  (echte Temp-Dateien mit bekanntem Inhalt) legt genau eine Aufgabe und zwei `TaskAttachment`s an, die über `task` mit ihr
  verbunden sind, in Reihenfolge der Eingabe, mit passendem `data`, `fileName` und `typeIdentifier`.
  (Test: `CaptureServiceTests`, Anhänge speichern)
- **AC-8:** Anhänge mit Status `.tooLarge` oder `.overLimit` werden nie gelesen und nie gespeichert (Beleg: Der Test
  übergibt eine `fileURL` auf eine nicht vorhandene Datei, und `save` wirft nicht und legt keinen Anhang an). Eine Datei,
  die als `.ready` gemeldet ist, aber beim Einfügen mehr als 50 MB meldet, wird ebenfalls nicht gespeichert.
  (Test: `CaptureServiceTests`, nie lesen)
- **AC-9:** Ist die Datei eines bereiten Anhangs nicht lesbar (gelöscht), wird nur dieser Anhang übersprungen; die Aufgabe
  und die übrigen Anhänge werden gespeichert und `save` wirft nicht. Mit leerem Text wirft `save` weiterhin
  `CaptureError.emptyText`, auch mit bereitem Anhang, und es bleibt nichts im Store. Ohne `attachments` verhält sich `save`
  wie bisher (alle bestehenden Tests in `CaptureServiceTests` grün, alle bisherigen Aufrufer unverändert).
  (Test: `CaptureServiceTests`, unlesbar, leerer Text, Bestand)
- **AC-10:** Die Änderung berührt weder `project.yml`, `LooseEndsShare/`, `Shared/Models/` noch `cloudkit/schema.ckdb`;
  `CLAUDE.md` nennt `SharedAttachment` bei `Shared/Services`. Der vor der Prüfung vorbereitete Text der Pull-Request-
  Beschreibung (`docs/artifacts/feat-399-teilen-anhaenge/pr-schnitt-1.md`) verweist mit „Refs #399“ (nicht „Closes“), weil
  das Ticket für Schnitt 2 offen bleibt. (Beleg: `git diff --name-only` gegen `main` und diese Datei)

## Test Plan

Swift Testing wie die bestehenden Suites. Temp-Dateien legt der Test selbst im Temp-Ordner an und räumt sie auf. Der
In-Memory-Container (`ModelContainerFactory.make(inMemory: true)`) bleibt in einer lokalen Variable am Leben, solange
der Kontext benutzt wird (CLAUDE.md). Läufe: `./scripts/sim.sh sim-unit`, nie auf dem Mac-Host.

| Datei | Fälle | ACs |
|---|---|---|
| `LooseEndsTests/SharedAttachmentTests.swift` (NEU) | Titelregel, Fotoname, Größe, Obergrenze | AC-1 bis AC-4 |
| `LooseEndsTests/SharedContentTests.swift` (ERGÄNZT) | Datei-Prefill, Foto leer, Vorrang, `.tooLarge` ohne Prefill | AC-5, AC-6 |
| `LooseEndsTests/CaptureServiceTests.swift` (ERGÄNZT) | zwei Anhänge, nie lesen, unlesbar, leerer Text | AC-7 bis AC-9 |
| Diff gegen `main`, `pr-schnitt-1.md` | Dateiliste, „Refs #399“ | AC-10 |

Rot-Phase: Alle neuen Tests scheitern zuerst am Compiler (Typ und Parameter fehlen), danach an den Regeln.

## Definition of Done

- [ ] AC-1 bis AC-10 belegt, alle Unit-Tests grün (`./scripts/sim.sh sim-unit`) und die CI grün.
- [ ] Im GitHub-Issue #399 steht als Kommentar, dass Schnitt 1 gebaut ist und Schnitt 2 folgt; das Issue bleibt offen.
- [ ] Abschlussbericht: „Kein Pfad der Geräteliste berührt.“

## Alternatives

- **Foto ohne Text speichern, Titel „Foto <Datum>“ (B):** Henning hat es abgewählt. Es würde die Regel „keine Aufgabe ohne
  Text“ (`CaptureError.emptyText`) für einen Kanal aufheben. Gekippt würde nichts; die Regel bleibt.
- **An eine bestehende Aufgabe hängen (C):** Henning hat es abgewählt; eigener Ablauf (Suche, Auswahl). Nur als eigenes
  Ticket, falls er es vermisst.
- **Speicherweg mit `Data` statt Temp-Datei:** verworfen. Mehrere Fotos oder ein großes PDF als `Data` im Speicher der
  Erweiterung (etwa 120 MB) können sie beenden. Mit der Datei wird einzeln und erst beim Einfügen gelesen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — kein Modell-, Schema- oder Architekturwechsel; ein weiterer reiner Werttyp in `Shared/Services`
  nach dem bestehenden Muster (`SharedContent`, `AttachmentKind`).

## Known Limitations

- Keine sichtbare Wirkung, bis Schnitt 2 die Erweiterung anschließt: Laden der Anhänge per `NSItemProvider`, Maske
  „Anhänge“, Aktivierungsregel, Texte, Aufräumen der Temp-Dateien. Stufe 3 (TestFlight) gehört zu Schnitt 2.
- `photoFileName` formatiert das Datum nach der Sprache des Geräts; der Test prüft die Form, nicht einen festen Wortlaut.
- Die Typ-Erkennung „ist ein Bild“ verlässt sich auf `UTType`. Unbekannte Typen gelten als Datei, nicht als Bild.
- Ein Anhang, der beim Lesen scheitert, fehlt still an der Aufgabe (nur Log). Eine Anzeige dafür gibt es erst mit der Maske.

## Changelog

- 2026-10-17: Teil-Spec für Schnitt 1 angelegt (Analyse `docs/context/feat-399-teilen-anhaenge.md`, Henning „Entwurf A“).
