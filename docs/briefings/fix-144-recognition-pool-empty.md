---
spec_file: docs/specs/enrichment/fix-144-recognition-pool-empty.md
spec_sha256: b97354d72f3150775537247e047ee316d58aeb507a073fc82fd360f7a8838280
---

# PO-Briefing: fix-144-recognition-pool-empty

- **Spec:** docs/specs/enrichment/fix-144-recognition-pool-empty.md
- **Issue:** #144
- **Erstellt:** 2026-09-28

## Was gebaut wird

Eine zweite, wortgleiche Aufgabenerfassung übernimmt künftig Dauer und Kontext der ersten auch ohne Apple Intelligence oder nach einem fehlgeschlagenen Modellaufruf — bisher nie.

## Was das Ticket wollte und was die Spec daraus macht

Das Ticket stellt unter „Zu entscheiden (Alternativen, nicht vorweggenommen)" drei Lösungswege wörtlich zur
Wahl: (1) den Modell-Vermerk nach dem Regelschritt setzen — vom Ticket selbst verworfen, weil das
mit ADR-4 kollidiert und zwei Vermerke statt einem bräuchte; (2) einen eigenen Vermerk „Regeln sind
gelaufen" (`rulesAppliedAt`) — vom Ticket als „sauberer gegenüber ADR-4" eingeordnet; (3) die
Vergleichsmenge anders schneiden, über einen gesetzten Wert statt über einen Zeitstempel — vom
Ticket mit „die Bedeutung der Menge verschiebt sich" kommentiert. Der Ticket-Text schreibt trotz der
Überschrift „nicht vorweggenommen" bereits: „Option 2 sieht heute am ehesten tragfähig aus, weil sie
ADR-4 nicht aufweicht."

Die Spec wählt exakt Option 2. **Urteil: passt zum Ticket und geht über dessen Vermutung hinaus.**
Sie deckt sich mit der im Ticket genannten Neigung, begründet die Wahl aber zusätzlich mit
konkreten Testzeilen statt nur mit der Tragfähigkeits-Vermutung: Option 1 würde laut Spec sechs
benannte Prüfungen brechen, Option 3 eine bestehende Zusage aus der #136-Spec direkt kippen. Belegt,
nicht nur behauptet.

Zum Ticket-Abschnitt „Warum die 24 Tests aus #136 das nicht gefangen haben" (bestehende Tests setzen
`processedAt` über die Hilfsfunktion `makeProcessed` von Hand, statt den echten Weg zu prüfen): Die
beiden im Ticket zitierten Reproduktionstests laufen über den echten `processPending()`-Pfad ohne
diesen Kurzschluss; `makeProcessed` taucht im Testplan nur für ein bewusst simuliertes
Altbestand-Szenario auf (AC-4), nicht zur Fehlerverschleierung. Die im Ticket wörtlich zitierten
Fehlermeldungen und Fundstellen (`EnrichmentTests.swift:724/725/744`, `EnrichmentWriter.swift:94`,
`recognitionInputs`) stimmen mit den in der Spec genannten Zeilen überein — keine Abweichung
gefunden.

Der Korpus-Beleg (Ticket-Haken 3) hat sich über drei Briefing-Durchgänge entwickelt: erst fehlte er
ganz, dann kam ein Zahlenbeleg mit Registrierungspflicht dazu, jetzt wird die Belegdatei ausdrücklich
maschinell aus dem Lauf erzeugt (Zeitstempel, Commit-Kennung, Testzahlen und Messzahlen kommen alle
aus echten Kommandos, nichts wird getippt) — und die Spec benennt selbst offen, wo die Erzwingung
dieses Mechanismus endet. Details dazu unter „Abgleich" und den Anmerkungen.

Die Spec ändert weiterhin zusätzlich eine ältere Spezifikation (#136) mit. Das Ticket verlangt in
seiner DoD nur eine ADR-Entscheidung, keine Änderung an der #136-Spec. **Urteil unverändert:
sachlich naheliegend, aber wörtlich mehr, als das Ticket verlangt** — ohne die Änderung würde die
alte Formulierung „Pool enthält nur bereits verarbeitete Aufgaben" der neuen Vergleichsmenge
widersprechen; trotzdem ein Umfang, der über den wörtlichen Ticket-Haken hinausgeht.

## Definition of Done

Fertig, wenn die Wiedererkennung auch ohne Apple-Intelligence-Modell greift, gezeigt in Tests, Simulator, maschinell erzeugter Korpus-Messung und auf Hennings iPhone.

### Abgleich mit den fünf Ticket-Haken (im Wortlaut)

1. „Die beiden Tests in `RecognitionPoolReachabilityTests` sind grün, ohne dass sie abgeschwächt
   wurden" — **abgedeckt.** Selbst am Testcode geprüft: Ein Test bleibt wörtlich unverändert, der
   zweite wechselt nur das geprüfte Feld, die Zahlenaussage (3 Aufgaben) bleibt gleich. Die Spec
   erklärt die dafür nötigen Zusatztests (AC-4, AC-5) ausdrücklich zur Pflicht.
2. „Die App im Simulator ... zeigt den Ablauf ... durchgespielt, nicht nur gebaut" —
   **abgedeckt** durch den geplanten UI-Test mit Bildbeleg je Schritt, als Artefakt registriert.
3. „`./scripts/sim.sh unit` grün, Korpus-Messung echt gelaufen" — **abgedeckt, mit einer offen
   benannten und angemessen begrenzten Restlücke.** Die Belegdatei wird jetzt maschinell erzeugt:
   Zeitstempel aus `date`, Commit-Kennung aus `git rev-parse HEAD`, Testzahlen aus der
   `xcodebuild.log`-Zusammenfassung, Messzahlen aus den Berichten, die der Lauf selbst schreibt —
   kein Wert wird von Hand eingetragen. Das erfüllt die CLAUDE.md-Bedingung „entsteht aus einem
   echten Lauf … darf niemals von Hand gesetzt werden" auf der Ebene der *Werterzeugung*. Was die
   Spec selbst offen benennt (neuer Unterabschnitt „Grenze dieses Mechanismus"): Die
   *Registrierung* dieser Datei prüft weiterhin nicht, ob sie wirklich zum aktuellen Stand gehört —
   das bleibt bis zur allgemeinen Lösung in #145 (Schnitt 2, dort inzwischen um Messbelege
   ergänzt) unerzwungen. Ich teile diese Einschätzung nach eigener Prüfung des Werkzeugcodes.
4. „Entscheidung zwischen den Alternativen in einem ADR festgehalten, falls ADR-4 berührt wird" —
   **abgedeckt**, eigener Abschnitt „Architektur-Entscheidung (ADR)" mit Ergänzungstext für ADR-4.
5. „Gelaufen auf Hennings iPhone" — **abgedeckt**, als Teil der drei Abnahmestufen in der Spec-DoD.

## Wie geprüft wird

Automatisierte Tests, eine maschinell erzeugte Korpus-Messung und ein bebilderter Simulator-Durchlauf zeigen die Werteübernahme; ob der Beleg zum aktuellen Stand passt, prüft das Werkzeug noch nicht automatisch.

## Kritische Anmerkungen

1. Der Korpus-Beleg wird jetzt maschinell erzeugt statt getippt — ob er zum aktuellen Stand passt,
   bleibt bis #145 unerzwungen; das ist eine bewusste Restrisiko-Entscheidung für Henning, keine
   offene Lücke der Spec.
2. Die Spec ändert zusätzlich eine ältere Spezifikation (#136) mit, obwohl der Ticket-Haken nur eine
   ADR-Entscheidung verlangt — sachlich naheliegend, aber mehr als wörtlich gefordert.

### Vertiefung

1. **Trägt die maschinelle Erzeugung als Zwischenlösung?** Ja. Sie schließt die triviale Lücke (Zahlen
   frei erfinden) vollständig, weil Zeitstempel, Commit-Kennung und Testzahlen aus echten
   Kommandoausgaben stammen müssen, um in diesem Format zusammenzupassen. Offen bleibt nur die
   *aktive Prüfung* dieser Werte gegen den Stand zum Zeitpunkt der Freigabe (ein Registrier-Befehl,
   der eine ältere, aber technisch gültige Datei erneut einreicht, würde nicht auffallen). Das ist
   ein anderes, deutlich kleineres Risiko als vorher — kein „ich behaupte es einfach", sondern
   „ich müsste einen alten, echten Lauf wiederverwenden". Ich halte #144 damit nicht für auf einem
   unbelegten Nachweis abgeschlossen — der Nachweis ist belegt, nur (noch) nicht automatisch
   gegengeprüft.
2. **Ist die Verschiebung nach #145 sauber abgegrenzt?** Ja. Eine Prüfsumme, die Artefakt-Inhalt und
   aktuellen Stand automatisch abgleicht, ist eine Änderung am gemeinsamen Workflow-Werkzeug, nicht
   an der Wiedererkennungs-Logik dieses Tickets — sie träfe den Simulator-Beleg genauso wie den
   Korpus-Beleg. Eine Einzellösung nur für #144 würde entweder den Umfang dieses Bugfixes sprengen
   (Änderung an gemeinsamer Infrastruktur statt an vier Dateien) oder eine Sonderbehandlung nur für
   einen Artefakt-Typ schaffen, während der Simulator-Beleg weiter unerzwungen bliebe — inkonsistent
   gegenüber der bereits vorgeschlagenen, typübergreifenden Lösung in #145. Die Verschiebung schiebt
   also keine Arbeit weg, die zu #144 gehört; sie vermeidet eine doppelte, inkonsistente Umsetzung.
3. **#136-Spec wird mitgeändert.** Der Ticket-Haken 4 verlangt wörtlich nur eine ADR-Entscheidung
   „falls ADR-4 berührt wird". Die Spec geht weiter und passt zusätzlich eine Acceptance Criterion
   einer anderen, bereits abgenommenen Spec an. Sachlich folgerichtig (sonst widersprächen sich zwei
   gültige Spec-Texte), aber ein Umfang, den das Ticket nicht wörtlich verlangt hat.

## Was bewusst draußen bleibt

- Das Feld „Energie" bleibt unverändert außen vor (eigener Architektur-Entscheid, ADR-5).
- Die Titel-Erkennung bleibt beim Sprachmodell, weil sie echtes Sprachverstehen braucht.
- `RecognitionRule` selbst wird nicht angefasst — die Korpus-Messung dient als Regressionsbeleg, nicht
  als Test von etwas Neuem.
- Ein bei der Untersuchung gefundener, unabhängiger Fehler bei der Kontext-Vorbelegung ist bereits
  als eigenes Ticket (#146) vorgemerkt und wird hier ausdrücklich nicht mitgelöst.
- Die automatische, kryptografische Prüfung von Belegen gegen den aktuellen Stand bleibt #145
  vorbehalten — bewusst nicht Teil dieses Bugfixes, siehe Vertiefung.

## Empfehlung

Freigeben — mit einer Produktentscheidung, die Henning bewusst treffen soll: Er akzeptiert, dass der Korpus-Messbeleg bis zur allgemeinen Prüf-Erzwingung in #145 maschinell erzeugt, aber nicht automatisch gegengeprüft wird — oder er lässt #144 auf #145 warten. Beides ist vertretbar, die Entscheidung gehört ihm.
