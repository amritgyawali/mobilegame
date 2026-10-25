"""Install verified official Godot ZIPs into a private portable toolchain."""
import hashlib
import json
from pathlib import Path
import shutil
import sys
import zipfile

root = Path(sys.argv[1]).resolve()
lock = json.loads((Path(__file__).parent / "godot-release-lock.json").read_text())
editor = root / "Godot" / lock["version"]
templates = root / "Godot/templates" / (lock["version"] + ".stable")
allowed_templates = {"android_debug.apk", "android_release.apk", "android_source.zip", "version.txt"}
for asset in lock["assets"]:
    is_templates = asset["name"].endswith(".tpz")
    archive_path = root / "downloads" / ("Godot-4.7.2-templates.tpz" if is_templates else "Godot-4.7.2.zip")
    algorithm, expected = asset["digest"].split(":", 1)
    with archive_path.open("rb") as source:
        assert hashlib.file_digest(source, algorithm).hexdigest() == expected, "Godot download checksum mismatch"
    target = templates if is_templates else editor
    with zipfile.ZipFile(archive_path) as source:
        for entry in source.infolist():
            name = entry.filename.removeprefix("templates/") if is_templates else entry.filename
            if entry.is_dir() or (is_templates and name not in allowed_templates):
                continue
            destination = (target / name).resolve()
            assert destination.is_relative_to(target.resolve()), "ZIP escaped install directory"
            destination.parent.mkdir(parents=True, exist_ok=True)
            with source.open(entry) as data, destination.open("wb") as output:
                shutil.copyfileobj(data, output)
    print("Installed verified " + asset["name"], flush=True)
(editor / "_sc_").touch()
