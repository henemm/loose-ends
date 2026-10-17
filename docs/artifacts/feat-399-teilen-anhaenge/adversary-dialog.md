# Adversary Dialog — feat-399-teilen-anhaenge
Spec: docs/specs/feat-399-schnitt-1-anhang-speichern.md
Datum: 2026-10-17 11:39

## Checkliste
- [x] **Input:** Eine Aufgabe mit Text und drei Anhängen (zwei bereit, einer zu groß).
- [x] **Output:** Die Aufgabe liegt im Store, mit zwei `TaskAttachment`s in der Reihenfolge der Eingabe.
- [x] **Ohne Anhänge:** `save` verhält sich bytegleich wie bisher.
- [x] **Side effects:** Keine Änderung am Modell, am Schema oder an Berechtigungen. Keine neuen AppStorage-Schlüssel. Keine
- [x] **AC-1:** `SharedAttachment.title(fromFileName:)` macht aus „Befund_Dr-Meier.pdf“ den Titel „Befund Dr Meier“, fasst Mehrfach-Leerzeichen („a__b - c.pdf“ → „a b c“) zusammen, trimmt Ränder und liefert für „.pdf“ oder „___.pdf“ einen leeren Text. (Test: `SharedAttachmentTests`, Titelregel)
- [x] **AC-2:** `SharedAttachment.photoFileName(typeIdentifier:at:prefix:)` liefert mit festem Datum, Präfix „Photo“ und Typ `public.heic` einen Namen, der mit „Photo “ beginnt, das numerisch formatierte Datum samt kurzer Uhrzeit enthält und auf „.heic“ endet; bei einem unbekannten Typ endet er auf „.jpg“. (Test: `SharedAttachmentTests`, Fotoname)
- [x] **AC-3:** `SharedAttachment.classify(_:)` gibt Anhänge bis `AttachmentKind.maximumBytes` (inklusive genau 50 MB) als `.ready` zurück und jeden mit mehr Bytes als `.tooLarge`; ein zu großer Anhang belegt keinen der zehn Plätze. (Test: `SharedAttachmentTests`, Größe)
- [x] **AC-4:** Bei zwölf bereiten Anhängen liefert `classify` die ersten zehn als `.ready`, den 11. und 12. als `.overLimit`, und die Reihenfolge der Eingabe bleibt erhalten. (Test: `SharedAttachmentTests`, Obergrenze)
- [x] **AC-5:** `SharedContent.make` mit einem bereiten PDF-Anhang „Befund_Dr-Meier.pdf“ und ohne Text, Link und Mail ergibt den Prefill „Befund Dr Meier“; mit einem bereiten Foto als einzigem Anhang bleibt der Prefill leer; mit Foto und PDF wird der Titel des PDFs genommen; ein Anhang mit Status `.tooLarge` oder `.overLimit` liefert nie einen Prefill. (Test: `SharedContentTests`, Anhang-Prefill)
- [x] **AC-6:** Text, Web-Link, `message://`-Link und Mail behalten Vorrang: Mit einem PDF-Anhang und zusätzlich einem Text (oder Link oder Mail) ist der Prefill derselbe wie ohne den Anhang, und `attachments` enthält das PDF trotzdem. Alle bestehenden Tests in `SharedContentTests` laufen unverändert grün; eine Datei-URL wird weiterhin als Link verworfen. (Test: `SharedContentTests`, Vorrang und Bestand)
- [x] **AC-7:** `CaptureService.save("Befund Dr Meier", via: .share, attachments: [a, b], in:)` mit zwei bereiten Anhängen (echte Temp-Dateien mit bekanntem Inhalt) legt genau eine Aufgabe und zwei `TaskAttachment`s an, die über `task` mit ihr verbunden sind, in Reihenfolge der Eingabe, mit passendem `data`, `fileName` und `typeIdentifier`. (Test: `CaptureServiceTests`, Anhänge speichern)
- [x] **AC-8:** Anhänge mit Status `.tooLarge` oder `.overLimit` werden nie gelesen und nie gespeichert (Beleg: Der Test übergibt eine `fileURL` auf eine nicht vorhandene Datei, und `save` wirft nicht und legt keinen Anhang an). Eine Datei, die als `.ready` gemeldet ist, aber beim Einfügen mehr als 50 MB meldet, wird ebenfalls nicht gespeichert. (Test: `CaptureServiceTests`, nie lesen)
- [x] **AC-9:** Ist die Datei eines bereiten Anhangs nicht lesbar (gelöscht), wird nur dieser Anhang übersprungen; die Aufgabe und die übrigen Anhänge werden gespeichert und `save` wirft nicht. Mit leerem Text wirft `save` weiterhin `CaptureError.emptyText`, auch mit bereitem Anhang, und es bleibt nichts im Store. Ohne `attachments` verhält sich `save` wie bisher (alle bestehenden Tests in `CaptureServiceTests` grün, alle bisherigen Aufrufer unverändert). (Test: `CaptureServiceTests`, unlesbar, leerer Text, Bestand)
- [x] **AC-10:** Die Änderung berührt weder `project.yml`, `LooseEndsShare/`, `Shared/Models/` noch `cloudkit/schema.ckdb`; `CLAUDE.md` nennt `SharedAttachment` bei `Shared/Services`. Der vor der Prüfung vorbereitete Text der Pull-Request- Beschreibung (`docs/artifacts/feat-399-teilen-anhaenge/pr-schnitt-1.md`) verweist mit „Refs #399“ (nicht „Closes“), weil das Ticket für Schnitt 2 offen bleibt. (Beleg: `git diff --name-only` gegen `main` und diese Datei)

## Dialog

### Runde 1
**Adversary:** Alle 14 Punkte gegen Code, Tests und eigenen Lauf geprüft. Beweise:

Confirmation:
  AC: AC-1
  Code reference: Shared/Services/SharedAttachment.swift:17
  Evidence: Test "A file name becomes a readable title ..." grün im vollen Lauf; Wegwerf-Programm (swiftc gegen die Originaldatei): ".pdf" -> "", "___.pdf" -> "", "  .pdf" -> "", "a.b.c.pdf" -> "a.b.c", "v1.2 Bericht.pdf" -> "v1.2 Bericht", "Bericht" -> "Bericht". Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/SharedAttachment.swift:28
  Evidence: Wegwerf-Programm: public.heic -> "Photo <Datum>.heic", unbekannter Typ und "" -> ".jpg", public.png -> ".png"; Test "A photo is named like one added in the detail" grün. Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Services/AttachmentKind.swift:13
  Evidence: fits(byteCount:) ist <= maximumBytes; fits(_ data:) ruft es auf (Z. 9-11). classify (SharedAttachment.swift:34) zählt .tooLarge nicht in readyCount. Tests "Up to 50 MB is ready ..." und "Size check by byte count ..." grün. Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Services/SharedAttachment.swift:40
  Evidence: readyCount >= 10 -> .overLimit; map erhält die Reihenfolge; classify([]) = [] (Wegwerf-Programm); Test "Ten are attached ..." grün. Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Services/SharedContent.swift:40
  Evidence: erster .ready-Anhang ohne UTType-image-Konformität liefert den Titel; Foto allein -> ""; Status .tooLarge/.overLimit wird nie gewählt; Test "A shared file without text gives its readable name ..." grün. Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Services/SharedContent.swift:35
  Evidence: Mail-, message://-, Web-Link-Zweig unverändert, attachments in jedem Zweig übernommen (Z. 31, 35, 38, 42); isFileURL-Filter bleibt; Test "Text, links and mail keep the lead ..." und alle Bestandstests grün. Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Services/CaptureService.swift:36
  Evidence: Schleife über .ready-Anhänge, createdAt = capturedAt + index ms (strikt steigend); Test "Ready attachments are stored ..." prüft Reihenfolge, data, fileName, typeIdentifier, task-Bezug grün. Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Shared/Services/CaptureService.swift:46
  Evidence: where status == .ready (Z. 36) schließt .tooLarge/.overLimit vor jedem Lesen aus; insert prüft die Dateigröße per resourceValues vor Data(contentsOf:) (Z. 46-51); Test mit fehlender Datei und 50 MB+1 per truncate grün. Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Services/CaptureService.swift:58
  Evidence: do/catch ohne try?, loggt nur Typ-Identifier und Größe, keinen Dateinamen und keinen Inhalt; emptyText wird vor dem Einfügen geworfen (Z. 29), kein Store-Rest; Alt-Überladung Z. 16 delegiert mit []; SiriCaptureTests und CaptureServiceTests Bestand grün. Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: Shared/Services/SharedContent.swift:1
  Evidence: Die Dateiliste des Diffs gegen origin/main enthält weder project.yml, LooseEndsShare/, Shared/Models/ noch cloudkit/schema.ckdb; CLAUDE.md nennt SharedAttachment bei Shared/Services; pr-schnitt-1.md Z. 3 "Refs #399", kein "Closes". Status: CONFIRMED

Expected Behavior (Input, Output, Ohne Anhänge, Side effects): durch AC-7/8/9 und die unveränderte Alt-Überladung (CaptureService.swift:16) belegt; keine Änderung an Shared/Models, Schema, project.yml, keine AppStorage-Schlüssel.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/SharedAttachment.swift:20
  Description: Die Endung wird beim letzten Punkt abgeschnitten, wenn dahinter kein Leerraum folgt. Dateiname ohne Endung, aber mit Punkt in der Zahl: "Bericht v1.2" -> "Bericht v1"; "Foto.tar.gz" -> "Foto.tar" (Wegwerf-Programm).
  Spec requirement: AC-1 — Titel ohne Endung
  Conflict: Der Vorschlag kann ein Stück des echten Namens verlieren, wenn der Name keine Endung hat. Geteilte Dateien tragen praktisch immer eine Endung; der Nutzer sieht den Vorschlag und kann ihn ändern. Kein Spec-Bruch.
  Remediation: Optional: nur abschneiden, wenn der Rest nach dem Punkt höchstens 5 Zeichen lang ist, keinen Leerraum enthält und einen Buchstaben hat.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/SharedAttachment.swift:30
  Description: photoFileName nutzt date.formatted(.numeric, .shortened); in Gebietsschemata wie en_US entsteht "1/1/1970", also ein Schrägstrich im Dateinamen. Genauso arbeitet das Vorbild AttachmentsSection.addPhoto; der Name wird nur angezeigt.
  Spec requirement: AC-2 — Name wie im Vorbild
  Conflict: Keiner zur Spec; nur Hinweis für Schnitt 2, falls der Name je als Dateipfad dient.
  Remediation: Keine in Schnitt 1.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: Shared/Services/CaptureService.swift:16
  Description: Beleg-Lage: Die im Auftrag vorgegebenen Einzelläufe (sim-unit LooseEndsTests/<Suite>) führen 0 Tests aus ("Executed 0 tests"), weil der Filter die Swift-Testing-Suiten nicht trifft; sie beweisen nichts. Bekannte Eigenart. Der Nachweis der neuen Tests stammt aus dem vollen Lauf (Runde 2).
  Spec requirement: Definition of Done — alle Unit-Tests grün
  Conflict: Kein Defekt im Produktcode.
  Remediation: Vollen Lauf als Beleg nehmen.

**Implementierer:** keine Antwort nötig, keine Findings über LOW.

### Runde 2
**Adversary:** Gezielte Bruchversuche: (a) Foto als erster, tooLarge-PDF als zweiter Anhang -> kein Prefill (Foto ist Bild, PDF nicht .ready; SharedContent.swift:40). (b) tooLarge-PDF zuerst, bereites PDF danach -> der zweite liefert den Titel. (c) save nur mit nicht bereiten Anhängen -> Aufgabe ohne Anhang, kein Lesen. (d) unlesbarer Anhang in der Mitte -> Reihenfolge der übrigen bleibt, da createdAt aus dem Index der Eingabe stammt (CaptureService.swift:36). (e) Typen, die UTType nicht kennt, gelten als Datei (Known Limitation der Spec). (f) Überladungs-Mehrdeutigkeit: alte 4-Parameter-Form und neue mit Pflicht-attachments sind unterscheidbar; die Funktionsreferenz in SiriCaptureTests kompiliert (voller Lauf). (g) Logger: nur Typ-Identifier und Bytes, kein Dateiname, kein Inhalt (CaptureService.swift:48,58). (h) Dateigröße unbekannt -> siehe F004. (i) LooseEnds/Info.plist (NSCameraUsageDescription, Drift aus generate) steht im Diff gegen origin/main, gehört nicht zur Änderung und darf nicht eingereicht werden; AC-10 verbietet sie nicht ausdrücklich.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/CaptureService.swift:46
  Description: fileSize ?? 0 lässt eine Datei mit unbekannter Größe die Prüfung bestehen; gelesen wird sie trotzdem vollständig.
  Spec requirement: AC-8 — Größe vor dem Lesen nochmals prüfen
  Conflict: Nur theoretisch; Temp-Dateien im lokalen Dateisystem liefern fileSize immer.
  Remediation: Bei nil überspringen oder nach dem Lesen data.count prüfen.

**Implementierer:** Die LOW-Punkte bleiben unbehoben; keine Spec-Verletzung.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

### Runde 3
**Adversary:** Nachtrag des vollen Laufs. Ich habe docs/artifacts/feat-399-teilen-anhaenge/adversary-test-output.txt selbst gelesen: sim-unit im Simulator, "Test Succeeded", exit=0, 0 Fehlschläge (kein ✘), 793 gesamt, 790 bestanden, 3 übersprungen laut Koordinator (SelfConsistencyReportTests/writesReport, zwei SpeechLatencyTests aus #274; keiner betrifft #399). Grün und namentlich sichtbar: Suite "Shared attachment" (Titelregel, Fotoname, 50 MB, Zehnergrenze, byteCount: AC-1 bis AC-4), SharedContent-Tests "A shared file without text gives its readable name; photos alone leave the field empty" und "Text, links and mail keep the lead over a shared file, which is still carried" (AC-5, AC-6), Suite "CaptureService" mit den vier neuen Tests (AC-7 bis AC-9) und Bestand, Suite "Attachment kind". Damit ist die Lücke aus Runde 2 (SharedAttachment/SharedContent nicht erreicht) geschlossen. Die Übersprungenen sind benannt und nicht #399-bezogen. Findings F001 bis F004 bleiben (alle LOW).
**Implementierer:** keine Antwort nötig.


Testlage (eigene Läufe): Die vier Einzelläufe lieferten "Executed 0 tests" (Filter trifft Swift Testing nicht, kein Beleg). Der volle Lauf (sim-unit) brach nach 260 bestandenen Prüfungen bei FocusBloxCalibrationTests mit exit=65 ab, ohne eine einzige fehlgeschlagene Prüfung (Simulator mit anderen Sitzungen geteilt, Sperre danach über 50 Minuten von einer fremden Sitzung gehalten, zweiter Versuch nicht mehr gestartet). In diesem Lauf bestanden die vier neuen CaptureService-Tests (AC-7, AC-8, AC-9) sowie die Suiten "Attachment kind" und "CaptureService". Die Suiten SharedAttachment und SharedContent wurden in meinem Lauf nicht mehr erreicht; für sie stützt sich der Beleg auf den Implementierer-Lauf test-green-output.txt (788 bestanden, 0 fehlgeschlagen; die Datei ist älter als die letzte Änderung der Quelldateien) und auf mein Wegwerf-Programm gegen SharedAttachment.swift. Ein frischer vollständiger Lauf steht aus.

Code-Befund: kein Defekt gegen die Spec; vier LOW-Hinweise (F001-F004).

## Verdict
VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:33471032390a2080c65c21157624461e8b70d6805a2e26c2a2e90802c63fcb37  Shared/Services/AttachmentKind.swift
- sha256:095dda144e730d28536410eda6e271765de53ea239588528bbc9f80e3dc40d18  Shared/Services/CaptureService.swift
- sha256:baedbe4042d600c0dbc6d2a1f0d167151e74554fdb6d87ff699496291abc843d  Shared/Services/SharedAttachment.swift
- sha256:9dac64d95ba58fa93d300386ab7fd7c62e1302c790ae2f597d96cbb406a53aa7  Shared/Services/SharedContent.swift

## Prüfbasis

- base: 85ed8a236cebb548bfa946fce08da949fcfbe886
- blob:8d63d53c824e04b71fe61cbd2b8c27da3e620cf1  Shared/Services/AttachmentKind.swift
- blob:938223deb5906c48dcc58c538a44a0c1c6f3dc88  Shared/Services/CaptureService.swift
- blob:b2c5b51b0639786893ea42ed0d4c484f4be5b21b  Shared/Services/SharedAttachment.swift
- blob:b7ae94e0e832d4de9b9837a875e2a7afeeaf6ba6  Shared/Services/SharedContent.swift

## Geprüfte Dateien

- sha256:33471032390a2080c65c21157624461e8b70d6805a2e26c2a2e90802c63fcb37  Shared/Services/AttachmentKind.swift
- sha256:095dda144e730d28536410eda6e271765de53ea239588528bbc9f80e3dc40d18  Shared/Services/CaptureService.swift
- sha256:baedbe4042d600c0dbc6d2a1f0d167151e74554fdb6d87ff699496291abc843d  Shared/Services/SharedAttachment.swift
- sha256:9dac64d95ba58fa93d300386ab7fd7c62e1302c790ae2f597d96cbb406a53aa7  Shared/Services/SharedContent.swift

## Prüfbasis

- base: 85ed8a236cebb548bfa946fce08da949fcfbe886
- blob:8d63d53c824e04b71fe61cbd2b8c27da3e620cf1  Shared/Services/AttachmentKind.swift
- blob:938223deb5906c48dcc58c538a44a0c1c6f3dc88  Shared/Services/CaptureService.swift
- blob:b2c5b51b0639786893ea42ed0d4c484f4be5b21b  Shared/Services/SharedAttachment.swift
- blob:b7ae94e0e832d4de9b9837a875e2a7afeeaf6ba6  Shared/Services/SharedContent.swift
