"""Tests: das App-Icon ist ein Icon-Composer-Paket mit heller und dunkler Darstellung (#40).

Aufruf: python3 scripts/test_app_icon_package.py

Xcode übersetzt `LooseEnds/Resources/AppIcon.icon` zu Liquid Glass. Das Manifest ist von Hand geschrieben und ohne Bau
nicht zu prüfen; dieser Test hält die Form fest, die der Spike (2026-10-26) als baubar gezeigt hat: ein Fill für den
Grund, eine Gruppe mit der Faden-Ebene, für Dunkel ein eigener Grund und ein eigenes Fadenbild.
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


def read_asset(name):
    return (PACKAGE / "Assets" / name).read_text(encoding="utf-8")


class AppIconPackageTests(unittest.TestCase):
    def test_manifest_has_one_group_with_the_thread_layer(self):
        icon = manifest()
        self.assertEqual(len(icon["groups"]), 1, "der Grund ist ein Fill, keine Ebene")
        self.assertEqual([layer["image-name"] for layer in layers(icon)], ["layer-thread.svg"])

    def test_light_fill_is_the_flat_ground(self):
        self.assertEqual(manifest()["fill"], {"solid": "srgb:0.95686,0.95294,0.93333,1.00000"}, "Grund #F4F3EE")

    def test_dark_appearance_has_its_own_ground_and_thread_image(self):
        icon = manifest()
        fills = [entry for entry in icon.get("fill-specializations", []) if entry.get("appearance") == "dark"]
        self.assertEqual(len(fills), 1, "Dunkel braucht einen eigenen Grund")
        self.assertIn("solid", fills[0]["value"])
        images = [entry for layer in layers(icon) for entry in layer.get("image-name-specializations", [])
                  if entry.get("appearance") == "dark"]
        self.assertEqual([entry["value"] for entry in images], ["layer-thread-dark.svg"])

    def test_every_named_image_exists(self):
        icon = manifest()
        names = {layer["image-name"] for layer in layers(icon)}
        names |= {entry["value"] for layer in layers(icon) for entry in layer.get("image-name-specializations", [])}
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
