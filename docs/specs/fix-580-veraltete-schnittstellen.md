---
entity_id: fix-580-veraltete-schnittstellen
type: bugfix
created: 2026-10-24
updated: 2026-10-24
status: draft
workflow: fix-580-veraltete-schnittstellen
---

# Spec: #580 — Veraltete Schnittstellen im iOS-27-Bau ersetzen (Share, Detailansicht, Hintergrundabgleich)

## Approval

- [ ] Approved (Henning)

## Purpose

Der Bau mit dem iOS-27-SDK meldet sechs Warnungen über veraltete Schnittstellen (Meilenstein M3, kein Epic). Sie werden ersetzt; das
Verhalten bleibt gleich: Teilen von Text, Link, Mail, Foto und Datei, die Detailansicht, die tägliche Neuplanung der
Mitteilungen. Es ist kein Fehler im Betrieb, also keine Reproduktion; der Nachweis ist der Bau ohne die sechs Zeilen und der
unveränderte Ablauf.

**Hat es bisher funktioniert?** Ja. Alle drei Stellen laufen unverändert; nur das SDK stuft sie jetzt als veraltet ein.

### Die sechs Warnungen (frisch aus dem Bau vom 2026-10-24, nicht aus dem Ticket; dessen Zeilen sind verschoben)

| Stelle | Warnung (Wortlaut des SDK) |
|---|---|
| `LooseEndsShare/ShareViewController.swift:74` (Mail), `:78` (URL), `:82` (Text) | `loadItem(forTypeIdentifier:options:)` was deprecated in iOS 27.0: Use `loadObjectOfClass:completionHandler:` instead |
| `LooseEnds/Views/TaskDetailView.swift:151`, `:152` | `+` was deprecated in iOS 26.0: Use string interpolation on `Text` instead |
| `LooseEnds/Notifications/BackgroundRefresh.swift:40` | `submit` was deprecated in iOS 27.0: Use `submitTaskRequest(_:completionHandler:)` (or `try await submitTaskRequest(_:)`) to capture all error conditions |

### Recherche (zuerst, mit Quellen)

- `Text +`: Ersatz ist ein einziger `Text` mit Interpolation; ein gestalteter `Text` darf darin stehen. Grund laut Apple: feste
  Wortreihenfolge schadet Lokalisierung und Rechts-nach-links.
  https://developer.apple.com/documentation/swiftui/text/+(_:_:).md ·
  https://nilcoalescing.com/blog/TextConcatenationVsTextInterpolationInSwiftUI ·
  https://www.hackingwithswift.com/forums/100-days-of-swiftui/day-71-text-interpolation-deprecated-on-ios-26/30390
- `submit`: Ersatz `submitTaskRequest(_:completionHandler:)`, ab iOS 27. Die Header-Zeile „nicht vom Main-Thread aufrufen“ ist
  laut Apple-DTS falsch: „The new API is definitely intended to support being called from any thread, including the main
  thread“ (Bug FB24179736).
  https://developer.apple.com/tutorials/data/documentation/backgroundtasks/bgtaskscheduler/submittaskrequest(_:completionHandler:).md ·
  https://developer.apple.com/forums/thread/840876. Ein async-Überlad steht nur in der SDK-Warnung, nicht in der Doku. Ein
  Forenbericht zu einem XPC-Fehler unter iOS 27 ist ein Einzelfall ohne Apple-Bestätigung.
- `loadItem`: Die Veraltung steht nur in der SDK-Warnung. `loadObject(ofClass:)` gibt es für `NSItemProviderReading`-Klassen
  (URL, String); `loadDataRepresentation` und `loadFileRepresentation` sind die Wege für alles andere.
  https://developer.apple.com/documentation/foundation/nsitemprovider.md

Regelweg-Vermerk (Regeln vor Modell): Kein Modell beteiligt. Reine Ablösung von Systemschnittstellen und eine
Byte-zu-Text-Dekodierung; die Frage „ohne Modell geht es nicht, weil …“ stellt sich nicht.

## Source

| Datei | Änderung |
|---|---|
| `LooseEndsShare/ShareViewController.swift` | drei `loadItem`-Zweige ersetzt: URL und Text über `loadObject` (Text mit Rückfall auf `loadDataRepresentation`), Mail über `loadDataRepresentation`; `loadedKind(_:branch:)` und `string(from:)` entfallen |
| `Shared/Services/SharedContent.swift` | neue reine Funktion `decode(_ data: Data) -> String` (UTF-8, sonst Latin-1); sie steht neben der bestehenden privaten `decode(_:charset:) -> String?` (Z. 129, Mail-Kopfzeilen) und ersetzt sie nicht |
| `LooseEndsTests/SharedContentTests.swift` | Tests für `decode` |
| `LooseEnds/Views/TaskDetailView.swift` | „Said“-Zeile als ein `Text` mit zwei gestalteten `Text`-Werten in der Interpolation |
| `LooseEnds/Notifications/BackgroundRefresh.swift` | `submitTaskRequest(_:completionHandler:)`, Fehler im Handler geloggt |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEndsShare/ShareViewController.swift` | MODIFY | siehe Verhaltensgleichheit unten |
| `Shared/Services/SharedContent.swift` | MODIFY | neue Überladung `decode(_:)`, ihr Datenzweig stammt aus `string(from:)` in `ShareViewController.swift` (dort entfällt es) |
| `LooseEndsTests/SharedContentTests.swift` | MODIFY | vier Dekodierungsfälle und ein Mail-Kettentest (fünf Tests) |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | Z. 148-157, ein `Text` statt `+` |
| `LooseEnds/Notifications/BackgroundRefresh.swift` | MODIFY | `schedule()` Z. 35-44 |

Geschätzt **+70 / −50 LoC**, **5 Dateien**, innerhalb der Scoping-Limits (4–5 Dateien, ±250 LoC). Der Katalog
`LooseEnds/Resources/Localizable.xcstrings` wird nicht angefasst (Entscheidung E3 unten; wäre sonst die sechste Datei).

**Geräteliste berührt:** `LooseEndsShare/` und `LooseEnds/Notifications/`. Stufe 3 (Hennings iPhone, über TestFlight) ist
Pflicht, aber **nur nach seinem wörtlichen „jetzt ist ein Test möglich“**. „Kein Pfad der Geräteliste berührt“ gilt hier nicht.

**Side-Effects:** Keine Änderung an Info.plist, Entitlements, `project.yml`, AppStorage-Schlüsseln, Datenmodell,
CloudKit-Schema, Texten (der Katalogschlüssel „Said“ bleibt, wie er ist), Audio-Dateien oder Berechtigungen. Keine neue
Abhängigkeit. Sichtbar ändert sich nichts. Die Probenzeile (#24 AC-1) kann für Text und Mail den Wert `loaded=` anders
benennen (siehe E1), ihr Vertrag bleibt.

### Nicht in diesem Ticket

- Foto- und Datei-Anhänge (`attachment(from:type:into:)`, `loadFileRepresentation`): unverändert, dort steht keine Warnung.
- Der Zweig `item.attributedContentText` am Kopf von `collect` (Text, den die Absender-App als Beschreibung mitgibt): unverändert.
- `SharedContent.make`, Kopfzeilen-Parser, Kanalwahl: unverändert.

## Implementation Details

### 1. BackgroundRefresh

```swift
BGTaskScheduler.shared.submitTaskRequest(request) { error in
    if let error {
        logger.error("Scheduling the background refresh failed: \(error, privacy: .public)")
    }
}
```

`schedule()` bleibt `static`, synchron und `@MainActor`; die drei Aufrufer (Register-Handler, App-Wechsel in den
Hintergrund, nach jedem Lauf) ändern sich nicht. Apple-DTS bestätigt den Aufruf vom Hauptthread. Der `do/catch` entfällt;
der Fehler, den `submit` früher beim Aufruf warf, kommt jetzt im Handler an und wird geloggt, nie verschluckt, kein `try?`.
Ob der Handler auf einem anderen Strang läuft: `logger` ist `Sendable`, der Handler fasst nichts Isoliertes an.

### 2. TaskDetailView („Said“-Zeile)

Ein einziger `Text` per Interpolation, zwei gestaltete `Text`-Werte darin:

```swift
let head = Text(String(localized: "Said").uppercased())
    .font(.caption2.weight(.semibold))
    .tracking(1)
let said = Text(task.rawText)
    .font(.system(.subheadline, design: .serif))
    .italic()
Text("\(head)  \(said)")
    .foregroundStyle(.secondary)
    .accessibilityLabel(task.rawText)
    .accessibilityIdentifier("detailRawText")
```

Stile, `foregroundStyle`, die zwei Leerzeichen (laufender Satz, #438), `accessibilityLabel(task.rawText)` und die Kennung
`detailRawText` bleiben wie heute. Die Kennung `detailRawTextMarker` darüber (Z. 136-141) bleibt unangetastet.

### 3. Share — `loadItem` ablösen, Verhaltensgleichheit

`loadItem` lieferte je nach Absender einen von vier Werten (`URL`, `Data`, `String`, `NSAttributedString`) oder eine
Datei-URL; `loadedKind`/`string(from:)` werteten alle aus. `loadObject(ofClass:)` liefert genau die gewünschte Klasse oder
scheitert. Damit nichts still wegfällt, ist jeder heutige Fall einzeln zugeordnet:

| Heutiger Fall (aus `loadItem`) | Neuer Weg | Bleibt erhalten? |
|---|---|---|
| URL-Zweig: Wert ist `URL` (Web- oder `message://`-Link) | `loadObject(ofClass: URL.self)`, Art `url` | ja |
| URL-Zweig: Wert ist Datei-URL (Art `file`; `make` verwirft sie später) | `loadObject(URL.self)` liefert sie ebenso; Art `file`, wenn `isFileURL` | ja, identisch |
| URL-Zweig: Wert ist `Data` (Art `data`, heute **ohne** URL — nichts wird übernommen) | `loadObject` scheitert oder liefert eine URL; Fehler geloggt, Art `none` | ja: auch heute entsteht daraus keine URL |
| Text-Zweig: Wert ist `String` | `loadObject(ofClass: String.self)`, Art `text` | ja |
| Text-Zweig: Wert ist `NSAttributedString` | `loadObject(String.self)` bekommt den Klartext; zusätzlich bleibt der Kopf-Zweig `item.attributedContentText` | ja |
| Text-Zweig: Wert ist `Data` | Rückfall `loadDataRepresentation(plainText)` → `SharedContent.decode`, Art `data` | ja |
| Text-Zweig: Wert ist Datei-URL, deren Inhalt als Text gelesen wird | derselbe Rückfall `loadDataRepresentation`: sie liefert den Dateiinhalt, ohne dass die Erweiterung die Datei selbst öffnen muss | ja; gleich oder besser (Latin-1 statt nur UTF-8, siehe E2) |
| Mail-Zweig: `Data` (RFC 822) | `loadDataRepresentation(emailMessage)` → `decode`, Art `data` | ja |
| Mail-Zweig: Datei-URL, Inhalt als Text gelesen | dieselbe `loadDataRepresentation` (liefert den Dateiinhalt) | ja |
| Mail-Zweig: `String`/`NSAttributedString` | entfällt als eigener Fall: ein Mailtyp (`emailMessage`) liefert Bytes, keine Zeichenkette; das Anbieten als String wurde nie beobachtet (siehe Probenzeilen aus #24) | bewusst, begründet |

Ablauf je Zweig, in der heutigen Reihenfolge (Anhang vor Mail vor URL vor Text, `hasItemConformingToTypeIdentifier`):

- Mail: `loadDataRepresentation(forTypeIdentifier: UTType.emailMessage.identifier)`, mit `withCheckedThrowingContinuation`
  (Muster der Anhänge, `ShareViewController.swift:127`); Bytes → `SharedContent.decode` → `mails`.
- URL: `loadObject(ofClass: URL.self)`; ein Fehler wird per `logFailure` (Domäne und Code, nie Inhalt) geloggt.
- Text: `loadObject(ofClass: String.self)`; scheitert es, einmaliger Rückfall `loadDataRepresentation(forTypeIdentifier:
  UTType.plainText.identifier)` → `decode`. Scheitert auch das, wird geloggt und der Anbieter übersprungen (wie heute: nie fatal).
- Gibt das SDK `loadObject(ofClass:)` als `async throws` ohne Warnung her, darf es statt des Rückrufs mit Continuation
  genutzt werden; der Entwickler wählt, was warnungsfrei baut.

`SharedContent.decode(_ data: Data) -> String`: UTF-8; ist die Folge kein gültiges UTF-8, ISO-Latin-1 (das jede
Bytefolge abbildet). Leere Daten ergeben `""` wie heute (`String(data: Data(), encoding: .utf8)` ist `""`); `make` trimmt
und verwirft leere Texte, eine leere Mail bleibt wie bisher eine Mail ohne Betreff. Es entsteht kein Optional.

**Probenzeile (#24 AC-1):** `SharedContent.probeLine(typeIdentifiers:loaded:)` bleibt unverändert; sie loggt weiter nur
Typkennungen und Art (`url`, `file`, `text`, `data`, `file`/`data` bei Anhängen, `none`), nie Inhalt. Art ist künftig: URL-Zweig
`url`/`file`, Text-Zweig `text` (über `loadObject`) oder `data` (Rückfall), Mail-Zweig `data`. Der frühere Wert `mail` als
Zweigname entfällt; er kam heute nur vor, wenn `loadItem` einen unerwarteten Typ lieferte.

### Entscheidungen über die Analyse hinaus (begründet)

- **E1 — Text mit Rückfall, URL und Mail ohne:** Die Analyse nannte den Rückfall nur als Option für die URL. Beim Lesen des
  Codes zeigt sich, dass `string(from:)` für Text vier Wertarten annahm (String, NSAttributedString, Data, Datei-URL). Weil
  `loadObject(String)` nur dort greift, wo der Anbieter den Typ als String liefert, bekommt der Text-Zweig den Rückfall auf
  `loadDataRepresentation`. Die URL hat heute für `Data` keinen Weg zu einer URL (Verhalten unverändert), die Mail liest ohnehin
  Bytes; beide brauchen keinen Rückfall. Ein Rückfall für die URL (Analyse: „bleibt Rückfall, falls `loadObject(URL)` auf dem
  Gerät fehlschlägt“) wird nicht vorab gebaut, sondern erst, wenn Stufe 3 einen Absender nennt, der sonst verloren geht.
- **E2 — Latin-1 auch für gelesene Dateien:** Heute las der Datei-URL-Fall nur UTF-8; die Datenwege fielen auf Latin-1 zurück.
  Mit einem Weg (`loadDataRepresentation` + `decode`) gilt überall UTF-8, sonst Latin-1. Das ist eine kleine Erweiterung (statt
  ein Text-Verlust bleibt ein lesbarer Text), kein Verlust.
- **E3 — Kein Katalogeintrag:** Die Interpolation `Text("\(head)  \(said)")` erzeugt den Schlüssel `%@  %@`. Der Katalog ist
  von Hand gepflegt und enthält Schlüssel nur mit Übersetzung; ein fehlender Schlüssel setzt die Zeichenfolge unverändert ein,
  und mit zwei `Text`-Argumenten ist sie sprachneutral. Es wird **kein** Eintrag angelegt. **Entscheidungsregel:** Zeigt der
  Bau einen Diff an `LooseEnds/Resources/Localizable.xcstrings` oder der CI-Schritt „Generate leaves the tree clean“
  (`.github/workflows/ci.yml`) wegen des Schlüssels einen Fehler,
  oder bricht die Zeile im Screenshot anders um, wird die Zeile als `AttributedString` mit zwei Läufen gebaut (Alternative
  unten), ohne neuen Schlüssel; bleibt trotzdem ein Katalog-Diff, kommt der Eintrag als sechste Datei dazu und wird im
  Abschlussbericht genannt.

## Test Plan

### Automated Tests (TDD RED zuerst)

Unit-Tests in `LooseEndsTests/SharedContentTests.swift` (Swift Testing, Suite `SharedContent`), RED vor `decode`:

- `decodesUTF8`: „Überweisung für Müll“ als UTF-8-Bytes ergibt denselben Text, Umlaute unverändert.
- `decodesLatin1WhenNotUTF8`: Bytes `0xC4 0x70 0x66 0x65 0x6C` („Äpfel“ in Latin-1, ungültiges UTF-8) ergeben „Äpfel“.
- `decodesEmptyToEmptyString`: leere `Data` ergibt `""`, kein Absturz.
- `decodesInvalidSequenceWithoutLoss`: eine bewusst ungültige Folge (`0xFF 0xFE 0x41`) ergibt einen String der Länge 3
  (Latin-1 bildet jedes Byte ab), nie `nil` und kein Absturz.
- Ein Test, dass `decode` eine Mail liefert, die `subject(ofMail:)` und `messageURL(ofMail:)` weiter lesen (UTF-8 mit Umlaut im
  Betreff-Encoded-Word), schließt die Kette Bytes → Betreff.

Bestehende Tests bleiben grün: alle `SharedContentTests`, `SharedAttachmentFileTests`, UI-Tests mit `detailRawText`
(`accessibilityIdentifier` und Label unverändert), `./scripts/sim.sh unit` komplett.

Warnungsfreiheit ist messbar: Das Bau-Log von `./scripts/sim.sh build` enthält keinen der sechs Warnungstexte
(`loadItem(forTypeIdentifier:options:)` was deprecated, `'+' was deprecated in iOS 26.0`, `'submit' was deprecated`); Beleg per
`grep` auf das Log, Ergebnis 0 Treffer. Gilt für App und Share-Erweiterung.

### Abnahme (Stufen)

1. **Tests:** `decode`-Tests rot, dann grün; voller Unit-Lauf `./scripts/sim.sh unit` grün; Bau ohne die sechs Warnungen.
2. **Simulator:** `./scripts/sim.sh build`, `launch`; Detailansicht einer Aufgabe mit abweichendem Rohtext als Screenshot
   **vorher (main) und nachher**, beide geöffnet und beschrieben (muss dasselbe Bild sein); UI-Test mit `detailRawText` per
   `./scripts/sim.sh test-proof` grün. Das Teilen zeigt der Simulator nur eingeschränkt (Safari-Link und Notizen-Text gehen
   über das Teilen-Blatt, Mail, Fotos und Dateien kaum), der Simulator-Teil wird so weit wie möglich gespielt.
3. **Gerät (Pflicht, `LooseEndsShare/` und `LooseEnds/Notifications/` stehen auf der Geräteliste):** Über TestFlight in
   Hennings normaler App, **erst nach seinem wörtlichen „jetzt ist ein Test möglich“**; vorher wird nichts auf einem seiner
   Geräte gestartet, auch nichts Lesendes. Henning bekommt Buildnummer und Prüfschritte (AC-12 bis AC-17), keine
   Befehlszeile; seine Rückmeldung schließt die Geräte-ACs.

## Acceptance Criteria

- **AC-1:** Das Bau-Log von `./scripts/sim.sh build` (iOS-App und Share-Erweiterung, iOS-27-SDK) enthält keine der sechs
  Warnungen aus der Tabelle oben (0 Treffer); der Bau ist erfolgreich.
- **AC-2:** `BackgroundRefresh.schedule()` ruft `submitTaskRequest(_:completionHandler:)` auf; ein Fehler im Handler wird mit
  `logger.error` geloggt. Es gibt weder `try?` noch einen leeren `catch`. `schedule()` bleibt `static`, synchron und
  `@MainActor`, die Aufrufer sind unverändert; unter Tests (`isRunningTests`/`isUITesting`) bleibt die Funktion stumm.
- **AC-3:** Die „Said“-Zeile in der Detailansicht ist **ein** `Text` (Interpolation zweier gestalteter `Text`-Werte, kein
  `+`): Kopf in `caption2` semibold, Zeichenabstand 1, Großbuchstaben; Rohtext in Serif `subheadline` kursiv; zwei Leerzeichen
  dazwischen; zweite Zeile beginnt am Rand; Farbe `.secondary`. Der Screenshot nachher gleicht dem vorher (Simulator).
- **AC-4:** Die Zeile trägt weiter `accessibilityLabel(task.rawText)` und die Kennung `detailRawText`; der Marker
  `detailRawTextMarker` ist unverändert; die bestehenden UI-Tests, die den Rohtext suchen, bleiben grün.
- **AC-5:** `SharedContent.decode(_:)` liefert für UTF-8-Bytes den Text, für ungültiges UTF-8 den Latin-1-Text, für leere Daten
  `""` und für eine beliebige Bytefolge nie `nil` und nie einen Absturz; die Unit-Tests dazu (UTF-8, Latin-1, leer, ungültig)
  sind grün.
- **AC-6:** Der URL-Zweig lädt über `loadObject(ofClass: URL.self)`; ein Web- oder `message://`-Link kommt als URL in
  `SharedContent` an (Kanal `share`/`mail` wie heute); eine Datei-URL wird weiter von `make` verworfen; ein Ladefehler wird mit
  Domäne und Code geloggt (nie Inhalt) und nie fatal.
- **AC-7:** Der Text-Zweig lädt über `loadObject(ofClass: String.self)` und fällt bei Fehlschlag einmal auf
  `loadDataRepresentation(forTypeIdentifier: plainText)` mit `decode` zurück; Text als `String`, als `NSAttributedString`
  (Klartext), als `Data` und als gelesener Dateiinhalt kommt wie heute als `texts` an.
- **AC-8:** Der Mail-Zweig lädt über `loadDataRepresentation(forTypeIdentifier: emailMessage)` und dekodiert mit `decode`;
  Betreff, `message://`-Link und Kanal `mail` entstehen wie heute (`subject(ofMail:)`, `messageURL(ofMail:)` unverändert).
- **AC-9:** Reihenfolge der Zweige (Anhang, Mail, URL, Text), Foto- und Datei-Anhänge, der Kopf-Zweig
  `attributedContentText` und `SharedContent.make` sind unverändert; `loadedKind(_:branch:)` und `string(from:)` sind entfernt,
  nichts ruft sie noch.
- **AC-10:** Die Probenzeile (#24 AC-1) enthält weiter nur Typkennungen und die Art des geladenen Werts, niemals Inhalt (Text,
  Betreff, URL, Dateiname); `SharedContent.probeLine` und sein bestehender Test sind unverändert grün.
- **AC-11:** Der volle Unit-Lauf (`./scripts/sim.sh unit`) und `./scripts/sim.sh test-proof` für die Klasse mit `detailRawText`
  sind grün; der Diff berührt nur die fünf genannten Dateien, keine Info.plist, Entitlements, `project.yml`, AppStorage-Schlüssel
  oder Katalogdatei (außer laut Entscheidung E3, dann genannt).
- **AC-12 (Gerät):** Nach Hennings ausdrücklichem „jetzt ist ein Test möglich“ erscheint beim Teilen eines **Links aus Safari**
  in „Loose Ends“ das Erfassungsformular mit Titel (Seitentitel oder Link) und dem Link als Quelle.
- **AC-13 (Gerät):** Beim Teilen von **Text aus Notizen** steht der Text im Formular, mit Umlauten unverändert.
- **AC-14 (Gerät):** Beim Teilen einer **Mail** aus Mail steht der Betreff im Formular, Kanal Mail, der Rücksprung-Link
  (`message://`) ist gesetzt; ein Betreff mit Umlauten bleibt unverändert.
- **AC-15 (Gerät):** Beim Teilen eines **Fotos** aus Fotos hängt es als Anhang an, ohne dass das Textfeld etwas vorbelegt.
- **AC-16 (Gerät):** Beim Teilen einer **Datei** aus Dateien (z. B. PDF) hängt sie als Anhang an, der Dateiname dient als Titel.
- **AC-17 (Gerät, eingeschränkt belegbar):** Die App startet unter TestFlight und wechselt in den Hintergrund ohne Absturz; die
  tägliche Neuplanung ist weiterhin eingeplant. Ein Fehler beim Einplanen steht im Protokoll (`logger.error`), das TestFlight
  nicht liefert; der Beleg ist daher der Code-Pfad (AC-2) und Hennings Beobachtung, dass die Mitteilungen auch nach mehreren
  Tagen ohne App-Öffnen weiter pünktlich kommen (kein harter Beleg, nur Abwesenheit eines Fehlers).

## Dependencies

| Komponente | Beschreibung |
|---|---|
| `NSItemProvider` (Foundation) | `loadObject(ofClass:)`, `loadDataRepresentation(forTypeIdentifier:)` |
| `BGTaskScheduler` (BackgroundTasks) | `submitTaskRequest(_:completionHandler:)`, ab iOS 27 |
| SwiftUI `Text` | Interpolation gestalteter `Text`-Werte |
| `SharedContent` (`Shared/Services/`) | `make`, `probeLine`, Kopfzeilen-Parser, neu `decode` |
| `Localizable.xcstrings` | Schlüssel „Said“ unverändert |

Keine neue Abhängigkeit.

## Risiken

- **Teilen ist der einzige Pfad, den der Simulator kaum zeigt (mittel):** Ob `loadObject(URL)`/`loadObject(String)` für alle
  Absender wie `loadItem` liefern (Safari, Mail, Notizen, Nachrichten), zeigt nur das Gerät. Gegenmittel: Rückfall im
  Text-Zweig, Stufe 3 über TestFlight mit fünf benannten Absendern (AC-12 bis AC-16), Probenzeile loggt die Art; ein nur dort
  sichtbarer Verlust wird als Folgeschnitt behoben, nicht geraten.
- **XPC-Fehler von `submitTaskRequest` unter iOS 27 (niedrig, unbestätigt):** Ein Einzelbericht ohne Apple-Bestätigung. Neu
  steht ein Fehler im Protokoll statt unsichtbar zu fehlen; prüfbar nur im Gerätelog, nicht in TestFlight (AC-17).
- **Interpolationsschlüssel (niedrig):** siehe E3, Rückfall `AttributedString`.
- **Probenzeile ändert den Wert `loaded=` (niedrig):** Wer die #24-Auswertung liest, sieht `text`/`data` statt `mail` für
  den Mailzweig; der Vertrag (nie Inhalt) bleibt.

## Alternativen

- **Ein einziger Weg über `loadDataRepresentation` für alle drei Zweige:** weniger Verzweigung, aber die URL-Dekodierung (Safari
  liefert teils Bookmark-Daten) wäre eigener Code, den `loadObject` Apple überlässt. Verworfen; nur der Text-Zweig bekommt
  den Rückfall (E1). Für die URL wird er erst gebaut, wenn Stufe 3 einen Absender zeigt, den `loadObject(URL)` verliert.
- **`Transferable` / `loadTransferable`:** moderner, verlangt aber eigene Typen und kippt die Entscheidung, `SharedContent`
  auf Strings und URLs aufzubauen; für eine reine Warnungsbereinigung zu groß.
- **Detail als `AttributedString` (zwei Läufe):** ein Text, kein Schlüssel; gleichwertig. Rückfall nach E3.
- **BackgroundRefresh mit `try await submitTaskRequest`:** verlangt `schedule()` als `async` und ändert drei Aufrufer; kein
  Gewinn, und das Async-Überlad steht nicht in Apples Doku. Verworfen.
- **Warnungen unterdrücken statt ersetzen:** versteckt, dass `loadItem` und `submit` in der nächsten SDK-Stufe entfallen können.
  Verworfen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: reine Ablösung veralteter Systemschnittstellen ohne Verhaltensänderung, keine Architekturentscheidung

## Definition of Done

- AC-1 bis AC-11 erfüllt; `decode`-Tests zuerst rot, dann grün; alle bestehenden Tests grün; Bau ohne die sechs Warnungen
  (Log belegt, 0 Treffer).
- Simulator-Screenshots der Detailansicht vorher und nachher angesehen und beschrieben.
- Geräte-ACs (AC-12 bis AC-17) nur nach Hennings wörtlichem „jetzt ist ein Test möglich“, über TestFlight; Auslieferung als
  TestFlight-Build mit „Was testen“-Text (Safari-Link, Notizen-Text, Mail, Foto, Datei teilen), Hennings Rückmeldung schließt sie.
- PR verweist mit `Refs #580` statt `Closes #580`, bewusst abweichend vom Regelfall: Stufe 3 läuft laut CLAUDE.md über
  TestFlight nach dem Merge, das Ticket bleibt bis zu Hennings Rückmeldung offen (Vorbild #295). Nach der Bestätigung wird es von
  Hand geschlossen.
- Abschlussbericht ohne Git-Vokabular: Der Bau ist warnungsfrei; Teilen, Detailzeile und tägliche Mitteilungsplanung verhalten
  sich wie vorher; Henning teilt nach dem TestFlight-Bau je einen Link, Text, eine Mail, ein Foto und eine Datei und meldet,
  ob jedes im Formular ankommt.

## Changelog

- 2026-10-24: Initiale Spec für #580 aus Kontext und Analyse; Verhaltensgleichheit des Teilens fallweise abgebildet
  (E1 bis E3).
