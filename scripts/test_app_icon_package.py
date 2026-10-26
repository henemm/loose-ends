"""Tests: das App-Icon ist ein Icon-Composer-Paket mit heller und dunkler Darstellung (#40).

Aufruf: python3 scripts/test_app_icon_package.py

Xcode übersetzt `LooseEnds/Resources/AppIcon.icon` zu Liquid Glass. Das Manifest ist von Hand geschrieben und ohne Bau
nicht zu prüfen; dieser Test hält die Form fest, die der Bau (2026-10-26) als wirksam gezeigt hat: eine Gruppe mit der
Faden-Ebene, Grund und Fadenbild nur über `fill-specializations` und `image-name-specializations` — der Eintrag ohne
`appearance` ist hell, der mit `"appearance": "dark"` dunkel.
Die schlichten Schlüssel `fill` (oberste Ebene) und `image-name` (je Ebene) dürfen nicht stehen: sobald sie da sind,
ignoriert `actool` die Dunkel-Spezialisierungen lautlos und rendert Dunkel wie Hell (belegt in
`docs/artifacts/40-icon-composer-paket/render-Dark-testform-ignoriert.png`).
Der Bau (`sim.sh build`, `mac-build`) und das gerenderte Bild belegen den Rest.
"""
import json
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = ROOT / "LooseEnds" / "Resources" / "AppIcon.icon"
SOURCE_THREAD = ROOT / "docs" / "design" / "logo" / "layer-thread.svg"
LIGHT_THREAD, DARK_THREAD = "#0F6E73", "#5FC4C9"


def manifest():
    with open(PACKAGE / "icon.json", encoding="utf-8") as handle:
        return json.load(handle)


def layers(icon):
    return [layer for group in icon["groups"] for layer in group["layers"]]


def light(entries):
    """Der Eintrag ohne `appearance` ist die helle Darstellung."""
    return [entry["value"] for entry in entries if "appearance" not in entry]


def dark(entries):
    return [entry["value"] for entry in entries if entry.get("appearance") == "dark"]


def read_asset(name):
    return (PACKAGE / "Assets" / name).read_text(encoding="utf-8")


class AppIconPackageTests(unittest.TestCase):
    def test_manifest_has_one_group_with_the_thread_layer(self):
        icon = manifest()
        self.assertEqual(len(icon["groups"]), 1, "der Grund ist ein Fill, keine Ebene")
        self.assertEqual([light(layer.get("image-name-specializations", [])) for layer in layers(icon)],
                         [["layer-thread.svg"]], "hell = Eintrag ohne appearance")

    def test_light_fill_is_the_flat_ground(self):
        self.assertEqual(light(manifest().get("fill-specializations", [])),
                         [{"solid": "srgb:0.95686,0.95294,0.93333,1.00000"}], "Grund #F4F3EE, Eintrag ohne appearance")

    def test_dark_appearance_has_its_own_ground_and_thread_image(self):
        icon = manifest()
        fills = dark(icon.get("fill-specializations", []))
        self.assertEqual(len(fills), 1, "Dunkel braucht einen eigenen Grund")
        self.assertIn("solid", fills[0])
        images = [value for layer in layers(icon) for value in dark(layer.get("image-name-specializations", []))]
        self.assertEqual(images, ["layer-thread-dark.svg"])

    def test_plain_keys_are_absent_because_they_switch_dark_off(self):
        icon = manifest()
        reason = "schaltet in actool die Dunkel-Spezialisierungen lautlos ab (render-Dark-testform-ignoriert.png)"
        self.assertNotIn("fill", icon, f"schlichtes 'fill' {reason}")
        for layer in layers(icon):
            with self.subTest(layer=layer.get("name")):
                self.assertNotIn("image-name", layer, f"schlichtes 'image-name' {reason}")

    def test_group_has_specular_and_neutral_shadow_and_layers_are_glass(self):
        icon = manifest()
        for group in icon["groups"]:
            self.assertIs(group.get("specular"), True, "AC-1: Gruppe mit specular")
            self.assertEqual(group.get("shadow", {}).get("kind"), "neutral", "AC-1: neutraler Schatten")
        for layer in layers(icon):
            with self.subTest(layer=layer.get("name")):
                self.assertIs(layer.get("glass"), True, "AC-1: jede Ebene ist Glas")

    def test_every_named_image_exists(self):
        icon = manifest()
        names = {entry["value"] for layer in layers(icon) for entry in layer.get("image-name-specializations", [])}
        self.assertEqual(names, {"layer-thread.svg", "layer-thread-dark.svg"})
        for name in names:
            with self.subTest(image=name):
                self.assertTrue((PACKAGE / "Assets" / name).is_file(), f"{name} fehlt unter AppIcon.icon/Assets")

    def test_thread_images_differ_from_the_source_only_in_stroke_colour(self):
        source = SOURCE_THREAD.read_text(encoding="utf-8")
        self.assertEqual(read_asset("layer-thread.svg"), source, "hell = die Quelle aus docs/design/logo")
        self.assertEqual(read_asset("layer-thread-dark.svg"), source.replace(LIGHT_THREAD, DARK_THREAD))

    def test_icon_name_matches_the_build_setting(self):
        with open(ROOT / "project.yml", encoding="utf-8") as handle:
            project = yaml.safe_load(handle)
        setting = project["targets"]["LooseEnds"]["settings"]["base"]["ASSETCATALOG_COMPILER_APPICON_NAME"]
        self.assertEqual(setting, PACKAGE.stem)

    def test_logo_readme_no_longer_sends_the_reader_to_the_gui(self):
        readme = (ROOT / "docs" / "design" / "logo" / "README.md").read_text(encoding="utf-8")
        self.assertNotIn("Nächster Schritt auf dem Mac", readme, "das Paket ist von Hand erzeugt, der GUI-Schritt entfällt")


if __name__ == "__main__":
    unittest.main()
