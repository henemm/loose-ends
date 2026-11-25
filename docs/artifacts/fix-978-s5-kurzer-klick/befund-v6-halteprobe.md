# Befund v6 – Halteprobe (AC-5): Abbruchregel (a) greift

- Lauf: `mac-panel-repeat.yml` mit `halteprobe=true`, Lauf-Kennung **45658361541**, Commit `c800f7b`, Job-Ergebnis success (2026-11-25, 18:11 Uhr MEZ).
- Halteprobe selbst wie in v4 bestanden: hold-1.0 20 von 20 zu, hold-0.1 0 von 20 zu.
- Anhänge per `xcresulttool export attachments` geöffnet (81 Dateien). **Alle 40 Klickanhänge** tragen dieselbe Zeile:
  `read hold: unknown (log not readable: Connection to logd failed)`.
  Beispiel (Klick 1795626680.850, d 0.1): `result: open`, `monitor saw nothing`, `read hold: unknown (log not readable: Connection to logd failed)`.
- Die Haltedauer aus dem App-Protokoll steht weiterhin im Auswerter (Spalte „key → Maus hoch“, 1,0-s-Klicks 0,90 bis 0,97 s), gelesen vom
  Lauf-Skript außerhalb des Testläufers, nicht im Test.

## Bewertung

Der macOS-UI-Testläufer darf `OSLogStore.local()` nicht lesen: Die Verbindung zu `logd` scheitert. Recherche: dieselbe Meldung tritt in der
Sandbox auf (OSLogErrorDomain 10); `local()` verlangt Admin-Konto bzw. das nicht vergebene Entitlement `com.apple.logging.local-store`
(mjtsai.com „OSLogStore on Monterey“, Apple-Forum 666679, Apple-Doku `OSLogStore.local()`).

Nach Spec v6 gilt **Abbruchregel (a)**: Stopp, Rückfall **A-ax** als Spec-Nachtrag; AC-6 und AC-7 werden mit diesem Stand nicht angegangen.
Der Retry-Pfad ist damit wirkungslos, aber sicher: Ohne Haltedauer greift er nie, ein Panel-zu-Fall bleibt hart rot (wie v5).
