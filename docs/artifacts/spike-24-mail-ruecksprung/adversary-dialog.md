# Adversary Dialog — spike-24-mail-ruecksprung
Spec: docs/specs/measurement/spike-24-mail-ruecksprung.md
Datum: 2026-10-08 19:40

## Checkliste
- [x] Das Teilen funktioniert wie bisher; nur das Log ist reicher.
- [x] Ergebnis ist eine der Aussagen: „Mail liefert `message:`/Message-ID zuverlässig“, „nur auf Weg X“
- [x] Fallback bei „nie“: Betreff und Absender bleiben als Text; ohne `sourceURL` kein Link.
- [x] **AC-1 Messpunkt:** Given ein Teilen-Vorgang in der Teilen-Erweiterung / When die Anhänge gelesen werden / Then steht je Anhang die Liste seiner Typkennungen (`registeredTypeIdentifiers`) und je Eintrag der geladene Typ im Log (`Logger`, Kategorie `Share`), ohne Inhalte (kein Betreff, kein Text, keine Adressen). Das Verhalten der Erweiterung ändert sich nicht.
- [x] **AC-2 Messreihe (geändert per override 2026-10-08):** Given der Prüfbau „LE Prüfbau“ auf dem iPhone / When Henning in Mail jeden erreichbaren Weg einmal ausprobiert (ganze Mail teilen, Text markieren und teilen, Drucken → Teilen) / Then liegt je Weg eine Zeile „Weg, was ankam, ob `message:`-URL oder Message-ID ankam“ im Bericht, aus Hennings Beobachtung und der Recherche. Die Typkennungen aus dem Log und die Vorgabe „vier Mails, zwei Konten“ entfallen: Henning beendete den Gerätelauf, und auf keinem Weg kam eine `message:`-URL an.
- [x] **AC-3 Rücksprung (geändert per override 2026-10-08):** Given der Bericht / When der Rücksprung gewertet wird / Then steht dort, dass er mangels `message:`-URL nicht gemessen werden konnte, mit dem Stand der Recherche (öffnet auf iOS, wenn die Mail im Postfach liegt; gelöschte Mail und entferntes Konto unbelegt). Die Frage geht an das Folgeticket (AC-6).
- [x] **AC-4 Ergebnis:** Given die Messreihe / When sie ausgewertet ist / Then steht in `docs/project/02-datenmodell-und-ansichten.md` (Frage 5) „zuverlässig“ oder „unzuverlässig“ mit den Einschränkungen und den Belegen aus dem Bericht.
- [x] **AC-5 Fallback (geändert per override 2026-10-08):** Given Mail liefert keine verwendbare URL / When geteilt wird / Then ist der Fallback entschieden und dokumentiert: Datei-Links (Drucken → Teilen liefert eine PDF) werden weder `sourceURL` noch Titelvorschlag (`SharedContent.make`, Tests `fileLinkDropped`, `fileLinkWithText`, Regression `webLinkStaysSource`); „Source“ erscheint nur bei gesetzter `sourceURL`. Die Beschriftung „Open in Mail“ entfällt, weil nie eine `message:`-URL ankommt.
- [x] **AC-6 Folgeentscheidung:** Given das Ergebnis / When Teilen als Weg unbrauchbar ist / Then ist für Drag & Drop (Alternative A) und Siri-Bildschirminhalt (#25, Alternative B) ein gemeinsames GitHub-Issue angelegt (erledigt: #289); ADR-9 und das User-Story-Muss „Rücksprung“ bleiben bis dahin unverändert und sind dort zur Entscheidung gestellt.
- [x] **AC-7 Stand:** Given der Spike ist fertig / When `docs/project/04-stand.md` gelesen wird / Then ist Spike-Punkt 2 mit Ergebnis und Link zum Bericht aktualisiert.
- [x] **AC-8 Bestehende Tests:** Given der Funktionsumfang / When Unit-Tests laufen / Then bleiben alle grün (inkl. `SharedContentTests`).

## Dialog

### Runde 1
**Adversary:** Diff gelesen, Tests selbst gelaufen. Befunde:
Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEndsShare/ShareViewController.swift:64
  Description: Die Messzeile (`SharedContent.probeLine`, Typkennungen und geladene Art, ohne Inhalt) steht im Code, wurde aber nie zur Laufzeit gesehen. device-run*.txt enthalten keine `types=`-Zeile; ein Simulator-Teilen ist ohne Mail-Konto nicht moeglich.
  Spec requirement: AC-1 - je Anhang Typkennungen und geladener Typ im Log (Kategorie Share)
  Conflict: Nur Code-Lesung und der Unit-Test der Zeilenform belegen AC-1, nicht der echte Ablauf. Spec raeumt selbst ein, dass die Typkennungen nicht gemessen wurden (per override).
  Remediation: Entweder AC-1 im Bericht ausdruecklich als "eingebaut, nicht beobachtet" fuehren oder beim naechsten erlaubten Geraetelauf die Zeile beobachten.
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/SharedContent.swift:17
  Description: `urls.filter { !$0.isFileURL }` ist korrekt fuer file-URL neben message:-Link (Link bleibt, Zeile 19), mehrere URLs (erste Nicht-Datei-URL gewinnt, Zeile 32) und Datei allein (leer, Zeile 35). Getestet sind nur Datei allein, Datei+Text, https. Der Fall Datei neben message:-URL hat keinen eigenen Test.
  Spec requirement: AC-5 - Datei-Links weder sourceURL noch Titelvorschlag, Web-Links bleiben
  Conflict: Kein Fehlverhalten gefunden, nur Testluecke.
  Remediation: Optional ein Test "file + message: bleibt message:".
Finding:
  ID: F003
  Severity: MEDIUM
  Category: regression
  Code reference: LooseEndsShare/ShareViewController.swift:49
  Description: test-green-output2.txt (Lauf 18:31) ist aelter als die letzte Aenderung an ShareViewController.swift (18:33). Der Beleg deckt den letzten Stand der Erweiterung nicht ab.
  Spec requirement: AC-8 - alle Unit-Tests gruen
  Conflict: Beleg formal veraltet. Ich habe deshalb selbst `sim.sh build` (Build Succeeded, LooseEndsShare mitgebaut: adversary-build.txt) und `sim.sh unit` (Test Succeeded, 465 Haken, 0 Fehler; adversary-unit-output.txt) auf dem aktuellen Stand gefahren. Damit erledigt.
  Remediation: Keine; adversary-unit-output.txt ist der Beleg.
**Implementierer:** (nicht beteiligt; Kontext isoliert)

### Runde 2
**Adversary:** Nachgebohrt. (1) Datenschutz: ShareViewController.swift:62-65 loggt nur `registeredTypeIdentifiers` und die Art (data/file/mail/url/text); keine Betreffe, Texte, Adressen, URLs. Die zwei bestehenden Fehlerzeilen (61, 86) sind unveraendert. (2) Verhalten: Aenderung am Ablauf nur die lokale Variable `kind` und das Log; ein Wurf in `loadItem` erreicht das Log mit loaded=none, die Schleife laeuft weiter. Einzige Verhaltensaenderung ist der Datei-URL-Filter (per override AC-5 gewollt): Eine allein geteilte Datei ergibt jetzt leeren Vorschlag statt Pfad als Titel. (3) Die Messdatei-Funktion ist entfernt: kein FileManager/write in ShareViewController.swift. (4) Alle Aufrufer: SharedContent.make wird nur von ShareViewController.swift:68 gerufen. (5) Doku: Frage 5 beantwortet, 04-stand Punkt 2 aktualisiert (nennt aber nur "Folgeticket", nicht #289: kleine Luecke); #289 existiert und ist offen.
**Implementierer:** (nicht beteiligt)

### Runde 3 (neue Belege)
**Adversary:** F001: simulator-share-log.txt geprueft. Befehle, Simulator-UDID, Subsystem/Kategorie-Praedikat und Zeile `types=[public.url] loaded=url` (19:48:10) liegen nach dem bestandenen Wegwerf-UI-Test (19:48:09), Zeitfolge stimmt; die Zeile enthaelt keine URL. Einschraenkung: der Rohlog liegt nicht ab, die Zeile ist wortwoertlich uebertragen; das Format passt exakt zu probeLine. Fuer den Teilen-Weg Safari belegt das AC-1 (Typkennung plus geladene Art, ohne Inhalt) zur Laufzeit; Mail-Typkennungen vom Geraet bleiben bewusst unerhoben (AC-2 per override). F002: Test fileLinkNextToMessageLink existiert (SharedContentTests.swift:75) und ist in meinem erneuten vollen Lauf gruen. F003: Ein Teil-Lauf reicht nicht als Beweis, daher voller Lauf nach der letzten Aenderung: adversary-unit-output2.txt, Test Succeeded, 466 Haken, 0 Fehler. Hashes von ShareViewController.swift und SharedContent.swift per shasum unveraendert zum Stempel.
**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

AC-1 jetzt auch zur Laufzeit im Simulator belegt (Safari-Teilen, simulator-share-log.txt); AC-2 bis AC-8 belegt. Voller Unit-Lauf auf dem Endstand: 466 bestanden, 0 fehlgeschlagen, 0 uebersprungen; Build der Erweiterung erfolgreich.

Confirmation:
  AC: AC-1 (Code vorhanden, Laufzeit offen)
  Code reference: LooseEndsShare/ShareViewController.swift:64
  Evidence: Log-Zeile ohne Inhalt nach jedem Anhang; Laufzeitzeile im Simulator belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Services/SharedContent.swift:17
  Evidence: Datei-URLs werden gefiltert; https und message: bleiben; Tests fileLinkDropped, fileLinkWithText, webLinkStaysSource gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Shared/Services/SharedContent.swift:40
  Evidence: adversary-unit-output.txt Test Succeeded; adversary-build.txt Build Succeeded inkl. LooseEndsShare.
  Status: CONFIRMED

## Geprüfte Dateien

- sha256:68a1234dee5d34273dc0314a9bde0eb1bc1817364fdaf2432aa477833c5fd6bf  LooseEndsShare/ShareViewController.swift
- sha256:3aa62c7bd588c7e254f532c2243a3435adf45e7874683155a41d76650f3361f1  Shared/Services/SharedContent.swift

## Prüfbasis

- base: 39a6c161eaf313ffa84261baf720cc2f3fbb4efb
- blob:314679138651f29bcc7a5515de1c299ec211051a  LooseEndsShare/ShareViewController.swift
- blob:f4490247b47be3a5bb93cadb05a90abc988f8722  Shared/Services/SharedContent.swift

## Geprüfte Dateien

- sha256:68a1234dee5d34273dc0314a9bde0eb1bc1817364fdaf2432aa477833c5fd6bf  LooseEndsShare/ShareViewController.swift
- sha256:3aa62c7bd588c7e254f532c2243a3435adf45e7874683155a41d76650f3361f1  Shared/Services/SharedContent.swift

## Prüfbasis

- base: 39a6c161eaf313ffa84261baf720cc2f3fbb4efb
- blob:314679138651f29bcc7a5515de1c299ec211051a  LooseEndsShare/ShareViewController.swift
- blob:f4490247b47be3a5bb93cadb05a90abc988f8722  Shared/Services/SharedContent.swift
