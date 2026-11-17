# Context: feat-625-store-datenschutz (#625, Vorbereitung)

## Request Summary
#625 bringt die App mit eingeschaltetem Konto („Claude“) in den Store. PO-Entscheidung 2026-11-17: **jetzt nur
vorbereiten** – App-Store-Datenschutzangaben, Datenschutz-Manifest, Auftragsverarbeitungsvertrag (AVV) mit Hetzner,
Datenschutztext auf aktuellen Stand, Freigabe durch Henning. Store-Schalter `LEAccountEnabled` und Einreichung erst,
wenn #795, #796 und #624 geschlossen sind (Kommentar im Issue).

## Related Files
| File | Relevance |
|------|-----------|
| `docs/reference/datenschutz-entwurf.md` | Quelle des Datenschutztexts (DE Z. 60–100, EN ab Z. 178); Konto-Teil seit #615 S4e live. **Fehlt:** die Abschrift (Liste offener Aufgaben, die die App seit #795 S3 an den Dienst sendet) und die Geräte-Kennung für den Weckruf (`device_tokens`, #795 S5a) |
| henemm-website `content/legal/loose-ends/privacy-policy{,-en}/_index.md` | öffentliche Fassung; eine Änderung gilt erst mit der Website |
| `LooseEnds/PrivacyInfo.xcprivacy` | `NSPrivacyCollectedDataTypes` leer; mit Konto im Store mindestens „User ID“ (Apple-Kennung), „Other User Content“ (Abschrift, Aufträge), ggf. „Device ID“ (Push-Token, `X-Device`) |
| `project.yml:82-84`, `LooseEnds/Info.plist` | `LEAccountEnabled: false` – bleibt in diesem Schnitt aus |
| `scripts/test_asc_what_to_test.py:282-286` | hält den Schalter aus – bleibt unverändert |
| `docs/reference/claude-abschrift-vertrag.md` | Inhalt der Abschrift: offene Aufgaben (Titel, Fälligkeit, Felder), „Jetzt“, ohne Rohtext und Notiz |
| `server/migrations/001–009` | was der Dienst speichert (Abschrift, Aufträge, Ergebnisse, Konten, Sitzungen gehasht, Apple-Token verschlüsselt, OAuth gehasht, Gerätetoken) |
| `LooseEnds/Claude/ClaudeSyncTrigger.swift`, `ClaudeSync.swift`, `DeviceRegistration.swift` | belegen, was die App sendet und wann |
| `scripts/asc_*.py`, `.github/workflows/asc-*.yml` | bestehende ASC-API-Werkzeuge (Store-Texte, Bilder, Version, Einreichen) – kein Weg für App-Privacy |
| `docs/project/00-entscheidungen.md` ADR-21 | Datenhaltung bleibt in iCloud; Dienst hält nur Abschrift/Aufträge |

## Existing Patterns
- Rechtstext: Entwurf im Repo mit Beleg-Tabelle, Hennings datierte Freigabe, EN wortgetreu, Website-PR (#705, #763, #615 S4e).
- Store-Sperre: Schalter aus in `project.yml`, nur TestFlight-Eingabe `konto` schaltet ein, `asc_store_version.py` ordnet
  einen solchen Bau nie einer Store-Version zu (#615 S4c-2a).
- ASC-Arbeit über CI-Workflows mit API-Schlüssel (`asc-store-*.yml`), nie über Hennings Konto.

## Dependencies
- Upstream: #795 (Abschrift-Upload ist gebaut, Weckruf S5c-2 offen), #796 (Betrieb, Überwachung), #624 (MCP-App, keine
  neuen Daten), Tür `ALLOWED_APPLE_SUBS` (nur Hennings Konto; Regel „geht mit #625“ laut CLAUDE.md).
- Downstream: Store-Update mit Schalter an (zweiter Teil von #625, später).

## Existing Specs
- `docs/specs/feat-615-schnitt-4e-datenschutz.md`, `feat-615-schnitt-4c2a-freischalten.md`, `feat-705-schnitt-2b2a-datenschutzseite.md`

## Recherche (2026-11-17)
- **App-Privacy-Angaben haben keine offizielle ASC-API.** fastlane `upload_app_privacy_details_to_app_store` nutzt eine
  inoffizielle Schnittstelle und verlangt eine Apple-ID mit Owner/Admin, kein API-Schlüssel
  (https://docs.fastlane.tools/actions/upload_app_privacy_details_to_app_store/). Apple:
  https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy – Angaben in App Store Connect
  (Web), Änderung jederzeit, gilt für alle Plattformen der App.
- **Hetzner AVV:** wird nicht automatisch geschlossen, Abschluss über das Kundenkonto (AGB Hetzner,
  https://www.hetzner.com/de/rechtliches/agb; TOMs https://docs.hetzner.com/de/general/others/technical-and-organizational-measures/).
  Braucht Hennings Hetzner-Anmeldung; Claude kann die Seite in seinem Browser öffnen, er meldet sich nur an.
- Off-site-Sicherung liegt auf Hennings eigenem Heimserver → kein Auftragsverarbeiter.

## Risks & Considerations
- Datenschutztext ist **heute schon unvollständig** für TestFlight-Bauten mit Konto: die Abschrift wird gesendet, steht
  aber nicht im Text. Sollte vor dem Schalter in jedem Fall nachgezogen werden.
- App-Privacy-Angaben gelten sofort für die live Version im Store (iOS und Mac). Daten als „gesammelt“ zu deklarieren,
  bevor der Schalter an ist, ist zulässig (Apple: „Daten, die Sie oder Partner sammeln“ – Überdeklaration ist kein
  Ablehnungsgrund), Unterdeklaration schon. Alternative: Angaben erst mit dem Schalter setzen.
- `PrivacyInfo.xcprivacy` ändert sich im App-Bundle → Pfad `Info.plist`-ähnlich? Nein, aber Bau-Ressource; Geräteliste
  nennt sie nicht. Manifest kann jetzt schon die Datentypen nennen, ohne Verhalten zu ändern.
- Zwei Repos (loose-ends, henemm-website), beide per PR.
- Was Henning tun muss: Wortlaut freigeben, bei Hetzner anmelden (AVV), bei App Store Connect anmelden (Privacy-Fragebogen),
  sofern nicht fastlane mit seiner Apple-ID – das wäre eine neue Abhängigkeit und Hennings Anmeldung in einem Skript.

## Analysis

### Type
Feature (Vorbereitung; Store-Schalter und Einreichung sind ein späterer Teil von #625)

### Befund
- Der Datenschutztext ist für Konto-Bauten heute schon unvollständig: die App sendet die **Abschrift** (je offener
  Aufgabe id, abgeleiteter Titel, Status, Fälligkeit/`dueHasTime`, Tag-Namen, Projektname, `nextRank`, `isKnaeuel`;
  dazu `nowCount` und Listen als IDs; kein Rohtext, keine Notiz, keine Anhänge, `Shared/Services/TranscriptCodec.swift`)
  und bei Aufträgen die **Geräte-Kennung** `X-Device` (`LooseEnds/Claude/DeviceIdentity.swift`). Server: `transcripts`
  eine Zeile je Konto, überschrieben, Kaskade beim Löschen (Migration 001/006).
- Der **Push-Token** (Migration 008, Klartext + Geräte-UUID, Abmelden behält die Zeile, max. 10) wird von der App noch
  nicht gesendet; Aufruf kommt mit #795 S5c-2 (andere Sitzung).
- Entwurf „Offen, nicht belegt“: „Aufgabenübertragung … nicht gebaut“ ist überholt.
- `scripts/test_datenschutz_text.py::test_no_transcript_in_account_section` **verbietet** heute „Abschrift“/„transcript“
  im Konto-Abschnitt (Sperre aus #615 S4e) → umdrehen.
- Fünf `PrivacyInfo.xcprivacy`, alle `NSPrivacyCollectedDataTypes` leer; nur das App-Target (`LooseEnds/`, iOS+macOS)
  enthält Konto-Code. Kein Test prüft Manifeste. `LooseEnds/PrivacyInfo.xcprivacy` steht nicht auf der Geräteliste
  (Stufe 3) → Abnahme endet nach Stufe 2.
- App-Store-Datenschutzangaben: keine offizielle API → Eintrag im ASC-Web; Claude öffnet die Seite in Hennings Chrome,
  Henning meldet sich nur an, Claude füllt aus (Muster CloudKit-Console). Dasselbe für den Hetzner-AVV.

### Affected Files (with changes)
| File | Change Type | Schnitt | Description |
|------|-------------|---------|-------------|
| `docs/reference/datenschutz-entwurf.md` | MODIFY | 1 | Absatz Abschrift + Geräte-Kennung (DE/EN wortgetreu), Beleg-Zeilen, „Offen“-Punkt ersetzt durch „Weckruf-Token folgt mit #795 S5c-2“, Status-Kopf „freizugeben“ |
| `scripts/test_datenschutz_text.py` | MODIFY | 1 | Verbot umdrehen (Abschnitt muss Abschrift nennen), neue Anker DE/EN |
| henemm-website `content/legal/loose-ends/privacy-policy{,-en}/_index.md` | MODIFY | 1 (nach Freigabe) | öffentliche Fassung |
| `LooseEnds/PrivacyInfo.xcprivacy` | MODIFY | 2 | User ID, Device ID, Other User Content; linked, kein Tracking, App Functionality |
| `scripts/test_privacy_manifest.py` | CREATE | 2 | alle fünf Manifeste: App-Target genau drei Typen, übrige leer |
| `docs/reference/app-store-datenschutzangaben.md` | CREATE | 3 | Antworten zum ASC-Fragebogen mit Belegen; Test: gleiche Typen wie Manifest |
| `docs/artifacts/feat-625-*/avv-hetzner.*` | CREATE | 4 | Beleg AVV (Datum, ohne Zugangsdaten), Beleg-Zeile im Entwurf |

### Scope Assessment
- S1: 2 Dateien (+ Website 2), ~100–130 LoC; S2: 2–3 Dateien, ~60–90 LoC; S3: 1–2 Dateien, ~60–80 LoC; S4: Beleg.
- Risk Level: LOW–MEDIUM (kein Verhalten der App ändert sich; Risiko liegt in Rechtsaussagen und Unterdeklaration).

### Technical Approach
Wortlaut-Prinzip wie bisher: nur, was gebaut und im Code belegt ist. Reihenfolge: S1 Text → Hennings datierte Freigabe →
Website-PR (schließt die heutige Lücke, unabhängig vom Schalter). S2 Manifest + Test, S3 Label-Vorlage. S4 AVV parallel.
Das ASC-Label wird erst zusammen mit der Version eingetragen, die den Schalter an hat (vorher Überdeklaration für 1.0.x
und Widerspruch zum Text „ohne Konto kein Datenverkehr“). Push-Token: eigener kleiner Nachzug nach #795 S5c-2, bis dahin
Punkt unter „Offen, nicht belegt“ und Prüfpunkt im Schalter-Gate. Optional-Disclosure-Ausnahme greift nicht (Abschrift
läuft nach Anmeldung automatisch, Kernfunktion des Features) → deklarieren.

### Alternativen
- A: Manifest erst mit dem Schalter (keine Bundle-Änderung in 1.0.x; dafür Text und Manifest auseinander).
- B: Label sofort setzen (Überdeklaration für die Live-Version, Widerspruch zum Text) – verworfen.
- C: Kein AVV („nur Infrastruktur“) – trägt nicht, Hetzner betreibt den Server mit Personendaten (Art. 28 DSGVO).
- D: Push-Token schon jetzt in den Text (spart eine Freigaberunde, bricht die Beleg-Regel).
Keine ADR fällt; ADR-21 bleibt (Daten in iCloud, Dienst hält nur Abschrift/Aufträge).

### Dependencies
#795 S5c-2 (Push-Token, andere Sitzung) für den Nachzug; henemm-website-PR; Hennings Anmeldung bei Hetzner und ASC.

### Open Questions
- [ ] Henning gibt den neuen Wortlaut (Abschrift, Geräte-Kennung) frei – in Phase Spec/Freigabe.
- [ ] Server-Protokoll-IPs (14 Tage, Missbrauchsabwehr) im ASC-Fragebogen: beim Ausfüllen gegen Apples Definition prüfen.

## Nachbesserung 2026-11-17 (aus /60-validate)

- Befund AC-2: `generatedAt` (Zeitpunkt der Abschrift) stand nicht im Absatz. Henning hat den Wortlaut am 2026-11-17 per
  AskUserQuestion freigegeben und die Ergänzung gewählt: DE „Außerdem steht darin, wann die Abschrift erstellt wurde.“,
  EN “It also states when the transcript was created.” (direkt nach dem Satz „… nur als Kennungen.“ / “… as identifiers only.”).
- Befund Ablauf: henemm-website#80 ging vor seiner ausdrücklichen Freigabe live; die Freigabe ist jetzt nachgeholt.
- Nächste Schritte: RED – beide Sätze als Anker in `ANCHORS` von `scripts/test_datenschutz_text.py` (Beleg `red.txt` neu);
  GREEN – Entwurf DE/EN ergänzen; Website-PR mit beiden Seiten, danach `live.txt`, `vergleich.txt`, `live-de.png`,
  `live-en.png` neu; voller CI-Lauf auf dem Endstand in `green.txt`; Abschlussbericht mit dem AC-16-Satz.
