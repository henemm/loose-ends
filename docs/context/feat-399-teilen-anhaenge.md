# Context: feat-399-teilen-anhaenge

## Request Summary
#399 „Anhänge zulassen — und als Ziel für Anhänge registrieren (iOS)“: Fotos und Dateien (PDF u. a.) aus dem
Teilen-Menü anderer Apps (Fotos, Dateien, Mail-Drucken, Safari-PDF …) landen als Anhang an einer Aufgabe. Der letzte
offene Teil von #442 (Henning 2026-10-15: „Fotos, Dateien/PDF, Dokument scannen und das Teilen-Menü“).

## Stand
- #442 Schnitt 1 (PR #450): Modell `TaskAttachment` (`externalStorage`, CloudKit-Schema in `cloudkit/schema.ckdb`).
- #442 Schnitt 2 (PR #454): Detailansicht — Foto, Datei, Vorschau (Quick Look), Löschen.
- #442 Scan (PR #457): Dokument scannen als PDF.
- Teilen-Erweiterung: nimmt nur Text, Links, Mails an. Ein Foto oder eine Datei aktiviert sie gar nicht.

## Related Files
| File | Relevance |
|------|-----------|
| `project.yml` (LooseEndsShare, `NSExtensionActivationRule`, Z. 256) | Aktivierungsregel nur `public.text`/`public.url`/`public.email-message` — muss Bilder und Dateien zulassen (Stufe 3) |
| `LooseEndsShare/ShareViewController.swift` (91 LoC) | `collect(from:)` liest je Provider Mail, URL, Text; Bild-/Dateidaten werden nicht geladen |
| `LooseEndsShare/ShareCaptureView.swift` (72 LoC) | Maske: Textfeld, Quell-Link, „Done“ nur mit Text; `save()` ruft `CaptureService.save` |
| `Shared/Services/SharedContent.swift` | reine Reduktion der geteilten Inhalte (prefill, sourceURL, channel); filtert Datei-URLs weg (#24/#291) |
| `Shared/Services/CaptureService.swift` | `save(_:via:sourceURL:in:)` legt `TaskItem` an, `TitleRule`; leerer Text → `CaptureError.emptyText` |
| `Shared/Models/TaskAttachment.swift` | Ziel-Modell: `data`, `fileName`, `typeIdentifier`, `createdAt`, `task` |
| `Shared/Services/AttachmentKind.swift` | `maximumBytes` 50 MB, `fits(_:)`, `symbol(for:)` — wiederverwendbar |
| `LooseEnds/Views/AttachmentsSection.swift` | Vorbild fürs Anlegen: Foto (`loadTransferable`, Name „Photo <Datum>“), Datei (`lastPathComponent`, UTType aus Endung), `add` prüft `fits` und speichert |
| `LooseEndsTests/SharedContentTests.swift` | bestehende Unit-Tests der Teilen-Reduktion |
| `LooseEndsShare/Localizable.xcstrings` | Texte der Erweiterung (neue Strings hier) |

## Existing Patterns
- Reine, testbare Logik in `Shared/Services` (`SharedContent`, `AttachmentKind`); die Erweiterung macht nur I/O.
- Anhang anlegen = `TaskAttachment(task:data:fileName:typeIdentifier:)` einfügen, vorher `AttachmentKind.fits`.
- Fehler beim Lesen eines Providers werden geloggt und übersprungen, nie fatal; Log nur Typen, nie Inhalt (#24 `probeLine`).
- Erweiterung speichert in den gemeinsamen Store (`ModelContainerFactory.make()`), App veredelt beim nächsten Start (ADR-4).

## Dependencies
- Upstream: `NSItemProvider` (`loadItem`/`loadFileRepresentation`/`loadDataRepresentation`), `UTType`, SwiftData-Store der App-Gruppe, CloudKit-Asset über `externalStorage`.
- Downstream: Detailansicht (`AttachmentsSection`) zeigt den Anhang; CloudKit trägt ihn zu den anderen Geräten. Kein Modell- und kein Schemawechsel nötig (Typ besteht schon).

## Existing Specs
- `docs/specs/spike-24-mail-ruecksprung.md` und `docs/context/spike-24-mail-ruecksprung.md`: Mail hat keinen Teilen-Knopf für ganze Mails; „Drucken → Teilen“ liefert ein PDF im Temp-Ordner der Erweiterung, deshalb verwirft `SharedContent` Datei-URLs (#291). Mit #399 kann genau dieses PDF als Anhang ankommen statt verworfen zu werden.

## Risks & Considerations
- **Speichergrenze der Erweiterung** (Share-Extensions haben deutlich weniger Speicher als die App; Wert recherchieren). Mehrere Fotos oder ein großes PDF auf einmal in `Data` laden kann die Erweiterung beenden. `AttachmentKind.maximumBytes` (50 MB) gilt je Anhang.
- **Wie kommen Fotos an:** als Datei-URL, als `UIImage` oder als `Data` — je nach Quell-App verschieden; HEIC aus Fotos. Recherche: Apples Empfehlung (`loadFileRepresentation` vs. `loadItem`).
- **Aktivierungsregel:** zu weit → Loose Ends erscheint überall (auch bei Typen, die wir nicht wollen); Begrenzung der Anzahl (`NSExtensionActivationSupportsImageWithMaxCount` usw. oder SUBQUERY). Nur `TRUEPREDICATE` ist für den Store verboten.
- **Leerer Text:** `CaptureService.save` verlangt Text, „Done“ ist ohne Text gesperrt. Bei nur einem Foto braucht es eine Regel für den Text (Produktfrage, z. B. Dateiname oder leer lassen und Nutzer tippt).
- **Neue Aufgabe vs. bestehende:** bisher legt die Erweiterung immer eine neue Aufgabe an (Produktfrage).
- **Stufe 3:** `project.yml` und `LooseEndsShare/` sind auf der Geräteliste → Nachweis über TestFlight auf Hennings iPhone. Der Simulator kann Fotos teilen, aber ein UI-Test der Teilen-Erweiterung ist aufwendig; Logik in `Shared/Services` unit-testen.
- **iPad** teilt dieselbe Erweiterung; Mac hat keine Teilen-Erweiterung (iOS only, Ticket sagt „(iOS)“).
- Nebenbefund, nicht Teil dieses Tickets: die versionierte `LooseEnds/Info.plist` auf main enthält `NSCameraUsageDescription` aus `project.yml` nicht; `generate` ergänzt sie lokal (Drift nach #457).

## Analysis

### Type
Feature

### Research (2026-10-17)
- Share extensions: ~120 MB memory (https://cur.at/sykla3a?m=web) → load one attachment at a time, never all as `Data`.
- `loadFileRepresentation` hands a temp URL valid only inside the handler → copy/read there. `loadItem(public.image)` returns URL, Data or UIImage depending on the source app (https://developer.apple.com/forums/thread/712179) → file representation, `loadDataRepresentation` as fallback.
- `TRUEPREDICATE` is rejected in review (https://www.nutrient.io/blog/hiding-action-share-extensions-in-your-own-apps/) → extend the existing SUBQUERY with `public.image` and `public.data` (covers PDF and other files).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Services/SharedAttachment.swift` | CREATE | pure value type (data/temp file, fileName, typeIdentifier, status ok/tooLarge/overLimit); title from file name (no extension, `_`/`-` → space); default photo name; 10-item cap; size check via `AttachmentKind.fits` |
| `Shared/Services/SharedContent.swift` | MODIFY | `attachments` field; prefill falls back to the file title only for a non-image file and only when no text/URL/mail; `isFileURL` filter stays |
| `Shared/Services/CaptureService.swift` | MODIFY | `save(..., attachments: [SharedAttachment] = [])` inserts `TaskAttachment`s; `emptyText` stays |
| `LooseEndsShare/ShareViewController.swift` | MODIFY | per-provider loading helper (image/pdf/data via `loadFileRepresentation`, size check before reading, sequential), keeps `collect` ≤ 50 LoC |
| `LooseEndsShare/ShareCaptureView.swift` | MODIFY | „Anhänge“ section: SF Symbol (`AttachmentKind.symbol`), name, size; grey row with reason for skipped items |
| `project.yml` | MODIFY | activation rule + `public.image`, `public.data` (no count cap in the rule; cap in code with a visible reason) |
| `LooseEndsShare/Localizable.xcstrings` | MODIFY | „Attachments“, „Too large (over 50 MB), not attached“, „More than 10, not attached“ |
| `LooseEndsTests/SharedAttachmentTests.swift`, `SharedContentTests.swift`, CaptureService tests | CREATE/MODIFY | pure rules + save with attachments in an in-memory container |

### Scope Assessment
- Files: ~8 incl. tests, Estimated LoC: +300–350 → over the limit → **two cuts**:
  - **Schnitt 1 (pure + save path):** `SharedAttachment`, `SharedContent`, `CaptureService` + unit tests. No visible change.
  - **Schnitt 2 (extension):** loading, form section, activation rule, strings. Stage 3 (`project.yml`, `LooseEndsShare/` on the device list) → TestFlight on Henning's iPhone.
- Risk Level: MEDIUM (memory limit of the extension, App Review on the predicate, source apps deliver differently).

### Technical Approach
- New task only (as today). Photos: text empty, field focused, „Fertig“ disabled until text. Files: file name without extension as prefill.
- Memory: copy each temp file into the extension's own temp folder during collect (no `Data` held); on save insert the task and the attachments one by one, reading each file only when inserting; sizes > 50 MB are never read (size via `resourceValues(.fileSizeKey)`).
- Mail „Drucken → Teilen“ PDF (#24) becomes an attachment instead of being dropped; its name is checked on the device.
- Activation rule changed last, so the extension never shows up before it can handle the input.
- Simulator: Photos app share works there (stage 2 evidence: screenshot of the form + the attachment in the detail). Device/TestFlight only: real memory, HEIC/Live Photo, Mail print PDF, iCloud sync, App Review of the predicate.

### Alternatives (shown in the draft)
- B: thumbnails + „Fertig“ without text, title „Foto <Datum>“ → would drop the „no task without text“ rule (`CaptureError.emptyText`) for one channel.
- C: attach to an existing task → own flow (search, pick), own ticket if missed.

### Draft
`docs/artifacts/feat-399-teilen-anhaenge/entwurf.html` → https://claude.ai/artifact/PXMwhP62kKH6M2k9g8GbDZ. „Heute“ is still a rebuild from code; the real screenshot of today's mask is taken in the stage-2 simulator run of Schnitt 2, next to the new mask.

### Open Questions
- [x] Henning 2026-10-17: **Entwurf A** (Zeilen unter dem Text, Foto: Feld leer und Fertig erst mit Text, Datei: Dateiname als Vorschlag, immer neue Aufgabe). B und C nicht bauen; C nur als eigenes Ticket, falls er es vermisst.
