# Vorfall 2026-09-30 09:29 — die RED-Prüfung hat selbst auf Hennings iPhone zugegriffen

## Was passiert ist

Die erste Fassung der Abwesenheitsprüfung (Phase 5, TDD RED) setzte AC-1 wörtlich um: „When
`./scripts/sim.sh device-test RecognitionWalkthroughTests` läuft / Then meldet der Befehl
`Unbekannter Befehl`". Sie rief den Befehl also auf — **während er noch existierte**. Damit lief
genau der Ablauf, den dieses Ticket abschafft:

- `device_probe_locked` startete die produktive App `com.henning.looseends` auf
  `00008140-00111D582681801C` im Vordergrund (Fernstart),
- `xcodebuild test` baute signiert, installierte die App neu und dazu
  `com.henning.looseends.uitests.xctrunner`,
- der Testlauf belief sich auf 40,1 s Testzeit, insgesamt rund 50 s Gerätebelegung,
- Ergebnis: `** TEST FAILED **`,
  `RecognitionWalkthroughTests.testWordEqualRecaptureTakesOverDurationAndContext()`.
  Protokoll: `~/Library/Developer/Xcode/DerivedData/LooseEnds-device-default/device-test.log`.

## Zustand des Geräts danach (rein lesend erhoben, `devicectl device info apps`)

| Kennung | Name | Bewertung |
|---|---|---|
| `com.henning.looseends` | Loose Ends | **von diesem Lauf überschrieben** — Hennings Installation trägt jetzt den Stand aus diesem Arbeitszweig, nicht den, den er selbst gebaut hatte |
| `com.henning.looseends.uitests.xctrunner` | LooseEndsUITests-Runner | **von diesem Lauf installiert**, gehört nicht auf sein Telefon |
| `com.henning.looseends.lab` | LE Labor | unverändert, gehört dorthin |

## Warum das hier steht

Es ist derselbe Fehler, den #153 abstellt — begangen in dem Schritt, der ihn abstellen soll. Die
Ursache ist nicht Unachtsamkeit im Einzelfall, sondern die Bauart des Kriteriums: **Ein Kriterium,
das die Abwesenheit eines Befehls dadurch prüft, dass es ihn aufruft, ist genau so lange
gefährlich, wie der Befehl noch da ist.** Das „Given der Rückbau ist umgesetzt" steht zwar in
AC-1, ist aber nur ein Satz — keine Schranke.

## Was dagegen getan wurde

Die Prüfung ruft den Befehl nicht mehr blind auf. Sie sieht zuerst nach, ob die Dispatch-Zeile
`device-test)` noch in `scripts/sim.sh` steht. Steht sie da, gilt AC-1 als nicht erfüllt, **ohne**
den Befehl auszuführen; erst wenn sie weg ist, wird aufgerufen — dann trifft der Aufruf den
Fehlerzweig und spricht kein Gerät an. Die Reihenfolge ist damit im Prüfwerkzeug verankert, nicht
im Vorsatz.

## Offen für Henning

Der Test-Runner `com.henning.looseends.uitests.xctrunner` liegt weiterhin auf seinem Telefon und
gehört dort nicht hin. Ihn zu entfernen wäre wieder ein schreibender Zugriff auf sein Gerät —
deshalb wird er nicht ungefragt entfernt.
