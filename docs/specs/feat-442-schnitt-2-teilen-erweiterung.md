---
entity_id: feat-442-schnitt-2-teilen-erweiterung
type: feature
created: 2026-10-18
updated: 2026-10-18
status: draft
workflow: feat-442-teilen-erweiterung
---

# Spec: #442 Schnitt 2 — Teilen-Erweiterung nimmt Fotos und Dateien an

## Approval

- [ ] Approved (Henning)

## Purpose

Wer in einer anderen App ein Foto oder eine Datei (PDF, Dokument) über „Teilen“ an Loose Ends schickt, bekommt eine neue
Aufgabe mit diesem Anhang (Entwurf A, Henning 2026-10-17, `docs/artifacts/feat-399-teilen-anhaenge/entwurf.html`).
Heute erscheint die App im Teilen-Menü nur für Text, Link und Mail; Fotos und Dateien findet man dort nicht.

Schnitt 1 (PR #517) hat die Regeln und den Speicherweg gebaut (`SharedAttachment`, `SharedContent.make(attachments:)`,
`CaptureService.save(attachments:)`). **Schnitt 2** schließt die Erweiterung daran an: Laden der Anhänge, Maske mit der
Zeilengruppe „Anhänge“, Aufräumen der Temp-Dateien, Texte und zuletzt die Aktivierungsregel. Es ist **rein regelbasiert**;
ein Sprachmodell kommt nicht vor (Regeln vor Modell).

Verhalten, wie in Schnitt 1 und im Entwurf freigegeben:
- Eine geteilte Datei legt immer eine **neue Aufgabe** an. Text, Link und Mail behalten Vorrang.
- Bei einer Datei ohne Text ist der Dateiname (ohne Endung, lesbar) der Vorschlag; bei nur Fotos bleibt das Feld leer,
  die Tastatur ist offen und „Fertig“ bleibt gesperrt, bis Text da ist.
- Je Anhang höchstens 50 MB, höchstens 10 Anhänge je Aufgabe; was darüber liegt, wird in der Maske sichtbar mit Grund
  abgewiesen und nicht gespeichert.

## Source

- **Neu:** `Shared/Services/SharedAttachmentFile.swift` (I/O-Helfer, damit das Kopieren ohne `NSItemProvider` testbar ist),
  `LooseEndsTests/SharedAttachmentFileTests.swift`
- **Geändert:** `LooseEndsShare/ShareViewController.swift`, `LooseEndsShare/ShareCaptureView.swift`,
  `LooseEndsShare/Localizable.xcstrings`, `project.yml` (nur `NSExtensionActivationRule`), `CLAUDE.md` (ein Eintrag)

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `SharedAttachment` (`classify`, `photoFileName`, `title(fromFileName:)`, `maximumCount`) | Wiederverwendung, unverändert | Status, Fotoname, Titelvorschlag |
| `SharedContent.make(texts:urls:mails:attachments:)` | Wiederverwendung, unverändert | Vorrang und Prefill |
| `CaptureService.save(…attachments:in:)` | Wiederverwendung, unverändert | Speichern, liest je Anhang einzeln |
| `AttachmentKind.symbol(for:)`, `AttachmentKind.fits(byteCount:)`, `maximumBytes` | Wiederverwendung | Symbol je Zeile, 50-MB-Grenze |
| `NSItemProvider.loadFileRepresentation(forTypeIdentifier:)` | Apple-API | liefert eine Datei, die **nur im Handler** gültig ist |
| `Logger` (`com.henning.looseends`, Kategorie `Share`) | Wiederverwendung | Fehler loggen, nie verschlucken, nur Typen und Größen, nie Inhalt oder Namen |

Recherche (aus der Analyse, `docs/context/feat-442-teilen-erweiterung.md`): Aktivierungsregel ist ein `NSPredicate`,
`SUBQUERY` mit `UTI-CONFORMS-TO` ist üblich, `TRUEPREDICATE` lehnt das Review ab; Zählgrenzen in der Regel machen laut
Apple-Forum (Threads 838151, 838066) Fehler. Die gelieferte Datei ist nur im Handler gültig. Quell-Apps liefern Fotos
unterschiedlich (Forum 712179), die Dateirepräsentation deckt sie einheitlich ab. Der Speicher der Erweiterung ist knapp
(etwa 120 MB).

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Services/SharedAttachmentFile.swift` | NEU | Reine Typwahl `attachmentType(registered:)`; `adopt(…)` kopiert eine gelieferte Datei in einen eigenen Temp-Ordner und liefert ein `SharedAttachment`; `makeDirectory()`/`remove(_:)` für den Ordner |
| `LooseEndsShare/ShareViewController.swift` | MODIFY | `collect(from:)`: Anhänge sequenziell laden, `classify`, an `SharedContent.make` und Maske reichen; Aufräumen bei Fertig und Abbruch |
| `LooseEndsShare/ShareCaptureView.swift` | MODIFY | Zeilengruppe „Anhänge“ (Entwurf A) mit Hinweisen; `save()` reicht `attachments` durch |
| `LooseEndsShare/Localizable.xcstrings` | MODIFY | neue Texte (Englisch als Quelle, Deutsch) |
| `project.yml` | MODIFY | `NSExtensionActivationRule` um `public.image` und `public.data` erweitern — **zuletzt** |
| `CLAUDE.md` | MODIFY | Ein Eintrag `SharedAttachmentFile` bei `Shared/Services` |
| `LooseEndsTests/SharedAttachmentFileTests.swift` | NEU | Typwahl und Kopieren mit echten Temp-Dateien |

Erwartet: etwa 150 Zeilen Produktcode und Texte, 90 Zeilen Tests, zusammen rund 240 LoC (Ziel ≤ 250). Sechs Dateien
Produktcode, Texte und Doku, dazu eine Testdatei. Wird die Grenze beim Bauen überschritten, wird angehalten und
nachgefragt.

**Nicht angefasst:** `Shared/Models/`, `cloudkit/schema.ckdb`, `SharedAttachment`, `SharedContent`, `CaptureService`,
`AttachmentKind`, die App-Ansicht `AttachmentsSection`. Kein Schemawechsel, keine neue Berechtigung, keine
Entitlement-Änderung.

**Stufe 3 Pflicht** (`project.yml`, `LooseEndsShare/` stehen auf der Geräteliste); der Nachweis läuft über TestFlight,
nichts auf Hennings Geräten ohne sein wörtliches „jetzt ist ein Test möglich“.

## Implementation Details

### `SharedAttachmentFile` (Shared/Services, I/O ohne UI)

```swift
enum SharedAttachmentFile {
    /// Welcher registrierte Typ ist der Anhang? nil = kein Anhang (Text, Link, Mail bleiben wie sie sind).
    static func attachmentType(registered identifiers: [String]) -> String?
    /// Kopiert `source` (nur im Handler gültig) nach `directory/<UUID>/<Name>`; liest keine Bytes in den Speicher.
    static func adopt(_ source: URL, typeIdentifier: String, suggestedName: String?,
                      into directory: URL, at date: Date, photoPrefix: String) throws -> SharedAttachment
    static func makeDirectory() throws -> URL      // Temp-Ordner der Erweiterung
    static func remove(_ directory: URL)            // räumt auf, Fehler werden geloggt
}
```

**`attachmentType(registered:)`**: erster Eintrag, der zu `public.image` passt; sonst erster, der zu `public.data` passt,
aber **nicht** zu `public.url`, `public.text` oder `public.email-message`; sonst `nil`. Damit bleiben Text, Web-Link,
Mail und `message://` auf ihren bisherigen Zweigen, und ein Datei-Link (`public.file-url` passt zu `public.url`) wird nicht
fälschlich als Anhang gelesen; eine Datei aus „Dateien“ kommt über ihren eigenen Typ (zum Beispiel `com.adobe.pdf`).

**`adopt`**: Größe per `resourceValues(forKeys: [.fileSizeKey])` **vor** dem Kopieren. Ist sie über
`AttachmentKind.maximumBytes`, wird **nicht** kopiert: Ergebnis mit `byteCount` und Name, `fileURL` zeigt auf den (nicht
mehr gültigen) Ursprung, der Status `.tooLarge` entsteht in `classify`; gelesen wird so eine Datei nie. Sonst wird mit
`FileManager.copyItem` in einen Unterordner `<UUID>` des Temp-Ordners kopiert (Namen können kollidieren). Der Name ist
`suggestedName`, sonst `source.lastPathComponent`; ist er leer oder für ein Bild nur eine Systemvorgabe ohne Namen, gilt
`SharedAttachment.photoFileName(typeIdentifier:at:prefix:)`, für Nicht-Bilder `File`. Es wird nie `Data` gehalten.

### `ShareViewController.collect(from:)`

Pro Provider, **nacheinander** (nicht parallel, wegen des Speichers): Ist `attachmentType(registered:)` nicht `nil`, wird
`loadFileRepresentation(forTypeIdentifier:)` über eine Continuation aufgerufen und **im Handler** `adopt` aufgerufen;
schlägt das Laden fehl, liefert der Provider nichts oder wirft `adopt`, wird der Fehler geloggt (nur Typ, nie Inhalt) und
der Provider übersprungen. Als Rückfall, wenn die Dateirepräsentation fehlt, aber `Data` kommt (`loadDataRepresentation`),
wird diese Datenmenge **sofort** in eine Temp-Datei geschrieben und nicht gehalten. Alle anderen Provider laufen über die
bestehenden Zweige (Mail, URL, Text), unverändert. Danach `SharedAttachment.classify(…)` und
`SharedContent.make(texts:urls:mails:attachments:)`. Die bestehende Protokollzeile (`probeLine`) bleibt.

Der Temp-Ordner wird in `collect` angelegt und im View Controller gehalten; `finish` und `cancel` rufen
`SharedAttachmentFile.remove` **vor** `completeRequest`/`cancelRequest`. Ein Fehlschlag beim Speichern räumt nicht auf
(der Nutzer kann es noch einmal versuchen).

### `ShareCaptureView` (Entwurf A)

Unter Textfeld und Quell-Link eine zusätzliche Gruppe, nur wenn `content.attachments` nicht leer ist:

- Überschrift „Attachments“ / „Anhänge“.
- Je Anhang eine Zeile: `Label(fileName, systemImage: AttachmentKind.symbol(for:))` (SF Symbol, outline) und die Größe
  (`ByteCountFormatter`, `.file`).
- Status `.tooLarge`: die Größe wird durch den grauen Hinweis „Too large (max. 50 MB) – not attached“ /
  „Zu groß (max. 50 MB) – nicht angehängt“ ersetzt; `.overLimit`: „More than 10 – not attached“ /
  „Mehr als 10 – nicht angehängt“. Beides sichtbar, nie still.
- Die Fertig-Regel bleibt „Text nötig“ (`canSave`); `onAppear` fokussiert das Feld, wenn der Prefill leer ist (gilt auch
  für nur Fotos). `save()` reicht `content.attachments` an `CaptureService.save(… attachments:)` durch; der Container lebt
  über die ganze Dauer.
- Farbbudget: nur Grau für Hinweise und Größen, kein Rot, keine Emojis, keine eigenen Bilder.

### Aktivierungsregel (`project.yml`, zuletzt)

Zu den drei bisherigen Bedingungen kommen `ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.image"` und
`… "public.data"`, mit `OR` verbunden. **Keine Zählgrenze** in der Regel, **kein `TRUEPREDICATE`**. `public.data` ist weit
(es umfasst auch Text und Links, die schon passen); die Obergrenze von zehn Anhängen setzt der Code mit sichtbarem Grund.
Die Regel wird als letzter Schritt geändert, damit die Erweiterung nie vor ihrer Fähigkeit erscheint.

## Expected Behavior

- **Input:** Ein Foto aus Fotos wird an Loose Ends geteilt.
- **Output:** Die Maske zeigt das leere Textfeld mit offener Tastatur, darunter die Gruppe „Anhänge“ mit einer Zeile
  (Symbol, Name, Größe). „Fertig“ geht erst mit Text; danach liegt eine neue Aufgabe mit einem Anhang im Store und im
  Detail unter „Anhänge“.
- **Input:** Ein PDF „Rechnung_Stadtwerke_Oktober.pdf“ aus Dateien. **Output:** Prefill „Rechnung Stadtwerke Oktober“,
  eine Anhangszeile.
- **Input:** Eine Mail über „Drucken → Teilen“ (PDF). **Output:** wie ein PDF aus Dateien (statt wie bisher verworfen).
- **Input:** Ein Link oder Text, ohne Datei. **Output:** unverändert wie heute, keine Anhangsgruppe.
- **Input:** Elf Fotos. **Output:** zehn Zeilen mit Größe, die elfte mit dem Hinweis „Mehr als 10 – nicht angehängt“.
- **Input:** Ein Film über 50 MB. **Output:** Zeile mit dem Hinweis „Zu groß …“, nichts wird kopiert oder gespeichert.
- **Side effects:** Temp-Dateien der Erweiterung werden nach Fertig und Abbruch gelöscht. Keine neuen Berechtigungen,
  keine AppStorage-Schlüssel, keine Audiodateien, kein Schemawechsel. Neue Texte in `LooseEndsShare/Localizable.xcstrings`.

## Acceptance Criteria

- **AC-1:** `SharedAttachmentFile.attachmentType(registered:)` liefert für `["public.jpeg", "public.image"]` den Typ
  `public.jpeg`, für `["com.adobe.pdf", "public.file-url"]` den Typ `com.adobe.pdf`, und `nil` für
  `["public.plain-text"]`, `["public.url"]`, `["public.file-url"]`, `["public.email-message"]` und `[]`.
  (Test: `SharedAttachmentFileTests`, Typwahl)
- **AC-2:** `SharedAttachmentFile.adopt` kopiert eine echte Temp-Datei in einen Unterordner des übergebenen Ordners und
  liefert ein `SharedAttachment` mit `byteCount` gleich der Dateigröße, dem vorgeschlagenen Namen, dem Typ und einer
  `fileURL` mit identischem Inhalt; zwei Dateien mit gleichem Namen überschreiben sich nicht. Ohne `suggestedName` wird der
  Dateiname der Quelle genommen; fehlt er, bekommt ein Bild den `photoFileName`, eine andere Datei den Namen „File“.
  (Test: `SharedAttachmentFileTests`, Kopieren und Namen)
- **AC-3:** Eine Datei über `AttachmentKind.maximumBytes` wird von `adopt` **nicht** kopiert (Beleg: im Ordner liegt danach
  keine Datei, `byteCount` ist die echte Größe); `SharedAttachment.classify` macht sie danach zu `.tooLarge`. Eine nicht
  vorhandene Quelle wirft einen Fehler. (Test: `SharedAttachmentFileTests`, zu groß und Fehler; Größen dürfen über eine
  Dünn-Datei, `truncate`, nachgebildet werden)
- **AC-4:** `makeDirectory()` legt einen leeren Ordner an, `remove(_:)` löscht ihn samt Inhalt und wirft nicht, wenn er
  schon weg ist. (Test: `SharedAttachmentFileTests`, Aufräumen)
- **AC-5:** Text, Web-Link und `message://`-Link laufen weiterhin über ihre bisherigen Zweige: Alle bestehenden Tests in
  `SharedContentTests` und `CaptureServiceTests` bleiben grün, und `ShareViewController.collect` ruft für sie weder
  `loadFileRepresentation` noch `adopt` auf. (Beleg: volle Unit-Tests grün, Durchsicht des Codes im Diff)
- **AC-6:** Die Aktivierungsregel in `project.yml` nennt `public.image` und `public.data` zusätzlich zu `public.text`,
  `public.url` und `public.email-message`, enthält weder `TRUEPREDICATE` noch eine Zählbedingung außer dem bisherigen
  `@count >= 1`, und die aus `project.yml` erzeugte `LooseEndsShare/Info.plist` trägt dieselbe Regel. Die Regel ist die
  **letzte** geänderte Datei in der Commit-Reihenfolge. (Beleg: `grep` auf `project.yml` und erzeugte Info.plist,
  `git log --stat`)
- **AC-7:** Im Simulator wird ein Foto aus der Fotos-App über „Teilen“ an die Erweiterung gegeben (Stufe 2): Die Maske
  zeigt das leere Textfeld mit offener Tastatur, darunter „Anhänge“ mit einer Zeile (Symbol, Name, Größe); „Fertig“ ist
  gesperrt, bis Text steht; nach dem Speichern zeigt das Detail der neuen Aufgabe den Anhang unter „Anhänge“. Das
  Bildschirmfoto der Maske und das des Details werden geöffnet und beschrieben. (Beleg: `./scripts/sim.sh screenshot`
  Maske und Detail, Beschreibung im Abnahmebericht)
- **AC-8:** Im Simulator mit einem PDF aus Dateien: Der Vorschlag im Textfeld ist der lesbar gemachte Dateiname ohne
  Endung, „Fertig“ ist sofort aktiv, der Anhang liegt nach dem Speichern an der Aufgabe. Bildschirmfoto der Maske und des
  Details. (Beleg: Screenshots, beschrieben)
- **AC-9:** Mit elf geteilten Fotos zeigt die Maske zehn Zeilen mit Größe und die elfte mit „Mehr als 10 – nicht
  angehängt“, nach dem Speichern hängen zehn Anhänge an der Aufgabe. Mit einer Datei über 50 MB zeigt die Zeile „Zu groß
  (max. 50 MB) – nicht angehängt“, und es hängt nichts daran. Die Texte stehen in Englisch und Deutsch in
  `Localizable.xcstrings`. (Beleg: Screenshots im Simulator; Texte per Durchsicht)
- **AC-10:** Nach „Fertig“ und nach „Abbrechen“ ist der Temp-Ordner der Erweiterung gelöscht. (Beleg: Simulatorlauf, danach
  Blick in den Temp-Ordner der Erweiterung; die Aufräum-Funktion selbst ist in AC-4 getestet)
- **AC-11:** **Stufe 3, Hennings iPhone über TestFlight** (nach „jetzt ist ein Test möglich“ und dem Merge): ein Foto aus
  Fotos, ein PDF aus Dateien, der Mail-Weg „Drucken → Teilen“ und mehrere Fotos auf einmal erscheinen im Teilen-Menü,
  landen als Anhang an einer neuen Aufgabe und tauchen über iCloud auf einem zweiten Gerät auf. Die Erweiterung wird dabei
  nicht vom System beendet. Henning bekommt die Buildnummer mit den Prüfschritten; seine Rückmeldung schließt den Punkt,
  das Ticket bleibt bis dahin offen. (Beleg: Rückmeldung im Ticket)

## Test Plan

Swift Testing wie die bestehenden Suites. Temp-Dateien legt der Test im Temp-Ordner an und räumt sie auf; große Dateien
als Dünn-Dateien (`FileHandle.truncate(atOffset:)`), nie mit echten 50 MB. Läufe: `./scripts/sim.sh sim-unit`, nie auf dem
Mac-Host. Die Teilen-Erweiterung selbst ist kein Unit-Test-Ziel (UI und `NSItemProvider`); sie wird in Stufe 2 und 3
gefahren.

| Datei / Lauf | Fälle | ACs |
|---|---|---|
| `LooseEndsTests/SharedAttachmentFileTests.swift` (NEU) | Typwahl, Kopieren und Namen, zu groß, Fehler, Aufräumen | AC-1 bis AC-4 |
| Volle Unit-Tests (`sim-unit`) | Bestand unverändert grün | AC-5 |
| `grep` / `git log --stat` | Aktivierungsregel, Reihenfolge | AC-6 |
| Simulator (`build`, `launch`, `screenshot`) | Foto, PDF, elf Fotos, große Datei, Aufräumen | AC-7 bis AC-10 |
| TestFlight, Hennings iPhone | echter Teilen-Weg, Mail-PDF, Abgleich | AC-11 |

Rot-Phase: `SharedAttachmentFileTests` scheitern zuerst am Compiler (Typ fehlt), danach an den Regeln.

## Definition of Done

- [ ] AC-1 bis AC-10 belegt, alle Unit-Tests grün (`./scripts/sim.sh sim-unit`) und die CI grün.
- [ ] Simulator: Foto, PDF, Grenzfälle durchgespielt, Bildschirmfotos geöffnet und beschrieben.
- [ ] Nach Merge: TestFlight-Bau mit „Was testen“ auf Deutsch; Henning bekommt Buildnummer und Prüfschritte (AC-11).
- [ ] Issue #442 ist nach seiner Rückmeldung aktualisiert und geschlossen; Board-Status gepflegt.

## Alternatives

- **Nur Dateien annehmen, Fotos weiter nur im Detail (a):** kleiner, aber von Henning ausdrücklich gewollt (Fotos über
  Teilen); verworfen.
- **An bestehende Aufgabe hängen statt neue (b):** eigener Ablauf (Suche, Auswahl); bei Bedarf eigenes Ticket.
- **`loadTransferable` mit eigenem `Transferable`-Typ (c):** moderner, aber der Speicher der Erweiterung ist damit schwerer
  zu begrenzen; verworfen.
- **Aktivierungsregel „für alles“ oder mit Zählgrenze (d):** `TRUEPREDICATE` lehnt das Review ab, Zählgrenzen machen laut
  Forum Fehler; deshalb weite Typen und die Grenze im Code mit sichtbarem Grund.

Keine ADR wird gekippt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — kein Modell-, Schema- oder Architekturwechsel; ein weiterer I/O-Helfer in `Shared/Services` nach dem
  Muster von Schnitt 1, die Erweiterung bleibt dünn (I/O und Maske).

## Known Limitations

- Fotos kommen je nach Quell-App als HEIC, JPEG oder Live Photo; es wird gespeichert, was die App als Datei liefert.
- Speichergrenze der Erweiterung und das Verhalten bei vielen großen Dateien sind nur auf dem Gerät belegbar (AC-11).
- Der Simulator kann Fotos und Dateien teilen; Mail-„Drucken → Teilen“ und der iCloud-Abgleich nur das Gerät.
- Die Aktivierungsregel ist weit (`public.data`): Loose Ends erscheint auch für Typen, aus denen wir nichts Sinnvolles
  machen können; solche Anhänge werden trotzdem als Datei angenommen.
- Ein Anhang, der beim Lesen im Speichern scheitert, fehlt still (nur Log), wie in Schnitt 1 festgelegt.

## Changelog

- 2026-10-18: Teil-Spec für Schnitt 2 angelegt (Analyse `docs/context/feat-442-teilen-erweiterung.md`, Vorgänger
  `feat-399-schnitt-1-anhang-speichern.md`, Entwurf A freigegeben 2026-10-17).
