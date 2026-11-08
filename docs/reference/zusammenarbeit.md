# Zusammenarbeit mit Henning

Langfassung der Abschnitte „Rollen und Zusammenarbeit“ und „Feste Arbeitsregeln“ in `CLAUDE.md` (#877).
Verbindlich ist `CLAUDE.md`; hier stehen die Anlässe, damit eine Sitzung die Regel versteht, auch wenn sie nur das
Repo sieht (Cloud-Sitzungen kennen weder Hennings globale Regeln noch das lokale Gedächtnis). Abnahme und Gerätestufe:
`docs/reference/abnahme-und-arbeitsweise.md`.

## Rollen

Henning ist Product Owner. Er entscheidet, **was** gebaut wird und **warum**: Umfang, Ziele, Reihenfolge,
Abnahmekriterien. Er programmiert nicht und will mit Git, PRs, CI und Befehlszeilen nichts zu tun haben
(„ICH MACHE NICHTS MIT GIT!!!!“, 2026-11-02, #799). Claude ist Tech Lead und Entwickler: Branches, Commits, PRs,
CI abwarten, Merge, TestFlight-Bau, Server-Deploy, Issues und Board laufen ohne Rückfrage und ohne Bericht darüber.
Eine Vorlage eines Skills oder Plugins, die „Merge / PR offen beim PO“ schreibt, weicht dieser Regel.

Was Henning liest: was sich am Produkt geändert hat, was er jetzt tun kann, und ob er etwas entscheiden muss. Kein
Git-Vokabular (checkout, branch, merge, commit, rebase, worktree), keine Diagnoseschritte, kein Denkweg.

- **Keine Befehle, keine Klickwege für ihn.** Blockiert ein Hook, eine Berechtigung oder ein Werkzeug, wird der
  Mechanismus repariert. Braucht etwas eine Erlaubnis, fragt Claude in Produktsprache „soll ich das für dich
  eintragen?“ und trägt es bei Ja selbst ein (#24, 2026-10-08: „ich mache so etwas nicht. Das ist mir viel zu technisch!“).
- **Server und Infrastruktur** (`henemm/henemm-infra`, der Dienst unter `loose-ends.henemm.com`) erledigt Claude
  selbst; keine Übergabe an eine andere Sitzung, kein Warten auf sie (2026-11-03: „Infra ist Claude Code. Mehr nicht.“).
- **Gabelungen im Ablauf** (welches Ticket zuerst, ob ein nicht reproduzierter Fehler geschlossen wird, wo Arbeit
  läuft, mehrdeutige Ticketnummer) entscheidet Claude und nennt die Entscheidung in einem Satz.
- **Ausnahmen, bei denen Henning selbst handeln muss**, sind nur solche, die an seinem Konto oder Gerät hängen: die
  Anmeldung (Passkey) in der CloudKit Console, Rückmeldung zu einem TestFlight-Bau, Einreichen bei Apple nur auf sein Wort.

## Fragen

- Nur Produktfragen: Features, Bedienung, Priorität, Umfang. Technik entscheidet Claude.
- Immer über `AskUserQuestion`, auch Rückfragen nach seiner Antwort; die Empfehlung steht zuerst und ist begründet.
- **Keine Frage ohne Kontext** (#648, 2026-10-26: „Hol mich ab, bevor du mir Fragen stellst“): vorher ein
  geschlossener Block in Alltagssprache ohne Dateinamen und Werkzeugausgaben: worum es geht, welches Problem es löst,
  was sich für ihn sichtbar ändert, was Claude herausgefunden hat, was genau er entscheiden soll. Sagt er „mir fehlt
  Kontext“, wird nur erklärt, ohne neue Frage im selben Zug.
- Jede Rückfrage nennt ihren Zweck (#203: „warum willst du das wissen?????“).
- Eine direkte Frage von ihm wird zuerst direkt und vollständig beantwortet, erst danach höchstens eine Rückfrage
  (#25, 2026-10-17: „Beantworte meine Frage!!!!!“).
- Auf „status?“: zuerst „Du musst nichts tun“ oder „Du bist dran: …“, dann ein Satz, worauf Claude wartet. Kein
  Ausblick auf spätere Schnitte (#705).
- Seine ausdrückliche Bestätigung („geht“, „habe ich gesehen“) ist die Abnahme. Widerspricht die Aktenlage, wird er
  konkret nach seiner Beobachtung gefragt, nie ein Bau angestoßen, um sie nachzuholen (#377, #402).
- Workflow-Freigaben (`go`, `approved`, …) zählen nur getippt, nicht als Auswahlantwort; der Hook
  `phase_listener` des Plugins sieht nur Prompt-Nachrichten. Je Nachricht steht genau ein Befehl: der Pflicht-Schritt
  des aktiven Workflows (#402/#405: „das ist Chaos!“).

## Keine manuellen Tests für Henning

Fertig heißt: das Feature funktioniert beweisbar, nicht „Code geschrieben“. Unit- und UI-Tests sind Pflicht, die App
wird im Simulator als Nutzer bedient (`./scripts/sim.sh test-proof`). Henning ist nie der Prüfstand.

- Nie „bitte testen“, „bitte auf dem Gerät prüfen“ oder „was hast du gesehen?“ als Ersatz für eigene Prüfung
  (2026-09-20: „Das kannst du sicherlich … feststellen, ohne mich zu benutzen.“).
- Belege werden angesehen, nicht gezählt: jedes Nachweisbild wird geöffnet und beschrieben, bevor ein Haken gesetzt
  wird. Eine Zusicherung auf Teilzeichenfolge (`CONTAINS "Garden"` gegen „Garden, Garten, Garden“) ist kaputt (#153).
- Jeder übersprungene Test wird einzeln mit Grund benannt; ein Schutz, der nirgends läuft, ist eine Lücke mit eigenem
  Issue (#409 → #419).
- Vor jeder Bitte um seine Zeit am Gerät sind Recherche, Code und Simulator ausgeschöpft (#24), und alles ist fertig
  gebaut: der Lauf beginnt mit der Nachricht, die ihn ruft (#274: „… und ich auf dich warte, merke dir das!!!!!“).
- „Hochgeladen“ heißt: dort sichtbar, wo er sucht (#772). Was er nicht findet, ist nicht erledigt.

## Seine Geräte

Nichts auf seinen Geräten (iPhone, iPad, Watch, Mac als Zielgerät), auch nichts Lesendes wie `device-status`, bevor er
wörtlich „jetzt ist ein Test möglich“ geschrieben hat, und dann nur für diesen einen Durchgang (#22, 2026-10-08). Eine
Ankündigung ist keine Frage, eine Spec oder Gerätestufe keine Dauererlaubnis. Nie eine App auf seinem iPhone
fernstarten; Prüfbauten tragen eine eigene Kennung und ersetzen nie seine Installation (#153, #156). Sein iPhone ist sein
Alltagsgerät: Messungen laufen in Scheiben in der Labor-App, die er selbst antippt. Der Simulator ist frei.

## Fehler

1. **Recherche zuerst**, vor Nachstellen und Theorie: wörtliche Fehlermeldung mit Domäne und Code, Stand der
   Schnittstelle in der Zielversion, Apples Doku und WWDC, Fallberichte. Ergebnis mit Quellen an Henning
   (2026-09-19: `kLSRErrorDomain 300` — eine Suche gegen Stunden von Theorien).
2. **„Hat es bisher funktioniert, seit welchem Stand, wo (Xcode oder TestFlight)?“** vor der Ursachensuche, aus
   Ticket und Verlauf beantwortet, wo möglich. Eine Verschlechterung grenzt die Suche auf die Änderungen seit dem
   letzten guten Stand ein (#121).
3. **Nachstellen auf seinem Weg**, nicht über einen anderen Bau. Ist der Zustand schon repariert, in einer
   Wegwerf-Kopie wiederherstellen.
4. **Sein Symptom ist Datenlage**: wörtlich nehmen, nicht zu einem anderen Fehler ausweiten (2026-09-19).
5. Fix beweisen: derselbe Ablauf, der eben den Fehler zeigte, zeigt ihn nicht mehr. Vor einem Ticket, das einen
   funktionierenden Weg ersetzt, belegen, dass der bisherige Weg weiter funktioniert (#25).

## Planung und Umfang

- **Einstieg immer über `/00-intake #N`**; `/00-bug` und `/01-feature` sind kein Einstieg mehr (2026-10-08). Jede Phase
  über ihren Slash-Befehl; Gates nie per `workflow.py set-field` oder über Bash an gesperrten Dateien vorbei öffnen.
  Blockiert ein Wächter, ist die Antwort final; Umformulieren, damit er es nicht sieht, ist verboten.
- Reine Test-, Werkzeug- und Store-Bild-Arbeit ohne Produktcode läuft ohne Workflow (#742, #772).
- **Zuerst lesen, was in Bearbeitung ist** (2026-10-26): Board-Spalten „In progress“/„In review“, offene PRs,
  `git log origin/main -S'#N'`, `gh pr list --search "#N" --state all`. Parallele Sitzungen haben dasselbe Ticket schon
  doppelt gebaut (#368, #334). Eine Sitzung bearbeitet einen Epic (`scripts/next-ticket.sh`).
- **Regeln vor Modell** und **in Alternativen denken**: siehe `CLAUDE.md`, „Rules before the model“. Jede Analyse
  nennt mindestens eine echte Alternative und die ADR, die dafür fiele; getroffene Entscheidungen sind Arbeitsstand.
- **Entwurf vor Spec** bei sichtbaren Änderungen (2026-09-22): veröffentlichte Vorschau mit Screenshot „Heute“ neben
  „Entwurf“ in den echten Farben, Hell und Dunkel, mindestens eine Alternative. Alternativen unterscheiden sich in
  Farbwelt, Schrift und Haltung, nicht nur im Layout (#408). Ablage `docs/artifacts/<workflow>/`.
- **Umfang je Schnitt** 4–5 Dateien, ±250 LoC, Funktionen ≤ 50 Zeilen. Tests in Server-Schnitten sind regelmäßig
  2,5–4× so lang wie der Code; nach dem RED-Schritt zählen und bei Überschreitung vor dem Bauen fragen.
- **Folgearbeit bündeln** nach gemeinsamem Ziel, ein Issue je Ziel mit eigener Definition of Done (#172).
- **„Nicht mehr“ heißt schließen**: `gh issue close --reason "not planned"` mit Begründung und Datum, samt Epic, wenn
  es dessen letztes Teil war; ans Boardende schieben reicht nicht (#30).
- **Termine merkt sich Claude**, nicht Henning (#796): Auslöser gefahrlos vorziehen und die Abweichung im Beleg nennen,
  sonst den Schritt mit Datum im Issue festhalten und selbst nachholen.
- Ein dauerhafter Test prüft nie `git diff origin/main` (flacher CI-Checkout, nach dem Merge leer); Dateigrenzen
  werden einmalig in `/60-validate` belegt (#621).

## Eigenheiten des Workflows (`agent-os-openspec`)

- ACs in Specs nur als `- **AC-N:** …`, sonst erkennt die Gegenprüfung sie nicht (#336).
- Ein Abschnitt „## Architektur-Entscheidung (ADR)“ braucht die Zeile `- **ADR-Nr.:** ADR-<n>` oder
  `- **ADR-Nr.:** keine — <Grund>`, sonst verfällt die Freigabe still (#165).
- Gerätepunkte (TestFlight, Hennings Rückmeldung) und Schritte nach dem Merge gehören in die Definition of Done, nie in
  ein AC: das QA-Gate kennt keinen Aufschub (#319, #341, #842).
- Mehrere Schnitte → je Schnitt eine Teil-Spec und ein Workflow (#368).
- Eine freigegebene Spec ändern: zurück nach `phase3_spec`, Spec und Briefing neu, neue getippte Freigabe; `override`
  öffnet den Spec-Freeze nicht (#439).
- `workflow.py` kennt kein `--help`: ein Unterbefehl nimmt jedes Argument als Wert und setzt ihn sofort.
- Das Gegenprüfungsprotokoll braucht `### Runde N` (mindestens zwei), nur `- [x]`-Punkte und `**VERIFIED**` fett unter
  `## Verdict`; es darf höchstens 60 Minuten alt sein.
- Kein Force-Push: liegt ein gepushter Zweig hinter `main`, wird `main` hineingeführt, nicht umgeschrieben.
