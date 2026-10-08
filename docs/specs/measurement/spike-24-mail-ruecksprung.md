---
entity_id: spike-24-mail-ruecksprung
type: feature
created: 2026-10-08
updated: 2026-10-08
status: draft
workflow: spike-24-mail-ruecksprung
---

# Spec: Spike #24 — Mail-Rücksprung über die Teilen-Erweiterung (Messung)

**Status:** draft · **Workflow:** spike-24-mail-ruecksprung · **Erstellt:** 2026-10-08 · **Aktualisiert:** 2026-10-08

## Approval

- [ ] Approved

## Purpose

Entscheidung #6 / ADR-9 legt fest: Eine aus Apple Mail geteilte Aufgabe speichert eine `message:`-URL
in `TaskItem.sourceURL` und springt damit zur Quell-Mail zurück. Belegt ist das nur mit einer
Beispielmail in `SharedContentTests`, nie mit dem, was Mail wirklich an die Teilen-Erweiterung gibt.
Die Recherche (2026-10-08) spricht dagegen: iOS Mail hat keinen Teilen-Knopf für eine ganze Nachricht,
`public.email-message` kommt in der Praxis nicht an, markierter Text enthält keine Message-ID. Für
iOS 26/27 ist nichts belegt. Der Spike klärt, was ankommt, ob der Rücksprung die richtige Mail öffnet
und welcher Fallback gilt (Issue #24, offene Frage 5 in `02-datenmodell-und-ansichten.md`).

**Ohne Modell:** Reiner Mess- und Regelweg. Die Message-ID-Auswertung (`SharedContent.messageURL`)
bleibt Regel; es gibt kein Feld, für das ein Sprachmodell vorgeschlagen wird.

## Source

- **File:** `LooseEndsShare/ShareViewController.swift` — **Identifier:** `ShareViewController.collect(from:)` (Messpunkt)
- **File:** `Shared/Services/SharedContent.swift` — **Identifier:** `SharedContent.make(texts:urls:mails:)`, `messageURL` (unverändert)
- **File:** `LooseEnds/Views/TaskDetailView.swift` — **Identifier:** Abschnitt „Source“ (Zeile ~189, nur Beschriftung)
- **File:** `LooseEndsTests/SharedContentTests.swift` — **Identifier:** bestehende Kopfzeilen-Tests
- **File:** `docs/reference/mail-ruecksprung-messung.md` (neu) — **Identifier:** Messbericht

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `NSExtensionItem` / `NSItemProvider` | Upstream, API | Quelle dessen, was Mail an die Erweiterung gibt; `registeredTypeIdentifiers` zeigt die Typen |
| Apple Mail (iOS 27) | Upstream, System | liefert, was es liefert; nicht beeinflussbar |
| `message:`-URL (Message-ID) | Upstream, System | Rücksprung ([NSHipster](https://nshipster.com/message-id/)) |
| `CaptureService.save(..., sourceURL:)`, `TaskItem.sourceURL` | Downstream | speichern die URL; unverändert, kein neues Modellfeld |
| Prüfkennung `com.henning.looseends.probe` (#156), `xctrace --launch` (Gerätelog) | Werkzeug | Gerätelauf neben Hennings Alltags-App |
| ADR-9, Entscheidung #6, User-Story-Muss „Rücksprung“ | Downstream | könnten nach dem Ergebnis angepasst werden |
| #25 (Siri-Reminders) | Downstream | Alternative B baut auf ihm auf |

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEndsShare/ShareViewController.swift` | MODIFY (+~12) | Typkennungen je Anhang ins Log (AC-1) |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY (nur falls die Messung `message:` bestätigt, ~3) | Beschriftung „Open in Mail“ (AC-5) |
| `LooseEndsTests/SharedContentTests.swift` | MODIFY (nur falls der Fallback Code braucht) | Test Absender-Text |
| `docs/reference/mail-ruecksprung-messung.md` | CREATE | Messbericht je Konto und Weg (AC-2, AC-3) |
| `docs/project/02-datenmodell-und-ansichten.md`, `docs/project/04-stand.md` | MODIFY | Ergebnis (AC-4, AC-7) |

Umfang: 3–6 Dateien, ca. +60/−10 Zeilen Code, Rest Dokumentation. Unter den Grenzen.

**Nicht Teil dieser Änderung:** Drop-Ziel (Drag & Drop), `NSUserActivity`, Siri-Weg (#25), neue
Modellfelder (kein CloudKit-Schemaeintrag nötig).

## Implementation Details

1. **Messpunkt:** In `collect(from:)` je Anhang `provider.registeredTypeIdentifiers` und den Typ des
   geladenen Werts (URL, String, Data, Datei) mit `Logger` (Kategorie `Share`) ausgeben, Typen
   `privacy: .public`, Inhalte nie. Kein Eingriff in den Ablauf.
2. **Messreihe (Gerät):** Prüfbau installieren, Henning teilt aus Mail; das Log kommt per
   `xctrace --launch`, nicht per `device-console` (zeigt nichts, #160).
3. **Rücksprung:** gespeicherte oder von Hand gesetzte `message:`-URL öffnen; Randfälle gelöschte Mail
   und entferntes Konto.
4. **Auswertung:** Bericht, Ergebnis in Frage 5, Fallback und Folge-Issues.

## Expected Behavior

- Das Teilen funktioniert wie bisher; nur das Log ist reicher.
- Ergebnis ist eine der Aussagen: „Mail liefert `message:`/Message-ID zuverlässig“, „nur auf Weg X“
  oder „nie“, jeweils mit Konto und Weg belegt.
- Fallback bei „nie“: Betreff und Absender bleiben als Text; ohne `sourceURL` kein Link.

## Test Plan

- Unit: `SharedContentTests` bleiben grün (AC-8); neue Tests nur, falls Code für den Fallback entsteht.
- Simulator (Stufe 2): Erweiterung mit Text und URL teilen, das Log zeigt die Typkennungen (AC-1);
  die Aufgabe zeigt „Source“ nur mit URL.
- Gerät (Stufe 3, Pflicht, `LooseEndsShare/` steht auf der Geräteliste): Messreihe AC-2/AC-3. Läuft
  erst, wenn Henning wörtlich „jetzt ist ein Test möglich“ schreibt; die Anfrage nennt Ablauf und
  Dauer (ca. 15 Min., Prüfbau, vier Mails aus zwei Konten). Henning teilt und tippt, ich lese das
  Log aus und werte aus.

## Acceptance Criteria

- **AC-1 Messpunkt:** Given ein Teilen-Vorgang in der Teilen-Erweiterung / When die Anhänge gelesen
  werden / Then steht je Anhang die Liste seiner Typkennungen (`registeredTypeIdentifiers`) und je
  Eintrag der geladene Typ im Log (`Logger`, Kategorie `Share`), ohne Inhalte (kein Betreff, kein
  Text, keine Adressen). Das Verhalten der Erweiterung ändert sich nicht.
- **AC-2 Messreihe:** Given der Prüfbau „LE Prüfbau“ auf dem iPhone / When aus Mail mindestens vier
  Nachrichten aus mindestens zwei Konten auf allen erreichbaren Wegen geteilt werden (markierter
  Text, Drucken → Teilen, Teilen-Knopf falls vorhanden) / Then liegt je Vorgang eine Zeile „Konto,
  Weg, Typkennungen, ob `message:`-URL oder Message-ID ankam“ im Bericht.
- **AC-3 Rücksprung:** Given eine gespeicherte oder von Hand gesetzte `message:`-URL / When sie
  geöffnet wird / Then ist im Bericht festgehalten, ob die richtige Mail erscheint — für Mail im
  Postfach, gelöschte Mail und entferntes Konto, je mit Beobachtung.
- **AC-4 Ergebnis:** Given die Messreihe / When sie ausgewertet ist / Then steht in
  `docs/project/02-datenmodell-und-ansichten.md` (Frage 5) „zuverlässig“ oder „unzuverlässig“ mit den
  Einschränkungen und den Belegen aus dem Bericht.
- **AC-5 Fallback:** Given das Ergebnis / When Mail keine verwendbare URL liefert / Then ist der
  Fallback entschieden und dokumentiert. Vorbehaltlich der Messung: Betreff (Titelvorschlag) und
  Absender bleiben als Text in der Aufgabe; „Source“ erscheint nur bei gesetzter `sourceURL` (bereits
  so) und heißt bei einer `message:`-URL „Open in Mail“; kein Ausblenden nach Verdacht, weil die App
  nicht wissen kann, ob die Mail noch existiert.
- **AC-6 Folgeentscheidung:** Given das Ergebnis / When Teilen als Weg unbrauchbar ist / Then ist für
  Drag & Drop (Alternative A) und Siri-Bildschirminhalt (#25, Alternative B) je ein GitHub-Issue
  angelegt oder ein bestehendes verlinkt; ADR-9 und das User-Story-Muss „Rücksprung“ sind angepasst
  oder ausdrücklich bestätigt.
- **AC-7 Stand:** Given der Spike ist fertig / When `docs/project/04-stand.md` gelesen wird / Then
  ist Spike-Punkt 2 mit Ergebnis und Link zum Bericht aktualisiert.
- **AC-8 Bestehende Tests:** Given der Funktionsumfang / When Unit-Tests laufen / Then bleiben alle
  grün (inkl. `SharedContentTests`).

## Risiken

- **Gerätegrenze:** Belastbar ist nur Hennings iPhone; nichts läuft dort vor seinem wörtlichen
  „jetzt ist ein Test möglich“.
- Mail liefert womöglich auf keinem Weg etwas Verwendbares: dann ist das Ergebnis „unbrauchbar“, und
  der Spike ist trotzdem erfüllt (Fallback, Folge-Issues).
- Ob eine gelöschte Mail beim Öffnen sauber scheitert, ist nicht belegt; Beobachtung statt Annahme.

## Alternativen (zu ADR-9)

| Alternative | Kippt welche Entscheidung | Einschätzung |
|---|---|---|
| A. Drag & Drop einer Mail in die App (iPad/Mac) | ADR-9: Share nicht mehr Hauptweg | bei Wettbewerbern belegt; eigenes Ticket, falls Teilen unbrauchbar |
| B. Siri-Bildschirminhalt von Mail über #25 | ADR-9 Teil „App-Schema“ wird Hauptweg | passt zu Hennings Siri-Wunsch; hängt an #25 |
| C. Weiterleiten an eigene Adresse / Mac-Skript | Rücksprung als Muss | aufwendig, schwach |
| D. Kein Rücksprung, nur Betreff und Absender als Text | Entscheidung #6 „Rücksprung: ja“ | Nulllinie, heute schon vorhanden; macht das Muss zum Kann |

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Der Spike misst nur und ändert ADR-9 nicht. Eine Anpassung von ADR-9 wäre das
Ergebnis der Auswertung (AC-6), nicht dieser Spec.

## Recherche (2026-10-08)

Quellen und Befunde: `docs/context/spike-24-mail-ruecksprung.md` (DEVONtechnologies-Forum, MPU Talk,
MacStories „iOS 8, Email, and Extensions“, OmniGroup-Forum, NSHipster „Message-ID and Mail.app Deep
Linking“, Apple-Forum 705696). Für iOS 26/27 ist nichts belegt; das klärt nur die Messung.

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt; alle Unit-Tests grün.
- [ ] Stufe 2 (Simulator) mit angesehenen Screenshots; Stufe 3 (Gerät) als Messreihe nach Hennings „jetzt ist ein Test möglich“.
- [ ] `docs/reference/mail-ruecksprung-messung.md`, Frage 5 in `02-datenmodell-und-ansichten.md` und `04-stand.md` aktualisiert.
- [ ] Fallback entschieden und dokumentiert; Folge-Issues angelegt oder verlinkt.
- [ ] Issue #24 mit `Closes #24` im PR; Hennings Alltags-App unverändert.

## Changelog

- 2026-10-08: Spec aus der Analyse in `docs/context/spike-24-mail-ruecksprung.md` geschrieben.
