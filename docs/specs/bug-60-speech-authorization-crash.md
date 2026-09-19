# Spec: Bug #60 — Erfassung stirbt an der Rechteabfrage der Spracherkennung

## Problem
`SFSpeechRecognizer.requestAuthorization` stellt seine Antwort über den TCC-Dienst auf einem
Hintergrund-Strang zu. Der Abschluss steht in der `@MainActor`-Klasse `SpeechCapture` und erbt
dadurch die Hauptstrang-Bindung. Swift prüft die Isolation beim Aufruf und bricht den Prozess ab
(`dispatch_assert_queue` → `brk #0x1`). Die App ist ab diesem Moment tot: Abbrechen, Mikrofon,
alles.

## Acceptance Criteria

- **AC-1:** Given die App läuft mit Spracherfassung (ohne `--ui-testing`) / When der Nutzer (+)
  antippt und das System die Rechteabfrage für Spracherkennung beantwortet / Then läuft die App
  weiter und der Erfassungs-Screen bleibt bedienbar.
- **AC-2:** Given der Erfassungs-Screen ist offen / When der Nutzer „Abbrechen" antippt / Then
  schließt der Screen, der Startbildschirm ist wieder bedienbar und ein erneutes Antippen von (+)
  öffnet die Erfassung wieder.
- **AC-3:** Given die Testlage / When die UI-Tests laufen / Then deckt mindestens einer den Weg
  **ohne** `--ui-testing` ab, also samt Rechteabfrage und Spracherfassung — vor dem Fix rot, danach
  grün.
- **AC-4:** Given der bestehende Funktionsumfang / When Unit- und UI-Tests laufen / Then bleiben sie
  alle grün.

## Änderung
`LooseEnds/Speech/SpeechCapture.swift`: `requestSpeechAuthorization()` wird `nonisolated static`.
Der Abschluss erbt damit keine Aktor-Bindung; die Prüfung entfällt. `state` und `transcript` bleiben
unverändert hauptstrang-gebunden, weil sie weiterhin nur aus `start()` heraus gesetzt werden.

## Nicht Teil dieses Fixes
Die Kurzbefehle („Kurzbefehl tut nichts") sind ein eigener Fehler mit eigener Nachstellung.

## Umfang
1 Quelldatei, 1 Testdatei. Weit unter der 250-LoC-Grenze.
