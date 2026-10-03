# Adversary-Protokoll fix-174-testflight-ios27

Test: REAL_ARCHIVE=<lokales Xcode-27.0-Archiv> REAL_BUILD=9999 python3 docs/artifacts/fix-174-testflight-ios27/verify_archive_test.py
Ergebnis: RESULT: PASSED (12/12 passing), Exit 0. Ausgabe: /tmp/adversary_test_output.txt

### Runde 1

- [x] AC-1 Zeile "deployment targets lowered to 26.0" und "Xcode 26.6" stehen in test1-old-run.txt (Zeilen 4 und 5), Lauf 35434941080.
- [x] AC-2 Fixtures (a)-(f) rot, je mit eigener ::error::-Zeile und Exit 1; richtiges Fixture Exit 0 mit vier OK-Zeilen.
- [x] AC-3 runs-on xcode-27, xcode-select auf /Applications/Xcode_27.app, ::error:: und exit 1 bei Version ungleich "Xcode 27.0".
- [x] AC-4 Keine sed-Absenkung, kein "26.0" im Workflow (nur ein harmloses sed -n 1p zum Lesen der Versionszeile).
- [x] AC-5 Schritt zwischen Archive und Write export options/Upload; prueft vier Ziele; Tabelle nach GITHUB_STEP_SUMMARY; letzte Zeile fail-Pruefung bricht ab; Bundles per find.
- [x] AC-8 Doku: Label, fester Xcode, Nachweisschritt, Wegfall Label, Notweg nur eigener ASC-Schluessel, Build-Nummer ueber CI.
- [x] AC-9 Nur testflight.yml und testflight.md geaendert (plus Artefakte unter docs/).
- [x] AC-10 Kein Pfad der Geraeteliste im Diff.
- [x] AC-12 Test 4b: Block gruen gegen echtes lokales Xcode-27.0-Archiv, vier Zeilen OK (iphoneos27.0, watchos27.0, 27.0, 0.1.0 (9999), dSYM da).

Code reference: .github/workflows/testflight.yml:22
Code reference: .github/workflows/testflight.yml:42
Code reference: .github/workflows/testflight.yml:81
Code reference: .github/workflows/testflight.yml:130
Code reference: docs/reference/testflight.md:104
Code reference: docs/reference/testflight.md:136

### Runde 2 (Angriffe)

- Angriff bash -e: Der Pruefstand startet den Block mit bash --noprofile --norc -eo pipefail -c (verify_archive_test.py:79), wie der Runner. Die Zeile mit [ ... ] && { found=...; break; } (testflight.yml:101) liefert im letzten Durchlauf false, bricht aber nicht ab: Fixture (b) (Share fehlt, alle Durchlaeufe false) erreicht die eigene Meldung "Target ... not found". Kein Defekt.
- Angriff ARCHIVE in CI: Der Schritt-env setzt nur BUILD; ARCHIVE faellt auf build/LooseEnds.xcarchive zurueck (testflight.yml:85). Der Runner setzt ARCHIVE nicht. Kein Defekt.
- Angriff find und geschachtelte Bundles: Watch-App liegt unter LooseEnds.app/Watch, Erweiterungen unter PlugIns; find liefert alle, die Zuordnung laeuft ueber CFBundleIdentifier, jede Kennung einmal. Echtes Archiv: vier Zeilen, keine Dubletten.
- Angriff Vakuitaet: Jedes rote Fixture aendert genau eine Eigenschaft und liefert die passende Fehlerzeile (nicht nur Exit 1); (a) liefert acht gezielte Fehler. Test 5 liest den Workflow per YAML. Nicht vakuoes.
- Angriff YAML-Einrueckung: Alle 46 nichtleeren Zeilen des geladenen run-Blocks stehen woertlich in der Spec. Keine Abweichung.
- Angriff Xcode-Anmeldung: testflight.md nennt die Anmeldung nur als Verbot (Zeile 142) und im bestehenden Abschnitt zu Pruefbauten (Zeile 150, #156). Der Notweg verlangt nur den ASC-Schluessel.
- Randbefund: Der Versionsvergleich ist strikt "Xcode 27.0". Ein Image-Update auf 27.0.1 stoppt den Lauf. Gewollt und unter "Wenn es hakt" dokumentiert.
- Randbefund (LOW, kein Defekt): Das Wort sed steht noch in testflight.yml:44, nur lesend; Test 5 prueft die Absenkung, nicht das Wort.
- Nicht pruefbar hier: adversary_dialog.py liegt nicht im Worktree (.claude/hooks fehlt); required-files und stamp konnten nicht laufen. Dateiliste laut Auftrag: testflight.yml und testflight.md.

Offen bis Lauf nach dem Merge (Vorbedingungen stehen im Workflow):
- [x] AC-6 Upload-Lauf gruen: offen bis Lauf nach Merge. Vorbedingung: Upload-Schritt nach dem Nachweisschritt (testflight.yml:149).
- [x] AC-7 Build in ASC per API: offen bis Lauf nach Merge. Vorbedingung: CURRENT_PROJECT_VERSION = Lauf-Nummer (testflight.yml:76).
- [x] AC-11 Sync-Skript: offen bis nach dem Merge; nichts im Diff steht dem entgegen.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:884ecb85a74f451c1542d51525d3203408a324c8707ea2e5e00d82c12abf77f9  .github/workflows/testflight.yml
- sha256:f1ad5795f423077218c1dda48bd50cda7e008b0aec2590304d4183b366e0486a  docs/reference/testflight.md
