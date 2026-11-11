---
entity_id: feat-615-schnitt-4e-datenschutz
type: feature
created: 2026-11-10
updated: 2026-11-10
status: draft
workflow: feat-615-s4e-datenschutz
---

# Spec: Datenschutztext mit Konto-Teil, Schnitt 4e (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 4e; das Issue bleibt offen (`Refs #615`, nie `Closes #615`): #625 (Store-Datenschutzangaben, Store-Schalter, Einreichung) und #795 (App lädt Abschrift hoch) folgen.
Analyse: `docs/context/feat-615-s4e-datenschutz.md` (belegte Fakten, Entscheidungen Henning 2026-11-10; verbindlich).
Vorgänger: `docs/specs/feat-615-schnitt-4d-auth-oeffnen.md` (Anmeldewege offen), Muster Rechtstext: `docs/specs/feat-705-schnitt-2b2a-datenschutzseite.md`, `docs/specs/feat-763-schnitt-13-datenschutz-en.md`.
Es ist ein reiner Textschnitt: **kein App-Code, kein Dienstcode, kein Pfad der Geräteliste.** Zwei Repos (`loose-ends`, `henemm/henemm-website`), je ein PR.

## Für den PO

Der Datenschutztext sagt heute „Es gibt keinen eigenen Server, kein Konto bei uns“. Das stimmt nicht mehr, sobald jemand die Verbindung zu Claude nutzt: Dafür gibt es das Konto mit Apple und unseren Dienst bei Hetzner in Deutschland. Dieser Schnitt schreibt den Text so um, dass er das ehrlich und in einfachen Worten sagt, und veröffentlicht ihn auf deiner Seite henemm.com, deutsch und englisch. Den vollständigen Wortlaut findest du unten in dieser Spezifikation; mit deiner Freigabe gibst du ihn frei.

Zwei Dinge hast du schon entschieden: Der Schalter, der das Konto in der App im Store sichtbar macht, bleibt aus, bis wir es mit #625 für andere öffnen. Und die Sicherungen des Dienstes werden höchstens 30 Tage aufbewahrt; der Text nennt 30 Tage. Ich stelle diese Frist auf deinem Heimserver ein und veröffentliche den Text erst, wenn sie gilt. Nichts davon ändert etwas in den Stores oder auf deinem Gerät.

Was der Text nicht behauptet: dass die App deine Aufgabenliste zum Dienst hochlädt. Das tut sie heute noch nicht; der Absatz dazu kommt mit dem Schnitt, der es einbaut. Was er dagegen sagt: Bittest du Claude, eine Aufgabe anzulegen oder zu ändern, liegt dieser Auftrag samt Inhalt beim Dienst, bis du dein Konto löschst.

## Purpose

`docs/reference/datenschutz-entwurf.md` (Quelle) und die öffentlichen Seiten `https://www.henemm.com/legal/loose-ends/privacy-policy/` (de) und `https://www.henemm.com/legal/loose-ends/privacy-policy-en/` (en) beschreiben die App als reine Gerät-und-iCloud-App. Seit #615 S4b/S4c (App) und #796, #621 S6b, S4d (Betrieb) gibt es einen Dienst (`https://loose-ends.henemm.com`, Hetzner), ein Konto über „Mit Apple anmelden“ und die Verbindung zu claude.ai. ADR-21 verlangt, den Text zu ändern, **bevor** ein externer Nutzer Claude verbinden kann. Der Konto-Teil ist heute nur in TestFlight-Bauten mit `konto=true` sichtbar, der Dienst lässt nur ein Konto zu (`ALLOWED_APPLE_SUBS`); der Text beschreibt ihn trotzdem, weil TestFlight-Tester ihn sehen, und formuliert die Verbindung zu Claude als freiwillig.

**Ablauf (feste Reihenfolge):**

1. Wortlaut (unten) durch Henning freigeben lassen (Spec-Freigabe).
2. Standort des Servers lesend bestätigen (AC-9).
3. Prüfskript `scripts/test_datenschutz_text.py` schreiben, RED (Entwurf hat die Aussagen noch nicht).
4. Entwurf im Repo ändern (DE + EN), `CLAUDE.md`, GREEN; PR in `loose-ends`.
5. Sicherungsfrist 30 Tage in `henemm-infra` (Issue #421) umgesetzt und belegt (AC-10).
6. Erst dann: PR in `henemm-website` mit beiden Seiten; nach Merge und Auslieferung Live-Prüfung (AC-11).

**Regeln vor Modell:** reiner Text und eine Textprüfung per Regex; die Zeile „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 um (Text ändern, bevor ein externer Nutzer Claude verbinden kann) und die Entscheidung #615 (nur Apple, Konto-Gruppe, Löschen in der App); keine neue Abhängigkeit, kein neues Verfahren, kein Schema.
- **Rationale:** Eine Seite für App und Dienst (Entscheidung #705 bleibt), der Konto-Teil als eigener, klar überschriebener Abschnitt, der nur zutrifft, wenn der Nutzer die Verbindung zu Claude nutzt. Jede Aussage hat einen Beleg (Tabelle unten); was der Code nicht belegt, steht nicht im Text.

## Source

**Dateien (loose-ends):** `docs/reference/datenschutz-entwurf.md`, `CLAUDE.md` (ein Satz im Datenschutz-Absatz unter „Build“), `scripts/test_datenschutz_text.py` (neu).
**Dateien (`henemm/henemm-website`):** `content/legal/loose-ends/privacy-policy/_index.md`, `content/legal/loose-ends/privacy-policy-en/_index.md`.
**Nicht berührt:** `project.yml` (`LEAccountEnabled` bleibt `false`), `LooseEnds/Info.plist`, `PrivacyInfo.xcprivacy`, `scripts/test_asc_what_to_test.py`, die Store-Datenschutz-URL und alle Tests zum Schalter (alles #625).

### Wortlaut (Entwurf, deutsch)

Die öffentliche Seite führt die Änderungen an denselben Stellen wie der Entwurf; der Entwurf trägt zusätzlich die Beleg-Tabelle.

**1. Kurzfassung** (ersetzt den heutigen Absatz „Kurzfassung für Nutzer“):

> Loose Ends speichert deine Aufgaben auf deinem Gerät und, wenn du iCloud nutzt, in deinem privaten iCloud.
> Es gibt keine Werbung und kein Tracking. Gesprochenes wird auf deinem Gerät in Text umgewandelt. Die App fragt nur
> nach Rechten, wenn du die Funktion benutzt, die sie braucht. Nur wenn du die freiwillige Verbindung zu Claude nutzt,
> legst du ein Konto bei uns an und nutzt einen Dienst von uns; was dann gespeichert wird, steht im Abschnitt „Wenn du
> die Verbindung zu Claude nutzt“.

**2. Abschnitt „Wo es liegt“**, letzter Punkt (ersetzt „Kein eigenes Backend, keine Analyse- oder Werbe-Dienste, kein Tracking.“):

> - Keine Analyse- oder Werbe-Dienste, kein Tracking. Einen eigenen Dienst (Server) gibt es nur für die freiwillige Verbindung zu Claude, siehe nächster Abschnitt; ohne sie verlässt nichts außer dem iCloud-Abgleich dein Gerät.

**3. Neuer Abschnitt** (steht nach „Wo es liegt“, vor „Welche Rechte und warum“):

> ## Wenn du die Verbindung zu Claude nutzt
>
> Das ist freiwillig. Ohne sie gibt es kein Konto bei uns und keinen Datenverkehr zu unserem Dienst. Du nutzt sie, indem du dich in den Einstellungen unter „Claude“ mit Apple anmeldest; damit entsteht dein Konto bei uns. Dann gilt zusätzlich:
>
> **Anmeldung.** Du meldest dich nur mit Apple an. Wir fragen Apple weder nach deinem Namen noch nach deiner E-Mail-Adresse. Gespeichert wird nur die Kennung, die Apple für dich in dieser App vergibt, und der Zeitpunkt, zu dem das Konto angelegt wurde.
>
> **Was unser Dienst speichert.** Eine Anmeldung (Sitzung) speichern wir nur als Prüfsumme, nicht im Klartext; sie endet, wenn du sie 90 Tage nicht benutzt, oder wenn du dich abmeldest. Das Zugangsmerkmal, das Apple uns bei der Anmeldung gibt, speichern wir verschlüsselt, um es beim Löschen deines Kontos bei Apple zu widerrufen. Verbindest du Claude (den Konnektor in claude.ai), speichern wir dessen Zugangsdaten ebenfalls nur als Prüfsumme.
>
> **Aufträge aus Claude.** Bittest du Claude, eine Aufgabe anzulegen oder zu ändern (etwa sie zu erledigen, ihr ein Datum zu geben, sie zurückzustellen oder einen Unterpunkt anzufügen), speichert der Dienst diesen Auftrag mit seinem Inhalt (zum Beispiel dem Titel der neuen Aufgabe), bis deine App ihn übernimmt, und danach das Ergebnis. Aufträge und Ergebnisse bleiben gespeichert, bis du dein Konto löschst.
>
> **Wo.** Der Dienst läuft auf einem Server der Hetzner Online GmbH in Deutschland.
>
> **Server-Protokolle.** Wenn du den Dienst aufrufst, schreibt der Webserver deine IP-Adresse, die aufgerufene Adresse, den Zeitpunkt und den Antwortcode in ein Protokoll. Wir brauchen es, um Fehler zu finden und Missbrauch abzuwehren (Art. 6 Abs. 1 lit. f DSGVO, berechtigtes Interesse). Die Protokolle werden nach 14 Tagen gelöscht.
>
> **Sicherungen.** Die Datenbank des Dienstes wird nachts gesichert, verschlüsselt auf einem weiteren Rechner in Deutschland. Sicherungen werden höchstens 30 Tage aufbewahrt.
>
> **Löschen.** In den Einstellungen unter „Claude“ löschst du mit „Konto löschen“ dein Konto. Das entfernt dein Konto und alle Daten, die der Dienst zu diesem Konto gespeichert hat, und widerruft die Anmeldung bei Apple. Vorhandene Sicherungen laufen innerhalb von 30 Tagen aus. „Abmelden“ beendet nur die Sitzung auf diesem Gerät.
>
> **Apple und Claude.** Bei der Anmeldung handelt Apple nach Apples Datenschutz. Was Claude (Anthropic) mit dem macht, was du dort schreibst oder abrufst, regelt Anthropics Datenschutz, nicht dieser Text.

**4. Abschnitt „Verantwortlicher und Kontakt“**, Satz zum Löschen (ersetzt „Deine Daten löschst du selbst: Aufgaben in der App; den iCloud-Bereich der App in den iCloud-Einstellungen unter „Speicher verwalten“.“):

> Deine Daten löschst du selbst: Aufgaben in der App; den iCloud-Bereich der App in den iCloud-Einstellungen unter „Speicher verwalten“; ein Konto bei unserem Dienst mit „Konto löschen“ in den Einstellungen der App.

Nicht im Wortlaut: ein Absatz zur Aufgabenübertragung (Abschrift) an den Dienst; er kommt mit #795.

### Wortlaut (Entwurf, englisch, wortgetreu)

Die englische Seite hat die Abschnitte 1 bis 6; die Änderungen stehen in Abschnitt 2 („In short“), 3 (letzter Punkt), dem neuen, nummerierten Abschnitt „### 4. If you use the connection to Claude“ direkt nach Abschnitt 3; die bisherigen Abschnitte 4 bis 6 werden zu 5 bis 7 (sie verweisen nicht per Nummer aufeinander), und der Löschsatz steht im Abschnitt 7 (bisher 6, „Your rights, deletion and changes“). „Last updated“ wird auf das Veröffentlichungsdatum gesetzt.

**Abschnitt 2, erster Absatz:**

> Loose Ends stores your tasks on your device and, if you use iCloud, in your private iCloud.
> There is no advertising and no tracking. What you say is turned into text on your device. The app only asks for
> permissions when you use the function that needs them. Only if you use the voluntary connection to Claude do you create an
> account with us and use a service of ours; what is stored then is described in the section "If you use the connection to Claude".

**Abschnitt 3, letzter Punkt:**

> - No analytics or advertising services, no tracking. There is a service (server) of our own only for the voluntary connection to Claude, see the next section; without it, nothing leaves your device except the iCloud sync.

**Neuer Abschnitt:**

> ### 4. If you use the connection to Claude
>
> This is voluntary. Without it there is no account with us and no traffic to our service. You use it by signing in with Apple in Settings under "Claude"; this creates your account with us. Then the following also applies:
>
> **Sign-in.** You sign in with Apple only. We do not ask Apple for your name or your email address. What is stored is only the identifier Apple assigns to you for this app, and the time the account was created.
>
> **What our service stores.** We store a sign-in (session) only as a checksum, not in plain text; it ends when you do not use it for 90 days, or when you sign out. The token Apple gives us at sign-in is stored encrypted, so that we can revoke it with Apple when your account is deleted. If you connect Claude (the connector in claude.ai), we likewise store its access credentials only as a checksum.
>
> **Orders from Claude.** If you ask Claude to create or change a task (for example to complete it, give it a date, put it aside or add a subtask), the service stores this order with its content (for example the title of the new task) until your app takes it over, and then the result. Orders and results stay stored until you delete your account.
>
> **Where.** The service runs on a server of Hetzner Online GmbH in Germany.
>
> **Server logs.** When you call the service, the web server writes your IP address, the address called, the time and the response code to a log. We need it to find errors and to defend against abuse (Art. 6(1)(f) GDPR, legitimate interest). The logs are deleted after 14 days.
>
> **Backups.** The service's database is backed up at night, encrypted, on another computer in Germany. Backups are kept for 30 days at most.
>
> **Deleting.** In Settings under "Claude" you delete your account with "Delete account". This removes your account and all data the service has stored for that account, and revokes the sign-in with Apple. Existing backups expire within 30 days. "Sign out" only ends the session on this device.
>
> **Apple and Claude.** At sign-in, Apple acts under Apple's privacy rules. What Claude (Anthropic) does with what you write or retrieve there is governed by Anthropic's privacy policy, not by this text.

**Abschnitt 7 (bisher 6), Löschsatz:**

> You delete your tasks in the app itself, the app's iCloud area in the iCloud settings under "Manage Storage", and an account with our service with "Delete account" in the app's settings.

Die Bezeichnungen („Claude“, „Konto löschen“, „Abmelden“; en „Claude“, „Delete account“, „Sign out“) sind in der Spec-Phase gegen `LooseEnds/Views/AccountSection.swift` und `LooseEnds/Resources/Localizable.xcstrings` gelesen und stimmen; AC-4 hält den Beleg fest.

### Beleg-Tabelle (kommt in den Entwurf unter „Beleg im Code“, ersetzt die Zeile „Kein eigenes Backend, keine Fremd-SDKs“)

| Aussage | Beleg |
|---|---|
| Freiwillig; ohne Konto kein Verkehr zum Dienst | `LooseEnds/Claude/AccountWiring.swift` (`forApp`, nichts wird vor einem Tipp gesendet), `LooseEnds/Views/AccountSection.swift` (Gruppe „Claude“ in den Einstellungen) |
| Keine Fremd-SDKs, keine Analyse | `project.yml` ohne `packages`-Abschnitt; `URLSession` nur im Konto-Teil (`LooseEnds/Claude/`) |
| Nur Apple; kein Name, keine E-Mail | `LooseEnds/Views/AccountSection.swift:177` `requestedScopes = []`; `server/migrations/002_accounts.sql` (`apple_sub`, Anlagezeit) |
| Sitzung nur als Prüfsumme, 90 Tage Nichtbenutzung | `server/migrations/002_accounts.sql`, `server/src/accounts.ts` (`SESSION_IDLE_DAYS` = 90, #615 S4a) |
| Apple-Zugangsmerkmal verschlüsselt, zum Widerruf | `server/src/apple-vault.ts` (AES-256-GCM), `server/migrations/005_apple_tokens_per_client.sql`, `server/src/auth.ts` (`/auth/delete` widerruft) |
| Zugangsdaten des Konnektors nur als Prüfsumme | `server/migrations/004_oauth.sql`, `server/src/oauth-adapter.ts` (Ids als SHA-256) |
| Hetzner, Deutschland | `docs/artifacts/feat-615-s4d-auth-oeffnen/monitor-*.txt` (Server `rennwienix`), `docs/artifacts/feat-615-s4e-datenschutz/standort.txt` (AC-9) |
| Server-Protokolle mit IP, 14 Tage | `/etc/logrotate.d/nginx` auf `rennwienix` (`daily`, `rotate 14`), Beleg `docs/artifacts/feat-615-s4e-datenschutz/protokolle.txt` (AC-9) |
| Sicherungen nachts, verschlüsselt, höchstens 30 Tage | `henemm-infra` `docs/backup-offsite.md` und Issue #421 (Frist), Beleg `docs/artifacts/feat-615-s4e-datenschutz/sicherung.txt` (AC-10) |
| „Konto löschen“ entfernt alles zum Konto, widerruft bei Apple | `server/src/accounts.ts` (`deleteAccount`), `server/src/auth.ts` (`POST /auth/delete`), Nachweis `docs/artifacts/feat-615-s4d-auth-oeffnen/loeschen-lokal.md` |
| Aufträge aus Claude mit Inhalt und Ergebnis, bis zur Kontolöschung | `server/migrations/001_claude_schema.sql` (`orders`, `order_results`, kein Ablauf), `server/migrations/007_order_kinds.sql`, `server/src/mcp.ts` (`capture_task`, `complete_task`, `set_due` und weitere Auftragswerkzeuge), `server/src/accounts.ts` (`deleteAccount` löscht Aufträge und Ergebnisse) |
| „Abmelden“ beendet nur die Sitzung dieses Geräts | `server/src/auth.ts` (`POST /auth/logout` beendet genau diese Sitzung), `LooseEnds/Views/AccountSection.swift` (Hinweis „Signing out disconnects only this device“) |
| Sicherungen auf einem weiteren Rechner in Deutschland, verschlüsselt | `henemm-infra` `docs/backup-offsite.md` (restic, verschlüsselt, Heimserver in Deutschland, append-only), Beleg `sicherung.txt` (AC-10) |
| Apple und Anthropic handeln nach eigenem Datenschutz | kein Code-Beleg möglich; Verweis auf fremde Verantwortung, steht deshalb im Entwurf unter „Offen, nicht belegt“ als bewusst nicht prüfbar |
| Rechtsgrundlage Protokolle | Art. 6 Abs. 1 lit. f DSGVO (Recherche im Kontext: Server-Logs mit IP 7 bis 14 Tage gängig) |

Im Abschnitt „Offen, nicht belegt“ des Entwurfs kommen zwei Punkte hinzu: die Aufgabenübertragung (#795) ist nicht beschrieben, weil sie nicht gebaut ist; und was Anthropic mit Inhalten macht, ist deren Sache, nicht im Code prüfbar. Die Statuszeile des Entwurfs nennt Hennings Freigabe des Konto-Teils (Datum der Freigabe) und die Veröffentlichung.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `henemm/henemm-infra#421` (Sicherung der Loose-Ends-Datenbank off-site höchstens 30 Tage), heute offen | Voraussetzung der Veröffentlichung (AC-10); wird von Claude umgesetzt |
| Website-Repo `henemm/henemm-website`, Seiten aus PR #75 und #76 | bestehend; zweiter PR |
| Betrieb aus #796, #621 S6b, #615 S4d | bestehend (Belege dort) |
| Downstream | #625 (Store-Schalter, `PrivacyInfo.xcprivacy` mit „User ID“, Store-Angaben, Auftragsverarbeitung mit Hetzner), #795 (Absatz zur Abschrift) |

## Acceptance Criteria

Belege liegen unter `docs/artifacts/feat-615-s4e-datenschutz/` („Belegordner“). Kein Beleg enthält Zugangsdaten, `sub`-Werte oder IP-Adressen von Nutzern.

- **AC-1:** Kurzfassung korrigiert: GIVEN `docs/reference/datenschutz-entwurf.md` WHEN der Abschnitt „Kurzfassung für Nutzer“ und der Abschnitt „Wo es liegt“ gelesen werden THEN enthalten sie weder den heutigen Satz „Es gibt keinen eigenen Server, kein Konto bei uns, …“ noch „keinen eigenen Server“ noch „Kein eigenes Backend“, und die Kurzfassung verweist auf die freiwillige Verbindung zu Claude im Wortlaut von Punkt 1 und 2 oben.
- **AC-2:** Konto-Abschnitt vollständig (deutsch): GIVEN der Entwurf WHEN der Abschnitt „Wenn du die Verbindung zu Claude nutzt“ gelesen wird THEN steht er nach „Wo es liegt“ und vor „Welche Rechte und warum“, trägt wörtlich den freigegebenen Text von Punkt 3 und enthält die Aussagen: nur Apple, kein Name und keine E-Mail, Sitzung nur als Prüfsumme und 90 Tage, Aufträge aus Claude mit Inhalt bis zur Kontolöschung, Hetzner in Deutschland, Protokolle mit IP-Adresse 14 Tage nach Art. 6 Abs. 1 lit. f DSGVO, Sicherungen höchstens 30 Tage, „Konto löschen“ entfernt das Konto samt Daten und widerruft bei Apple, Freiwilligkeit.
- **AC-3:** Keine Behauptung ohne Beleg: GIVEN der Entwurf WHEN der Konto-Abschnitt auf Aufgabenübertragung geprüft wird THEN kommt weder „Abschrift“ noch eine Aussage vor, dass die App Aufgaben zum Dienst hochlädt; und jede Aussage des Abschnitts hat eine Zeile der Beleg-Tabelle mit Datei, Migration, Issue oder Beleg aus dem Belegordner; die Tabelle ersetzt die Zeile „Kein eigenes Backend, keine Fremd-SDKs“ und nennt den Konto-Teil als einzigen Ort für `URLSession`.
- **AC-4:** Löschhinweis erweitert: GIVEN der Entwurf WHEN „Verantwortlicher und Kontakt“ gelesen wird THEN nennt der Löschsatz zusätzlich „Konto löschen“ in den Einstellungen der App (Wortlaut Punkt 4); die Knopfbezeichnungen im Text sind gegen die Kataloge gelesen (Beleg `knoepfe.txt`: Katalogschlüssel und Wort je Sprache).
- **AC-5:** Englisch inhaltsgleich: GIVEN der Abschnitt „English“ im Entwurf WHEN er mit dem deutschen verglichen wird THEN enthält er die vier Änderungen (Abschnitt 2, 3, neuer Abschnitt 4, Löschsatz im Abschnitt 7, bisher 6) im oben angegebenen Wortlaut, ohne Zusätze und Kürzungen; die Zahlen 14, 30 und 90 stehen in beiden Sprachen; „Last updated“ trägt das Veröffentlichungsdatum; die Statuszeile des Abschnitts nennt die Freigabe und die englische Website-Seite.
- **AC-6:** Prüfskript: GIVEN `scripts/test_datenschutz_text.py` (ein `unittest.TestCase`, wie die übrigen Skript-Tests) WHEN der CI-Befehl `python -m unittest discover -s scripts -p 'test_*.py'` läuft THEN ist es grün und prüft im Entwurf je Sprache (a) die Kernaussagen per Regex („14 Tage“/„14 days“, „30 Tage“/„30 days“, „90 Tage“/„90 days“, „Hetzner“, „Deutschland“/„Germany“, „Konto löschen“/„Delete account“, „Art. 6 Abs. 1 lit. f“/„Art. 6(1)(f)“), (b) dass die veralteten Wendungen des heutigen Textes („keinen eigenen Server“, „Kein eigenes Backend“, „no server of our own“, „No backend of our own“) im ganzen Entwurf fehlen; „kein Konto bei uns“/„no account with us“ ist nicht verboten, weil der neue Konto-Abschnitt es absichtlich sagt („Ohne sie gibt es kein Konto bei uns …“), (c) dass „Abschrift“/„transcript“ im Konto-Abschnitt fehlt. Es läuft in der CI des Repos mit.
- **AC-7:** RED vorher: GIVEN das Skript und der unveränderte Entwurf WHEN das Skript läuft THEN ist es rot, und der Beleg `red.txt` zeigt die fehlenden Aussagen (mindestens 14 Tage, 30 Tage, 90 Tage, Hetzner, Konto löschen) und die vorhandenen veralteten Sätze.
- **AC-8:** `CLAUDE.md` aktuell: GIVEN `CLAUDE.md` WHEN der Datenschutz-Absatz unter „Build“ gelesen wird THEN nennt er, dass der Text seit dem Veröffentlichungsdatum den Konto-Teil enthält (Verweis auf diese Spec), dass der Store-Schalter `LEAccountEnabled` bis #625 aus bleibt und die Sicherungsfrist 30 Tage beträgt; die übrigen Sätze des Absatzes bleiben unverändert.
- **AC-9:** Standort und Protokollfrist belegt (lesend): GIVEN `rennwienix` und die Hetzner-Cloud-Angaben WHEN in der Umsetzung lesend geprüft wird — `/etc/logrotate.d/nginx` und das Rechenzentrum aus dem Metadatendienst (`http://169.254.169.254/hetzner/v1/metadata/availability-zone`) über SSH auf `rennwienix`, ersatzweise `hcloud server describe`; kein Schreiben, kein Neustart; dieser Lesezugriff braucht eine Freigabe der Sitzung für Lesen am Live-Server, die in der Spec-Phase nicht vorlag (in der Analyse wurde `rotate 14` dort schon gelesen) — THEN zeigt `protokolle.txt` `daily` und `rotate 14` für den nginx-Zugriffsprotokoll-Eintrag, und `standort.txt` nennt den Standort (erwartet Nürnberg, nbg1); lautet das Ergebnis anders als „Deutschland“ oder „14“, wird der Wortlaut angepasst und neu zur Freigabe vorgelegt, bevor etwas veröffentlicht wird.
- **AC-10:** Reihenfolge, Sicherungsfrist gilt vor der Veröffentlichung: GIVEN `henemm/henemm-infra#421` WHEN der Website-PR gemergt werden soll THEN ist #421 geschlossen und `restic snapshots --path /home/hem/backups/loose-ends` (nur lesend; auf `rennwienix` gegen das off-site Repository mit den Zugangsdaten aus dessen Sicherungsskript oder auf dem Heimserver, der das Repository trägt und dort ausdünnt; `rennwienix:/home/hem/backups/loose-ends/` selbst hält nur den jüngsten Dump) zeigt keinen Snapshot älter als 30 Tage (Beleg `sicherung.txt` mit Befehl, Zeitpunkt, Zahl und ältestem Datum); ist die Frist erst im selben Zug gesetzt, zeigt der Beleg den Lauf der Aufbewahrung (`forget --prune` nach `--keep-within 30d`) und danach dieselbe Zählung; vorher wird der Website-PR nicht gemergt.
- **AC-11:** Live-Prüfung: GIVEN der gemergte und ausgelieferte Website-PR WHEN `curl -sS -o seite.html -w '%{http_code}'` die URLs `https://www.henemm.com/legal/loose-ends/privacy-policy/` und `https://www.henemm.com/legal/loose-ends/privacy-policy-en/` abruft THEN ist der Code je 200, und das Prüfskript (Aufruf mit `DATENSCHUTZ_LIVE=1`) findet in beiden Seiten die Kernaussagen aus AC-6 (a), den Abschnitt „Wenn du die Verbindung zu Claude nutzt“ bzw. „If you use the connection to Claude“ und keinen der veralteten Sätze aus AC-6 (b); Beleg `live.txt` mit Codes und Treffern. Die Datenschutz-URL, die bei Apple gesetzt ist, bleibt unverändert (Beleg: Repo-Variable `ASC_PRIVACY_POLICY_URL` und `PRIVACY_URL_EN` ohne Diff).
- **AC-12:** Seite und Entwurf gleich: GIVEN der veröffentlichte Text (beide Sprachen) und der Entwurf WHEN die Abschnitte verglichen werden THEN stimmen die Kernsätze der Punkte 1 bis 4 wörtlich überein; die öffentliche Seite enthält nicht die Abschnitte „Beleg im Code“ und „Offen, nicht belegt“ (Beleg `vergleich.txt`).
- **AC-13:** Schalter unberührt: GIVEN der Diff beider PRs WHEN er geprüft wird THEN enthält er weder `project.yml` noch `LooseEnds/Info.plist` noch `PrivacyInfo.xcprivacy` noch `scripts/test_asc_what_to_test.py`, und `LEAccountEnabled` ist in `project.yml` weiterhin `false` (Beleg `schalter.txt`: Diff-Dateiliste und Zeile aus `project.yml`).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/datenschutz-entwurf.md` | MODIFY | Kurzfassung, „Wo es liegt“, neuer Konto-Abschnitt, Löschsatz, Beleg-Tabelle, „Offen“, Status, EN-Abschnitt; ≈ +105/−8 |
| `CLAUDE.md` | MODIFY | Datenschutz-Absatz: Konto-Teil, Schalter aus bis #625, 30 Tage; ≈ +2/−1 |
| `scripts/test_datenschutz_text.py` | CREATE | Textprüfung Entwurf und Live-Seite; ≈ 60 |
| `henemm-website: content/legal/loose-ends/privacy-policy/_index.md` | MODIFY | öffentliche deutsche Fassung; ≈ +25/−4 |
| `henemm-website: content/legal/loose-ends/privacy-policy-en/_index.md` | MODIFY | öffentliche englische Fassung; ≈ +25/−4 |
| `docs/artifacts/feat-615-s4e-datenschutz/` | CREATE | Belege (Text); zählt nicht zum Dateilimit |

### Estimated Changes

- **Dateien: 5 Pfade**; der Belegordner (nur Belegtexte, kein Produkt) zählt nicht mit, wie in den Belegordnern früherer Schnitte. Davon 2 in `henemm-website` (zweites Repo, eigener PR), 3 in `loose-ends`. Am Rand des Limits von 4 bis 5.
- **LoC: ≈ 230 bis 250** (Entwurf ≈ 115, Prüfskript ≈ 60, Website ≈ 60, `CLAUDE.md` ≈ 3), davon über 80 Prozent Rechtstext. Innerhalb von ±250 LoC; Rechtstext in zwei Sprachen und zwei Repos ist der Grund für die Nähe zur Grenze. Wächst der Text bei Hennings Korrekturen, wird das Prüfskript nicht gekürzt, sondern die Website-Seiten getrennt gemergt.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine Migration, keine neue Abhängigkeit.
- **Seiteneffekte nach außen (explizit):** Zwei öffentliche Rechtsseiten ändern ihren Inhalt; eine Aufbewahrungsfrist am Heimserver (restic, Teil von #421) wird gesetzt, dabei werden Sicherungen der Loose-Ends-Datenbank älter als 30 Tage unwiderruflich gelöscht; das ist bewusst (Entscheidung Henning 2026-11-10) und nur für diesen einen Pfad.
- **Parallele Arbeit:** vor jedem PR `origin/main` und offene PRs in beiden Repos erneut prüfen; `CLAUDE.md` ist Hotspot.

## Risiken

- **Text vor der Frist veröffentlicht.** Würde „30 Tage“ stehen, bevor die Aufbewahrung greift, wäre der Text falsch. Gegenmittel: AC-10 (Reihenfolge, `restic snapshots` als Beleg), Website-PR erst danach.
- **Standort nicht bestätigt.** In der Spec-Phase war Lesen am Live-Server für diese Sitzung nicht freigegeben; vorhandene Belege zeigen nbg1 nur indirekt (Kapazitätsprüfung „cx43 in nbg1“ in `docs/artifacts/feat-615-s4d-auth-oeffnen/monitor-nachher.txt`). Der Weg steht in AC-9. Bleibt er unbelegt, steht nur „Deutschland“ nach Hennings Wissen, nicht „Nürnberg“; ist auch das unbelegt, bleibt der Satz draußen und kommt zur Freigabe zurück (AC-9).
- **Text beschreibt etwas, das nur TestFlight-Tester sehen.** Gewollt: Freiwilligkeit steht im Text, der Store-Schalter bleibt aus. Gegenmittel: AC-13.
- **Store-Angaben später.** Mit dem Store-Schalter (#625) müssen `PrivacyInfo.xcprivacy` („User ID“, mit #795 „Other User Content“) und die Datenschutzangaben in App Store Connect nachziehen; das ist hier ausdrücklich nicht Teil und wird im PR als Folge benannt.
- **Rechtliche Belastbarkeit.** Der Text ist ein Entwurf eines Tech Leads, keine Rechtsberatung; die Auftragsverarbeitung mit Hetzner ist Teil von #625. Gegenmittel: jede Aussage belegt, Freigabe durch Henning.
- **Zwei Repos.** Ein Auseinanderlaufen von Entwurf und Seite wäre ein Fehler im Beleg; Gegenmittel AC-12.

## Test Plan

Kein App- oder Dienstcode, also keine Unit- oder UI-Tests der App. Geprüft wird der Text maschinell:

| Prüfung | Beleg | AC |
|---|---|---|
| `scripts/test_datenschutz_text.py` rot vor, grün nach der Änderung | `red.txt`, CI | AC-1 bis AC-3, AC-5 bis AC-7 |
| Knopfbezeichnungen gegen die Kataloge | `knoepfe.txt` | AC-4 |
| `CLAUDE.md` | Diff | AC-8 |
| Protokollfrist und Standort lesend | `protokolle.txt`, `standort.txt` | AC-9 |
| Sicherungsfrist (`restic snapshots`) | `sicherung.txt` | AC-10 |
| Live-Seiten (curl, Skript mit `DATENSCHUTZ_LIVE=1`), Sichtprüfung im Browser | `live.txt`, `live-de.png`, `live-en.png` | AC-11 |
| Vergleich Entwurf und Seite | `vergleich.txt` | AC-12 |
| Dateiliste der PRs, Schalter | `schalter.txt` | AC-13 |

- [ ] Test 1 (AC-6, AC-7): GIVEN der unveränderte Entwurf WHEN das Skript läuft THEN rot; GIVEN der geänderte Entwurf THEN grün.
- [ ] Test 2 (AC-6): GIVEN ein Entwurf mit dem Satz „Es gibt keinen eigenen Server“ WHEN das Skript läuft THEN rot (Gegenprobe, dass die Prüfung veraltete Sätze fängt).
- [ ] Test 3 (AC-11): GIVEN die ausgelieferten Seiten WHEN das Skript mit `DATENSCHUTZ_LIVE=1` läuft THEN grün, ohne Netz (`DATENSCHUTZ_LIVE` nicht gesetzt) werden die Live-Tests übersprungen und im Beleg einzeln benannt.

**Ehrlich zur Belegkraft:** Das Skript belegt, dass der Text die Kernsätze enthält und die veralteten nicht; ob die Aussagen wahr sind, belegt die Beleg-Tabelle (Code und Betrieb). Eine rechtliche Prüfung ersetzt keines von beiden.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): Konto-Abschnitt in der einen Seite, Store-Schalter aus, Sicherung 30 Tage** | siehe Purpose | ehrlich ohne Store-Folgen; Seite bleibt eine | Text beschreibt Funktion, die im Store noch nicht sichtbar ist | — |
| **A1 Schalter in 4e einschalten** (Plan der 4d-Spec) | Store-Bau mit Gruppe „Claude“ | schließt #615 früher | jeder Store-Nutzer sieht einen Anmeldeknopf, der mit „nicht zugelassen“ endet (`ALLOWED_APPLE_SUBS` lässt nur ein Konto zu), die App lädt noch nichts hoch (#795), Store-Datenschutzangaben fehlen (#625), Ablehnungsrisiko im Review | die Reihenfolge der 4d-Spec (4e vor #625); verworfen, Henning 2026-11-10 |
| **A2 eigene Seite nur für den Dienst** | zweite URL `https://www.henemm.com/legal/loose-ends-service/privacy-policy/` | App (privat in iCloud) und Dienst sauber getrennt | zwei Seiten, zwei URLs bei Apple, Nutzer liest das Wichtigste nicht; kippt „eine Seite“ aus #705 | Entscheidung #705 („eine Seite“); verworfen |
| **A3 Aufbewahrung drei Jahre offen nennen** | Text sagt „bis zu drei Jahre“ (heutige restic-Regel `--keep-yearly 3`) | keine Infra-Arbeit | schwer zu erklären, für eine kleine Datenbank unverhältnismäßig, widerspricht „Löschen“ im Text | die Aufbewahrungsregel in `henemm-infra` (`docs/backup-offsite.md`); verworfen, Henning 2026-11-10: 30 Tage |

## Out of Scope / Folgeschnitte

- **#625:** `LEAccountEnabled` im Store-Bau, `PrivacyInfo.xcprivacy` („User ID“), Datenschutzangaben in App Store Connect, Auftragsverarbeitung mit Hetzner, Einreichung, eigener Server vor externen Nutzern.
- **#795:** App lädt die Abschrift hoch; der Absatz zur Aufgabenübertragung (was der Dienst von den Aufgaben speichert, ohne Rohtext und Notiz) kommt mit ihm und ändert Text und Seite erneut.
- **henemm-infra#421:** Umsetzung der 30-Tage-Frist ist Teil der Voraussetzung (AC-10), aber nicht dieser Spec-Diff.
- Änderungen an App, Dienst, Migrationen, Info.plist, Entitlements: keine.

## Abnahme

Kein Pfad der Geräteliste berührt: nur Rechtstext (`docs/reference`, `scripts`, `CLAUDE.md`, Website-Repo). Stufe 1 ist das Prüfskript (rot vor, grün nach, CI). Stufe 2 (benutzen, nicht nur bauen) ist hier das, was ein Nutzer tatsächlich sieht: beide Live-Seiten im Browser geöffnet, ganz durchgescrollt, Screenshot je Sprache (`live-de.png`, `live-en.png`) geöffnet und beschrieben, dazu AC-11. Die App ändert sich nicht, deshalb kein Simulatorlauf; der Bericht sagt „Kein Pfad der Geräteliste berührt. Reiner Text, keine App-Änderung; Stufe 2 an den Live-Seiten belegt.“ Nichts auf Hennings Geräten.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt, Belege im Belegordner
- [ ] Wortlaut von Henning freigegeben (Spec-Freigabe), Datum im Entwurf vermerkt
- [ ] henemm-infra#421 geschlossen, Frist 30 Tage belegt, danach erst die Website veröffentlicht
- [ ] PR in `loose-ends` (Prüfskript, Entwurf, `CLAUDE.md`, `Refs #615`) und PR in `henemm-website` gemergt, CI grün; beide Seiten live (200)
- [ ] #615 kommentiert (Stand 4e, Folgen #625 und #795), Board-Karte aktuell, Memory geschrieben

Keine Gerätepunkte (Stufe 3 greift nicht).

## Changelog

- 2026-11-10: Initial spec created (Schnitt 4e)
- 2026-11-10: PO-Briefing 2: Aufträge umfassen alle Auftragswerkzeuge (anlegen oder ändern, Beispiele)
- 2026-11-10: PO-Briefing (Ampel rot): Absatz „Aufträge aus Claude“ (DE/EN) ergänzt, Beleg-Zeile, AC-2
- 2026-11-10: Spec-Prüfung 3: englische Nummerierung festgelegt (neuer Abschnitt 4, bisher 4–6 werden 5–7)
- 2026-11-10: Spec-Prüfung 2: unittest statt pytest (CI), Lesewege für AC-9/AC-10 benannt, Beleg-Zeilen für Abmelden, Sicherungsort, Apple/Anthropic, Stufe 2 an den Live-Seiten
- 2026-11-10: Spec-Prüfung: Verbotsliste in AC-1/AC-6 auf die tatsächlichen Wendungen des heutigen Textes gesetzt (Widerspruch zu „kein Konto bei uns“ im neuen Abschnitt), URLs ausgeschrieben, Zählung Belegordner
- 2026-11-10: Knopfwörter gegen Katalog bestätigt; Konto entsteht durch Anmelden mit Apple (Wortlaut Punkt 3, DE und EN)
