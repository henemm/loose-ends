# Context: 176-testflight-abnahme

## Request Summary
Issue #176 (M3, Epic #371): Die TestFlight-Fassung selbst wird als Nutzer durchgespielt, je Schritt ein Beleg;
dazu eine interne Tester-Gruppe in App Store Connect mit „Was zu testen ist“. Zuschnitt (Henning, 2026-10-25):
**Prüfliste + Gruppe**, nichts auf seinen Geräten ohne sein wörtliches „jetzt ist ein Test möglich“.

## Stand der Voraussetzungen
- #175 (CloudKit Production) und #183 (TestFlight-Lauf belegt Annahme bei Apple) sind geschlossen; Henning-Entscheidung
  vom 2026-10-03 („#176 startet erst danach“) ist erfüllt.
- Offene Rückmeldungen aus TestFlight, die in die Liste gehören: #607 (Modelltitel), #584 (Icon-Zahl, Build 96),
  #601 (Schreibzeile, Build 101), #605 (Unteraufgaben beim Löschen). Alle vier sind gemergt, keiner bestätigt.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/reference/testflight.md` | Abschnitt 6 beschreibt die Gruppe `Familie` (interne Tests); Abschnitt 5 „Build starten“; hier käme die Prüfliste hin oder wird verlinkt |
| `docs/reference/abnahme-und-arbeitsweise.md` | Drei Stufen, Regel „Refs #N statt Closes #N, wenn eine Rückmeldung verlangt wird“ (#544) |
| `docs/reference/funktionsuebersicht.md` | Was die App heute kann; Quelle für die Prüfschritte |
| `docs/project/01-user-story.md` | Erfolgskriterien der Story; jeder Haken der Liste muss sich auf ein Kriterium zurückführen lassen |
| `scripts/asc_what_to_test.py`, `scripts/asc_wait_build.py` | ASC-API-Zugriff (JWT per `openssl`, nur Standardbibliothek); Vorbild, falls die Gruppe per Skript angelegt wird |
| `.github/workflows/testflight.yml` | „Was testen“ je Build wird dort schon gesetzt (#347) |

## Existing Patterns
- ASC-Zugriff gibt es nur in der CI (Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`); lokal nicht abrufbar
  (Memory: TestFlight-Belege abrufbar?). Alles, was die ASC-API braucht, läuft als Workflow oder Skript mit Test gegen Fixtures.
- Belege entstehen aus echten Läufen und werden nie von Hand gesetzt (Hennings Regel vom 2026-09-27).
- Gerätepunkte sind sein Handgriff; ich bereite vor und werte aus (Ticket-Kommentar vom 2026-10-03, #143, #160).

## Dependencies
- Upstream: App Store Connect API (`/v1/betaGroups`, `/v1/betaBuildLocalizations`, ggf. `betaAppLocalizations`); Rolle Admin am Schlüssel.
- Downstream: #371 (Epic Einladung), die erste Einladung externer Tester.

## Überschneidung mit #342 (wichtig)
#342 Teil 3 „Testgruppe und Hinweise“ (Gruppe in App Store Connect, „Was zu testen ist“ je Build, Weg für Rückmeldungen)
deckt dasselbe wie der zweite Haken von #176. „Was zu testen ist“ je Build setzt seit #347 die CI. Bleibt für #176 nur:
die Gruppe selbst, und ob sie schon existiert, ist von hier aus nicht prüfbar (kein ASC-Zugriff lokal).
Folge für die Analyse: Gruppen-Teil entweder hier erledigen und in #342 abhaken, oder aus #176 streichen und dort lassen.

## Existing Specs
- Keine. Ein Vorgänger-Kontext mit demselben Werkzeug: `docs/context/feature-183-testflight-beleg.md`.

## Risks & Considerations
- **Geräteregel:** Kein Schritt der Liste startet etwas auf seinen Geräten. Die Spec muss jeden Gerätepunkt als „wartet auf
  Hennings Wort“ markieren, nicht als meinen Arbeitsschritt.
- **Kein Pfad der Geräteliste berührt**, falls nur Doku und ein ASC-Skript entstehen.
- **Beleg-Format offen:** Bildschirmfoto oder Protokoll je Schritt; Ablage (`docs/artifacts/176-…`) und wer die Fotos liefert
  (Henning schickt, ich öffne und beschreibe, bevor ein Haken fällt) sind in der Analyse festzulegen.
- **Mac und Watch:** Das Ticket nennt iPhone-Schritte; Mac (TestFlight, `macOS` wählen, #405) und iPad gehören nach dem
  Alltags-Stand dazu und fehlen im Tickettext.
- **Prüfdatum:** Die Liste gilt für einen Build; ihre Schritte brauchen die Buildnummer, gegen die sie gelaufen sind.
- **Alternative zur einmaligen Abnahme:** Liste als wiederkehrender Release-Schritt (Teil von #342) statt Einmalabnahme.

## Analysis

### Type
Feature (Prozess/Doku, kein Produktcode). Entscheidungen Henning 2026-10-25: Testgruppe bleibt in #342 (Teil 3), #176 wird
reine Prüfliste; Henning spielt nur Lücken durch, alles andere wird aus bereits bestätigten Builds und Tickets belegt.

### Recherche (zuerst)
- ASC-API kann Gruppen anlegen: `POST /v1/betaGroups`, internes Flag `isInternalGroup` (App Store Connect API 1.5 release notes,
  developer.apple.com/documentation/appstoreconnectapi/beta-groups). Build-Zuordnung per Relationship-Endpoint nicht belegt gefunden.
  Folge: Gruppen-Skript wäre möglich, ist aber für #176 nicht nötig (→ #342). Interne Gruppe `Familie` ist in testflight.md §6 schon vorgesehen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/abnahme-testflight.md` | CREATE | Feste Prüfliste: Schritt, Bedienweg, Quelle (Kriterium der Story), Status (belegt durch Build/Ticket · Lücke · wartet auf Hennings Wort), Beleg-Verweis, Buildnummer |
| `docs/artifacts/176-abnahme/` | CREATE | Belege (Bildschirmfotos/Protokolle), von mir geöffnet und beschrieben, bevor ein Haken fällt |
| `docs/reference/testflight.md` | MODIFY | Verweis auf die Prüfliste; Gruppen-Haken ausdrücklich unter #342 |
| `docs/reference/abnahme-und-arbeitsweise.md` | MODIFY (klein) | Prüfliste als Release-Schritt vor jeder Einladung nennen |

### Scope Assessment
- Files: 3–4, nur Doku. Estimated LoC: +150/-5. Risk Level: LOW (kein Produktcode, kein Pfad der Geräteliste: „Kein Pfad der Geräteliste berührt.“)

### Technical Approach
1. Liste aus `01-user-story.md` (Erfolgskriterien) und `funktionsuebersicht.md` ableiten; Ticketschritte (Text, Sprache, Veredelung,
   Ansichten, Erledigt/Parken, Mitteilung, Kalender, Watch-Diktat, Widget, Control Center, Teilen) plus **iPad, Mac (TestFlight macOS), Ortserinnerung**,
   die im Tickettext fehlen.
2. Jeden Schritt gegen Ticket-/Memory-Stand abgleichen (Henning-bestätigte Builds, z. B. #534 Build 107, #293 Build 112, #673 Build 115, #240 Build 61,
   #409 Build 64): belegt → Verweis auf Ticket + Buildnummer; sonst Lücke.
3. Offene Rückmeldungen #607, #584, #601, #605 (gemergt, unbestätigt) als Lückenschritte.
4. Lücken werden gebündelt als EIN Prüfblock für Henning vorbereitet (TestFlight-„Was testen“-Text), ausgelöst erst nach seinem wörtlichen
   „jetzt ist ein Test möglich“. Abweichungen = neue Tickets.
5. Ohne Modell geht es nicht? Nicht relevant, kein Modellweg im Spiel.

### Alternativen
- **Komplett neu durchspielen** (verworfen von Henning): gründlicher, kostet eine Gerätesitzung. 
- **Wiederkehrender Release-Schritt statt Einmalabnahme:** Die Liste bleibt als Vorlage für jede Einladungswelle (Teil von #342). Kippt keine ADR.
- **Gruppe per ASC-Skript hier mitbauen:** verworfen (Doppelung mit #342).

### Befunde, die gegen den Plan sprechen
Keine harten. Schwäche: „belegt durch Ticket“ ist schwächer als ein frischer Beleg. Gegenmittel: Buildnummer pro Haken, Liste gilt nur
für den genannten Build; ältere Belege werden bei Zweifel als Lücke geführt.

### Dependencies
Upstream: #175, #183 erledigt. Downstream: #371 (Einladung), #342 (übernimmt Testgruppe). Meilenstein „TestFlight 0.1“ schließt erst nach Hennings Rückmeldung.

### Open Questions
- [x] Testgruppe: in #342 (Henning 2026-10-25)
- [x] Umfang: nur Lücken (Henning 2026-10-25)
- [ ] Meilenstein „TestFlight 0.1“: existiert er noch? (`gh api` in der Spec klären; M3 ist heute der Rahmen)
