"""Das Datenschutz-Manifest folgt dem Konto-Schalter (#625 Schnitt 2).

Store-Bauten (`LEAccountEnabled` aus) erheben nichts: `NSPrivacyCollectedDataTypes` bleibt leer. Bauten mit `konto`
an senden die Apple-Kennung (`apple_sub`), die Abschrift der offenen Aufgaben und die Kennung der Installation
(`X-Device`) an den Dienst; ihr Manifest bekommt im CI genau diese drei Typen. Die Liste hier ist die eine Quelle.

    python3 scripts/privacy_manifest.py apply <manifest>
    python3 scripts/privacy_manifest.py check <manifest> --account true|false
"""
import argparse
import plistlib
import sys

KEY = "NSPrivacyCollectedDataTypes"
PURPOSE = "NSPrivacyCollectedDataTypePurposeAppFunctionality"
ACCOUNT_TYPES = [
    {
        "NSPrivacyCollectedDataType": kind,
        "NSPrivacyCollectedDataTypeLinked": True,
        "NSPrivacyCollectedDataTypeTracking": False,
        "NSPrivacyCollectedDataTypePurposes": [PURPOSE],
    }
    for kind in (
        "NSPrivacyCollectedDataTypeUserID",
        "NSPrivacyCollectedDataTypeDeviceID",
        "NSPrivacyCollectedDataTypeOtherUserContent",
    )
]


class ManifestError(Exception):
    pass


def load(path):
    """Das Manifest als dict; jede Lesestörung wird eine ManifestError mit dem Pfad."""
    try:
        with open(path, "rb") as handle:
            manifest = plistlib.load(handle)
    except OSError as error:
        raise ManifestError(f"{path}: cannot read ({error.strerror or error})")
    except Exception:
        raise ManifestError(f"{path}: not a valid property list")
    if not isinstance(manifest, dict):
        raise ManifestError(f"{path}: top level is not a dictionary")
    return manifest


def apply(path):
    """Setzt die drei Konto-Typen; alle anderen Schlüssel bleiben, ein zweiter Lauf ändert nichts."""
    manifest = load(path)
    manifest[KEY] = [dict(item) for item in ACCOUNT_TYPES]
    try:
        with open(path, "wb") as handle:
            plistlib.dump(manifest, handle)
    except OSError as error:
        raise ManifestError(f"{path}: cannot write ({error.strerror or error})")


def entry_findings(item):
    """Befunde zu einem Eintrag, der zu den Konto-Typen gehört."""
    kind = item.get("NSPrivacyCollectedDataType")
    findings = []
    if item.get("NSPrivacyCollectedDataTypeLinked") is not True:
        findings.append(f"{kind}: NSPrivacyCollectedDataTypeLinked must be true")
    if item.get("NSPrivacyCollectedDataTypeTracking") is not False:
        findings.append(f"{kind}: NSPrivacyCollectedDataTypeTracking must be false")
    if item.get("NSPrivacyCollectedDataTypePurposes") != [PURPOSE]:
        findings.append(f"{kind}: NSPrivacyCollectedDataTypePurposes must be exactly [{PURPOSE}]")
    return findings


def account_findings(types):
    """Befunde für einen Konto-Bau: genau die drei Typen, je einmal und richtig belegt."""
    wanted = [item["NSPrivacyCollectedDataType"] for item in ACCOUNT_TYPES]
    findings, seen = [], []
    for item in types:
        kind = item.get("NSPrivacyCollectedDataType") if isinstance(item, dict) else None
        if kind not in wanted:
            findings.append(f"type not collected by this build: {kind}")
        elif kind in seen:
            findings.append(f"type listed twice: {kind}")
        else:
            seen.append(kind)
            findings.extend(entry_findings(item))
    findings.extend(f"type missing: {kind}" for kind in wanted if kind not in seen)
    return findings


def check(path, account):
    """Befunde zum Manifest; leer heißt, es passt zum Schalter."""
    types = load(path).get(KEY, [])
    if not isinstance(types, list):
        return [f"{KEY} is not an array"]
    if not account:
        return [f"{KEY} must be empty for a build without the account, found {len(types)} entries"] if types else []
    return account_findings(types)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Privacy manifest that follows the account switch (#625).")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("apply").add_argument("manifest")
    checker = commands.add_parser("check")
    checker.add_argument("manifest")
    checker.add_argument("--account", required=True, choices=("true", "false"))
    args = parser.parse_args(argv)
    try:
        if args.command == "apply":
            apply(args.manifest)
            print(f"{args.manifest}: {len(ACCOUNT_TYPES)} collected data types set")
            return 0
        findings = check(args.manifest, args.account == "true")
    except ManifestError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    for finding in findings:
        print(f"{args.manifest}: {finding}", file=sys.stderr)
    if not findings:
        print(f"{args.manifest}: matches account={args.account}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
