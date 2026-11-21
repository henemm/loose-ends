---
entity_id: feat-625-schnitt-3-fragebogen
type: feature
created: 2026-11-21
updated: 2026-11-21
status: draft
workflow: feat-625-s3-fragebogen
---

# Spec: Vorlage für den App-Store-Datenschutzfragebogen, Schnitt 3 (#625)

## Approval

- [ ] Approved

## GitHub Issue

#625 (Store-Datenschutzangaben, Store-Schalter, Einreichung). Schnitt 3 von 4; das Issue bleibt offen (`Refs #625`, nie `Closes #625`).
Analyse: `docs/context/feat-625-s3-fragebogen.md` (Abschnitte „Recherche“, „Analysis“, „Empfehlung und Alternativen“, „Nachprüfung 2026-11-21“).
Vorgänger: `docs/specs/feat-625-schnitt-2-privacy-manifest.md` (nennt diese Vorlage in „Out of Scope / Folgeschnitte“).
Es gibt keinen App-Code, keinen Dienstcode und keine Oberfläche. Geändert werden eine neue Doku-Datei, ein neuer Test und eine Zeile in einer Doku-Datei. **Kein Pfad der Geräteliste berührt.**

**Folgt in späteren Schnitten (nicht Teil dieser Spec):**

- **Folgeschnitt in #625, Datenschutztext nachziehen:** Der öffentliche Datenschutztext beschreibt den Push-Token (Weckruf) noch als „nicht aufgerufen“ (`docs/reference/datenschutz-entwurf.md`, Abschnitt „Offen, nicht belegt“, Punkt „Weckruf (Push-Token)“). Seit #795 S5c-2a ruft die App ihn mit Konto auf. Vor dem Schalter muss der Text samt Website-Seite nachziehen; der Wortlaut braucht Hennings Freigabe. Dieser Befund wird hier nur benannt und nicht gebaut.
- Schnitt 4: Auftragsverarbeitung mit Hetzner.
- Schalter-Schnitt: `LEAccountEnabled` an; erst dann werden die Antworten im Store eingetragen.

## Für den PO

Auf jeder Store-Seite zeigt Apple ein Datenschutz-Etikett: Dort steht, welche Daten die App erhebt. Bei Loose Ends steht heute „Keine Daten erhoben“, und das stimmt, solange die Verbindung zu Claude im Store ausgeschaltet ist.

Sobald die Verbindung im Store eingeschaltet wird, muss das Etikett drei Dinge nennen: deine Apple-Kennung, eine Kennung der Installation und die Abschrift deiner offenen Aufgaben. Dieser Schnitt schreibt vorab auf, was dann bei Apple anzukreuzen ist und was bewusst nicht, jeweils mit Begründung. Ein automatischer Test sorgt dafür, dass diese Liste nie von der Liste abweicht, die die Testbauten schon führen.

Jetzt ändert sich nichts: Das Etikett im Store bleibt unverändert, auf deinem iPhone und in der App ändert sich nichts Sichtbares, und du musst nichts tun. Eingetragen wird erst, wenn die Verbindung im Store eingeschaltet wird, und nur nach deinem ausdrücklichen Ja zum Wortlaut.

## Purpose

Apples Datenschutz-Etikett wird in App Store Connect (Web) beantwortet, gilt für die App insgesamt und wirkt sofort. Die Antworten für den Konto-Bau müssen deshalb vor dem Schalter-Schnitt feststehen, geprüft und von Henning freigegeben sein. Der Schnitt legt `docs/reference/app-store-datenschutzangaben.md` an (Stand heute, Antworten mit Konto je Typ, bewusst nicht Angegebenes mit Grund, Zeitpunkt und Ablauf, Quellen) und einen Test, der die Typ-Tabelle der Vorlage gegen `ACCOUNT_TYPES` in `scripts/privacy_manifest.py` hält, damit Manifest und Fragebogen eine Quelle haben.

**Regeln vor Modell:** reine Datei- und Tabellenprüfung (Text einlesen, Zeilen vergleichen); die Zeile „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine – keine ADR fällt.
- **Rationale:** Es entsteht kein neues Verfahren und keine Abhängigkeit; das Muster „eine Quelle der Wahrheit, ein Test hält Kopien gleich“ (S2: `privacy_manifest.py`, `test_catalog_languages.py`) wird fortgesetzt. Die Vorlage ist Doku, keine Architektur.

## Source

**Dateien (3):** `docs/reference/app-store-datenschutzangaben.md` (neu), `scripts/test_app_store_datenschutzangaben.py` (neu), `docs/reference/datenschutz-entwurf.md` (eine Zeile im nicht öffentlichen Abschnitt „Beleg im Code“).
**Nicht berührt:** `scripts/privacy_manifest.py` (nur gelesen, Quelle `ACCOUNT_TYPES`), `LooseEnds/PrivacyInfo.xcprivacy`, `.github/workflows/*`, `project.yml`, jede `Info.plist`, der öffentliche Datenschutztext (Abschnitte vor „Beleg im Code“), App- und Dienstcode.

**Gegen den Code geprüft (Spec-Phase, 2026-11-21):**

- `ACCOUNT_TYPES` in `scripts/privacy_manifest.py`: genau drei Einträge `NSPrivacyCollectedDataTypeUserID`, `...DeviceID`, `...OtherUserContent`, je Linked true, Tracking false, Zweck `[NSPrivacyCollectedDataTypePurposeAppFunctionality]`; das Modul ist ohne Nebenwirkung importierbar (`main` nur unter `__main__`).
- `ci.yml` führt `scripts/test_*.py` per `unittest discover -s scripts` aus; der neue Test läuft ohne weitere Änderung. Der Ordner `scripts/` liegt dabei auf dem Importpfad, `import privacy_manifest` geht.
- `datenschutz-entwurf.md` hat den Abschnitt „Beleg im Code“ als Tabelle (Zeile „Manifest folgt dem Konto-Schalter …“ als Nachbar der neuen Zeile); der öffentliche Text steht davor.
- Die Vorlage existiert noch nicht; PR #976 (Doku „kein eigener Server“) berührt keine Datei dieses Schnitts.

### Festgelegtes Format der Vorlage (Vertrag zwischen Doku und Test)

Die Vorlage hat fünf Abschnitte in dieser Reihenfolge, jeweils als `##`-Überschrift: „Stand heute“, „Antworten mit Konto“, „Bewusst nicht angegeben“, „Zeitpunkt und Ablauf“, „Quellen“.

Der Test liest nur den Abschnitt `## Antworten mit Konto` (bis zur nächsten `##`-Überschrift). Darin steht genau eine Markdown-Tabelle mit dieser Kopfzeile in dieser Spaltenreihenfolge:

| Spalte | Inhalt | Werte |
|---|---|---|
| 1 `Manifest-Schlüssel` | der Schlüssel aus `ACCOUNT_TYPES`, in Backticks | `NSPrivacyCollectedDataTypeUserID`, `NSPrivacyCollectedDataTypeDeviceID`, `NSPrivacyCollectedDataTypeOtherUserContent` |
| 2 `Apple-Typ (ASC, englisch)` | Apples englischer Begriff als „Kategorie › Typ“; deutsche Begriffe nur als „vermutlich“ im Fließtext | Identifiers › User ID; Identifiers › Device ID; User Content › Other User Content |
| 3 `Verknüpft` | ob mit der Identität des Nutzers verknüpft | `ja` oder `nein` |
| 4 `Tracking` | ob zum Tracking genutzt | `ja` oder `nein` |
| 5 `Zweck` | Manifest-Schlüssel der Zwecke, in Backticks, mehrere durch Komma | `NSPrivacyCollectedDataTypePurposeAppFunctionality` |
| 6 `Beleg im Code` | Dateien als Beleg, Freitext | nicht geprüft |

Die Trennzeile der Tabelle wird übersprungen. Erwartete Zeilen: UserID (Apple-Kennung `apple_sub`), DeviceID (Installations-UUID `X-Device` und APNs-Gerätetoken), OtherUserContent (Abschrift offener Aufgaben, Aufträge aus Claude mit Inhalt); je Verknüpft `ja`, Tracking `nein`, Zweck App Functionality.

Inhalt der übrigen Abschnitte:

- **Stand heute:** Store-Etikett „Data Not Collected“, gilt app-weit, solange `LEAccountEnabled` aus ist; Store-Bauten haben ein leeres Manifest und senden nichts an den Dienst.
- **Bewusst nicht angegeben**, je Punkt mit Grund: Name und E-Mail (die App fragt keine `requestedScopes`); Standort (Orte und Ortssuche laufen auf dem Gerät bzw. bei Apple Karten, nichts davon erreicht den Dienst); Kontakte (kein Zugriff); Fotos und Dateien (Anhänge bleiben auf dem Gerät und in der privaten iCloud, nicht in der Abschrift); Rohtext und Notizen außerhalb der Abschrift (die Abschrift enthält sie laut Vertrag nicht); Absturz- und Leistungsdaten (nur Apple erhebt sie, dafür ist laut Apple nicht der Entwickler zuständig); keine Nutzungsanalyse und keine Fremd-SDKs; privates iCloud/CloudKit (Daten liegen in der iCloud des Nutzers, der Entwickler kann sie nicht lesen); Apple-Anmeldung selbst (Apple erhebt, nicht wir); **IP-Adresse im nginx-Protokoll, 14 Tage:** kein eigener Typ, Begründung mit Apple-Zitat („Declare the relevant data types based on how you use IP address, such as precise location, coarse location, device ID, or diagnostics.“): Die Adresse dient nur Fehlersuche und Missbrauchsabwehr (App Functionality), wir leiten daraus weder Standort noch Diagnosedaten ab, und Device ID mit Zweck App Functionality ist ohnehin angegeben.
- **Zeitpunkt und Ablauf:** Eintragen erst mit dem Schalter-Schnitt, im selben Zug wie die Einreichung, nie vorher, weil die Antworten app-weit gelten und sofort wirken (die laufende Store-Version 1.0.x erhebt nichts). Pflicht ist die Eintragung vor jeder Einreichung mit eingeschaltetem Konto. Es gibt keine offizielle App-Store-Connect-API dafür, also nur im ASC-Web: Claude öffnet die Seite in Hennings Browser, Henning meldet sich nur an (wie beim CloudKit-Deploy). Eingetragen wird nur nach Hennings ausdrücklichem Ja zum Wortlaut dieser Vorlage; die Auto-Ampel reicht nicht (Rechtsaussage).
- **Quellen:** `https://developer.apple.com/support/app-privacy-on-the-app-store` mit den benutzten Definitionen (User ID, Device ID, Other User Content, App Functionality, „collect“, Absatz zu IP-Adressen), dazu `scripts/privacy_manifest.py` und der Abschnitt „Beleg im Code“ im Datenschutzentwurf.

### Test `scripts/test_app_store_datenschutzangaben.py` (nur Standardbibliothek, `unittest`)

Eine reine Funktion `parse_types(text)` liest den Abschnitt `## Antworten mit Konto` und liefert je Zeile `(Schlüssel, verknüpft als bool, Tracking als bool, Zwecke als Liste)`; sie wirft einen Fehler bei fehlendem Abschnitt, fehlender Tabelle, abweichender Kopfzeile oder einem Wert außer `ja`/`nein`. Der Gleichlauf-Test importiert `ACCOUNT_TYPES` aus `privacy_manifest` und vergleicht Menge der Schlüssel (ohne doppelte, ohne fremde, ohne fehlende), Linked, Tracking und die Zweckliste. Negativtests arbeiten auf einer im Speicher mutierten Kopie des Vorlagentextes, nie auf der echten Datei.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/privacy_manifest.py` (`ACCOUNT_TYPES`) | skript | die eine Quelle; wird nur importiert |
| `docs/reference/datenschutz-entwurf.md` | doku | Quelle der Belege; bekommt eine Beleg-Zeile |
| `docs/reference/app-store-texte.md` | doku | Stilvorbild für die Vorlage; unverändert |
| `ci.yml` (`unittest discover -s scripts`) | workflow | führt den neuen Test aus |
| `docs/specs/feat-625-schnitt-2-privacy-manifest.md` | spec | Vorgänger |
| `https://developer.apple.com/support/app-privacy-on-the-app-store` | quelle | Apples Definitionen, Stand 2026-11-21 gelesen |
| Downstream | schnitte | Schnitt 4 (Hetzner), Datenschutztext-Nachzug (Push-Token), Schalter-Schnitt (Eintragen) |

## Acceptance Criteria

Belege liegen unter `docs/artifacts/feat-625-s3-fragebogen/` („Belegordner“). Kein Beleg enthält Zugangsdaten, Tokens oder `sub`-Werte.

- **AC-1:** GIVEN `docs/reference/app-store-datenschutzangaben.md` WHEN sie gelesen wird THEN hat sie die fünf `##`-Abschnitte „Stand heute“, „Antworten mit Konto“, „Bewusst nicht angegeben“, „Zeitpunkt und Ablauf“, „Quellen“ in dieser Reihenfolge, und „Stand heute“ nennt das Store-Etikett „Data Not Collected“ samt dem Satz, dass es app-weit gilt, solange der Konto-Schalter aus ist.
- **AC-2:** GIVEN der Abschnitt „Antworten mit Konto“ WHEN er gelesen wird THEN enthält er genau eine Tabelle mit der Kopfzeile `Manifest-Schlüssel | Apple-Typ (ASC, englisch) | Verknüpft | Tracking | Zweck | Beleg im Code` und genau drei Zeilen für UserID, DeviceID und OtherUserContent mit Verknüpft `ja`, Tracking `nein` und dem Zweck `NSPrivacyCollectedDataTypePurposeAppFunctionality`; die Apple-Typen stehen auf Englisch (deutsche Begriffe nur als „vermutlich“).
- **AC-3:** GIVEN der Abschnitt „Bewusst nicht angegeben“ WHEN er gelesen wird THEN nennt er je einen eigenen Punkt mit Grund für Name/E-Mail, Standort, Kontakte, Fotos/Dateien, Rohtext/Notizen außerhalb der Abschrift, Absturz- und Leistungsdaten (nur Apple), keine Analyse, privates iCloud und IP-Adresse; der IP-Punkt nennt „kein eigener Typ“, die 14 Tage im nginx-Protokoll und das Apple-Zitat zur IP-Adresse wörtlich.
- **AC-4:** GIVEN der Abschnitt „Zeitpunkt und Ablauf“ WHEN er gelesen wird THEN sagt er, dass erst mit dem Schalter-Schnitt und im selben Zug wie die Einreichung eingetragen wird (nie vorher, weil die Antworten app-weit gelten und sofort wirken), dass es nur im ASC-Web geht (keine API), dass Claude die Seite in Hennings Browser öffnet und Henning sich nur anmeldet, und dass nur nach Hennings ausdrücklichem Ja zum Wortlaut eingetragen wird; „Quellen“ nennt `https://developer.apple.com/support/app-privacy-on-the-app-store`.
- **AC-5:** GIVEN `scripts/test_app_store_datenschutzangaben.py` und die echte Vorlage WHEN der Test läuft THEN sind Menge der Schlüssel, Verknüpft, Tracking und Zwecke der Tabelle gleich `ACCOUNT_TYPES` aus `scripts/privacy_manifest.py` und der Test ist grün.
- **AC-6:** GIVEN eine im Speicher mutierte Kopie des Vorlagentextes mit fehlender Zeile, zusätzlicher Zeile, doppelter Zeile, geändertem Verknüpft-Wert, geändertem Tracking-Wert oder geändertem Zweck WHEN der Gleichlauf-Vergleich läuft THEN schlägt er jeweils fehl und die Meldung nennt den betroffenen Schlüssel.
- **AC-7:** GIVEN ein Vorlagentext ohne den Abschnitt „Antworten mit Konto“, ohne Tabelle darin, mit abweichender Kopfzeile oder mit einem Wert außer `ja`/`nein` WHEN `parse_types` läuft THEN wirft es einen verständlichen Fehler (kein stilles Leerergebnis, das den Vergleich bestehen ließe).
- **AC-8:** GIVEN der Ablauf der Entwicklung WHEN der Test vor Anlage der Vorlage läuft THEN ist er rot (Beleg `red.txt`), und nach Anlage der Vorlage läuft `python3 -m unittest discover -s scripts -p 'test_*.py'` grün mit dem neuen Test sichtbar enthalten (Beleg `green.txt`).
- **AC-9:** GIVEN `docs/reference/datenschutz-entwurf.md` WHEN der Abschnitt „Beleg im Code“ gelesen wird THEN enthält er genau eine neue Zeile, die sagt, dass die Fragebogen-Vorlage `docs/reference/app-store-datenschutzangaben.md` der Liste `ACCOUNT_TYPES` in `scripts/privacy_manifest.py` folgt und der Test `scripts/test_app_store_datenschutzangaben.py` das hält; die Abschnitte vor „Beleg im Code“ (öffentlicher Text) sind unverändert (Diff).
- **AC-10:** GIVEN der Diff des PR WHEN er geprüft wird THEN enthält er genau die drei Pfade `docs/reference/app-store-datenschutzangaben.md`, `scripts/test_app_store_datenschutzangaben.py`, `docs/reference/datenschutz-entwurf.md` plus den Belegordner, keine Datei unter `LooseEnds/`, `Shared/`, `server/`, `.github/`, weder `project.yml` noch eine `Info.plist`, und `LEAccountEnabled` ist in `project.yml` weiterhin `false` (Beleg `schalter.txt`).
- **AC-11:** GIVEN die Abnahme WHEN sie begründet wird THEN lautet der Satz im Bericht „Kein Pfad der Geräteliste berührt.“, die Abnahme endet nach Stufe 2 mit der Begründung, dass kein App-Code und keine Oberfläche geändert wird und deshalb kein Simulator-Durchlauf einen Nachweis erbrächte, und es gibt keinen Lauf auf Hennings Geräten.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/app-store-datenschutzangaben.md` | CREATE | Vorlage mit fünf Abschnitten und der Typ-Tabelle; ca. +100 |
| `scripts/test_app_store_datenschutzangaben.py` | CREATE | `parse_types`, Gleichlauf- und Negativtests (AC-5 bis AC-7); ca. +100 |
| `docs/reference/datenschutz-entwurf.md` | MODIFY | eine Beleg-Zeile im nicht öffentlichen Abschnitt „Beleg im Code“; ca. +1 |
| `docs/artifacts/feat-625-s3-fragebogen/` | CREATE | Belege (`red.txt`, `green.txt`, `schalter.txt`); zählt nicht zum Dateilimit |

### Estimated Changes

- Files: 3 (Limit 4 bis 5 eingehalten; Belegordner zählt nicht)
- LoC: App-Code +0; Doku/Test ca. +200 (App-Code-Limit ±250 unberührt, Testcode zählt nicht mit)
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`-Diff, keine neue Abhängigkeit, kein Eintrag im Store.
- **Seiteneffekte (explizit):** Der neue Test läuft in der CI; ändert jemand später `ACCOUNT_TYPES`, ohne die Vorlage nachzuziehen, wird `ci.yml` rot (gewollt).
- **Parallele Arbeit:** vor dem PR `origin/main` und offene PRs auf `datenschutz-entwurf.md` prüfen (Hotspot, Epic-Sitzung #625).

## Implementation Details

Reihenfolge (TDD): erst `scripts/test_app_store_datenschutzangaben.py` schreiben und rot belegen (Vorlage fehlt, Beleg `red.txt`), dann die Vorlage anlegen, dann grün belegen (`green.txt`), dann die Beleg-Zeile in `datenschutz-entwurf.md`, zuletzt der Diff-Beleg `schalter.txt`. Die Tabelle wird mit einfachem Zeilen- und `|`-Splitten gelesen, ohne Markdown-Bibliothek; Backticks um Schlüssel werden abgestreift. Jede Funktion bleibt unter 30 Zeilen. Der Text der Vorlage ist die Rechtsaussage-Grundlage und wird Henning mit dieser Spec zur Freigabe vorgelegt; Eintragen bei Apple ist nicht Teil dieses Schnitts.

## Test Plan

### Automated Tests (TDD RED)

- [ ] Test 1 (AC-5): GIVEN die echte Vorlage WHEN `parse_types` sie liest und mit `ACCOUNT_TYPES` vergleicht THEN sind Schlüsselmenge, Linked, Tracking und Zwecke gleich.
- [ ] Test 2 (AC-6): GIVEN eine mutierte Kopie des Textes (Zeile entfernt, fremde Zeile ergänzt, Zeile verdoppelt, Verknüpft, Tracking oder Zweck geändert) WHEN der Vergleich läuft THEN schlägt er je fehl und nennt den Schlüssel.
- [ ] Test 3 (AC-7): GIVEN Text ohne Abschnitt, ohne Tabelle, mit anderer Kopfzeile oder mit Wert außer `ja`/`nein` WHEN `parse_types` läuft THEN Fehler mit verständlicher Meldung.
- [ ] Test 4 (AC-1): GIVEN die echte Vorlage WHEN der Test die `##`-Überschriften liest THEN stehen die fünf Abschnitte in der festgelegten Reihenfolge.

| Prüfung | Beleg | AC |
|---|---|---|
| Test rot ohne Vorlage, grün mit Vorlage, CI-Befehl `unittest discover` | `red.txt`, `green.txt` | AC-1, AC-5 bis AC-8 |
| Inhaltliche Durchsicht der Vorlage gegen die ACs (Lesen, kein Test) | im Bericht | AC-2 bis AC-4 |
| Diff-Dateiliste, Schalter | `schalter.txt` | AC-9, AC-10 |

**Kein Simulator-Durchlauf:** Der Schnitt ändert weder App-Code noch Oberfläche noch Build-Konfiguration; ein Durchlauf der App würde nichts belegen, was der Schnitt behauptet. Der Nachweis ist der Test gegen `ACCOUNT_TYPES` und die Durchsicht des Textes. Dass die Angaben bei Apple tatsächlich passen, belegt erst der Schalter-Schnitt beim Eintragen mit Hennings Ja.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **Gewählt: Vorlage plus Gleichlauf-Test, IP nicht als eigener Typ** | Doku mit Tabelle, Test gegen `ACCOUNT_TYPES` | prüfbare Gleichheit mit dem Manifest, Freigabe vorab, Etikett nennt nur, was tatsächlich zählt | Pflegeaufwand einer weiteren Datei | keine ADR |
| **A IP-Adresse zusätzlich als „Other Diagnostic Data“ angeben** | vierte Zeile in Tabelle und Test | vorsichtiger, Etikett deckt jede Auslegung ab | die Adresse dient nur Fehlersuche und Missbrauchsabwehr, daraus entstehen keine Diagnosedaten; Etikett länger ohne Mehrwert für Nutzer; Device ID mit Zweck App Functionality ist schon angegeben und Apple nennt Device ID ausdrücklich als möglichen Typ für IP-Adressen | die Gleichheit mit `ACCOUNT_TYPES` (dann müsste auch das Manifest einen vierten Typ führen) |
| **B Keine Vorlage, Fragebogen im Schalter-Schnitt direkt ausfüllen** | spart Doku | kleinster Aufwand jetzt | Rechtsaussage ohne Freigabe vorab, keine prüfbare Gleichheit mit dem Manifest, der Schalter-Schnitt würde Entscheidung und Eintrag mischen | die Regel „Antworten vorab prüfbar und freigegeben“ |
| **C Etikett schon jetzt umstellen** | Antworten sofort eintragen | Etikett wäre vorbereitet | Antworten gelten app-weit und sofort, die Store-Version 1.0.x erhebt nichts: das Etikett wäre falsch und widerspräche dem leeren Manifest und dem Datenschutztext. **Verworfen.** | das Store-Etikett „Data Not Collected“ |

Keine ADR fällt bei keiner Variante.

## Out of Scope / Folgeschnitte

- Eintragen der Antworten in App Store Connect: erst im Schalter-Schnitt, nur nach Hennings Ja zum Wortlaut.
- Datenschutztext (öffentlich) und Website-Seite: Push-Token (Weckruf) nachziehen, eigener Folgeschnitt in #625, Wortlaut mit Hennings Freigabe.
- Schnitt 4: Auftragsverarbeitung mit Hetzner.
- Änderung von `privacy_manifest.py`, Workflows oder Manifesten: nicht in diesem Schnitt.

## Risiken

- **Vorlage und Manifest laufen auseinander.** Gegenmittel: der Test in der CI.
- **Deutsche Beschriftungen in ASC nicht belegt.** Gegenmittel: die Vorlage nennt Apples englische Begriffe, deutsche nur als „vermutlich“.
- **Auslegung „privates CloudKit ist nicht erhoben“ ist gängige Praxis, steht aber nicht wörtlich auf Apples Seite.** Gegenmittel: die Vorlage benennt das als Auslegung mit Begründung; Henning gibt den Wortlaut vor dem Eintragen frei.
- **Test prüft die Tabelle, nicht die Wahrheit der Belege.** Gegenmittel: Beleg-Spalte wird bei der Durchsicht gegen den Code gelesen (AC-2); der Test sagt bewusst nur „gleich der einen Quelle“.

## Definition of Done

- [ ] AC-1 bis AC-11 erfüllt, Belege im Belegordner
- [ ] PR mit `Refs #625` (nie `Closes`), CI grün, gemergt
- [ ] #625 kommentiert: Stand Schnitt 3; offener Folgeschnitt „Datenschutztext: Push-Token (Weckruf) nachziehen“ vermerkt (Befund, vor dem Schalter nötig); Folgen Schnitt 4 und Schalter-Schnitt; Board-Karte aktuell, Memory geschrieben

Keine Gerätepunkte (Stufe 3 greift nicht).

## Changelog

- 2026-11-21: Initial spec created (Schnitt 3 von #625, Vorlage für den App-Store-Datenschutzfragebogen)
