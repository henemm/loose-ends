# Messung an den eigenen Rohsätzen (#88)

Die Auswertung `RawSentenceColumn` liest Hennings eigene Erfassungen aus `docs/reference/loose-ends-rawtexts.json`
(gitignoriert, nie eingecheckt). Diese Datei schreibt der Export aus dem Datenspeicher der normalen Mac-App.

## Export (Schnitt B1b)

Aufruf aus dem Repo-Stamm, in einer Zeile (Bau in einen temporären Ordner, Standardspeicher der Mac-App, Ziel):

```bash
swiftc -parse-as-library "$PWD/Measurement/RawTextExport.swift" "$PWD/scripts/export-loose-ends-rawtexts.swift" -o "$TMPDIR/rawtext-export" && "$TMPDIR/rawtext-export" --store "$HOME/Library/Group Containers/group.com.henning.looseends/Library/Application Support/LooseEnds.store" --out docs/reference/loose-ends-rawtexts.json
```

- **Bau mit absolutem Skriptpfad** (`"$PWD/…"`): Der Export leitet den Repo-Stamm aus dem beim Bau eingetragenen Pfad des
  Skripts ab. Mit relativem Pfad gebaut hinge der Zielschutz vom Ordner ab, aus dem man startet; deshalb bricht der Export dann
  mit „Skriptpfad relativ, Repo-Stamm unbestimmt“ ab und schreibt nichts.
- **Speicher** (`--store`, Standard): `~/Library/Group Containers/group.com.henning.looseends/Library/Application Support/LooseEnds.store`
  (`ModelContainerFactory`: Konfiguration „LooseEnds“, App-Gruppe `group.com.henning.looseends`). Geöffnet wird nur lesend.
- **Ziel** (`--out`, Standard): `docs/reference/loose-ends-rawtexts.json`. Erlaubt sind nur `docs/reference/` und Pfade außerhalb
  des Repos; jedes andere Ziel im Repo wird verweigert. Geschrieben wird atomar: Eine vorhandene Zieldatei wird ersetzt, auch
  wenn sie schreibgeschützt ist, und ein Symlink als Ziel wird durch die Datei ersetzt, sein Linkziel bleibt unberührt.
- **Ausgabe**: nur Zahlen („N Sätze, davon M mit Titelkorrektur, K mit Dauer“) und der Zielpfad, nie ein Satz. Bei einem Fehler
  (Speicher fehlt, keine Datenbank, Tabelle fehlt, keine Aufgaben, Ziel verweigert) nennt sie Art und Pfad, schreibt nichts und
  endet mit einem Code ungleich 0.
- **Ableitung**: `titleBefore` ist der alte Wert der ersten Titelkorrektur des Nutzers (ohne Korrektur der aktuelle Titel),
  `titleUser` der neue Wert der letzten, `durationUser` der Wert der letzten Daueränderung des Nutzers; Ids sind laufende Nummern
  in der Reihenfolge der Erfassung.

- **Speicher ohne Nebendateien** (SQLite-Code 14): Der Speicher läuft im WAL-Modus. Liegen neben `LooseEnds.store` keine
  `-wal`- und `-shm`-Dateien (etwa weil die App geschlossen ist), lässt SQLite ihn rein lesend nicht öffnen; der Export bricht
  mit „SQLite-Code 14, Speicher ohne Nebendateien“ ab und schreibt nichts. Abhilfe: die Mac-App während des Exports laufen
  lassen. Der Export öffnet den Speicher nie schreibend, auch nicht, um die Nebendateien anzulegen.

## ⛔ Echter Speicher erst nach Hennings Wort

Der Lauf auf Hennings echtem Speicher ist Zugriff auf sein Gerät. Er geschieht erst, nachdem Henning wörtlich
„jetzt ist ein Test möglich“ geschrieben hat, und nur für diesen einen Durchgang (Schnitt B2). Bis dahin läuft der Export
nur gegen Wegwerf-Speicher, immer mit ausdrücklich gesetztem `--store`.
