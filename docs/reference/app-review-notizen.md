# Notizen für App Review (Entwurf, Antwort auf „Guideline 2.1 – Information Needed“, Version 1.0 iOS)

Stand 2026-11-01. Apple hat die Einreichung vom 2026-10-31 (ID b8154b09-0fff-4147-8354-a1e72a14aa4c) nicht abgelehnt, sondern
um Angaben gebeten. Der Text unten (erster Codeblock) kommt in das Feld „Notes“ der App-Review-Informationen. Gesetzt wird er
per Handlauf `asc-review-notes.yml` mit `aktion=notizen` (#788 Schnitt 1, höchstens 4000 Byte, ohne Platzhalter). Die
Bildschirmaufnahme, auf die Punkt 1 verweist, hängt Schnitt 2 an die Version; `notizen` läuft darum erst unmittelbar vor diesem
Schritt. Neu eingereicht wird erst nach Hennings Wort.

Jede Aussage unten ist am Repo geprüft (`LooseEnds/Info.plist`, `CLAUDE.md`, `docs/reference/beta-beschreibung.md`).

```
1. SCREEN RECORDING
Screen recording of a physical iPhone 16 Pro, attached to this submission. The device runs the latest iOS.
It starts with launching the app and shows the typical flow: capture a task by voice (title, due date and tag are filled in from the spoken sentence), capture one by typing, the "New"
list, a task's detail view and the list of loose ends.
The app has no account registration, login or account deletion, no user-generated content that is shared with other users
(so no reporting or blocking), and no paid content or in-app purchases.

2. PURPOSE AND AUDIENCE
Loose Ends is a task inbox for people who think of things faster than they can file them. You say or type one sentence; the
app turns it into a task with a title, a due date and tags. Audience: anyone who keeps a to-do list on iPhone, iPad, Mac and
Apple Watch and wants capturing to cost no effort. Value: nothing gets lost between "I should do that" and the list.

3. HOW TO USE IT
No login and no sample files are needed. Open the app, tap the capture button, and say or type for example "Call the
dentist tomorrow at 3 pm". The task appears under "New" with its due date and appears in "Now" when it is due.
Microphone and speech recognition are asked on first use of voice capture; notifications when a task has a due date.
Calendar, camera and location are optional and asked only when the user switches the matching feature on (calendar mirror,
scanning a document into a task, reminder at a place).

4. EXTERNAL SERVICES
- Apple Intelligence (on-device Foundation Models) refines titles. It runs on the device; no task text leaves it. Without
  Apple Intelligence the app works fully: dates, times, tags and durations come from rules, not from the model.
- Apple speech recognition (on-device) for voice capture.
- iCloud (CloudKit, the user's private database) syncs tasks between the user's own devices. We run no server of our own
  and have no access to the data.
- Apple MapKit for choosing a place, Apple EventKit for the optional calendar mirror.
No third-party SDKs, analytics, advertising or payment services.

5. REGIONS
The app behaves the same in all regions. The interface and the capture rules are available in German and English. The only
difference is Apple's own: Apple Intelligence is not offered on every device, language and region; where it is missing the
app uses its rules and says so in a short note.

6. REGULATED INDUSTRY
Not applicable. No regulated services, no protected third-party material.
```
