# Adversary Dialog — fix-580-veraltete-schnittstellen
Spec: docs/specs/fix-580-veraltete-schnittstellen.md
Datum: 2026-10-24 18:23

## Checkliste
- [x] **AC-1:** Das Bau-Log von `./scripts/sim.sh build` (iOS-App und Share-Erweiterung, iOS-27-SDK) enthält keine der sechs Warnungen aus der Tabelle oben (0 Treffer); der Bau ist erfolgreich.
- [x] **AC-2:** `BackgroundRefresh.schedule()` ruft `submitTaskRequest(_:completionHandler:)` auf; ein Fehler im Handler wird mit `logger.error` geloggt. Es gibt weder `try?` noch einen leeren `catch`. `schedule()` bleibt `static`, synchron und `@MainActor`, die Aufrufer sind unverändert; unter Tests (`isRunningTests`/`isUITesting`) bleibt die Funktion stumm.
- [x] **AC-3:** Die „Said“-Zeile in der Detailansicht ist **ein** `Text` (Interpolation zweier gestalteter `Text`-Werte, kein `+`): Kopf in `caption2` semibold, Zeichenabstand 1, Großbuchstaben; Rohtext in Serif `subheadline` kursiv; zwei Leerzeichen dazwischen; zweite Zeile beginnt am Rand; Farbe `.secondary`. Der Screenshot nachher gleicht dem vorher (Simulator).
- [x] **AC-4:** Die Zeile trägt weiter `accessibilityLabel(task.rawText)` und die Kennung `detailRawText`; der Marker `detailRawTextMarker` ist unverändert; die bestehenden UI-Tests, die den Rohtext suchen, bleiben grün.
- [x] **AC-5:** `SharedContent.decode(_:)` liefert für UTF-8-Bytes den Text, für ungültiges UTF-8 den Latin-1-Text, für leere Daten `""` und für eine beliebige Bytefolge nie `nil` und nie einen Absturz; die Unit-Tests dazu (UTF-8, Latin-1, leer, ungültig) sind grün.
- [ ] **AC-6:** Der URL-Zweig lädt über `loadObject(ofClass: URL.self)`; ein Web- oder `message://`-Link kommt als URL in `SharedContent` an (Kanal `share`/`mail` wie heute); eine Datei-URL wird weiter von `make` verworfen; ein Ladefehler wird mit Domäne und Code geloggt (nie Inhalt) und nie fatal.
- [ ] **AC-7:** Der Text-Zweig lädt über `loadObject(ofClass: String.self)` und fällt bei Fehlschlag einmal auf `loadDataRepresentation(forTypeIdentifier: plainText)` mit `decode` zurück; Text als `String`, als `NSAttributedString` (Klartext), als `Data` und als gelesener Dateiinhalt kommt wie heute als `texts` an.
- [ ] **AC-8:** Der Mail-Zweig lädt über `loadDataRepresentation(forTypeIdentifier: emailMessage)` und dekodiert mit `decode`; Betreff, `message://`-Link und Kanal `mail` entstehen wie heute (`subject(ofMail:)`, `messageURL(ofMail:)` unverändert).
- [x] **AC-9:** Reihenfolge der Zweige (Anhang, Mail, URL, Text), Foto- und Datei-Anhänge, der Kopf-Zweig `attributedContentText` und `SharedContent.make` sind unverändert; `loadedKind(_:branch:)` und `string(from:)` sind entfernt, nichts ruft sie noch.
- [x] **AC-10:** Die Probenzeile (#24 AC-1) enthält weiter nur Typkennungen und die Art des geladenen Werts, niemals Inhalt (Text, Betreff, URL, Dateiname); `SharedContent.probeLine` und sein bestehender Test sind unverändert grün.
- [x] **AC-11:** Der volle Unit-Lauf (`./scripts/sim.sh unit`) und `./scripts/sim.sh test-proof` für die Klasse mit `detailRawText` sind grün; der Diff berührt nur die fünf genannten Dateien, keine Info.plist, Entitlements, `project.yml`, AppStorage-Schlüssel oder Katalogdatei (außer laut Entscheidung E3, dann genannt).
- [ ] **AC-12 (Gerät):** Nach Hennings ausdrücklichem „jetzt ist ein Test möglich“ erscheint beim Teilen eines **Links aus Safari** in „Loose Ends“ das Erfassungsformular mit Titel (Seitentitel oder Link) und dem Link als Quelle.
- [ ] **AC-13 (Gerät):** Beim Teilen von **Text aus Notizen** steht der Text im Formular, mit Umlauten unverändert.
- [ ] **AC-14 (Gerät):** Beim Teilen einer **Mail** aus Mail steht der Betreff im Formular, Kanal Mail, der Rücksprung-Link (`message://`) ist gesetzt; ein Betreff mit Umlauten bleibt unverändert.
- [ ] **AC-15 (Gerät):** Beim Teilen eines **Fotos** aus Fotos hängt es als Anhang an, ohne dass das Textfeld etwas vorbelegt.
- [ ] **AC-16 (Gerät):** Beim Teilen einer **Datei** aus Dateien (z. B. PDF) hängt sie als Anhang an, der Dateiname dient als Titel.
- [ ] **AC-17 (Gerät, eingeschränkt belegbar):** Die App startet unter TestFlight und wechselt in den Hintergrund ohne Absturz; die tägliche Neuplanung ist weiterhin eingeplant. Ein Fehler beim Einplanen steht im Protokoll (`logger.error`), das TestFlight nicht liefert; der Beleg ist daher der Code-Pfad (AC-2) und Hennings Beobachtung, dass die Mitteilungen auch nach mehreren Tagen ohne App-Öffnen weiter pünktlich kommen (kein harter Beleg, nur Abwesenheit eines Fehlers).

## Dialog

### Runde 1
**Adversary:** Ich unterstelle: der Bau ist nicht warnungsfrei, der volle Lauf nicht grün, das Bild weicht ab, der Diff greift über die fünf Dateien hinaus, und im Share-Pfad geht ein früherer `loadItem`-Fall still verloren. Beweis gefordert: eigener Bau, eigener sim-unit-Lauf, beide Bilder geöffnet, Diffliste.
**Implementierer:**
- Bau selbst gefahren: `./scripts/sim.sh build` rc=0, "Build Succeeded", 0 Zeilen mit `warning:`/`deprecated`. Mein Lauf war inkrementell; der Beleg für frisch übersetzte Quellen steht in `warnings-check.txt` (vier Dateien per `touch` neu übersetzt, 0 Treffer der sechs Muster; im Log sichtbar übersetzt: ShareViewController, SharedContent, TaskDetailView, BackgroundRefresh). AC-1 belegt. Code reference: LooseEndsShare/ShareViewController.swift:73
- Voller `./scripts/sim.sh sim-unit` selbst: rc=0, "Test Succeeded"; Suite "SharedContent" passed; die vier decode-Tests plus Mail-Kette stehen als grüne Haken im Log. Übersprungen sind ausschließlich Messstrecken (SelfConsistencyReportTests: selfconsistency-run.json fehlt; zwei Latenzschutz-Tests: Sprache de_DE im Simulator nicht installiert). Keiner hängt an Share, Detailzeile oder BackgroundRefresh. 0 fehlgeschlagen. AC-5 belegt. Code reference: Shared/Services/SharedContent.swift:131
- AC-2: `submitTaskRequest(request) { error in if let error { log.error(...) } }`, kein `try?`, kein leeres catch, `schedule()` weiter static/synchron, Stummschaltung unter Tests (guard davor) unverändert. Abweichung vom Wortlaut `logger.error`: `log` ist `let log = Self.logger`, dieselbe Logger-Instanz (Subsystem und Kategorie identisch), nötig, weil die Handler-Closure @Sendable ist und der Compiler sonst die main-actor-isolierte Property meldet (Zwischenbau, in warnings-check.txt dokumentiert). Gleichwertig.
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:42
- AC-3/AC-4: Detailzeile ist `Text("\(head)  \(said)")` mit `.foregroundStyle(.secondary)`, `accessibilityLabel(task.rawText)`, Kennung `detailRawText`; `detailRawTextMarker` im Diff nicht berührt. Bilder geöffnet: `detail-nachher.png` zeigt "SAID" klein, fett, gesperrt, grau, zwei Leerzeichen Abstand, Rohtext Serif kursiv grau, zweite Zeile beginnt am linken Rand; `docs/artifacts/feat-477-schnitt-2-detail/iphone-detail-nachher.png` (Vorher) zeigt dieselbe Gestaltung mit gleichem Umbruch am Rand. Die Aufgaben sind verschieden (anderer Rohtext), die Gestaltung deckungsgleich; ein Bild derselben Aufgabe vor/nach liegt nicht vor (F001). Test-Proof `CaptureSmokeTests/testLongCaptureKeepsFullTextBelowTwelveWordTitle` grün (`simulator-run.txt`, HEAD 161fa4f); er prüft `detailRawText.label == words` (LooseEndsUITests/CaptureSmokeTests.swift:241-243). Code reference: LooseEnds/Views/TaskDetailView.swift:155
- AC-11: Namensliste des Diffs gegen main ohne docs: nur LooseEndsTests/SharedContentTests.swift (RED-Commit); Arbeitsbaum: die vier Quelldateien. Keine Info.plist, Entitlements, project.yml, Katalogänderung. Hinweis: `docs/context/fix-660-662-knaeuel-sprache.md` ist nicht versioniert und gehört nicht zu #580. `test-proof` lief auf einem Einzeltest, der den Rohtext prüft, nicht auf der ganzen Klasse.
- AC-9: Suche nach `loadedKind` und `string(from` in LooseEndsShare, Shared, LooseEnds: keine Aufrufer, keine Definitionen. Zweigreihenfolge Anhang, Mail, URL, Text im Code unverändert (Z. 66-90). AC-10: `probeLine` unverändert, Test grün.

### Runde 2
**Adversary:** Nachbohren an den Rändern: (a) fällt ein `loadItem`-Fall der Spec-Tabelle still weg? (b) Latin-1-Skalarabbildung gegen `String(data:encoding:.isoLatin1)`; leer, BOM, 0x80-0x9F, große Daten. (c) Doppeltes Resume, Swift-6-Isolation. (d) Loggt etwas Inhalt, stimmen die `kind`-Werte?
**Implementierer:**
- (a) Zuordnung gegen den Code: Mail-Data: `data(from:)` plus `decode`, kind "data" (ShareViewController.swift:73-76). URL/Web/message://: `object(URL.self)`, kind "url", Datei-URL "file" (Z. 78-81); `make` verwirft Datei-URLs weiter (unverändert). URL als Data: früher nichts übernommen; jetzt entsteht eine URL nur, wenn `loadObject` sie liefert, sonst Log: kein Verlust. Text als String: `object(String.self)`, "text". Text als NSAttributedString, Data, Datei-URL: kein eigener Zweig mehr, sondern `loadObject(String)` und bei nil der Rückfall `data(from:)` plus `decode` (Z. 83-88). Mail als Datei-URL: `loadDataRepresentation` liefert den Dateiinhalt. Mail als String/NSAttributedString entfällt bewusst (Spec begründet). Im Code fällt kein Fall still weg. ABER: ob `loadObject(String)`, `loadObject(URL)` und `loadDataRepresentation` je Absender (Safari, Notizen, Mail, Nachrichten) liefern, was `loadItem` lieferte, ist nur auf dem Gerät belegbar; der Simulator spielt das nicht, Unit-Tests erreichen `NSItemProvider` nicht. Kein Codefehler, aber kein Beweis: offen AC-6, 7, 8 und AC-12 bis 16 (Stufe 3, erst nach Hennings Wort).
- Restunschärfe Text: bietet ein Absender Text nur als NSAttributedString ohne Plain-Text-Bytes an, hängt es an `loadObject(String)`; scheitert das und liefert auch `loadDataRepresentation(plainText)` nichts, wäre der Text weg (früher `NSAttributedString.string`). Teilweise vom Kopf-Zweig `attributedContentText` aufgefangen; nur das Gerät klärt es (F002).
- (b) `decode`: erst `String(data:encoding:.utf8)`, sonst `String.UnicodeScalarView(data.map { Unicode.Scalar($0) })`. `Unicode.Scalar(UInt8)` ist die Identität 0-255, genau die ISO-8859-1-Abbildung (0x80-0x9F werden U+0080-U+009F wie bei Foundations `.isoLatin1`). Leer: UTF-8-Zweig liefert "" (decodesEmptyToEmptyString grün). BOM: UTF-8-BOM geht durch den unveränderten UTF-8-Zweig wie früher; UTF-16-BOM (0xFF 0xFE) fällt in Latin-1 wie früher (Test 0xFF 0xFE 0x41 ergibt 3 Zeichen). Große Daten: Skalararray (4 Byte je Byte) nur im Nicht-UTF-8-Fall; bei sehr großen Mails Speicherspitze in der Erweiterung (F003, niedrig). Code reference: Shared/Services/SharedContent.swift:131
- (c) `object`/`data` sind `@MainActor static`, je eine `withCheckedThrowingContinuation`; der Rückruf resümiert in jedem Zweig genau einmal (if let / else throw), die Fertigstellung von `loadObject`/`loadDataRepresentation` wird je Aufruf einmal gerufen; `CheckedContinuation` würde ein Doppel-Resume zur Laufzeit melden. Bau unter Swift 6 ohne Warnung. `_ObjectiveCBridgeable` ist Unterstrich-API (kein stabiler Vertrag), Bau grün. Code reference: LooseEndsShare/ShareViewController.swift:158
- (d) `logFailure` loggt nur Typkennung, Domäne, Code (Z. 150-153); die Probenzeile bekommt nur `registeredTypeIdentifiers` und kind (Z. 92). kind-Werte: Mail "data", URL "url"/"file", Text "text"/"data", Anhänge unverändert. Keine Inhalts-Leckage gefunden; früher wurde bei loadItem-Fehlern der volle Fehler öffentlich geloggt, jetzt weniger.
- Offen, nicht abgehakt: AC-6/7/8 und AC-12 bis 17 (Gerät). Auf Geräten wurde nichts gestartet.

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/TaskDetailView.swift:155
  Description: Vorher- und Nachher-Bild zeigen verschiedene Aufgaben; AC-3 verlangt "gleicht dem vorher". Gestaltung stimmt sichtbar überein, ein Bildvergleich derselben Aufgabe fehlt.
  Spec requirement: AC-3 — Screenshot nachher gleicht dem vorher
  Conflict: Beleg ist ein Sichtvergleich der Gestaltung, kein identischer Fall.
  Remediation: Optional dieselbe Aufgabe auf main fotografieren; kein Blocker.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEndsShare/ShareViewController.swift:83
  Description: Text-Zweig: `loadObject(String)` mit Rückfall `loadDataRepresentation`. Für Absender, die Text nur als NSAttributedString oder Datei anbieten, ist das Verhalten gegenüber `loadItem` im Simulator nicht belegt.
  Spec requirement: AC-7 — alle vier Textwertarten kommen als `texts` an
  Conflict: Nur auf dem Gerät prüfbar (AC-13); kein Code-Defekt nachgewiesen.
  Remediation: Stufe 3 mit Notizen-Text; Probenzeile (kind) auswerten.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/SharedContent.swift:131
  Description: Der Latin-1-Zweig baut ein Skalararray (ca. 4 Byte je Byte); bei sehr großen Nicht-UTF-8-Mails Speicherspitze in der Share-Erweiterung.
  Spec requirement: AC-5 — nie Absturz bei beliebiger Bytefolge
  Conflict: Für praxisübliche Größen unkritisch; früher kompakter.
  Remediation: Optional `String(data:encoding:.isoLatin1)` als zweiten Zweig (gleiches Ergebnis) statt der Handabbildung.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

(`precondition_origins.py --root .` verlangt `--lang`; ohne Profil keine Tabelle.)

## Verdict
VERDICT: AMBIGUOUS

Im Code und Simulator bewiesen: AC-1, 2, 3 (Gestaltung, F001), 4, 5, 9, 10, 11. Nicht abgehakt: AC-6, 7, 8 (Code entspricht der Spec, Verhalten gegen echte Absender nur auf dem Gerät belegbar) und AC-12 bis 17 (Stufe 3, erst nach Hennings wörtlichem „jetzt ist ein Test möglich“). Kein Defekt gefunden; F002 ist die einzige Unschärfe mit echtem Risiko und nur per Gerät klärbar.
Tests: sim-unit grün, 0 fehlgeschlagen, übersprungen: 3 Messstrecken-Tests (selfconsistency-run.json fehlt; zwei Latenzschutz-Tests, de_DE im Simulator nicht verfügbar), unabhängig von der Änderung.

## Geprüfte Dateien

- sha256:f8945d11529deb72fe611c11e6ef29fc2ddcf24f2d7537298497a632cb36ce22  LooseEnds/Notifications/BackgroundRefresh.swift
- sha256:16ccee38f592d3e8b89d79558f71718549830e7aeb7f94e80de78522421971e3  LooseEnds/Views/TaskDetailView.swift
- sha256:53bc2860f0f497844e497c1686cff9281a4a37156066458d032291141fce7790  LooseEndsShare/ShareViewController.swift
- sha256:abfd31b0e9b33488e7fa52ecd423773678c2b93bd1b9b055045aab53b9312805  Shared/Services/SharedContent.swift

## Prüfbasis

- base: 4d3649538149471671f607427c2746e762ac7d22
- blob:836ee49700d40ec619fcc1d77e5493cf31f0a158  LooseEnds/Notifications/BackgroundRefresh.swift
- blob:9c4aa0a2e532bdbbdc88b738ff9f96ec483c61c8  LooseEnds/Views/TaskDetailView.swift
- blob:fd5a1a17ae48fe22c001ca9690c61ae21f346a91  LooseEndsShare/ShareViewController.swift
- blob:0c43424c8aac3e589d63647f3e6a6ca5ece8bd6c  Shared/Services/SharedContent.swift
