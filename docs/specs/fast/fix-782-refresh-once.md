# Mini-Spec: fix-782-refresh-once

Issue #782 (Finding F001 aus der Gegenprüfung von #780). Ursache belegt in
`LooseEnds/Notifications/BackgroundRefresh.swift:40-43`: Der Ablauf-Handler meldet
`setTaskCompleted(success: false)`, der innere `Task { @MainActor in … }` läuft weiter und meldet nach
`reschedule()` noch `setTaskCompleted(success: true)`. Die Aufgabe wird zweimal beendet.

Recherche: Apple verlangt genau ein `setTaskCompleted` vor Ablauf
([BGTask](https://developer.apple.com/documentation/backgroundtasks/bgtask),
[setTaskCompleted(success:)](https://developer.apple.com/documentation/backgroundtasks/bgtask/settaskcompleted(success:))).
Was ein zweiter Aufruf bewirkt, dokumentiert Apple nicht. Verbreitete Muster: ein einziger, geschützter
Abschlussweg (Signal-iOS `BGProcessingTaskRunner`, Apple-Forum-Antwort mit `expirationHandler = nil`).

## Was ändert sich
- `RefreshHandle` bekommt `finish(success:)`: der erste Aufruf meldet `setTaskCompleted`, jeder weitere tut
  nichts (Marke unter `Mutex` aus `Synchronization`, von jeder Queue aus sicher).
- Ablauf-Handler und innerer Task rufen nur noch `handle.finish(success:)`.
- Der bestehende Ablauf-Test prüft jetzt, dass nach dem Weiterlaufen der Arbeit genau ein Abschluss mit
  `false` vorliegt (`completions == [false]`), statt nur des ersten.

## Was darf sich nicht ändern
- Kennung `com.henning.looseends.refresh`, Zeitplan (`earliest`, `schedule()`), Registrierung.
- Ohne Ablauf: `reschedule()` genau einmal, genau ein Abschluss mit `true`.
- Der Handler erbt keinen Actor (#780).

## Alternative
- Den inneren Task im Ablauf-Handler abbrechen (`Task.cancel()`) und nur dort `false` melden (Signal-Muster).
  Verworfen: `reschedule()` ist nicht abbruchfähig, der Task liefe trotzdem bis zum Ende; die Marke braucht
  es dann ohnehin. Keine ADR betroffen.

## Manuelle Test-Schritte
1. Keine (Henning testet nicht von Hand). Nachweis über Unit-Tests im Simulator.

## Abnahme
- `LooseEnds/Notifications/` steht auf der Geräteliste. Der Simulator kann die Hintergrund-Auffrischung
  nicht auslösen; das Verhalten liegt vollständig in `launchHandler`, das die Tests mit `FakeRefreshTask`
  von einer Hintergrund-Queue aufrufen. Stufe 3 greift trotzdem (Pfad der Geräteliste, keine Abwägung):
  Gerätepunkt in der Definition of Done, nicht als AC: nach dem TestFlight-Bau kommen die Morgen- und
  Abendmitteilung weiter, auch wenn die App einen Tag nicht geöffnet wurde. Bis zu Hennings Rückmeldung
  bleibt #782 offen (PR mit `Refs #782`).

## Inline-Test (wird während Implementierung geschrieben)
- [ ] Ablauf von einer Hintergrund-Queue, danach läuft die Arbeit zu Ende: `completions == [false]`
- [ ] Ohne Ablauf weiterhin `completions == [true]`, `reschedule` einmal (bestehender Test)
