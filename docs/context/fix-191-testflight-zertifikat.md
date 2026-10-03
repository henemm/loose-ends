# Context: fix-191-testflight-zertifikat

## Request Summary
Der TestFlight-Lauf verbraucht pro Lauf ein Signier-Zertifikat und scheitert, sobald das Konto-Limit voll ist.
Ziel (#191): beliebig viele Läufe, ohne dass die Zahl der Zertifikate im Konto wächst. Danach #183 wieder aufnehmen.

## Belege aus den echten Läufen (2026-10-03)
| Lauf | Ergebnis | Befund |
|------|----------|--------|
| #10 (37119618643) | grün | `archive.log`: `Signing Identity: "Apple Development: Created via API (T7D652RS7A)"`, Profile `iOS Team Provisioning Profile: …` für alle vier Ziele. Das ist die Entwicklungs-Signierung beim **Archivieren**. |
| #12 (37128541497) | rot nach 21 s im Schritt Archive | `Choose a certificate to revoke. Your account has reached the maximum number of certificates.` plus `No profiles for 'com.henning.looseends[.watchkitapp/.share/.widgets] were found: … iOS App Development provisioning profiles`, `** ARCHIVE FAILED **` |
| #10, Export | grün | `upload.log` nennt keine Signier-Identität (kein Hinweis auf ein im Lauf angelegtes Distributionszertifikat). Offen, ob der Export ein Zertifikat verbraucht. |

Der verbrauchte Typ ist also das **Apple-Development-Zertifikat aus dem Schritt Archive** („Created via API"). Jeder Lauf startet auf einem leeren Runner, `-allowProvisioningUpdates` mit ASC-Schlüssel findet keine Identität, legt ein Zertifikat an, der private Schlüssel geht mit dem Runner verloren.

## Recherche (Stand 2026-10-03)
- Wörtliche Meldung und Ursache bestätigt: https://rxliuli.com/blog/two-pitfalls-of-safari-cloud-signing-in-github-actions, https://support.bitrise.io/en/articles/9676601-error-your-account-has-reached-the-maximum-number-of-certificates, https://discuss.bitrise.io/t/new-development-certificates-created-with-every-build/21068
- Automatische Signierung auf CI funktioniert nur im ersten Lauf, danach „private key is not installed in your keychain": https://developer.apple.com/forums/thread/764554, https://developer.apple.com/forums/thread/760819
- Empfohlene Auswege dort: nicht mehr benutzbare Zertifikate widerrufen, oder ein eigenes Zertifikat samt Schlüssel hochladen und beim Signieren verwenden.
- **Noch nicht geklärt (gehört in `/20-analyse`):** Ob Xcode 27 daran etwas geändert hat; ob der Archiv-Schritt auch mit Distributionssignierung statt Entwicklung laufen kann (dann entfiele das Development-Zertifikat ganz); ob Cloud-Zertifikate („Cloud Managed Apple Distribution") gegen dasselbe Limit zählen.

## Related Files
| Datei | Relevanz |
|-------|----------|
| `.github/workflows/testflight.yml` | Schritt `Archive` (Zeile ~60–75: `-allowProvisioningUpdates`, `CODE_SIGN_STYLE=Automatic`), Schritt `Write export options` (`signingStyle automatic`), `Upload to TestFlight` (`-exportArchive` mit ASC-Schlüssel) |
| `docs/reference/testflight.md` | Einrichtung (4 Secrets), „Wenn es hakt", „Was der Workflow tut"; DoD verlangt Beschreibung des neuen Wegs |
| `project.yml` | `DEVELOPMENT_TEAM` fest, Signing-Einstellungen der vier Ziele (App, Watch, Widgets, Share) |
| `scripts/asc_wait_build.py`, `scripts/test_asc_wait_build.py` | Vorbild: ASC-API per JWT mit dem Teamschlüssel, Tests ohne Netz. Ein Aufräum-Skript (Zertifikate per API) würde dasselbe Muster nutzen. |
| `scripts/sim.sh` (`device-build`, `lab`) | Gerätebauten signieren lokal mit gespeicherten Profilen, anderer Pfad, vom Lauf nicht berührt (#156) |

## Existing Patterns
- Python-Skripte in `scripts/` mit `test_*.py` daneben, ASC-Zugriff per Teamschlüssel (Rolle Admin).
- Der Schlüssel wird im Lauf aus dem Secret in eine Datei geschrieben und am Ende gelöscht.
- Bekannte Lücke: CI führt `scripts/test_*.py` nicht aus (#185).

## Dependencies
- Upstream: Apple-Konto (Zertifikatslimit), ASC-API-Schlüssel (Admin), Runner-Image `xcode-27` mit Xcode 27.0, Secrets `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`.
- Downstream: #183 (echter Lauf mit Belegtabelle, wartet auf diesen Fix), jeder künftige TestFlight-Lauf.

## Existing Specs
- Keine Spec zur Signierung. Entscheidung „TestFlight ist ein Verteilkanal, ruht bis andere testen" steht in `CLAUDE.md`. Das Gerüst ist trotzdem Pflicht für #183.

## Risks & Considerations
- Das Konto steht **jetzt** am Limit. Ohne einmaliges Aufräumen (Widerruf unbrauchbarer „Created via API"-Zertifikate) läuft auch der Fix nicht, sofern er überhaupt ein neues Zertifikat braucht. Wer aufräumt und wie (ASC-API mit Admin-Schlüssel statt von Hand), entscheidet `/20-analyse`.
- Widerruf darf **kein** Zertifikat treffen, das Henning für seine Xcode-Gerätebauten nutzt (siehe Memory „Xcode ohne Konto").
- Ein eigenes dauerhaftes Zertifikat samt privatem Schlüssel wäre ein neues Geheimnis in GitHub und braucht manuelle Profile, die ablaufen (Pflegeaufwand).
- Blast Radius: Fehler blockiert jeden TestFlight-Lauf, auch den aus #183.
- Es gilt das Scoping-Limit 4–5 Dateien, ±250 LoC. Ein Aufräum-Skript mit Test plus Workflow plus Doku liegt nahe an der Grenze.

## Analysis

### Type
Bug (CI/Signierung). Reproduziert durch den echten Lauf #12 (37128541497, Log siehe oben), kein Nachbau nötig: Der Zustand „Konto am Limit“ besteht jetzt.

### Recherche (2026-10-03) — Ergebnisse
- Ursache bestätigt (leerer Runner, `-allowProvisioningUpdates` legt Zertifikat an, Schlüssel geht verloren, Zertifikat bleibt als „Created via API“ im Konto): rxliuli.com (Safari-Cloud-Signing-Falle), Bitrise-Support-Artikel 9676601, Apple-Forum 695759.
- Üblicher Ausweg dort: ein dauerhaftes Zertifikat samt Schlüssel als p12 importieren, dann „wiederverwendet jeder Lauf es“ (rxliuli). ASC-Schlüssel muss Rolle Admin haben (erfüllt).
- **Unsignierter Archiv-Schritt (`CODE_SIGNING_ALLOWED=NO`) ist widerlegt für uns:** Entitlements werden beim Archivieren in die Binärdatei geschrieben; unsigniert fehlen sie (Apple-Forum 671800, ITMS-90078). Wir brauchen App Groups in vier Zielen → Risiko zu hoch.
- Apples Doku zu Cloud-Zertifikaten sagt nichts zu Limit oder CI (developer.apple.com/help/account/create-certificates/cloud-managed-certificates). Ob der Export ein Zertifikat verbraucht, bleibt offen und wird gemessen, nicht vermutet.
- Xcode-27-Änderung: nichts gefunden.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_cleanup_certs.py` | CREATE | ASC-API per JWT (Muster `asc_wait_build.py`): Zertifikate listen, nur Entwicklungs-Zertifikate „Created via API“ widerrufen, `--dry-run`, Zahl vorher/nachher ins Protokoll |
| `scripts/test_asc_cleanup_certs.py` | CREATE | Tests ohne Netz: Auswahl (nichts anderes als „Created via API“+Entwicklung wird getroffen), Dry-run, Zählung |
| `.github/workflows/testflight.yml` | MODIFY | Schritt vor `Archive` (räumt den Bestand, heilt das volle Konto) und `always()`-Schritt nach dem Export; Zertifikatszahl in die Zusammenfassung |
| `docs/reference/testflight.md` | MODIFY | Weg beschreiben (DoD) |

### Scope Assessment
- Files: 4
- Estimated LoC: +~200/-0
- Risk Level: MEDIUM — Widerruf im Konto ist nicht umkehrbar; deshalb enge Auswahl und Dry-run zuerst.

### Technical Approach (Empfehlung)
Regelweg, kein neuer Baustein: Der Lauf räumt die Zertifikate, die er selbst anlegt, per ASC-API wieder ab — vor dem Archiv (löst das volle Konto sofort) und am Ende (`always()`). Nur Typ Entwicklung mit Anzeigename „Created via API“; Hennings eigene Xcode-Zertifikate tragen seinen Namen und werden nie angefasst. Vor dem ersten echten Widerruf läuft einmal `--dry-run` im CI und zeigt die Liste (Namen/Typen), damit die Auswahl an echten Daten bestätigt ist.
Nachweis: zwei Läufe hintereinander grün, Zertifikatszahl vorher = nachher (steht im Protokoll); damit wird auch gemessen, ob der Export eines verbraucht.

### Alternativen
- **A. Dauerhaftes Entwicklungs-Zertifikat als Secret (p12)**, im Lauf in eigenen Schlüsselbund importiert: kein Widerruf, robuster gegen Fehlgriffe. Ich kann es selbst per ASC-API erzeugen und per `gh secret set` ablegen, Henning muss nichts tippen. Nachteil: zwei neue Secrets, läuft nach einem Jahr ab (Pflege). Wird zur Empfehlung, falls der Dry-run zeigt, dass „Created via API“ nicht sauber von Hennings eigenen Zertifikaten trennt.
- **B. Unsignierter Archiv-Schritt:** widerlegt (Entitlements, s. o.).
- **C. fastlane match:** neue Abhängigkeit, braucht Freigabe; für ein Zertifikat unverhältnismäßig.
- Gekippt würde bei A: nichts in den ADRs; „TestFlight ruht“ bleibt, das Gerüst wird nur dauerhaft lauffähig.

### Dependencies
Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` (Admin, vorhanden). Downstream: #183 wartet.

### Open Questions
- [ ] Dry-run im CI: Trennt „Created via API“ + Entwicklungstyp sicher von Hennings eigenen Zertifikaten? (entscheidet Empfehlung vs. Alternative A)
- [ ] Verbraucht der Export (Cloud-Verteilzertifikat) selbst eins? Wird in den zwei Läufen gemessen.
- [ ] Widerruf macht die automatischen Profile ungültig; `-allowProvisioningUpdates` erzeugt sie neu — im Lauf zu bestätigen. Hennings Gerätebauten (#156, eigene Kennung) sind davon nicht betroffen.
