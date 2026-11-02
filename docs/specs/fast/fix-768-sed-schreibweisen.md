# Mini-Spec: fix-768-sed-schreibweisen

Ticket #768 (Befund F002 aus dem Adversary-Dialog zu #767). Nur `scripts/test_ci_xcode27.py`, kein Produktcode.

## Was ändert sich
- Das Suchmuster in `test_no_lowering_anywhere_in_github` erkennt schreibendes `sed` unabhängig von Flag-Bündel und Leerzeichen: `sed -i`, `sed -ni`, `sed -i.bak`, `sed  -i` (zwei Leerzeichen), `sed -n -i`, `sed --in-place`. Muster: `sed(\s+-[A-Za-z]+)*\s+(-[A-Za-z]*i|--in-place)`; die übrigen Alternativen (`26\.0`, `macos-26`, `project\.yml`) bleiben.
- Die Suche steht in einem Hilfsaufruf `lowering_hits(directory)`, den der Test auf `.github/` und die Gegenprobe auf eine Temp-Kopie anwenden.
- Neuer Test `test_sed_pattern_catches_every_writing_spelling`: legt in einer Temp-Kopie von `.github/` nacheinander je eine Zeile pro Schreibweise ab (`-i`, `-ni`, `--in-place`, zwei Leerzeichen); jede lässt `lowering_hits` einen Treffer liefern.

## Was darf sich nicht ändern
- Lesendes `sed -n …` (`sed -n 1p`, `sed -n 's/…/p'`) in `.github/` schlägt nicht an; die zwei erlaubten Zeilen aus #767 (`READS_PROJECT_YML`) bleiben erlaubt.
- Keine Änderung an `.github/` und keine neue Abhängigkeit.

## Manuelle Test-Schritte
Keine (kein UI, kein Gerät). Kein Pfad der Geräteliste berührt.

## Inline-Test (wird während Implementierung geschrieben)
- [ ] Gegenprobe: je eine Zeile pro schreibender Schreibweise in der Temp-Kopie lässt den Treffer entstehen (vorher mit dem alten Muster rot für `-ni`, `--in-place`, zwei Leerzeichen).
- [ ] Lesende Zeile `sed -n 1p` in der Temp-Kopie erzeugt keinen Treffer.
- [ ] `python3 -m unittest discover -s scripts` grün.
