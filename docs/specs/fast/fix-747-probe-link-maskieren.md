# Mini-Spec: fix-747-probe-link-maskieren

Closes #747 (aus #705 Schnitt 2b-2c). Das Repo ist öffentlich, das Log jedes Probe-Laufs damit für jede angemeldete
Person lesbar. Der Einladungslink der Gruppe „Tester“ darf dort nicht stehen.

## Was ändert sich
- `scripts/asc_beta_probe.py`, `report_groups`: Die Ausgabe `url=<Link>` wird `url=gesetzt` (Link an und Wert vorhanden)
  oder `url=-` (Link aus oder kein Wert). Dazu `filled(link)` wiederverwenden, aber `-` statt `leer` für „nichts“.
  Der Link selbst wird nirgends mehr gedruckt, auch nicht in Fehlerzeilen.
- `scripts/test_asc_beta_probe.py`:
  - `test_everything_present` prüft `url=gesetzt` statt `url={GROUP_LINK}`.
  - `test_output_has_no_contact_values_and_no_key`: `GROUP_LINK` wandert in die Liste der Werte, die **nicht** in der
    Ausgabe stehen dürfen (stdout + stderr); die Zeile „darf stehen“ entfällt.
  - Neuer Test: Gruppe mit Link aus (`publicLinkEnabled` false) druckt `url=-`.

## Was darf sich nicht ändern
- Alle anderen Zeilen und Felder der Probe (`link=an/aus`, `feedback=`, Zugriffs-, Build- und Einreichungszeilen).
- Die Probe bleibt rein lesend (nur GET), Exit-Codes bleiben.
- Kein Produktcode, keine Workflow-Datei, keine App.

## Nachstellen (vor dem Fix)
- Der geänderte Test ist vor dem Fix rot: Die Ausgabe enthält `https://testflight.apple.com/join/ABCDEF`.
  Nach dem Fix grün. Das ist derselbe Ablauf, der heute den Link ins Log druckt.

## Manuelle Test-Schritte
Keine. Der Lauf `aktion=probe` bleibt bis zum Merge ausgesetzt (DoD); danach zeigt er `url=gesetzt`.
Den Link findet Henning in App Store Connect, TestFlight, Gruppe „Tester“.

## Inline-Test (wird während Implementierung geschrieben)
- [ ] Mit eingeschaltetem Link taucht die URL in stdout und stderr nirgends auf; `url=gesetzt` steht in der Gruppenzeile.
- [ ] Mit ausgeschaltetem Link steht `url=-`.
