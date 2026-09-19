# Teststufen für die Spracherfassung

Entstanden am 2026-09-19, nachdem die Erfassung zweimal als „läuft" gemeldet wurde, obwohl sie
tot war. Der Fehler war jedes Mal mit einem Ende-zu-Ende-Versuch gesucht worden — und der sagt
nur „geht nicht", nie *wo*.

**Grundsatz:** Jede Stufe prüft genau ein Glied der Kette und läuft ohne Henning. Eine Stufe wird
erst angefasst, wenn die darunter grün ist. Schlägt eine fehl, ist die Ursache damit eingegrenzt,
nicht nur festgestellt.

## ⛔ Zuerst: Der Simulator kann keine Spracherkennung

Am 2026-09-19 im App-Prozess gemessen:

    Stufe 0 — Sprache de_DE: neu unterstützt 0, neu installiert —,
              alt verfügbar true, alt auf dem Gerät möglich true
    [System] Received update for GeneralASR assets, available languages: []

Im Simulator liegen **für keine Sprache** Erkennungsmodelle. Die alte Schnittstelle behauptet
trotzdem „verfügbar" und „auf dem Gerät möglich" — beides unwahr — und scheitert dann beim Start
mit `kLSRErrorDomain 300`. Die neue meldet ehrlich null Sprachen.

**Folge für dieses Konzept:** Die Stufen 0 bis 4 sind im Simulator nicht aussagekräftig. Sie
gehören auf ein echtes Gerät. Was im Simulator bleibt, ist alles, was ohne Erkennung prüfbar ist:
dass Ton ankommt, dass nichts abstürzt, und die Regel aus Stufe 6.

| Stufe | Prüft | Braucht | Wo |
|---|---|---|---|
| 0 | Sprache unterstützt? Modell installiert? | nichts | nur Gerät |
| 1 | Modell lässt sich laden und installieren | Netz | nur Gerät |
| 2 | Erkennung startet und endet sauber | Modell | nur Gerät |
| 3 | Ton kommt an und lässt sich umwandeln | Mikrofon (Stille genügt) | Simulator + CI |
| 4 | Erkennung liefert den erwarteten Text | Audiodatei | nur Gerät |
| 5 | Live-Mikrofon | Mac spricht | nur Gerät |
| 6 | Regel: nie scheinbar zuhören | — | Simulator + CI |
| 7 | Abnahme durch Henning | Gerät | zuletzt |

## Stufe 0 — Voraussetzungen
`SpeechTranscriber.supportedLocale(equivalentTo: .current)` liefert eine Sprache, und
`SpeechTranscriber.installedLocales` sagt, ob das Modell da ist.
**Fehlschlag heißt:** Deutsch wird nicht unterstützt (dann ist alles Weitere sinnlos) oder das
Modell fehlt (dann ist Stufe 1 dran). Kein Mikrofon, keine App, Millisekunden.

## Stufe 1 — Modell installieren
`AssetInventory.assetInstallationRequest(supporting:)` und `downloadAndInstall()`. Danach muss
Stufe 0 „installiert" melden.
**Fehlschlag heißt:** Der Weg, das Modell zu bekommen, funktioniert nicht — genau die Lücke, an der
die alte Schnittstelle scheiterte, ohne es sagen zu können.

## Stufe 2 — Analyzer ohne Ton
Transcriber und Analyzer erzeugen, `bestAvailableAudioFormat` abfragen, starten, beenden.
**Fehlschlag heißt:** Die Erkennung selbst kommt nicht hoch — unabhängig von Mikrofon und Sprache.

## Stufe 3 — Tonpfad
Der Tap liefert Puffer (Zähler > 0) und die Umwandlung ins Analyzer-Format wirft nicht. Stille
genügt; es geht nicht um Inhalt, sondern darum, dass überhaupt Puffer fließen.
**Fehlschlag heißt:** Mikrofon oder Audiositzung. Genau hier hätte man heute früh gesehen, dass der
Ton ankommt — die Erkennung aber nicht lief.
**Falle aus der Recherche:** Ein Format-Fehler gibt *keinen* Fehler, sondern stumm nichts. Deshalb
wird die Umwandlung hier eigens geprüft.

## Stufe 4 — Erkennung mit Datei (der eigentliche Beweis)
Eine mitgelieferte Audiodatei mit bekanntem Satz durch den Analyzer schicken und den Text
vergleichen. Mit `say -o` auf dem Mac erzeugt, also reproduzierbar.
**Warum das die wichtigste Stufe ist:** Kein Mikrofon, keine Lautstärke, kein Nebengeräusch, kein
Zufall. Läuft in CI und schlägt an, sobald die Erkennung kaputtgeht — im Gegensatz zu jedem
Mikrofontest.

## Stufe 5 — Live-Mikrofon im Simulator
Der Mac spricht über die Lautsprecher, der Simulator hört über das Mac-Mikrofon, der Text muss im
Feld erscheinen. Nur lokal: hängt von Lautstärke und Umgebung ab und wäre in CI unzuverlässig.

## Stufe 6 — Die Regel
Die Erfassung darf nie scheinbar zuhören, ohne dass etwas passiert: entweder Text oder eine
sichtbare Meldung. Gilt unabhängig von der Ursache und fängt jeden künftigen stummen Ausfall.

## Stufe 7 — Gerät
Erst wenn 0 bis 6 grün sind, signiert auf Hennings iPhone mit mitlaufender Konsole. Nicht vorher —
das Gerät ist die letzte Stufe, nicht die Suchmethode.
