# Adversary Dialog -- bundle-id-debug-156

Massstab: docs/specs/tooling/fix-156-pruefkennung.md. Arbeitsverzeichnis:
/Users/hem/Developer/loose-ends/.claude/worktrees/valiant-prancing-knuth.

### Runde 1

Spec vollstaendig gelesen (AC-1 bis AC-6, Schritt 0, Risiken, DoD). Produktivcode-Diff gegen den
Basis-Stand gelesen (project.yml, Shared/Persistence/ModelContainerFactory.swift, scripts/sim.sh,
.github/workflows/probe-build.yml, .github/workflows/testflight.yml, docs/project/00-entscheidungen.md,
docs/reference/testflight.md, LooseEndsTests/ModelContainerFactoryTests.swift) -- alles im Index,
unkommittiert. Das required-files-Werkzeug (Basis 2adb569) liefert nur
Shared/Persistence/ModelContainerFactory.swift, weil der Rest nur vorgemerkt, nicht committet ist;
deshalb selbst nachgesehen (vorgemerkte Aenderungen) und alle oben genannten Dateien als pruefrelevant
behandelt.

Eigener, unabhaengiger Testlauf (nicht nur die vorgelegten Artefakte uebernommen):
./scripts/sim.sh unit selbst ausgefuehrt (nicht die vorgelegte full-unit-summary.txt geglaubt) --
235 Tests, 0 Fehlschlaege, Suite "Model container identifiers" 4/4 gruen (readsBothKeys,
fallsBackWithoutDictionary, mixedCase, standardBuildKeepsProductionIdentifiers). Output gesichert unter
docs/artifacts/bundle-id-debug-156/adversary-unit-run.txt. Danach docs/reference/date-title-fidelity.md
(vom Lauf ueberschrieben) zurueckgesetzt, wie die Projektkonvention verlangt -- docs/reference/ ist
jetzt wieder sauber bis auf das ohnehin vorgesehene testflight.md.

Eigener Simulator-Build+Launch (Stufe 2), nicht nur den vorgelegten Screenshot geglaubt: das Projekt
selbst neu erzeugt (xcodegen generate) -- der Stand der Arbeitskopie zeigt danach keine weitere
Differenz an Info.plist/Entitlements gegenueber dem bereits vorgemerkten Stand (reproduzierbar, kein
Drift). ./scripts/sim.sh build (Exit 0, "Build Succeeded"), danach die vier generierten Plists direkt
mit plutil -p aus dem gebauten Produkt gelesen (nicht aus der Quelle project.yml):

| Ziel | CFBundleIdentifier | CFBundleDisplayName | LEAppGroup | LECloudContainer |
|---|---|---|---|---|
| LooseEnds.app | com.henning.looseends | Loose Ends | group.com.henning.looseends | iCloud.com.henning.looseends |
| LooseEndsWatch.app | com.henning.looseends.watchkitapp | Loose Ends | group.com.henning.looseends | iCloud.com.henning.looseends |
| LooseEndsWidgets.appex | com.henning.looseends.widgets | Loose Ends Widgets | group.com.henning.looseends | iCloud.com.henning.looseends |
| LooseEndsShare.appex | com.henning.looseends.share | Loose Ends | group.com.henning.looseends | iCloud.com.henning.looseends |

Das sind die tatsaechlich vom Build-System aufgeloesten Werte (nicht die unaufgeloeste
$(BUNDLE_ID_SUFFIX)-Schreibweise der Quelle) -- der Standardbau ist bitgleich zu heute, zusaetzlich die
zwei neuen Schluessel additiv vorhanden. Danach ./scripts/sim.sh launch (Exit 0, "App gestartet
(com.henning.looseends)", PID zurueckgemeldet, kein Absturz) und ein eigener Screenshot
(docs/artifacts/bundle-id-debug-156/adversary-sim-launch.png) -- zeigt die App unter dem Titel
"Loose Ends" laufend, identisch zum vorgelegten sim-launch.png.

- [x] AC-1: Standardbau bitgleich. Eigener Build + plutil -p auf den gebauten Produkten (Tabelle oben)
  zeigt PRODUCT_BUNDLE_IDENTIFIER, App-Gruppe, iCloud-Container, CFBundleDisplayName fuer alle vier
  Ziele unveraendert zu heute; LEAppGroup/LECloudContainer sind neue, zusaetzliche Schluessel mit
  denselben Werten wie die bisherigen hart kodierten Konstanten. WKCompanionAppBundleIdentifier im
  gebauten Watch-Plist = com.henning.looseends, unveraendert. Einschraenkung (bereits vom
  Implementierer selbst in built-values.txt benannt, hier bestaetigt): der Simulator-Build ist
  unsigniert, es existiert keine .xcent-Datei -- der Entitlements-Vergleich stuetzt sich auf die von
  xcodegen erzeugte Entitlements-Quelldatei (generated-diff.txt, additiv, keine Entfernung), nicht auf
  ein tatsaechlich aufgeloestes, signiertes Entitlement. Das ist dieselbe Variablensubstitution
  ($(BUNDLE_ID_SUFFIX)), die im Info.plist nachweislich korrekt aufloest (Tabelle oben) -- ein
  Restrisiko, aber kein Fund, der AC-1 widerlegt.
  Code reference: project.yml:31-32,50-52,63-67,91
- [x] AC-2: Unit-Test gruen, Rueckfall geprueft. Eigener Lauf (nicht nur das vorgelegte Artefakt):
  4/4 gruen, darunter explizit fallsBackWithoutDictionary (liefert group.com.henning.looseends /
  iCloud.com.henning.looseends bei nil) und mixedCase (ein Schluessel vorhanden, der andere faellt
  zurueck). Voller Regressionslauf 235/235 gruen, keine Fehlschlaege in irgendeiner anderen Suite.
  Code reference: LooseEndsTests/ModelContainerFactoryTests.swift:7-38
  Code reference: Shared/Persistence/ModelContainerFactory.swift:19-29
- [x] AC-3: Simulator unveraendert (Stufe 2). Eigener Build+Launch (oben), Bundle-ID
  com.henning.looseends, kein Absturz, eigener Screenshot zeigt denselben Zustand wie das vorgelegte
  sim-launch.png.
  Code reference: scripts/sim.sh:176-181,225-235
- [x] AC-4: Geraetebau installiert isoliert (Stufe 3). STAND RUNDE 1: Laut Auftrag ausdruecklich NICHT als erbracht zu
  behandeln: der signierte Pruefbau in der Cloud-CI braucht einen gesicherten (committeten) Stand, der
  erst nach diesem Verdict entsteht. Der aktuelle Stand (nur die RED-Tests committet) traegt die
  eigentliche Aenderung noch nicht -- ein Hochladen jetzt wuerde den falschen Stand bauen.
  apps-after.txt oder ein Vergleichsscreenshot existieren nicht. Code-Review des Mechanismus in Runde 2.
  INZWISCHEN UEBERHOLT: der Cloud-Weg wurde verworfen (Runde 4), AC-4 ist ueber den lokalen Weg
  (Registrierungslauf + gespeicherte Profile) jetzt eigenstaendig bewiesen -- siehe Runde 4 fuer den
  vollstaendigen, unabhaengig nachgepruefte Beleg.
- [x] AC-5: ADR-18 dokumentiert. Gelesen in docs/project/00-entscheidungen.md:175-181, direkt nach
  ADR-17 und vor "## Bewusst nicht in Version 1" wie von der Spec verlangt. Nennt #156 und die
  Spec-Datei.
  Code reference: docs/project/00-entscheidungen.md:175-181
- [x] AC-6: Release/TestFlight unveraendert. Vergleich des Workflows .github/workflows/testflight.yml
  gegen den Basis-Stand liefert keine Ausgabe -- die Datei ist seit dem Basis-Commit byte-identisch.
  Volltextsuche nach BUNDLE_ID_SUFFIX in der Datei: kein Treffer (bestaetigt testflight-grep.txt
  unabhaengig nachvollzogen).
  Code reference: .github/workflows/testflight.yml:1-125

Erste Runde: 5 von 6 AC eigenstaendig nachgewiesen (nicht nur die vorgelegten Artefakte uebernommen,
sondern Build, Test und Screenshot selbst reproduziert). AC-4 bleibt wie angewiesen offen. Runde 2
prueft den AC-4-Mechanismus durch Code-Lesen (ohne ihn auszufuehren), sucht nach Regressionen in
scripts/sim.sh und prueft Edge Cases (Nebenlaeufigkeit, Fehlerpfade, Aufrufer von
appGroup/cloudContainer).
### Runde 2

Mit Misstrauen gegen das eigene Ergebnis aus Runde 1 (vorschnelle Konvergenz vermeiden): erneut jede
Aufrufstelle von ModelContainerFactory.appGroup/.cloudContainer gesucht, um sicherzustellen, dass der
Umbenennungs-Umbau (Konstante -> berechnete static let mit gleichem Namen) keinen Aufrufer unbemerkt
bricht. Treffer ausschliesslich innerhalb von ModelContainerFactory.swift selbst (Methode make()) --
keine externen Aufrufer lesen die beiden Properties direkt, sie kommen nur ueber make() ins Spiel. Kein
Regressionsrisiko: alle Aufrufer von make() (App, Watch, Widgets, Share, CaptureTextIntent) bleiben
unveraendert, weil make() selbst nicht umgebaut wurde (Zeile 65-91 unveraendert, bestaetigt per Diff in
Runde 1).

Code-Lese-Pruefung des AC-4-Mechanismus (scripts/sim.sh:271-317, .github/workflows/probe-build.yml),
ohne ihn auszufuehren (kein Hochladen erlaubt):

1. cmd_device_build (sim.sh:310-314) ruft ci_device_app app LooseEnds -- keine eigene
   Geraete-Pruefung mehr vorher. Regression gegenueber heute: die VORHERIGE Fassung begann mit
   "local id; id=$(require_device) || return 1" (sichtbar im Diff aus Runde 1) und schlug sofort fehl,
   wenn kein iPhone verbunden war. Die neue Fassung prueft das Geraet gar nicht mehr vor dem Hochladen
   -- sie sichert den Pruefzweig, wartet auf den vollstaendigen Cloud-Lauf (Minuten), laedt das
   Artefakt herunter und entpackt es, bevor cmd_device_install (Zeile 320) ueberhaupt require_device
   aufruft und erst dann merkt, dass kein Geraet verbunden ist. Derselbe Effekt trifft cmd_lab (Zeile
   372-373: ci_device_app lab ... vor require_device in Zeile 374). Das ist kein Verstoss gegen eine
   der sechs AC (keine davon verlangt eine Geraete-Vorpruefung in device-build selbst), aber eine
   echte, im Diff sichtbare Verhaltens-Regression: ein versehentlicher Aufruf ohne verbundenes iPhone
   kostet jetzt einen vollen, signierten Cloud-Lauf statt eines sofortigen, kostenlosen Fehlschlags.
2. ci_fetch_app (sim.sh:291-308): wartet bis zu 60s (12 x 5s) auf das Erscheinen des Workflow-Laufs.
   Bei einer langsameren Warteschlange des CI-Dienstes koennte das zu kurz sein und faelschlich "Kein
   Pruefbau-Lauf gefunden" melden, obwohl der Lauf nur verspaetet erscheint -- ein Robustheits-, kein
   Korrektheitsproblem (kein AC verlangt eine Mindestwartezeit).
3. Zweig-Aufraeumen (sim.sh:285-287): das Loeschen des Pruefzweigs wird fehlertolerant behandelt, und
   zwar sowohl im Erfolgs- als auch im Fehlerfall (Zeile 284-287 liegt ausserhalb der Fallunterscheidung
   von rc) -- kein Leck offener Pruefzweige bei einem fehlgeschlagenen Lauf, wie im Kommentar
   versprochen. Selbst nachvollzogen: ja, der Code tut das.
4. probe-build.yml Trigger (Push auf Zweige probe/**, Zeile 11-13) + Scheme-Auswahl aus dem
   Zweig-Namen (Zeile 31-40) + bedingte extras=("BUNDLE_ID_SUFFIX=.probe" "LE_DISPLAY_NAME=LE
   Pruefbau") nur fuer KIND=app (Zeile 77-78): bash-Array-Syntax korrekt, Bedingung korrekt --
   probe/lab/<sha> bekommt keine Kennungs-Ueberschreibung (korrekt, LooseEndsLab hat laut project.yml
   ohnehin keine App-Gruppe/kein CloudKit, Zeile 209 unveraendert).
5. Die Sicherungs-Pruefung vor dem Hochladen (sim.sh:280, Status der Arbeitskopie mit Ausschluss von
   .claude): korrekt formuliert und selbst nachvollzogen -- der aktuelle Stand der Arbeitskopie ist
   ungleich leer wegen der vorgemerkten Aenderungen dieses Tickets, genau der Grund, warum AC-4 jetzt
   nicht ausfuehrbar ist, wie im Auftrag vorgegeben.
6. cmd_device (Zeile 344, kombiniert build+install+launch) existiert weiterhin unveraendert. Das
   verstoesst nicht gegen AC-4 -- AC-4 verlangt nur, dass der NACHWEIS diesen Befehl nicht benutzt
   (er wurde in dieser Pruefung nicht aufgerufen), nicht dass der Befehl selbst entfernt wird.

Kein Treffer fuer einen Fehler, der eine der sechs AC widerlegt. Ein echter, aber nicht blockierender
Regressions-Fund (F001) zu AC-4s Vorfeld.

Zweite, unabhaengige Pruefung der Testabdeckung (Edge Cases): resolveIdentifiers ist eine reine
Funktion ohne Bundle-Zugriff -- Grenzwerte geprueft: leeres Dictionary [:] vs. nil -- beide Pfade
verhalten sich laut Code identisch (infoDictionary?["key"] as? String liefert in beiden Faellen nil),
nur nil ist per Test abgedeckt, [:] nicht separat, aber der Code-Pfad ist exakt derselbe (kein
Sonderfall fuer leeres vs. fehlendes Dictionary) -- kein Fund. Typ-Fehlfall (Wert vorhanden, aber kein
String, z. B. eine Zahl) nicht separat getestet, faellt aber durch as? String ebenfalls auf
nil/Fallback zurueck -- dasselbe Verhalten, kein Fund.

Finding F001:
  ID: F001
  Severity: MEDIUM
  Category: regression
  Code reference: scripts/sim.sh:310-314 (cmd_device_build), scripts/sim.sh:372-374 (cmd_lab),
    scripts/sim.sh:258-262 (require_device)
  Description: Die bisherige cmd_device_build pruefte ein verbundenes iPhone (require_device) VOR dem
    eigentlichen Bauen und schlug ohne Geraet sofort fehl. Die neue Fassung ruft ci_device_app ohne
    vorherige Geraete-Pruefung auf: sie sichert den Arbeitsbaum, sichert den Pruefzweig, wartet auf den
    vollstaendigen signierten Cloud-Lauf (mehrere Minuten) und laedt das Artefakt herunter, bevor
    ueberhaupt geprueft wird, ob ein iPhone verbunden ist (das passiert erst in cmd_device_install,
    Zeile 320). Derselbe Aufbau in cmd_lab (Zeile 372-374).
  Spec requirement: Keine der sechs AC verlangt eine Geraete-Vorpruefung in device-build selbst --
    dies ist kein AC-Verstoss, sondern eine im Diff sichtbare Verhaltensaenderung gegenueber dem
    bisherigen Skript, die die Spec nicht erwaehnt und nicht begruendet.
  Conflict: Ein versehentlicher Aufruf von device-build/lab ohne verbundenes iPhone kostet jetzt einen
    vollen, kostenpflichtigen, signierten Cloud-Lauf (CI-Minuten, Apple-Signierung) statt eines
    sofortigen, kostenlosen lokalen Fehlschlags wie bisher.
  Remediation: require_device an den Anfang von cmd_device_build und cmd_lab zuruecksetzen (vor
    ci_device_app), damit ein fehlendes Geraet weiterhin sofort und ohne Cloud-Lauf auffaellt.

Zweite Runde bestaetigt Runde 1 (kein AC durch die vertiefte Pruefung widerlegt) und findet einen
echten, aber nicht blockierenden Regressions-Fund (F001) ausserhalb der sechs AC. AC-4 bleibt wie
angewiesen unbewiesen -- kein Code-Fehler gefunden, der es widerlegen wuerde, aber auch kein Beleg, der
es bestaetigt (das in der Spec selbst als Risiko benannte Kernrisiko -- automatische Anlage des neuen
iCloud-Containers beim Signieren -- ist durch keinen Cloud-Lauf in dieser Session belegt und kann es
laut Auftrag auch nicht sein).

## VERDICT: AMBIGUOUS

Ambiguous findings (require human review):
  AC-4: Der Mechanismus (sim.sh:271-317, probe-build.yml) ist bei reiner Code-Lektuere in sich
  konsistent und frei von erkennbaren Fehlern, aber das von der Spec selbst als Risiko benannte
  Kernrisiko (automatische Registrierung von App-Gruppe UND iCloud-Container .probe durch
  -allowProvisioningUpdates beim Signieren in der Cloud-CI) ist durch keinen tatsaechlichen Lauf in
  dieser Session belegt -- weder durch mich (Hochladen/Geraetebefehle in diesem Auftrag ausdruecklich
  verboten) noch durch ein vorgelegtes Artefakt (kein apps-after.txt, kein Vergleichsscreenshot, kein
  gruener Lauf-Link). Der vorgelegte device-build-probe.txt zeigt nur den FEHLGESCHLAGENEN lokalen
  Versuch, der ueberhaupt erst zum Signieren in der Cloud gefuehrt hat -- er belegt das Risiko, nicht
  seine Behebung. Henning/das Team muss entscheiden, ob mit AMBIGUOUS fortgefahren wird
  (workflow.py override-ambiguous) und AC-4 erst nach dem anstehenden, erst nach diesem Verdict
  moeglichen Cloud-Pruefbau auf dem echten Geraet nachgewiesen wird, oder ob vorher noch gewartet wird.

Proven points: 5/6 (AC-1, AC-2, AC-3, AC-5, AC-6 CONFIRMED durch eigene Reproduktion; AC-4 AMBIGUOUS)
Tests: 235 gruen, 0 fehlgeschlagen (eigener Lauf,
docs/artifacts/bundle-id-debug-156/adversary-unit-run.txt), darunter 4/4 fuer die neue Suite "Model
container identifiers".
Edge cases: nil- vs. leeres Dictionary, Typ-Fehlfall in resolveIdentifiers pruefen denselben Codepfad
wie der getestete nil-Fall -- kein Fund. Nebenlaeufigkeit: appGroup/cloudContainer sind static let,
Swift garantiert einmalige, threadsichere Initialisierung -- kein Fund.
Regressions: F001 (MEDIUM, scripts/sim.sh) -- device-build/lab pruefen das Geraet nicht mehr vor dem
Cloud-Lauf, kostet im Fehlerfall einen vollen signierten Lauf statt eines sofortigen lokalen
Fehlschlags. Kein AC-Verstoss, aber ein echter Qualitaetsverlust gegenueber heute.
Checklist: 5/6 Punkte eigenstaendig bewiesen (Build, Test und Screenshot selbst reproduziert, nicht nur
vorgelegte Artefakte uebernommen), AC-4 nach den vorgegebenen Regeln nicht als bewiesen behandelt.
Recommendation: F001 vor dem Zusammenfuehren beheben (require_device zurueck an den Anfang von
cmd_device_build/cmd_lab). AC-4 entweder jetzt per override-ambiguous freigeben (mit der Einschraenkung,
dass der tatsaechliche Geraete-Nachweis erst nach dem Commit auf dem echten iPhone folgt -- das ist
ohnehin die einzige Reihenfolge, die der Workflow erlaubt) oder den Adversary-Lauf nach dem ersten
erfolgreichen Cloud-Pruefbau mit apps-before/apps-after-Vergleich wiederholen.

## Geprüfte Dateien

- sha256:f9d01628839c0ce3a1b6cd90aa3590864b3616960724e0a1fb101da092f36697  .github/workflows/testflight.yml
- sha256:254e8f235ddc3e69b811c6d57aa74d71285b68ec6f69a7c0882f5a965beefe3c  LooseEndsTests/ModelContainerFactoryTests.swift
- sha256:ad16fcaefe0903f466db79177cc2f6a2180c74e89910af265151faeb414dcd5b  Shared/Persistence/ModelContainerFactory.swift
- sha256:d7c7de20bfb3bb5c92823af680c5b42fa789bcf4f98fd50a867522fa92a1659b  docs/project/00-entscheidungen.md
- sha256:917c1e80d0d825261374ae30d449660a6ecd78c62deb67f7ca0f5e69926f2087  project.yml
- sha256:c14288ec501f4f71f0ab54d4000e55007572a604495476cde9a2eb334a698f20  scripts/sim.sh

### Runde 3

Kontext: Henning hat bei AMBIGUOUS entschieden, F001 zuerst zu beheben. Nachgereicht: in
scripts/sim.sh steht require_device jetzt als erste Anweisung in cmd_device_build (Zeile 310) und
vor ci_device_app in cmd_lab (Zeile 374). Diese Runde prueft den Fix mit Misstrauen -- nicht die
Selbstauskunft "sonst ist nichts geaendert" uebernommen, sondern selbst nachgerechnet.

Umfang der Aenderung selbst geprueft, nicht behauptet: der Stand der Arbeitskopie zeigt seit Runde 2
ausschliesslich scripts/sim.sh als neu veraendert (plus die bereits in Runde 1/2 bekannten,
unveraenderten Aenderungen an docs/briefings/bundle-id-debug-156.md und
docs/specs/tooling/fix-156-pruefkennung.md, die nichts mit F001 zu tun haben). Kein Produktivcode
ausserhalb von scripts/sim.sh angefasst -- project.yml, ModelContainerFactory.swift, alle
Info.plist/Entitlements-Dateien stehen unveraendert zum Stand von Runde 1/2 (bestaetigt: keine neue
Differenz). Die sim.sh-Aenderung selbst ist exakt zwei Zeilen: require_device wurde in
cmd_device_build neu eingefuegt (vor dem Aufruf von ci_device_app) und in cmd_lab von der zweiten an
die erste Stelle verschoben (ebenfalls vor ci_device_app). Keine weitere Zeile im ganzen Skript
veraendert.

1. Syntax-Pruefung: bash -n scripts/sim.sh laeuft ohne Ausgabe und mit Exit 0 -- die Umstellung hat
   keinen Syntaxfehler eingefuehrt.
2. Code-Pfad in cmd_device_build (Zeile 310-314): erste Zeile ist jetzt
   "require_device >/dev/null || return 1" -- bei einem Fehlschlag (leerer Rueckgabewert von
   device_id, das heisst: kein physisches, verbundenes und als "available" gemeldetes iPhone) bricht
   die Funktion per "|| return 1" sofort ab, BEVOR die Kommentarzeile und der Aufruf von
   ci_device_app (der Arbeitsbaum-Pruefung, Zweig-Sicherung und Hochladen durchfuehrt) ueberhaupt
   erreicht werden. Dieselbe Garantie in cmd_lab (Zeile 374): "local id; id=$(require_device) ||
   return 1" steht jetzt vor "ci_device_app lab LooseEndsLab" (vorher danach). Bash-Kurzschlussauswertung
   (||) und die Reihenfolge der Anweisungen in der Funktion belegen zusammen: kein Pfad durch
   ci_device_app ist mehr erreichbar, ohne dass require_device zuvor erfolgreich war.
3. require_device() selbst (Zeile 258-262) ruft device_id() (Zeile 245-253): wenn die Umgebungsvariable
   LOOSEENDS_DEVICE NICHT gesetzt ist, fragt device_id() xcrun devicectl list devices ab und liefert
   nur eine Zeile mit "physical" im Text UND einem Status ungleich "unavailable" zurueck -- sonst
   leer. require_device() meldet bei leerem Ergebnis "Kein verbundenes iPhone..." und gibt 1 zurueck.
   Das ist exakt der Pfad, der vor der Umstellung fehlte: vorher konnte cmd_device_build/cmd_lab bei
   fehlendem Geraet trotzdem bis zum Hochladen des Pruefzweigs vordringen (siehe F001, Runde 2).

Ausfuehrung der vorgeschlagenen Nachstellung bewusst NICHT durchgefuehrt -- aus zwei eigenstaendig am
Code und an der realen Umgebung geprueften Gruenden, beide fallen unter die vom Auftrag selbst erlaubte
Ausnahme ("sonst nur per Code-Review belegen"):

a) device_id() (Zeile 246) liest LOOSEENDS_DEVICE, FALLS gesetzt, OHNE jede Pruefung gegen eine
   Geraeteliste zurueck ("if -n LOOSEENDS_DEVICE; echo $LOOSEENDS_DEVICE; return"). Eine ungueltige
   ID wie 00000000-0000000000000000 wird damit NICHT abgelehnt -- require_device() haette Erfolg
   gemeldet und den ungueltigen Wert als "verbundenes Geraet" durchgereicht. Die vorgeschlagene
   Nachstellung haette also nicht den Abbruchpfad gezeigt, sondern den Erfolgspfad mit einer
   Phantom-ID, und waere bis zur Arbeitsbaum-Pruefung in ci_device_app vorgedrungen.
b) Ohne LOOSEENDS_DEVICE haette device_id() stattdessen die echte Geraeteliste abgefragt -- selbst
   schreibgeschuetzt ausgefuehrt (xcrun devicectl list devices, keine Installation, kein Start):
   das Ergebnis zeigt "Hennings iPhone 16 Pro" mit Status "available (paired)" und Reality
   "physical" -- sein echtes iPhone ist in dieser Umgebung gerade erreichbar. Ein Lauf ohne
   Override haette also sein echtes Geraet gefunden, require_device waere erfolgreich gewesen, und
   der Lauf waere ebenfalls bis ci_device_app vorgedrungen -- in direktem Widerspruch zum Auftrag
   ("nichts pushen") und zur Geraeteregel in CLAUDE.md. Fuer BEIDE Varianten der vorgeschlagenen
   Nachstellung gilt: require_device haette in dieser konkreten Umgebung NICHT abgelehnt, egal ob
   mit Phantom-Override oder ohne -- der Beleg bleibt deshalb regelkonform beim Code-Review.

Finding F001 aus Runde 2 gilt hiermit als behoben:

Confirmation:
  AC: F001 (Finding aus Runde 2)
  Code reference: scripts/sim.sh:310-314
  Code reference: scripts/sim.sh:371-378
  Evidence: require_device steht jetzt als erste Anweisung in cmd_device_build und vor ci_device_app
    in cmd_lab, belegt durch Diff-Vergleich (exakt zwei Zeilen veraendert, sonst nichts),
    bash -n scripts/sim.sh (Exit 0, syntaktisch fehlerfrei) und Code-Lektuere der
    Kurzschlussauswertung. Ein fehlendes Geraet (device_id() liefert leer) bricht beide Funktionen
    vor jedem Kontakt zu ci_device_app (Arbeitsbaum-Pruefung, Zweig-Sicherung, Hochladen) ab.
  Status: CONFIRMED

AC-4 bleibt unveraendert offen, wie vom Auftrag vorgegeben: kein neuer Geraete-Nachweis in dieser
Runde erbracht oder erwartet -- der tatsaechliche Gerate-Beleg folgt erst nach dem Sichern des Standes.
Kein neuer Fund gegen eine der sechs AC in dieser Runde.

## VERDICT: AMBIGUOUS

Ambiguous findings (require human review):
  AC-4: unveraendert gegenueber Runde 2 -- der Mechanismus ist bei Code-Lektuere weiterhin
  konsistent, das von der Spec selbst benannte Kernrisiko (automatische Registrierung des neuen
  iCloud-Containers beim Signieren) bleibt durch keinen tatsaechlichen Cloud-Lauf belegt. Henning muss
  entscheiden, ob mit AMBIGUOUS fortgefahren wird (workflow.py override-ambiguous) und AC-4 erst nach
  dem Sichern des Standes auf dem echten Geraet nachgewiesen wird.

Proven points: 5/6 unveraendert (AC-1, AC-2, AC-3, AC-5, AC-6 CONFIRMED; AC-4 AMBIGUOUS). F001 zusaetzlich
als behoben bestaetigt (Confirmation oben).
Tests: keine Swift-Testdatei in dieser Runde veraendert (nur scripts/sim.sh) -- kein erneuter
./scripts/sim.sh unit-Lauf noetig, der vorherige Stand (235 gruen, 0 fehlgeschlagen,
docs/artifacts/bundle-id-debug-156/adversary-unit-run.txt) bleibt gueltig.
Edge cases: Zwei moegliche Nachstellungswege der vorgeschlagenen Pruefung eigenstaendig durchdacht und
beide als in dieser Umgebung ungeeignet verworfen (Phantom-Geraet wird nicht abgelehnt; echtes,
gerade erreichbares iPhone von Henning waere gefunden worden) -- Beleg bleibt beim Code-Review, wie
vom Auftrag selbst als Ausweichoption vorgesehen.
Regressions: keine neuen -- F001 behoben, kein neuer Regressionsfund.
Checklist: unveraendert 5/6, AC-4 bleibt der einzige offene Punkt.
Recommendation: AC-4 per workflow.py override-ambiguous freigeben und den tatsaechlichen
Geraete-Nachweis (apps-before/apps-after-Vergleich) nach dem Sichern des Standes in einer eigenen,
spaeteren Pruefrunde nachreichen, oder bis dahin warten.

## Geprüfte Dateien

- sha256:f9d01628839c0ce3a1b6cd90aa3590864b3616960724e0a1fb101da092f36697  .github/workflows/testflight.yml
- sha256:254e8f235ddc3e69b811c6d57aa74d71285b68ec6f69a7c0882f5a965beefe3c  LooseEndsTests/ModelContainerFactoryTests.swift
- sha256:ad16fcaefe0903f466db79177cc2f6a2180c74e89910af265151faeb414dcd5b  Shared/Persistence/ModelContainerFactory.swift
- sha256:d7c7de20bfb3bb5c92823af680c5b42fa789bcf4f98fd50a867522fa92a1659b  docs/project/00-entscheidungen.md
- sha256:917c1e80d0d825261374ae30d449660a6ecd78c62deb67f7ca0f5e69926f2087  project.yml
- sha256:516d38f9dd0fadec7f4a245b1d8857a05e56b0efe54df74381ffc28dd2cd96d7  scripts/sim.sh
### Runde 4

Kontext: Die Spec wurde grundlegend geaendert (Abschnitt 3, AC-4) und von Henning nach `override` mit
`approved` freigegeben. Kern: der Cloud-Signierweg ist verworfen (scheiterte nachweislich identisch:
„No profiles for com.henning.looseends.probe were found" -- mit Schluessel kann xcodebuild keine
NEUEN Entwicklungsprofile anlegen, nur bestehende verwenden). Weg 2: Gerätebauten laufen lokal, ohne
-allowProvisioningUpdates (kontaktiert Apple nicht, kann die Xcode-Anmeldung nicht abmelden), nur
LOOSEENDS_REGISTER=1 registriert einmalig ueber die Anmeldung. Diese Runde prueft den neuen Code und
die neuen AC-4-Belege mit Misstrauen -- jede Behauptung selbst nachgerechnet, nicht uebernommen.

Hinweis: zwischen Runde 3 und dieser Runde wurde der damalige Stand committet (084655c) -- mein
eigenes Dialog-Artefakt aus Runde 1-3 ist seitdem Teil der Historie. Das aendert nichts an dieser
Pruefung: die aktuellen, unkommittierten Aenderungen (scripts/sim.sh, docs/reference/testflight.md,
docs/specs/tooling/fix-156-pruefkennung.md, Loeschung von .github/workflows/probe-build.yml) werden
wie gewohnt gegen den Arbeitsbaum geprueft. Das required-files-Werkzeug (Basis 2adb569) liefert
weiterhin veraltet nur Shared/Persistence/ModelContainerFactory.swift -- per `git diff --stat HEAD`
selbst nachgesehen: genau die vier oben genannten Dateien sind diese Runde veraendert, sonst nichts.

1. F001 (Finding Runde 2, Fix bestaetigt Runde 3): WEITERHIN behoben, im neuen Code erneut geprueft.
   cmd_device_build (Zeile 297-303): erste Anweisung ist "local id; id=$(require_device) || return 1",
   danach ensure_project, danach signed_build. cmd_lab (Zeile 361-369): identische Reihenfolge
   (require_device zuerst, Zeile 362). Beide brechen bei fehlendem Geraet vor jedem Bauversuch ab.
   bash -n scripts/sim.sh: Exit 0, keine Ausgabe -- syntaktisch fehlerfrei.
   Code reference: scripts/sim.sh:297-303
   Code reference: scripts/sim.sh:361-369

2. Neuer Code gegen die Spec gelesen (nicht nur behauptet, dass er der Spec folgt):
   - signed_build (Zeile 275-295) ist im Kern die bereits VOR #156 erprobte lokale Baufunktion
     (identisches PIPESTATUS-Muster, identische xcbeautify-Behandlung, siehe Vergleich mit dem
     Stand vor 2adb569) -- kein neu erfundener Mechanismus, sondern ein Revert auf bewaehrten Code,
     nur mit einer neuen Bedingung: -allowProvisioningUpdates wird nur noch gesetzt, wenn
     LOOSEENDS_REGISTER=1 ist (Zeile 280-283), sonst nie. Das ist exakt die in der Spec verlangte
     Trennung (Abschnitt 3: „ohne -allowProvisioningUpdates kontaktiert xcodebuild Apple nicht").
   - cmd_device_build (Zeile 297-303) ruft signed_build mit "BUNDLE_ID_SUFFIX=.probe"
     "LE_DISPLAY_NAME=LE Pruefbau" als zusaetzliche xcodebuild-Argumente -- bash-Array-Semantik
     (shift 2, dann "$@" an args angehaengt) korrekt, selbst nachvollzogen.
   - device_app_path (Zeile 305) zeigt wieder auf das lokale Bauprodukt
     (Build/Products/Debug-iphoneos/LooseEnds.app) statt auf den entpackten Cloud-Export -- passt zu
     device-install/device-launch, die unveraendert bleiben (keine Zeile dort angefasst).
   - Keine Reste des verworfenen Wegs: ci_device_app, ci_fetch_app, "gh run", "git push origin" --
     kein Treffer mehr im ganzen Skript (eigene Volltextsuche). .github/workflows/probe-build.yml
     per Verzeichnislisting bestaetigt geloescht (nicht mehr vorhanden).
   - docs/reference/testflight.md (Zeile 111-120 neu) beschreibt denselben Mechanismus wortgleich
     zum Code: gespeicherte Profile, kein Apple-Kontakt im Normalfall, LOOSEENDS_REGISTER=1 fuer den
     einmaligen Registrierungslauf.
   Code reference: scripts/sim.sh:275-295
   Code reference: scripts/sim.sh:305
   Code reference: docs/reference/testflight.md:111-120
   Code reference: docs/specs/tooling/fix-156-pruefkennung.md:234-255

3. AC-1 bis AC-3 gegen den neuen Code: kein Produktivcode ausserhalb von scripts/sim.sh veraendert
   seit Runde 1-3 (git diff --stat HEAD zeigt nur scripts/sim.sh, docs/reference/testflight.md,
   docs/specs/tooling/fix-156-pruefkennung.md, docs/briefings/bundle-id-debug-156.md und die Loeschung
   von probe-build.yml -- project.yml, ModelContainerFactory.swift, alle Info.plist/Entitlements-
   Dateien sind unveraendert seit dem commiteten Stand). Die in dieser Runde veraenderten
   sim.sh-Zeilen (258-369) liegen ausschliesslich im Geraeteabschnitt -- cmd_build (Zeile 176) und
   cmd_launch (Zeile 225), die Stufe-2-Simulatorwege, sind nicht betroffen (ausserhalb des
   veraenderten Bereichs, per Zeilennummern-Abgleich bestaetigt). AC-1, AC-2, AC-3 bleiben damit auf
   dem in Runde 1 eigenstaendig reproduzierten Stand gueltig -- keine neue Pruefung noetig, keine
   Verschiebung festgestellt.

4. AC-4 gegen die Belege -- unabhaengig, nicht nur die vorgelegten Dateien geglaubt:

   a) Der tatsaechlich gebaute, signierte Pruefbau wurde SELBST gelesen, nicht nur
      probe-built-values.txt vertraut:
      plutil -p auf dem echten Bauprodukt
      (/Users/hem/Library/Developer/Xcode/DerivedData/LooseEnds-device-default/Build/Products/
      Debug-iphoneos/LooseEnds.app/Info.plist) liefert CFBundleIdentifier =
      com.henning.looseends.probe, CFBundleDisplayName = "LE Pruefbau", LEAppGroup =
      group.com.henning.looseends.probe, LECloudContainer = iCloud.com.henning.looseends.probe --
      exakte Uebereinstimmung mit probe-built-values.txt.
      codesign -d --entitlements - --xml auf demselben Bauprodukt (eigenstaendig ausgefuehrt, rein
      lesend) liefert application-identifier = XK87E2B3VR.com.henning.looseends.probe,
      com.apple.security.application-groups = [group.com.henning.looseends.probe],
      com.apple.developer.icloud-container-identifiers = [iCloud.com.henning.looseends.probe] --
      das ist eine ECHTE Signatur (codesign -dv zeigt CodeDirectory, Signature size=4783, Signed
      Time=1. Oct 2026 at 08:10:47, TeamIdentifier=XK87E2B3VR), kein unsignierter Simulator-Stub.
      Dasselbe fuer LooseEndsWidgets.appex (CFBundleIdentifier com.henning.looseends.probe.widgets,
      application-identifier XK87E2B3VR.com.henning.looseends.probe.widgets) und
      LooseEndsShare.appex (com.henning.looseends.probe.share, inkl. eigenem
      icloud-container-identifiers-Eintrag) -- beide exakt wie in probe-built-values.txt behauptet,
      jetzt am echten Bauprodukt bestaetigt. Damit ist das von der Spec selbst benannte Kernrisiko
      (automatische Registrierung von App-Gruppe UND iCloud-Container .probe) nachweislich geloest --
      nicht ueber GitHub (das scheiterte, siehe Changelog), sondern ueber den lokalen
      Registrierungslauf mit Xcode-Anmeldung.

   b) Die Geraete-App-Liste wurde SELBST, erneut, rein lesend abgefragt (xcrun devicectl device info
      apps --device 00008140-00111D582681801C --json-output <scratchpad>, keine Installation, kein
      Start) -- nicht nur apps-after.txt geglaubt. Ergebnis jetzt, in diesem Moment: drei
      Loose-Ends-Eintraege sind auf dem Geraet vorhanden -- com.henning.looseends ("Loose Ends",
      Container-Ordner A516562E-B97A-49D1-96B3-881F7FD50A39), com.henning.looseends.lab ("LE Labor",
      Container 7E861492-A5C9-4573-AEA4-FF11247DDD49) und com.henning.looseends.probe ("LE Pruefbau",
      Container 3AB430D4-E9FC-4056-AA8A-439A1C9A4190). Abgleich mit apps-before.txt: der
      Container-Ordner von com.henning.looseends ist VOR und NACH dem Pruefbau identisch
      (A516562E-B97A-49D1-96B3-881F7FD50A39) -- eine Neuinstallation oder Ueberschreibung haette laut
      iOS-Konvention einen neuen Bundle-Container angelegt; ein unveraenderter Ordner ist der
      praktische Beleg, dass Hennings echte App nicht angefasst wurde. com.henning.looseends.probe
      existiert in apps-before.txt nicht und ist in meiner eigenen Live-Abfrage UND in apps-after.txt
      identisch neu (derselbe Container, dieselbe Bundle-ID, derselbe Anzeigename) -- kein
      Widerspruch zwischen Beleg und eigener Nachpruefung.

   c) device-proof.txt beschreibt den Ablauf: LOOSEENDS_REGISTER=1 ./scripts/sim.sh device-build
      (einmaliger Registrierungslauf) -> device-install -> KEIN device-launch, KEIN device
      (kombiniert) -> danach ein normaler device-build ohne REGISTER (in der Sandbox) zur
      Bestaetigung, dass der Normalfall ohne Anmeldung auskommt. Das deckt sich mit der Spec
      (Abschnitt 3) und mit AC-4 woertlich ("weder device-launch noch device (kombiniert) werden
      gegen eine der beiden Apps aufgerufen"). In dieser Runde selbst wurden ausschliesslich
      lesende Befehle ausgefuehrt (plutil, codesign -d, xcrun devicectl device info apps) -- kein
      device-install, device-launch, device, lab oder LOOSEENDS_REGISTER selbst aufgerufen, wie
      vom Auftrag verlangt.

   AC-4 gilt damit als bewiesen -- nicht nur durch die vorgelegten Artefakte, sondern durch
   eigenstaendige, unabhaengige Nachpruefung an der echten Signatur und an der echten, live
   abgefragten Geraete-App-Liste.
   Code reference: docs/artifacts/bundle-id-debug-156/device-proof.txt
   Code reference: docs/artifacts/bundle-id-debug-156/probe-built-values.txt
   Code reference: docs/artifacts/bundle-id-debug-156/apps-before.txt
   Code reference: docs/artifacts/bundle-id-debug-156/apps-after.txt

Kein neuer Fund in dieser Runde. F001 bleibt behoben, AC-4 ist jetzt bewiesen, AC-1/AC-2/AC-3/AC-5/AC-6
bleiben unveraendert bestaetigt (kein beruehrter Code).

- [x] AC-1: Standardbau bitgleich. Unveraendert seit Runde 1 -- kein Produktivcode dafuer in dieser
  Runde angefasst (project.yml, Info.plist/Entitlements, ModelContainerFactory.swift unveraendert
  seit dem commiteten Stand).
  Code reference: project.yml:31-32,50-52,63-67,91
- [x] AC-2: Unit-Test gruen, Rueckfall geprueft. Unveraendert seit Runde 1/2 -- kein Swift-Code in
  dieser Runde angefasst, voriger Lauf (235 gruen, 0 fehlgeschlagen) bleibt gueltig.
  Code reference: Shared/Persistence/ModelContainerFactory.swift:19-29
  Code reference: LooseEndsTests/ModelContainerFactoryTests.swift:7-38
- [x] AC-3: Simulator unveraendert. cmd_build (Zeile 176) und cmd_launch (Zeile 225) liegen
  ausserhalb des in dieser Runde veraenderten Bereichs (Zeile 258-369) -- keine Verschiebung.
  Code reference: scripts/sim.sh:176-181
- [x] AC-4: Geraetebau installiert isoliert neben Hennings App (Stufe 3). Jetzt bewiesen -- eigene
  Lektuere des echten signierten Bauprodukts (codesign, plutil) und eigene, live abgefragte
  Geraete-App-Liste bestaetigen beide Eintraege, isolierte Kennungen und einen unveraenderten
  Container-Ordner fuer Hennings echte App. Kein device-launch, kein device (kombiniert) verwendet --
  weder vom Beleg noch von dieser Pruefung selbst.
  Code reference: scripts/sim.sh:297-303
  Code reference: docs/artifacts/bundle-id-debug-156/device-proof.txt
- [x] AC-5: ADR-18 dokumentiert. Unveraendert, erneut bestaetigt (Zeile 175-181, nach ADR-17, vor
  "Bewusst nicht in Version 1").
  Code reference: docs/project/00-entscheidungen.md:175-181
- [x] AC-6: Release/TestFlight unveraendert. Diff gegen den Basis-Stand UND gegen den Arbeitsbaum
  weiterhin leer -- byte-identisch, kein BUNDLE_ID_SUFFIX-Treffer.
  Code reference: .github/workflows/testflight.yml:1-125

Alle sechs AC jetzt bewiesen. Kein offener Checklisten-Punkt mehr.

## VERDICT: VERIFIED

Die Spec-Aenderung (Weg 2: lokale Signierung mit gespeicherten Profilen, einmaliger
Registrierungslauf ueber LOOSEENDS_REGISTER=1, GitHub-Weg vollstaendig entfernt) ist korrekt
umgesetzt. F001 bleibt behoben (require_device zuerst in cmd_device_build UND cmd_lab, erneut im
neuen Code bestaetigt). Der zuvor offene AC-4 ist jetzt durch eigenstaendige, unabhaengige
Nachpruefung bewiesen: das echte signierte Bauprodukt traegt nachweislich isolierte Kennungen
(codesign/plutil direkt gelesen), und die live abgefragte Geraete-App-Liste zeigt beide Apps
nebeneinander mit einem fuer Hennings echte App unveraenderten Speicherort. Alle sechs Acceptance
Criteria sind bewiesen, kein offener Punkt, kein neuer Fund.

Proven points: 6/6 (AC-1 bis AC-6 CONFIRMED).
Tests: 235 gruen, 0 fehlgeschlagen (Runde 1, docs/artifacts/bundle-id-debug-156/adversary-unit-run.txt)
-- weiterhin gueltig, kein Swift-Code seit diesem Lauf veraendert.
Edge cases: Geprueft, dass keine Reste des verworfenen GitHub-Wegs im Code oder in der Doku
zurueckbleiben (Volltextsuche, Verzeichnislisting) -- keine gefunden.
Regressions: keine -- F001 bleibt behoben, AC-1 bis AC-3 unveraendert gueltig (kein beruehrter Code),
AC-5/AC-6 unveraendert gueltig.
Checklist: 6/6 Punkte bewiesen.

## Geprüfte Dateien

- sha256:f9d01628839c0ce3a1b6cd90aa3590864b3616960724e0a1fb101da092f36697  .github/workflows/testflight.yml
- sha256:254e8f235ddc3e69b811c6d57aa74d71285b68ec6f69a7c0882f5a965beefe3c  LooseEndsTests/ModelContainerFactoryTests.swift
- sha256:ad16fcaefe0903f466db79177cc2f6a2180c74e89910af265151faeb414dcd5b  Shared/Persistence/ModelContainerFactory.swift
- sha256:67e42899006dcac65399ffb690b9acea6863a8d24955229a17f3a8bfe24557f6  docs/artifacts/bundle-id-debug-156/apps-after.txt
- sha256:14593c7942bcebbcf8d8e82f6b3dfa0a13d189d34c90fe9408af8d7d97270c32  docs/artifacts/bundle-id-debug-156/apps-before.txt
- sha256:ed401e2b6ef54eb517a329418fb250f6cb0060bc912c341442d81c2c6fd8e673  docs/artifacts/bundle-id-debug-156/device-proof.txt
- sha256:fea64dfd981eddbd0205d33b08e05a594094993e59b9bada8c0695bf11b9d7b3  docs/artifacts/bundle-id-debug-156/probe-built-values.txt
- sha256:d7c7de20bfb3bb5c92823af680c5b42fa789bcf4f98fd50a867522fa92a1659b  docs/project/00-entscheidungen.md
- sha256:d55f840fb26dc14c0a201bffadbc13f61bd5454580289a891bc2f36aec841dfb  docs/reference/testflight.md
- sha256:4471a6ed34a28296cd098c1c5eda7a26acf96d70cd52dce9d024a6be697bbdc5  docs/specs/tooling/fix-156-pruefkennung.md
- sha256:917c1e80d0d825261374ae30d449660a6ecd78c62deb67f7ca0f5e69926f2087  project.yml
- sha256:dab589f049e250a5daeab31cff42754bdbcd9bb7e13e024b77fe381e4163cd2c  scripts/sim.sh
