"""Liest nur, welche App-Store-Bilder in App Store Connect stehen (#742): je Version, Sprache und Bildgröße.

Aufruf: asc_store_probe.py
Umgebung wie asc_beta_probe.py. Nur GET. Druckt Zähler, Dateinamen, Pixelmaß und Lieferstatus, keine Schlüssel.
"""
import sys

from asc_beta_probe import Probe, attributes, records
from asc_wait_build import Fatal, find_app_id, read_config


def report_set(run, version_label, locale, screenshot_set):
    display = attributes(screenshot_set).get("screenshotDisplayType", "?")
    body = run.ask("appScreenshots", f"/v1/appScreenshotSets/{screenshot_set['id']}/appScreenshots?limit=20")
    shots = records(body)
    print(f"bildsatz version={version_label} sprache={locale} typ={display} anzahl={len(shots)}", flush=True)
    for shot in shots:
        a = attributes(shot)
        asset = a.get("imageAsset") if isinstance(a.get("imageAsset"), dict) else {}
        state = (a.get("assetDeliveryState") or {}).get("state", "?")
        print(f"bild typ={display} datei={a.get('fileName', '?')} maß={asset.get('width', '?')}x{asset.get('height', '?')} "
              f"zustand={state}", flush=True)


def report_subtitles(run, app_id):
    """Je App-Info Zustände, Feld- und Relationsnamen, dann Name und Untertitel je Sprache (#837).

    Nur Zustandswörter und Namen, nie andere Werte; ein leerer Untertitel steht als `keiner`.
    `keine` heißt: Antwort ohne Eintrag; `fehler` heißt: die Abfrage ist gescheitert.
    """
    body = run.ask("appInfos", f"/v1/apps/{app_id}/appInfos")
    if body is not None and not records(body):
        print("appinfo keine", flush=True)
    for number, info in enumerate(records(body), start=1):
        attrs = attributes(info)
        relations = info.get("relationships") if isinstance(info.get("relationships"), dict) else {}
        print(f"appinfo nr={number} state={attrs.get('state') or '?'} appStoreState={attrs.get('appStoreState') or '?'} "
              f"felder={','.join(sorted(attrs))} relationen={','.join(sorted(relations))}", flush=True)
        answer = run.ask("appInfoLocalizations", f"/v1/appInfos/{info['id']}/appInfoLocalizations?limit=50")
        if answer is None:
            print(f"untertitel appinfo={number} fehler", flush=True)
            continue
        locales = records(answer)
        if not locales:
            print(f"untertitel appinfo={number} keine", flush=True)
        for locale in locales:
            a = attributes(locale)
            subtitle = a.get("subtitle") or "keiner"
            print(f"untertitel appinfo={number} sprache={a.get('locale', '?')} name={a.get('name', '?')} "
                  f"untertitel={subtitle} zeichen={len(a.get('subtitle') or '')}", flush=True)


def main():
    try:
        config = read_config()
        app_id = find_app_id(config)
        run = Probe(config)
        report_subtitles(run, app_id)
        versions = records(run.ask("appStoreVersions", f"/v1/apps/{app_id}/appStoreVersions?limit=5"))
        if not versions:
            print("version keine", flush=True)
        for version in versions:
            a = attributes(version)
            label = f"{a.get('versionString', '?')}/{a.get('platform', '?')}/{a.get('appStoreState', '?')}"
            locales = records(run.ask("appStoreVersionLocalizations",
                                      f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations"))
            if not locales:
                print(f"sprache keine version={label}", flush=True)
            for locale in locales:
                name = attributes(locale).get("locale", "?")
                sets = records(run.ask("appScreenshotSets",
                                       f"/v1/appStoreVersionLocalizations/{locale['id']}/appScreenshotSets"))
                if not sets:
                    print(f"bildsatz keine version={label} sprache={name}", flush=True)
                for screenshot_set in sets:
                    report_set(run, label, name, screenshot_set)
        print(f"zusammenfassung antworten={run.answered} von={run.asked} befunde={run.findings}", flush=True)
        if not run.answered:
            raise Fatal("App Store Connect answered none of the store queries")
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
