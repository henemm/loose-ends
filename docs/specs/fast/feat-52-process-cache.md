# Mini-Spec: ProcessCache für ModelContainerFactory

## Was ändert sich
- Neuer generischer Baustein `ProcessCache<Value>` (Lock-geschützt, einmal bauen, danach dieselbe Instanz liefern).
- `ModelContainerFactory.make()` nutzt ihn für den echten (Nicht-Test-)Container statt der bisherigen manuellen `lock`/`cachedContainer`-Variablen.

## Was darf sich nicht ändern
- Verhalten von `make()` bleibt exakt gleich: Test-/UI-Test-/`inMemory`-Aufrufe weiterhin unabhängig, jedes Mal frisch, nie gecacht.
- Kein neuer öffentlicher API-Vertrag nach außen (nur interne Umstrukturierung).

## Manuelle Test-Schritte
Keine nötig — reine interne Umstrukturierung, Verhalten unverändert, durch bestehende Suite abgedeckt.

## Inline-Test (wird während Implementierung geschrieben)
- [ ] `ProcessCache`: zweimal aufrufen baut nur einmal, liefert beide Male dieselbe Instanz.

## Acceptance Criteria
- AC-1: `ProcessCache<Value>.value(build:)` ruft die `build`-Closure beim ersten Aufruf einmal auf und liefert das Ergebnis.
- AC-2: Ein zweiter Aufruf von `value(build:)` auf derselben Instanz ruft `build` nicht erneut auf und liefert dieselbe (identische) Instanz zurück.
- AC-3: `ModelContainerFactory.make()` verhält sich für `inMemory`/Test-/UI-Test-Aufrufe unverändert (weiterhin nie gecacht, jedes Mal frisch).
- AC-4: Bestehende `LooseEndsTests`-Suite bleibt vollständig grün.
