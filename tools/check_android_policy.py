"""Fail development/build checks if a shipping export targets another platform."""
import configparser
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent


def read_config(path):
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.optionxform = str
    # project.godot starts with a version key before its first INI section.
    config.read_string("[__header__]\n" + path.read_text(encoding="utf-8-sig"))
    return config


def android_options():
    exports = read_config(ROOT / "SummitShards/export_presets.cfg")
    presets = [section for section in exports.sections() if re.fullmatch(r"preset\.\d+", section)]
    assert presets, "At least one Android export preset is required"
    for section in presets:
        assert exports[section]["platform"] == '"Android"', "Only Android exports are supported: " + section
    return exports["preset.0.options"]


def validate():
    options = android_options()
    assert options["architectures/arm64-v8a"] == "true", "ARM64 support is required"
    assert options.get("architectures/x86", "false") == "false"
    assert options.get("architectures/x86_64", "false") == "false"
    for key, value in options.items():
        if key.startswith("permissions/") and key != "permissions/custom_permissions":
            assert value == "false", "Starter must remain permission-free: " + key
    project = read_config(ROOT / "SummitShards/project.godot")
    assert project["rendering"]["renderer/rendering_method.mobile"] == '"gl_compatibility"'
    assert project["application"]["run/max_fps"] == "60"
    assert project["application"]["run/low_processor_mode"] == "true"
    assert project["application"]["config/quit_on_go_back"] == "false"
    assert project["display"]["window/handheld/orientation"] == "1"
    assert project["display"]["window/energy_saving/keep_screen_on"] == "false"
    # Godot omits settings equal to their pinned-engine defaults when saving.
    assert project["display"].get("window/frame_pacing/android/enable_frame_pacing", "true") == "true"


if __name__ == "__main__":
    validate()
    print("Android-only policy passed: portrait, ARM64, GL compatibility, 60 FPS cap, low-processor mode, no permissions.")
