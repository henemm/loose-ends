# Context: feat-842-s3-texte-schreiben

## Request Summary
#842 Schnitt 3: Die englische Store-Seite braucht Texte. Beschreibung, Schlüsselwörter, Support-URL (Werbetext optional) der
Versions-Lokalisierung en-US von iOS 1.0.1 werden aus einer Textdatei im Repo über einen Handlauf nach App Store Connect
geschrieben, mit Gegenprobe. Bilder sind Schnitt 4 und nicht Teil dieses Schnitts.

## Stand bei Apple (Probelauf 42270571558, 2026-11-06 18:25 UTC, nach Schnitt 2)
| Version | Zustand | de-DE | en-US |
|---|---|---|---|
| iOS 1.0.1 | PREPARE_FOR_SUBMISSION (bearbeitbar) | Beschreibung 1638, Schlüsselwörter 100, Support-URL gesetzt, Werbetext 0, Bilder ja | Datensatz **vorhanden, aber alles leer** (0/0/keine/0), keine Platzierung, keine Bildsätze |
| iOS 1.0 | READY_FOR_SALE (gesperrt) | vollständig, Werbetext 139 | gibt es nicht |
| macOS 1.0 | READY_FOR_SALE (gesperrt) | vollständig | gibt es nicht |

Folgerungen:
- iOS 1.0.1 hat den en-US-Datensatz schon (Schnitt 1 / #837 legte ihn mit der App-Info an), also **PATCH**, kein POST. Ein
  fehlender Datensatz (neue Mac-Version) braucht POST mit Relationship `appStoreVersion`.
- Eine Mac-Version im Zustand PREPARE_FOR_SUBMISSION gibt es heute nicht. „Nächste Mac-Version“ aus der DoD ist deshalb
  heute nicht prüfbar; das Skript muss „keine bearbeitbare Version dieser Plattform“ klar melden und nichts schreiben.
- Der deutsche Wortlaut steht **nicht im Repo**, nur bei Apple (in der Probe-Ausgabe lesbar). Ein englischer Wortlaut muss
  neu geschrieben werden: Beschreibung (DE hat 1638 Zeichen, Grenze bei Apple 4000), Schlüsselwörter eigenständig (≤ 100
  Zeichen, nicht übersetzt, mit Kommas ohne Leerzeichen), Support-URL, Werbetext (Grenze 170).
- Fallen im deutschen Text, die der englische anders lösen muss: Ansichtsnamen („Jetzt, Neu, Fällig, Schnell, Alt, Wartet,
  Geparkt, Erledigt“) heißen in der englischen App „Now, New, Due, Quick, Old, Waiting, Parked, Completed“
  (`LooseEnds/Resources/Localizable.xcstrings`); Kontextbeispiele „Garten“/„Computer“ passen nur deutsch.

## Related Files
| Datei | Relevanz |
|---|---|
| `scripts/asc_store_probe.py` | Liest Texte (`report_version_texts`) und Platzierungen; Beleg nach dem Schreiben. Hat den Abruf `appStoreVersions` → `appStoreVersionLocalizations` |
| `scripts/asc_app_info.py` | Vorbild für den Schreibweg: Abschnittsdatei je Locale, Grenzen vor dem ersten Aufruf prüfen, nur bei Abweichung schreiben, Gegenprobe, `send` mit klaren 403/409-Meldungen |
| `scripts/asc_what_to_test.py` | `send_json` (PATCH/POST mit Wiederholung bei 5xx/408/429, Fatal bei anderen 4xx) und `get_data` |
| `scripts/asc_beta_probe.py` | `records`, `attributes`, `Probe`, `fetch` |
| `scripts/asc_locales.py` | Sprachcode → ASC-Locale, Liste ausgelieferter Sprachen (de, en) |
| `scripts/asc_wait_build.py` | `read_config`, `find_app_id`, `Fatal` |
| `scripts/test_asc_app_info.py` | Muster für den Nachbau der API in Tests |
| `.github/workflows/asc-app-info.yml` | Muster für den Handlauf: Eingabe `aktion` lesen/schreiben, Unit-Tests, Schlüssel nur im Lauf |
| `docs/reference/app-store-untertitel.md` | Muster der Textdatei (`## de-DE`, `## en-US`, Zeilen `Name:`) |
| `docs/reference/beta-beschreibung.md` | Vorhandener englischer Ton und Wortlaut („Say it“, „Now“ list) |

## Existing Patterns
- Handlauf = GitHub-Workflow `workflow_dispatch`, Python ohne Abhängigkeiten, Schlüssel nur im Lauf, Ausgabe ohne Geheimnisse.
  Store-Texte sind öffentlich und dürfen in der Ausgabe stehen.
- Schreiben nur bei Abweichung, in genau einen bearbeitbaren Zustand (`PREPARE_FOR_SUBMISSION`), danach Gegenprobe gegen Apple.
- Grenzen und Pflichtfelder werden geprüft, bevor die erste Anfrage läuft.
- Lehre aus Schnitt 2 (und #136): Der Nachbau der API im Test darf den Fehler nicht mitbauen. Pfad und Form der Antworten
  kommen aus dem echten Lauf (`appStoreVersionLocalizations` mit Attributen `description`, `keywords`, `supportUrl`,
  `promotionalText`, wie die Probe sie schon liest).

## Dependencies
- Upstream: ASC-API (`PATCH /v1/appStoreVersionLocalizations/{id}`, `POST /v1/appStoreVersionLocalizations`), Schlüssel mit
  Recht für App-Store-Versionen (der Schlüssel schrieb schon App-Info-Texte in #837, also vermutlich ausreichend; ein 403
  zeigt es sofort).
- Downstream: Schnitt 4 (Bilder) hängt an derselben Versions-Lokalisierung; die Einreichung von 1.0.1 (DoD-Punkt 3) braucht
  zusätzlich die Bilder, kann also erst nach Schnitt 4 belegt werden.

## Existing Specs
- `docs/specs/feat-842-schnitt-1-probe-texte.md`, `docs/specs/feat-842-schnitt-2-platzierungspfad.md`
- #837-Spezifikation (Untertitel-Schreibweg), `docs/reference/app-store-untertitel.md`

## Risks & Considerations
- **Wortlaut ist ein Produktthema:** Henning gibt den englischen Text frei, bevor er hochgeladen wird (Ticket). Das Skript
  schreibt erst, wenn die Datei im Repo steht; der Entwurf geht in der Spec zur Freigabe.
- **Keine Einreichung:** Schnitt 3 reicht nichts ein und rührt die deutschen Texte nicht an.
- **Gesperrte Versionen:** Texte von iOS 1.0 und macOS 1.0 (READY_FOR_SALE) sind nicht änderbar; Schreibversuch wäre ein 409.
  Das Skript wählt die Version über den Zustand, nie die erste beste.
- **Mehrere Bearbeitbare:** Gibt es später iOS und macOS gleichzeitig in Bearbeitung, braucht es die Plattform als Wahl.
- **Werbetext/Support-URL:** Support-URL der deutschen Seite (`https://www.henemm.com/footer-information/contact/`) ist eine
  deutsche Seite; ob es eine englische Adresse gibt, ist zu klären (Alternative: dieselbe URL, wie viele Apps es tun).
- **Schlüsselwörter:** Apple verlangt Kommas ohne Leerzeichen; Wörter aus dem Namen/Untertitel zählen schon, sollten nicht
  doppelt stehen. Eigenständig gewählt (Regel aus dem Ticket: „eigene, nicht übersetzt“).
- **Tests:** Python-Unit-Tests laufen in CI im Handlauf-Workflow (`python3 scripts/test_asc_….py`) und lokal ohne Simulator.
  Kein Pfad der Geräteliste berührt.
- Umfang: Skript ~120 LoC, Tests ~150 LoC, Workflow ~35, Textdatei ~40 → an der 250-LoC-Grenze; Teilung nur, falls die
  Spec darüber landet.

## Analysis

### Type
Feature (Werkzeug + Textdatei, keine App-Änderung).

### Recherche (zuerst, 2026-11-06)
- Schreibweg: `PATCH /v1/appStoreVersionLocalizations/{id}` mit `description`, `keywords`, `supportUrl`, `promotionalText`, `marketingUrl`;
  Anlegen per `POST /v1/appStoreVersionLocalizations` mit Relationship `appStoreVersion`
  ([Apple: App Store Version Localizations](https://developer.apple.com/documentation/appstoreconnectapi/app-store-version-localizations.md)).
- Regel hinter dem Ticket: Haben App-Info und Version nicht dieselben Sprachen, scheitert die Einreichung
  ([Apple: POST appStoreVersionLocalizations](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appstoreversionlocalizations.md)).
  Der Wortlaut der Fehlermeldung ist nicht belegt; das Ticket hat ihn aus Apples Doku.
- Grenzen: Beschreibung 4000 Zeichen, Werbetext 170, Schlüsselwörter 100 **Bytes** (nicht Zeichen), Kommas ohne Leerzeichen. Apples eigene Seiten
  nennen die Zahlen nicht; sie stammen aus Drittquellen und sind nur Vorprüfung: Apple selbst meldet bei Überschreitung 409.
  Konsequenz: Schlüsselwörter werden in Bytes gezählt, Werbetext optional.
- Korrektur zum Kontext oben: Die englische App hat die Ansichtsnamen (Now, New, Due, Quick, Old, Waiting, Parked, Completed) **und** die
  Standard-Kontexte Computer, Phone, Home, Garden, Errands, Out and about (Quellsprache im Katalog). „Garden“/„Computer“ passen also auch englisch.
- Support-URL: eine englische Kontaktseite gibt es nicht (`/en/footer-information/contact/` und `/en/contact/` liefern 404). Dieselbe Seite wie deutsch.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/app-store-texte.md` | CREATE | Wortlaut je Locale (en-US: Beschreibung, Schlüsselwörter, Support-URL, Werbetext) – zur Freigabe durch Henning |
| `scripts/asc_version_texts.py` | CREATE | `lesen` / `texte`: wählt die eine bearbeitbare Version je Plattform, PATCH nur bei Abweichung, POST bei fehlendem Datensatz, Gegenprobe |
| `scripts/test_asc_version_texts.py` | CREATE | Tests mit Nachbau der API nach Form aus dem echten Probelauf |
| `.github/workflows/asc-version-texts.yml` | CREATE | Handlauf wie `asc-app-info.yml` |

### Scope Assessment
- Files: 4 (alle neu), Estimated LoC: +~330 (Skript ~120, Tests ~150, Workflow ~35, Text ~40) – **über 250 LoC**
- Risk Level: LOW (nur ein bearbeitbarer Datensatz, nur en-US, deutsche Texte und gesperrte Versionen werden nie angefasst)

### Technical Approach
Reines Python-Werkzeug nach dem Muster `asc_app_info.py`: Textdatei laden und vor der ersten Anfrage prüfen (Pflichtfelder Beschreibung,
Schlüsselwörter, Support-URL; Grenzen), App-Versionen holen, je Plattform genau eine im Zustand `PREPARE_FOR_SUBMISSION` wählen (keine → klare Meldung,
nichts geschrieben; mehrere → Fehler), Lokalisierungen holen, nur Abweichendes schreiben, Gegenprobe. Deutsche Datensätze nie anfassen (nur Locales aus der Datei).
Mac: heute keine bearbeitbare Version → Meldung „keine bearbeitbare Version“, kein Fehler; die DoD „nächste Mac-Version“ ist damit erst belegbar, wenn es sie gibt.
**Teilung wegen LoC-Grenze:** 3a = Skript + Tests + Workflow mit Probetext aus der Datei (~290 LoC, knapp drüber) – Vorschlag stattdessen: die Textdatei ist Inhalt, nicht Code; Code ≈ 300 LoC. Die Spec entscheidet, ob getrennt wird (Skript `lesen`+Prüfung / Schreiben).

### Alternativen
1. **Bestehendes `asc_app_info.py` erweitern** statt neues Skript: weniger Dateien, aber vermischt App-Info (Untertitel) und Version (Beschreibung); beide haben verschiedene Zustände und Pfade. Verworfen, außer die Spec findet eine gemeinsame Hilfsfunktion.
2. **Kein Skript, Henning fügt in App Store Connect ein:** schneller, aber er hat mit Hand-Arbeit nichts zu tun (und es gäbe keinen Beleg/Wiederholbarkeit). Verworfen.
3. **Deutsche Texte ins Repo holen und beide Sprachen aus einer Datei pflegen:** sinnvoll, weil der deutsche Wortlaut nur bei Apple liegt. Kippt keine ADR, erweitert aber den Schnitt (Gefahr: dann schriebe das Werkzeug auch Deutsch). Vorschlag: als Folge-Ticket, nicht jetzt; das Skript schreibt nur Locales, die in der Datei stehen.
4. **Werbetext weglassen:** Pflicht ist er nicht; ein Satz kostet nichts und lässt sich ohne neue Version ändern. Empfehlung: setzen.

„Ohne Modell geht es nicht, weil …“ entfällt: kein Modell beteiligt.

### Entwurf englischer Wortlaut (Freigabe durch Henning in der Spec)
Beschreibung (eigene Fassung, gleiche Gliederung wie deutsch, mit den echten englischen App-Begriffen):
```
Say it in one sentence – Loose Ends takes care of the rest.

Tasks show up on the go: on a walk, at the checkout, while reading an email. Loose Ends captures them in a single sentence, without a form to fill in. The app then works out what is in your sentence and later shows you just what fits your situation right now.

CAPTURE IN ONE SENTENCE
• Type or dictate – in the app, on Apple Watch, with widgets, the Action button and Shortcuts
• Share sheet: turn text, links, emails, photos and files straight into a task
• Your original sentence is always kept unchanged

THE APP SORTS IT FOR YOU
• Due date, duration, importance and context are recognized from your sentence
• Fixed rules first, Apple Intelligence on your device only where language understanding is needed
• Learns from your choices: tag a sentence once, and it knows next time

YOU HAVE THE LAST WORD
• Every change is visible on the task
• Every field can be reset on its own

VIEWS THAT FIT THE MOMENT
• Now, New, Due, Quick, Old, Waiting, Parked, Completed
• By tag ("Garden", "Computer") and by project
• Repeating tasks and subtasks

REMINDS YOU AT THE RIGHT TIME – AND PLACE
• Notification on the due day with Complete, Next up, Tomorrow
• Reminder on arriving at a place (iPhone, iPad)
• Optionally add dates to your calendar

EVERYWHERE YOU ARE
• iPhone, iPad, Mac and Apple Watch
• Sync through your private iCloud

PRIVATE
Analysis runs on your device. Your tasks live in your iCloud, not on someone else's servers.
```
Schlüsselwörter (94 Bytes; ohne Wörter aus Name/Untertitel „Loose Ends, Voice, Tasks, Say it, Clear your head“):
`to-do,todo,reminders,dictation,list,GTD,context,notes,planner,inbox,watch,projects,due,capture`
Werbetext (125 Zeichen): `Say it in one sentence. Loose Ends recognizes date, duration and tag right on your device and later shows you just what fits.`
Support-URL: `https://www.henemm.com/footer-information/contact/`

### Dependencies
Upstream: ASC-Schlüssel mit Recht für Versionen (403 zeigt es sofort). Downstream: Schnitt 4 (Bilder) hängt an derselben Lokalisierung; Einreichung von 1.0.1 erst danach.

### Open Questions
- [ ] Henning: Wortlaut der Beschreibung, Schlüsselwörter und Werbetext freigeben oder ändern (Produktthema, in der Spec).
- [ ] LoC: Spec entscheidet über Teilung (Code ≈ 300 LoC statt 250).
- [ ] Deutsche Texte ins Repo holen (Alternative 3) als eigenes Ticket?
