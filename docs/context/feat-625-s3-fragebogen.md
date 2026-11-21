# Context: feat-625-s3-fragebogen (#625 Schnitt 3)

## Request Summary
Eine Vorlage für Apples Datenschutz-Fragebogen in App Store Connect („App-Datenschutz“, das Etikett auf der Store-Seite),
die genau sagt, was beim Umlegen des Konto-Schalters anzukreuzen ist. Eintragen selbst erst mit dem Schalter-Schnitt.
Vorher: PR #976 (Doku „kein eigener Server“) mergen, sobald die CI grün ist.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/reference/app-store-datenschutzangaben.md` | NEU: die Vorlage (in S2-Spec Z. 151 so vorgesehen) |
| `scripts/privacy_manifest.py` | `ACCOUNT_TYPES` = die eine Liste (UserID, DeviceID, OtherUserContent; verknüpft, kein Tracking, Zweck App-Funktion); die Vorlage muss ihr gleichen |
| `scripts/test_privacy_manifest.py` | Muster für einen Gleichlauf-Test (unittest, läuft per `ci.yml` `unittest discover -s scripts`) |
| `docs/reference/datenschutz-entwurf.md` | öffentlicher Text + „Beleg im Code“ + „Offen, nicht belegt“; Quelle jeder Angabe |
| `docs/specs/feat-625-schnitt-2-privacy-manifest.md` | Vorgänger; nennt Schnitt 3 und Schnitt 4 (AV-Vertrag Hetzner) |
| `docs/reference/app-store-texte.md` | Ort der übrigen Store-Angaben, Stil-Vorbild |

## Existing Patterns
- Eine Quelle der Wahrheit + Test, der Kopien gegen sie prüft (S2: Skript-Liste ↔ Archiv-Manifest; `test_catalog_languages.py`).
- Store-Angaben, die nur im ASC-Web gehen, laufen wie CloudKit-Deploy: Claude öffnet die Seite in Hennings Browser, er meldet sich nur an.

## Recherche (2026-11-21)
Quelle: https://developer.apple.com/support/app-privacy-on-the-app-store (vollständig gelesen).
- „Collect“ = vom Gerät senden und länger lesbar speichern, als zum Beantworten der Anfrage nötig. Nur auf dem Gerät
  verarbeitet = nicht erhoben. Token/IP, die nicht aufbewahrt werden = nicht anzugeben.
- „You are not responsible for disclosing data collected by Apple.“ (Apple-Absturzberichte, Sign in with Apple selbst,
  Apples Karten/Diktat.) Privates CloudKit: Daten liegen in der iCloud des Nutzers, wir können sie nicht lesen → nicht
  „collected“ (gängige Auslegung; Apple-Seite nennt CloudKit nur als Beispiel für „wenn *du* daraus Daten erhebst“).
- IP-Adressen gespeichert → „Declare the relevant data types based on how you use IP address, such as precise location,
  coarse location, device ID, or diagnostics.“
- Optional-Ausnahme verlangt u. a. „nur selten, nicht Kernfunktion“ und „jedes Mal aktiv gewählt“; „data collected on an
  ongoing basis after an initial request for permission must be disclosed“ → die Abschrift ist anzugeben, obwohl freiwillig.
- Antworten gelten für die App, nicht je Version; „You may update your answers at any time, and you do not need to submit
  an app update“. Pflicht vor jeder Einreichung.
- Es gibt keine offizielle App-Store-Connect-API für die Datenschutzangaben (nur das Web; fastlane nutzt die Web-Sitzung).
- Definitionen: User ID „account ID, assigned user ID … or other user- or account-level ID“; Device ID „advertising
  identifier, or other device-level ID“; Other User Content „Any other user-generated content“; App Functionality
  „authenticate the user, enable features, prevent fraud, implement security measures, ensure server up-time …“.

## Analysis

### Was die App mit eingeschaltetem Konto erhebt (gegen Code/Text geprüft)
| Datum | Apple-Typ | Verknüpft | Tracking | Zweck | Beleg |
|---|---|---|---|---|---|
| Apple-Kennung `apple_sub` | Identifiers › User ID | ja | nein | App Functionality | `002_accounts.sql`, `requestedScopes = []` |
| Installations-UUID `X-Device`, APNs-Gerätetoken | Identifiers › Device ID | ja | nein | App Functionality | `DeviceIdentity.swift`, `008_device_tokens.sql`, `DeviceRegistration` (seit #795 S5c-2a aufgerufen) |
| Abschrift offener Aufgaben, Aufträge aus Claude mit Inhalt | User Content › Other User Content | ja | nein | App Functionality | `TranscriptCodec.swift`, `001_claude_schema.sql` |
| IP-Adresse im nginx-Protokoll, 14 Tage | kein eigener Typ; Nutzung Fehlersuche/Missbrauchsabwehr | – | – | App Functionality | `protokolle.txt` (#615 S4e) |

Nicht angegeben (mit Grund in der Vorlage): Name/E-Mail (nicht angefragt), Standort/Orte, Kontakte, Fotos/Dateien,
Rohtext, Notizen, Gesundheit, Absturz-/Leistungsdaten (nur Apple), Nutzungsanalyse (keine), alles im privaten iCloud.

### Befund am Rand
Der öffentliche Datenschutztext beschreibt den Push-Token (Weckruf) noch nicht („Offen, nicht belegt“, Z. 208: „ruft ihn
aber noch nicht auf“) – seit #795 S5c-2a ruft die App ihn mit Konto auf. Vor dem Schalter muss der Text nachziehen
(Wortlaut braucht Hennings Freigabe). Gehört zum Ziel von #625 („saubere Rechtsgrundlage“) → als eigener Schnitt in #625
vermerken, nicht in diesem Schnitt bauen.

### Affected Files
| File | Change | Description |
|---|---|---|
| `docs/reference/app-store-datenschutzangaben.md` | CREATE | Vorlage: Stand heute (Store: „Keine Daten erhoben“), Antworten mit Schalter je Typ (Klickpfad EN, Verknüpfung, Tracking, Zweck, Beleg), bewusst nicht angegeben mit Grund, Zeitpunkt und Ablauf des Eintragens, IP-Entscheidung |
| `scripts/test_app_store_datenschutzangaben.py` | CREATE | hält die Typ-Tabelle der Vorlage gleich `ACCOUNT_TYPES` (Typ, verknüpft, Tracking, Zweck) |
| `docs/reference/datenschutz-entwurf.md` | MODIFY (nicht öffentlicher Beleg-Abschnitt) | Beleg-Zeile: Fragebogen-Vorlage folgt `privacy_manifest.py` |

Scope: 3 Dateien, ~+130 LoC Doku/Test, kein App-Code. **Kein Pfad der Geräteliste berührt.** Kein UI → kein Entwurf.

### Empfehlung und Alternativen
- **Empfehlung:** Vorlage + Gleichlauf-Test; IP-Adresse nicht als eigener Typ, weil sie nur für Sicherheit/Fehlersuche
  dient und Device ID mit Zweck App Functionality bereits angegeben ist (Apple nennt Device ID als möglichen Typ für IP).
- **Alternative A:** IP zusätzlich als „Other Diagnostic Data“ angeben (vorsichtiger, Etikett länger, kein Mehrwert für Nutzer).
- **Alternative B:** Keine Vorlage, Fragebogen direkt im Schalter-Schnitt ausfüllen (spart Doku, verliert die prüfbare
  Gleichheit mit dem Manifest und die Freigabe vorab).
- **Alternative C:** Etikett schon jetzt umstellen (Antworten gelten app-weit) – falsch für 1.0.1, die nichts erhebt. Verworfen.
- Keine ADR fällt.

## Risks & Considerations
- Deutsche ASC-Beschriftungen nicht belegt → Vorlage nennt Apples englische Begriffe, deutsche nur als „vermutlich“.
- Freigabe: Die Angaben sind rechtliche Aussagen; wie beim Datenschutztext (Memory „Rechtstext erst nach Freigabe“) braucht
  das Eintragen Hennings ausdrückliches Ja, die Auto-Ampel reicht nicht.
- Risiko Adversary: nur Doku + Test → niedrig, 1 Runde.

### Type
Feature (Doku + Gleichlauf-Test, kein App-Code)

### Nachprüfung 2026-11-21 (Wiedereinstieg nach /clear)
- `ACCOUNT_TYPES` in `scripts/privacy_manifest.py` unverändert: UserID, DeviceID, OtherUserContent; verknüpft, kein Tracking, ein Zweck.
- Push-Token: `PushWakeUp.swift` ruft `DeviceRegistration` auf; `datenschutz-entwurf.md` Z. 208–210 sagt noch „ruft ihn noch nicht auf“ → Befund am Rand bestätigt, eigener Schnitt in #625.
- Vorlage `docs/reference/app-store-datenschutzangaben.md` existiert noch nicht.
- PR #976 (Doku „kein eigener Server“) offen, CI läuft; mergen, sobald grün (berührt keine Datei dieses Schnitts).

### Dependencies
- Quelle: `scripts/privacy_manifest.py` (`ACCOUNT_TYPES`); Test läuft über `ci.yml` (`unittest discover -s scripts`).
- Eintragen im ASC-Web erst mit dem Schalter-Schnitt und nur nach Hennings ausdrücklicher Freigabe des Wortlauts.

### Open Questions
- keine für den PO in dieser Phase; die Freigabe der Antworten selbst erfolgt mit der Spec (`approved`).
