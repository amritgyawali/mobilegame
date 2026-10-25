"""Install only the pinned standalone Android APK development dependencies."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile


def install(root: Path) -> None:
    root = root.resolve()
    lock = json.loads((Path(__file__).parent / "android-release-lock.json").read_text(encoding="utf-8"))
    records = []
    for component in lock["components"]:
        archive = root / "downloads" / (component["id"] + ".zip")
        with archive.open("rb") as source:
            digest = hashlib.file_digest(source, "sha256").hexdigest()
        if archive.stat().st_size != component["bytes"] or digest != component["sha256"]:
            raise ValueError("Android archive checksum mismatch: " + component["id"])
        target = (root / component["destination"]).resolve()
        if not target.is_relative_to(root / "Android"):
            raise ValueError("Destination escaped standalone Android toolchain")
        strip = component["strip_prefix"]
        with zipfile.ZipFile(archive) as source:
            for entry in source.infolist():
                if strip and not entry.filename.startswith(strip):
                    raise ValueError("Unexpected archive root: " + entry.filename)
                relative = entry.filename[len(strip):]
                if not relative:
                    continue
                destination = (target / relative).resolve()
                if not destination.is_relative_to(target):
                    raise ValueError("Archive path escaped destination")
                if entry.is_dir():
                    destination.mkdir(parents=True, exist_ok=True)
                else:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    with source.open(entry) as data, destination.open("wb") as output:
                        shutil.copyfileobj(data, output)
        records.append({**component, "installed_destination": str(target)})
        print("Installed verified " + component["id"], flush=True)
    (root / "android-installation.json").write_text(json.dumps(records, indent=2), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("toolchain_root", type=Path)
    install(parser.parse_args().toolchain_root)
