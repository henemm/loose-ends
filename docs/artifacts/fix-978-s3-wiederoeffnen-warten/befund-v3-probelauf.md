# #978 S3 v3 – Probelauf widerlegt (2026-11-25)

Lauf: `mac-panel-repeat.yml` 45562032666, Zweig `fix/978-s3-wiederoeffnen-warten` (c328655),
`iterationen=2`, `kontrollarm=false`, Ergebnis **failure**. Artefakte unter `probe-45562032666/`.

## Prüfpunkte des Probelaufs (Spec v3)

| Punkt | Soll | Ist | |
|---|---|---|---|
| Klickweg open-app | `menubar-root` | `menubar-root` 2/2 | erfüllt |
| Klickweg return (⌘W) | `menubar-root`, nicht `fallback-looseends` | `fallback-looseends` 2/2 | **nicht erfüllt** (F002) |
| Keine Aktivierung im Klick | kein „Activate com.henning.looseends“ unter `Click … MenuBar` | keine; Klick wartet stattdessen auf `com.apple.finder to idle` | erfüllt |
| Klickdauer | < 1 s | 5,6 s (`Wait for com.apple.finder to idle` 06:41:11.87 → 06:41:17.45; Iteration 2 ebenso 5,7 s) | **nicht erfüllt** |
| key → Maus hoch | < 0,3 s | 0,71 s im Fall (key +0,588 s, global event=2 +1,299 s) | **nicht erfüllt** |
| Kein Fall | 0 | open-app 1/2 (Iteration 1: Panel auf, resign 20 ms nach Maus hoch, hide) | **nicht erfüllt** |

## Was das heißt

1. Die Wurzel „Menüleiste der vordersten App“ entfernt die Aktivierung von Loose Ends aus dem Klick
   (v3 hat das Ziel der Analyse v2 hier erreicht) – **der Fall tritt trotzdem auf**. Die Aktivierung
   war also nicht die Ursache, sondern lag nur zeitlich daneben.
2. Gleich bleibt das Muster aus S2: key beim Maus-runter, Maus-hoch erst ~0,7 s später, das System
   beendet die Panelsitzung 20 ms nach dem Maus-hoch. Neue Arbeitshypothese (noch nicht recherchiert,
   noch nicht belegt): Der Statusobjekt-Host deutet ein spätes Maus-hoch wie bei Menüs als
   „gedrückt halten und loslassen“ und schließt. Die Lücke zwischen runter und hoch entsteht in
   XCTests Klicksynthese, unabhängig von der Wurzel-App.
3. Im ⌘W-Arm liegt Loose Ends vorn, deshalb greift dort nur der Rückfall – v3 belegt den Nutzerweg
   für diesen Arm nicht.

## Nächster Schritt

Zurück in `/20-analyse #978`. Zuerst recherchieren (NSStatusItem / MenuBarExtra: Schließen bei
spätem mouseUp, Schwelle für Press-and-hold), dann Rückfallplan D (Erkennen „auf und zu im Klick“
und genau eine Wiederholung) gegen einen Klick mit festem kurzem Abstand runter/hoch per CGEvent
abwägen (`CGPreflightPostEventAccess` war auf dem Runner false, S2).
