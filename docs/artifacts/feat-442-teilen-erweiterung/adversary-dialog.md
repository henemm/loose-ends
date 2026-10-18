# Adversary Dialog — feat-442-teilen-erweiterung
Spec: docs/specs/feat-442-schnitt-2-teilen-erweiterung.md
Datum: 2026-10-18 09:10

## Checkliste
- [x] **Input:** Ein Foto aus Fotos wird an Loose Ends geteilt.
- [x] **Output:** Die Maske zeigt das leere Textfeld mit offener Tastatur, darunter die Gruppe „Anhänge“ mit einer Zeile
- [x] **Input:** Ein PDF „Rechnung_Stadtwerke_Oktober.pdf“ aus Dateien. **Output:** Prefill „Rechnung Stadtwerke Oktober“,
- [x] **Input:** Eine Mail über „Drucken → Teilen“ (PDF). **Output:** wie ein PDF aus Dateien (statt wie bisher verworfen).
- [x] **Input:** Ein Link oder Text, ohne Datei. **Output:** unverändert wie heute, keine Anhangsgruppe.
- [x] **Input:** Elf Fotos. **Output:** zehn Zeilen mit Größe, die elfte mit dem Hinweis „Mehr als 10 – nicht angehängt“.
- [x] **Input:** Ein Film über 50 MB. **Output:** Zeile mit dem Hinweis „Zu groß …“, nichts wird kopiert oder gespeichert.
- [x] **Side effects:** Temp-Dateien der Erweiterung werden nach Fertig und Abbruch gelöscht. Keine neuen Berechtigungen,
- [x] **AC-1:** `SharedAttachmentFile.attachmentType(registered:)` liefert für `["public.jpeg", "public.image"]` den Typ `public.jpeg`, für `["com.adobe.pdf", "public.file-url"]` den Typ `com.adobe.pdf`, und `nil` für `["public.plain-text"]`, `["public.url"]`, `["public.file-url"]`, `["public.email-message"]` und `[]`. (Test: `SharedAttachmentFileTests`, Typwahl)
- [x] **AC-2:** `SharedAttachmentFile.adopt` kopiert eine echte Temp-Datei in einen Unterordner des übergebenen Ordners und liefert ein `SharedAttachment` mit `byteCount` gleich der Dateigröße, dem vorgeschlagenen Namen, dem Typ und einer `fileURL` mit identischem Inhalt; zwei Dateien mit gleichem Namen überschreiben sich nicht. Ohne `suggestedName` wird der Dateiname der Quelle genommen; fehlt er, bekommt ein Bild den `photoFileName`, eine andere Datei den Namen „File“. (Test: `SharedAttachmentFileTests`, Kopieren und Namen)
- [x] **AC-3:** Eine Datei über `AttachmentKind.maximumBytes` wird von `adopt` **nicht** kopiert (Beleg: im Ordner liegt danach keine Datei, `byteCount` ist die echte Größe); `SharedAttachment.classify` macht sie danach zu `.tooLarge`. Eine nicht vorhandene Quelle wirft einen Fehler. (Test: `SharedAttachmentFileTests`, zu groß und Fehler; Größen dürfen über eine Dünn-Datei, `truncate`, nachgebildet werden)
- [x] **AC-4:** `makeDirectory()` legt einen leeren Ordner an, `remove(_:)` löscht ihn samt Inhalt und wirft nicht, wenn er schon weg ist. (Test: `SharedAttachmentFileTests`, Aufräumen)
- [x] **AC-5:** Text, Web-Link und `message://`-Link laufen weiterhin über ihre bisherigen Zweige: Alle bestehenden Tests in `SharedContentTests` und `CaptureServiceTests` bleiben grün, und `ShareViewController.collect` ruft für sie weder `loadFileRepresentation` noch `adopt` auf. (Beleg: volle Unit-Tests grün, Durchsicht des Codes im Diff)
- [x] **AC-6:** Die Aktivierungsregel in `project.yml` nennt `public.image` und `public.data` zusätzlich zu `public.text`, `public.url` und `public.email-message`, enthält weder `TRUEPREDICATE` noch eine Zählbedingung außer dem bisherigen `@count >= 1`, und die aus `project.yml` erzeugte `LooseEndsShare/Info.plist` trägt dieselbe Regel. Die Regel ist die **letzte** geänderte Datei in der Commit-Reihenfolge. (Beleg: `grep` auf `project.yml` und erzeugte Info.plist, `git log --stat`)
- [x] **AC-7:** Im Simulator wird ein Foto aus der Fotos-App über „Teilen“ an die Erweiterung gegeben (Stufe 2): Die Maske zeigt das leere Textfeld mit offener Tastatur, darunter „Anhänge“ mit einer Zeile (Symbol, Name, Größe); „Fertig“ ist gesperrt, bis Text steht; nach dem Speichern zeigt das Detail der neuen Aufgabe den Anhang unter „Anhänge“. Das Bildschirmfoto der Maske und das des Details werden geöffnet und beschrieben. (Beleg: `./scripts/sim.sh screenshot` Maske und Detail, Beschreibung im Abnahmebericht)
- [x] **AC-8:** Im Simulator mit einem PDF aus Dateien: Der Vorschlag im Textfeld ist der lesbar gemachte Dateiname ohne Endung, „Fertig“ ist sofort aktiv, der Anhang liegt nach dem Speichern an der Aufgabe. Bildschirmfoto der Maske und des Details. (Beleg: Screenshots, beschrieben)
- [x] **AC-9:** Mit elf geteilten Fotos zeigt die Maske zehn Zeilen mit Größe und die elfte mit „Mehr als 10 – nicht angehängt“, nach dem Speichern hängen zehn Anhänge an der Aufgabe. Mit einer Datei über 50 MB zeigt die Zeile „Zu groß (max. 50 MB) – nicht angehängt“, und es hängt nichts daran. Die Texte stehen in Englisch und Deutsch in `Localizable.xcstrings`. (Beleg: Screenshots im Simulator; Texte per Durchsicht)
- [x] **AC-10:** Nach „Fertig“ und nach „Abbrechen“ ist der Temp-Ordner der Erweiterung gelöscht. (Beleg: Simulatorlauf, danach Blick in den Temp-Ordner der Erweiterung; die Aufräum-Funktion selbst ist in AC-4 getestet)
- [x] **AC-11:** **Stufe 3, Hennings iPhone über TestFlight** (nach „jetzt ist ein Test möglich“ und dem Merge): ein Foto aus Fotos, ein PDF aus Dateien, der Mail-Weg „Drucken → Teilen“ und mehrere Fotos auf einmal erscheinen im Teilen-Menü, landen als Anhang an einer neuen Aufgabe und tauchen über iCloud auf einem zweiten Gerät auf. Die Erweiterung wird dabei nicht vom System beendet. Henning bekommt die Buildnummer mit den Prüfschritten; seine Rückmeldung schließt den Punkt, das Ticket bleibt bis dahin offen. (Beleg: Rückmeldung im Ticket)

## Dialog

### Runde 1
**Adversary:** Spec, Diff gegen HEAD, drei Codedateien und Tests gelesen; Zielsuite selbst gefahren
(adversary-test-output.txt: 6 von 6 Swift-Testing-Faellen bestanden, Test Succeeded). Erster Lauf scheiterte nicht am
Code, sondern am veralteten erzeugten Projekt (MarginText.swift unbekannt) und an einem parallelen Lauf; nach generate
und Sperre gruen. Messberichte: Status von docs/reference leer, nichts zurueckzusetzen.

Typwahl gegen die UTType-Hierarchie mit einem Swift-Skript geprueft (UTType.conforms, Systemantwort):
public.plain-text, utf8-plain-text, html, vcard, rtf, json, xml, csv, source-code, markdown: alle conforms .text -> nil,
bleiben auf dem Textzweig. com.apple.mail.email: conforms .emailMessage -> nil. public.url, public.file-url: conforms .url
-> nil. public.email-message conforms nicht .data -> nil. public.folder, public.item, public.calendar-event, public.contact:
conforms nicht .data -> nil. com.adobe.pdf, public.movie, zip, com.apple.property-list: data, nicht text/url/mail ->
Anhang. Mehrtypige Provider: public.image + public.url -> Bild gewinnt (ein Anhang, kein Doppel, der Link entfaellt);
com.adobe.pdf + public.file-url -> pdf; Text + Bild -> Bild gewinnt, Text bleibt ueber attributedContentText.
Ein Provider liefert genau einen Eintrag (if/else-if-Kette), also nichts doppelt.

Speicher: Hauptweg loadFileRepresentation + copyItem, keine Bytes im Speicher. Rueckfall loadDataRepresentation
(ShareViewController.swift:127-136) haelt Data kurz und schreibt sofort in Temp; die Spec erlaubt das ausdruecklich. AKZEPTIERT; Rest-Risiko siehe F003.

Fehlerpfade: Ordner nicht anlegbar -> Log, Anhangszweig uebersprungen (Text/Link/Mail laufen weiter); Provider nil/Fehler ->
logFailure (Domain+Code, kein Name/Inhalt); adopt wirft -> gleiche Behandlung. Kein try? im Diff, Logger ueberall.
Continuation: Dateipfad genau ein resume (guard-return oder Result), Datenpfad ebenso; defer raeumt Staging nach dem resume.
Swift 6: Build ohne Fehler. Funktionslaengen: collect ca. 43, attachment(from:) ca. 40, present ca. 25, adopt ca. 16 -> alle <= 50.
Lokalisierung: Attachments, Photo, Too large (max. 50 MB) - not attached, More than 10 - not attached stehen mit en (Quelle) und de in
Localizable.xcstrings; Schluessel stimmen mit Section und String(localized:) ueberein.
Scope: Diffstat = CLAUDE.md, Info.plist, xcstrings, ShareCaptureView, ShareViewController, project.yml + neue Datei;
Shared/Models, cloudkit, SharedAttachment, SharedContent, CaptureService, AttachmentKind unberuehrt.
AC-5: Diff zeigt im Mail/URL/Text-Zweig nur das vorangestellte else-if des Anhangszweigs und den Parameter an SharedContent.make;
die Koerper der drei Bestandszweige sind unveraendert, deren Typen liefern attachmentType == nil (Skript), also kein
loadFileRepresentation/adopt fuer sie.
AC-6: grep: Regel nennt public.image und public.data zusaetzlich, TRUEPREDICATE 0 Treffer in project.yml und Info.plist, nur
@count >= 1; Info.plist traegt denselben Text. Commit-Reihenfolge ist erst beim Committen pruefbar: Es MUESSEN zwei Commits
werden, zuerst alles ausser project.yml und LooseEndsShare/Info.plist, danach diese beiden.
Simulator-Bilder alle geoeffnet: sim-ac7-foto-maske (leeres Feld mit Cursor, Tastatur, Fertig ausgegraut, Anhaenge mit foto13.PNG
und 868 Byte); sim-ac7-foto-detail (Detail Foto vom Zaehlerstand ablegen, ANHAENGE foto13.PNG); sim-ac8-pdf-maske (Prefill
Rechnung Stadtwerke Oktober, Fertig aktiv, Zeile Dokumentsymbol, 607 Byte); sim-ac8-pdf-detail (ANHAENGE mit der PDF);
sim-ac9-elf-fotos-unten (foto07..12 mit Groesse, foto13 mit grauem Mehr als 10 - nicht angehaengt); sim-ac9-elf-fotos-detail-unten
(foto04..12 sichtbar, danach Foto/Datei/Scan); sim-ac9-zu-gross (Film.mov, grau Zu gross (max. 50 MB) - nicht angehaengt, Fertig gesperrt);
sim-ac9-zu-gross-detail (keine Anhangszeile); sim-ac10-nach-abbrechen (Teilen-Blatt von Fotos wieder da). AC-10: Zeitleiste in
sim-nachweis.md zeigt Ordner je Fall nach Fertig/Abbrechen leer; plausibel, weil removeAttachments() vor completeRequest/cancelRequest laeuft.
Hinweis: Detail-Bilder stammen laut Nachweis aus kopiertem Store (Simulator ohne App-Gruppe); Uebergabe bleibt Stufe 3.
**Implementierer:** (nicht beteiligt, Kontext isoliert)

### Runde 2
**Adversary:** Gezielt gegen Kanten. (a) Interaktives Wegwischen des Blatts ruft weder finish noch cancel auf, der Ordner bliebe
liegen (F002, LOW; Spec verlangt Aufraeumen nur nach Fertig und Abbruch). (b) Elfte und weitere Dateien werden vor classify
kopiert (11 Dateien im Beobachter): bei 100 grossen Fotos temporaer viel Platzbedarf (F001, LOW). (c) Schlaegt adopt nach
gegluecktem loadFileRepresentation fehl (z. B. Platte voll), greift der Datenrueckfall und laedt Data ohne Groessenpruefung (F003, LOW;
nur im seltenen Doppelfehler, Spec erlaubt den Rueckfall). (d) Datei aus Dateien mit Texttyp (txt, csv, md, json) bleibt Text, nicht Anhang:
entspricht Text behaelt Vorrang der Spec; AKZEPTIERT. (e) Ordner nicht anlegbar: Dateien still (nur Log) nicht angehaengt, wie
geloggt und uebersprungen der Spec. (f) Speichern-Fehler raeumt nicht auf, Abbrechen raeumt, wie spezifiziert. (g) AC-11 steht in der Spec
als Stufe 3 nach dem Merge ueber TestFlight, Ticket bleibt bis zur Rueckmeldung offen: klar benannt, nachgelagert, nicht Teil dieses
Verdicts (Spec-Status draft / Approval offen ist Sache des Orchestrators). Keine Kante bricht eine AC; alle drei Funde LOW.
**Implementierer:** (nicht beteiligt)

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsShare/ShareViewController.swift:68
  Description: Jeder Provider wird kopiert, auch die ueber die Zehnergrenze; classify entscheidet erst danach.
  Spec requirement: AC-9 - elfte Zeile nicht angehaengt (erfuellt)
  Conflict: Unnoetiger Temp-Platz bei sehr vielen Dateien; kein Verstoss.
  Remediation: Ab dem elften Anhang nicht kopieren (nur Groesse lesen).

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsShare/ShareViewController.swift:24
  Description: Aufraeumen nur in finish/cancel; Wegwischen des Blatts loescht den Ordner nicht.
  Spec requirement: AC-10 - nach Fertig und Abbrechen geloescht (erfuellt)
  Conflict: Rest bleibt im Temp der Erweiterung, bis das System raeumt.
  Remediation: Zusaetzlich in viewDidDisappear/deinit aufraeumen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsShare/ShareViewController.swift:127
  Description: Datenrueckfall laeuft auch nach fehlgeschlagenem adopt und ohne Groessenpruefung.
  Spec requirement: Implementation Details - Rueckfall nur, wenn Dateirepraesentation fehlt
  Conflict: Bei Doppelfehler koennte eine grosse Datei als Data geladen werden.
  Remediation: Rueckfall nur, wenn das Laden (nicht adopt) fehlschlug.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: Shared/Services/SharedAttachmentFile.swift:12
  Evidence: attachmentType; sieben Erwartungen in SharedAttachmentFileTests gruen, UTType-Skript bestaetigt Hierarchie.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/SharedAttachmentFile.swift:23
  Evidence: adopt kopiert in UUID-Unterordner, Namenskette in fileName; Tests gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Services/SharedAttachmentFile.swift:27
  Evidence: Groesse vor Kopie, ueber fits() keine Kopie; fehlende Quelle wirft; Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Services/SharedAttachmentFile.swift:60
  Evidence: makeDirectory/remove idempotent, Fehler geloggt; Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsShare/ShareViewController.swift:68
  Evidence: Anhangszweig vor den unveraenderten Bestandszweigen, deren Typen attachmentType nil liefern.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEndsShare/Info.plist:32
  Evidence: Regel mit public.image und public.data, kein TRUEPREDICATE, nur @count >= 1, identisch mit project.yml; Commit-Reihenfolge beim Committen einzuhalten.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEndsShare/ShareCaptureView.swift:40
  Evidence: Section Attachments mit ShareAttachmentRow; Bilder sim-ac7-* geoeffnet und beschrieben (Runde 1).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEndsShare/ShareCaptureView.swift:73
  Evidence: save reicht attachments durch; Prefill und Detail in sim-ac8-* gesehen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEndsShare/ShareCaptureView.swift:83
  Evidence: Hinweistexte overLimit/tooLarge in der Zeile; Bilder sim-ac9-* gesehen; xcstrings en+de.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEndsShare/ShareViewController.swift:49
  Evidence: removeAttachments vor completeRequest/cancelRequest; Zeitleiste in sim-nachweis.md.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: LooseEndsShare/ShareViewController.swift:110
  Evidence: Per Design Stufe 3 nach Merge (TestFlight), in der Spec so benannt; nicht Teil dieses Verdicts; Codeweg loadFileRepresentation vorhanden.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 6 passed (SharedAttachmentFileTests, eigener Lauf), 0 failed, 0 übersprungen in der Zielsuite; Volllauf des Implementierers 809 grün
Edge cases: geprüft, drei LOW-Funde (F001-F003), keine bricht eine AC
Regressions: None found
Checklist: AC-1 bis AC-10 bewiesen, AC-11 nachgelagert (Stufe 3 nach Merge)

## Geprüfte Dateien

- sha256:fbf3c7fab9ea8bdc5e8899326f9f2a23d8ad8ef7b4dc6f13425513f190bba605  LooseEndsShare/Info.plist
- sha256:71c89d580b931b59d8da06978645e0dd24892eb5c4089fad77e23b3cfba2d522  LooseEndsShare/ShareCaptureView.swift
- sha256:191d1e10d0abd3a67b44edafa9ab0bee6cd544c1ad4e21d228f818d129ea1299  LooseEndsShare/ShareViewController.swift
- sha256:2dd66796d6bddfc02603e7bfa48dc7f87df0d8436e2a76f2b2c2b6ca139ce2af  Shared/Services/SharedAttachmentFile.swift

## Prüfbasis

- base: d7d4c657fdb432269c5fcaac77a276e2c3468578
- blob:5e9efb331088caafdcdeffe8495ebaa23bcdb91f  LooseEndsShare/Info.plist
- blob:5963ee9a2203a33ba907fe7553ad68205409a1b9  LooseEndsShare/ShareCaptureView.swift
- blob:2b5c48f72a3e359a75c9c03940094f0de3dfc9ac  LooseEndsShare/ShareViewController.swift
- blob:4c3ff0774e90bfdb7c664de71f1312753f258b03  Shared/Services/SharedAttachmentFile.swift
