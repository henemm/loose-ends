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
