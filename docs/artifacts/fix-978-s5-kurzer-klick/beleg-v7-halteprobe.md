# #978 S5 v7 – Beleg Halteprobe (DoD-Zeile 2)

- Lauf: 45672549713 (`mac-panel-repeat.yml`, `halteprobe=true`), Commit 72e7dff, Zweig `fix/978-s5-kurzer-klick`, 2026-11-25
- Testergebnis: 20 Tests ausgeführt, 0 Fehler (`testHoldDurationProbe`, je Durchlauf ein 1,0-s- und ein 0,1-s-Klick)
- Quelle der Werte: Klickanhänge im `MacPanelRepeat.xcresult` (exportiert mit `xcrun xcresulttool export attachments`),
  Zeile `read hold:` = Accessibility-Wert des Statusobjekts (`round=<n> …`), den die App unter `--ui-testing` setzt

## Ergebnis

| Klick | Anzahl | Panel | gelesene Haltedauer |
|---|---|---|---|
| 1,0 s | 20 | 20 zu | alle ≥ 0,4 s: 0,827 bis 1,417 s (Median ≈ 0,91 s) |
| 0,1 s | 20 | 20 offen | 11 mit Sekunden 0,004 bis 0,094 s, 9 `short (no mouse up)` |

Kein Anhang trägt `unknown`. Der Wert am Statusobjekt ist per XCUITest lesbar, die Abbruchregel (a') greift nicht.
Die Trennung bei 0,4 s ist scharf: der kleinste Wert eines geschlossenen Panels liegt bei 0,827 s, der größte eines
offenen bei 0,094 s.

Geöffnet und beschrieben (Beispiel 0,1-s-Klick): `d: 0.1`, `result: open`, `monitor saw nothing`,
`read hold: short (no mouse up)`. Die Zeile „Monitor sah Ereignisse: 0 von 40“ der Zusammenfassung stammt aus dem
Protokoll-Abgleich von v6 (`OSLogStore`, im Läufer nicht lesbar) und betrifft den Wert am Statusobjekt nicht.

## Nächste DoD-Zeilen

- Nachweislauf `iterationen=40`: Lauf 45676450151, bestanden (`beleg-v7-nachweislauf.md`)
- drei Galerie-Läufe auf demselben Commit: erster Lauf 45672535443
