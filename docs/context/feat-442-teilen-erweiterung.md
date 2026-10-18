# Context: feat-442-teilen-erweiterung

## Request Summary
#442 (Detail: Anhänge an einer Aufgabe), letzter offener Teil: Das Teilen-Menü nimmt Fotos und Dateien an und legt sie
an eine neue Aufgabe (aus #399, dort geschlossen und in #442 aufgegangen). Schnitt 1 (Regeln, Speicherweg) ist gemergt
(PR #517); dies ist **Schnitt 2: die Erweiterung selbst**.

## Stand auf main (aac08c4)
- Gemergt: Modell `TaskAttachment` (#450), Detailansicht mit Foto/Datei/Vorschau/Löschen (#454), Scan (#457),
  `SharedAttachment`, `SharedContent.make(attachments:)`, `CaptureService.save(attachments:)` (#517).
- Offen: `LooseEndsShare/` lädt noch nichts; `project.yml` aktiviert die Erweiterung nur für Text, Link, Mail.
- Kein offener PR berührt das (nur #522, Widget). Kameratext `NSCameraUsageDescription` steht in `project.yml` Z. 90 (der lose Diff in
  `LooseEnds/Info.plist` im Arbeitsbereich war Generierungsrest und ist zurückgesetzt).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsShare/ShareViewController.swift` (91 LoC) | `collect(from:)` kennt Mail, URL, Text; hier kommt das Laden von Bild/Datei dazu (sequenziell, `loadFileRepresentation`, Kopie in eigenen Temp-Ordner, Größe vor dem Lesen) |
| `LooseEndsShare/ShareCaptureView.swift` (72 LoC) | Maske: Zeilengruppe „Anhänge“, `save()` reicht Anhänge an `CaptureService.save(attachments:)`; Fertig-Regel bleibt „Text nötig“ |
| `LooseEndsShare/Localizable.xcstrings` | neue Texte (Anhänge, zu groß, mehr als 10) |
| `project.yml` Z. 256 | `NSExtensionActivationRule` um `public.image` und `public.data` erweitern, als Letztes |
| `Shared/Services/SharedAttachment.swift`, `SharedContent.swift`, `CaptureService.swift`, `AttachmentKind.swift` | fertig aus Schnitt 1, unverändert nutzbar (`classify`, `photoFileName`, `title(fromFileName:)`, `symbol(for:)`) |
| `docs/specs/feat-399-schnitt-1-anhang-speichern.md` | Teil-Spec Schnitt 1, listet, was Schnitt 2 liefert |
| `docs/artifacts/feat-399-teilen-anhaenge/entwurf.html` | freigegebener Entwurf A (Henning 2026-10-17) |

## Existing Patterns
- Reine Logik in `Shared/Services`, die Erweiterung macht nur I/O. Fehler je Provider werden geloggt und übersprungen, Log nur Typen (`probeLine`).
- Speichern über `ModelContainerFactory.make()`, Container lebt über den ganzen Speichervorgang.
- Temp-Dateien räumt die Erweiterung auf (`save` löscht sie nicht, Spec Schnitt 1).

## Dependencies
- Upstream: `NSItemProvider` (`loadFileRepresentation`), `UTType`, App-Gruppe/CloudKit-Store.
- Downstream: `AttachmentsSection` im Detail zeigt die Anhänge; CloudKit trägt sie zu den Geräten. Kein Modell-/Schemawechsel.

## Research (2026-10-17 aus Schnitt 1, 2026-10-18 bestätigt)
- Aktivierungsregel: String wird als `NSPredicate` gelesen; SUBQUERY mit `UTI-CONFORMS-TO` ist üblich, `TRUEPREDICATE` wird im Review abgelehnt
  (https://www.nutrient.io/blog/hiding-action-share-extensions-in-your-own-apps/). Forum meldet Fehler bei Zählgrenzen
  (https://developer.apple.com/forums/thread/838151, 838066) → keine Anzahl in der Regel, Grenze im Code mit sichtbarem Grund.
- `loadFileRepresentation` liefert eine Temp-Datei, nur im Handler gültig → dort kopieren (https://developer.apple.com/documentation/foundation/nsitemprovider.md).
  Quellen liefern Fotos unterschiedlich (https://developer.apple.com/forums/thread/712179) → Dateirepräsentation, Daten als Rückfall.
- Speicher der Erweiterung begrenzt → nie alle Anhänge als `Data` halten.

## Existing Specs
- `docs/specs/feat-399-schnitt-1-anhang-speichern.md`; `docs/specs/spike-24-mail-ruecksprung.md` (Mail „Drucken → Teilen“ liefert ein PDF im Temp-Ordner;
  bisher verworfen, wird mit Schnitt 2 zum Anhang).

## Risks & Considerations
- **Stufe 3 Pflicht** (`project.yml`, `LooseEndsShare/`): Nachweis über TestFlight auf Hennings iPhone, nichts auf seinen Geräten ohne sein „jetzt ist ein Test möglich“.
- Aktivierungsregel zu weit → App erscheint bei Typen, die wir nicht wollen; zu eng → fehlt. Review-Risiko beim Prädikat.
- Speichergrenze bei großen PDFs/vielen Fotos; Fotos als HEIC/Live Photo je nach Quell-App.
- Aktivierungsregel zuletzt ändern, damit die Erweiterung nie vor ihrer Fähigkeit erscheint.
- Simulator kann Fotos teilen (Stufe 2: Maske und Anhang im Detail fotografieren); Speicher, Mail-Druck-PDF, iCloud-Abgleich nur auf dem Gerät.
- LoC: geschätzt ~150–200 in 4 Dateien (ViewController, CaptureView, Strings, project.yml) plus Tests der Ladehelfer, falls rein auslagerbar.

## Alternativen
- Nur Dateien annehmen, Fotos weiter nur im Detail (kleiner, aber von Henning ausdrücklich gewollt).
- An bestehende Aufgabe hängen statt neue (eigener Ablauf, falls er es vermisst: eigenes Ticket).

## Analysis

### Type
Feature (Schnitt 2 von #442/#399: die Teilen-Erweiterung nimmt Fotos und Dateien an)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsShare/ShareViewController.swift` | MODIFY | `collect(from:)`: Bild/Datei per `loadFileRepresentation`, im Handler in eigenen Temp-Ordner kopieren, Größe vor dem Lesen, Daten als Rückfall; Fehler je Provider loggen und überspringen; `SharedAttachment.classify` auf die Liste |
| `LooseEndsShare/ShareCaptureView.swift` | MODIFY | Zeilengruppe „Anhänge“ (Entwurf A), Hinweise „zu groß“ / „mehr als 10“; `save()` ruft `CaptureService.save(attachments:)`; Fertig-Regel bleibt „Text nötig“; Temp-Dateien nach Speichern/Abbruch löschen |
| `LooseEndsShare/Localizable.xcstrings` | MODIFY | neue Texte |
| `project.yml` | MODIFY | `NSExtensionActivationRule` um `public.image` und `public.data` erweitern, als Letztes |
| `LooseEndsTests/` (Ladehelfer, falls rein auslagerbar) | CREATE | Test der Kopier-/Größenlogik ohne `NSItemProvider` |
| `Shared/Services/*` (`SharedAttachment`, `SharedContent`, `CaptureService`, `AttachmentKind`) | unverändert | fertig aus Schnitt 1 (PR #517) |

### Scope Assessment
- Files: 4 Produktdateien + 1 Testdatei
- Estimated LoC: +150–200 / −10
- Risk Level: MEDIUM (Aktivierungsregel und Speicher der Erweiterung nur auf dem Gerät belegbar; kein Modell-/Schemawechsel)

### Technical Approach
Ohne Modell, reine Regeln: Typ-Entscheidung, Größe und Grenze sind in Schnitt 1 fertig und getestet; hier kommt nur I/O dazu.
1. Je Provider sequenziell `loadFileRepresentation` (Typ: erstes `public.image`, sonst `public.data` bzw. das Registrierte); Datei im Handler in einen eigenen Temp-Ordner kopieren (die gelieferte Datei ist nur dort gültig). Größe per `resourceValues` vor dem Lesen, nie `Data` halten.
2. Fotos ohne Dateinamen bekommen `photoFileName`; Mail „Drucken → Teilen“ liefert ein PDF und wird so zum Anhang (Spike #24).
3. `classify` setzt `ready`/`tooLarge`/`overLimit`; Maske zeigt Vorschau-Zeilen mit Symbol (`AttachmentKind.symbol(for:)`), SF Symbols outline.
4. Speichern mit Container über die ganze Dauer; danach Temp-Ordner entfernen (auch bei Abbruch).
5. Aktivierungsregel zuletzt, ohne Zählgrenze (Forum meldet Fehler), `UTI-CONFORMS-TO`, kein `TRUEPREDICATE`.

**Alternativen:** (a) nur Dateien, Fotos weiter nur im Detail — kleiner, aber von Henning ausdrücklich gewollt, verworfen; (b) Anhang an bestehende Aufgabe statt neue — eigener Ablauf, bei Bedarf eigenes Ticket; (c) `loadTransferable` mit eigenem `Transferable`-Typ statt `loadFileRepresentation` — moderner, aber im Erweiterungsspeicher schwerer zu begrenzen. Keine ADR wird gekippt.

### Befunde, die gegen den Plan sprechen
Keine, die den Weg ändern. Offene Risiken: Fotos als HEIC/Live Photo je nach Quell-App; Speichergrenze bei großen PDFs; Prädikat im Review.

### Dependencies
`NSItemProvider`, `UTType`, App-Gruppe/CloudKit-Store, `AttachmentsSection` im Detail zeigt das Ergebnis. Kein offener PR berührt den Bereich (Stand origin/main = aac08c4).

### Abnahme
Stufe 2: Simulator teilt Foto → Maske fotografieren → Anhang im Detail fotografieren. Stufe 3 Pflicht (`project.yml`, `LooseEndsShare/`): über TestFlight, nichts auf Hennings Geräten ohne sein „jetzt ist ein Test möglich“.

### Open Questions
- [ ] keine Produktfrage offen (Entwurf A am 2026-10-17 freigegeben, Entscheidungen aus Schnitt 1 gelten)
