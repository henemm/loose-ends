"""Die Sandbox der Mac-App für den CI-Klicktest (#544).

Aufruf: python3 scripts/mac_ci_entitlements.py <Ausgabe.plist>

Der CI-Mac signiert ad hoc, ohne Profil. Bisher strich er dabei alle Berechtigungen (CODE_SIGN_ENTITLEMENTS=),
und die App lief ohne Sandbox: Die Dateiauswahl ging in der CI auf und in Hennings TestFlight-App nicht, weil der
Sandbox die Berechtigung für vom Nutzer gewählte Dateien fehlte. Dieses Skript schreibt die Berechtigungen des Ziels
LooseEnds aus project.yml in eine plist, ohne die Schlüssel, die ein Profil brauchen (iCloud, Push, Siri,
App-Gruppe). Was die Sandbox erlaubt oder verbietet, gilt damit in der CI genau wie bei Henning.
"""
import plistlib
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
TARGET = "LooseEnds"
# Ohne Profil verweigert macOS den Start mit diesen Schlüsseln; sie ändern nichts an Klicks und Auswahlfenstern.
NEEDS_PROFILE = ("com.apple.developer.", "aps-environment", "com.apple.security.application-groups")


def sandbox_entitlements(project):
    """Die Berechtigungen des App-Ziels, die eine Ad-hoc-Signatur tragen kann."""
    properties = project["targets"][TARGET]["entitlements"]["properties"]
    return {key: value for key, value in properties.items() if not key.startswith(NEEDS_PROFILE)}


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    project = yaml.safe_load((ROOT / "project.yml").read_text(encoding="utf-8"))
    entitlements = sandbox_entitlements(project)
    if entitlements.get("com.apple.security.app-sandbox") is not True:
        print("::error::project.yml: Die Mac-App läuft ohne Sandbox, der Klicktest prüfte dann etwas anderes", file=sys.stderr)
        return 1
    Path(argv[1]).write_bytes(plistlib.dumps(entitlements))
    print("\n".join(f"{key}: {value}" for key, value in sorted(entitlements.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
