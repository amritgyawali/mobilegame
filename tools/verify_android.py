"""Verify the development APK's archive, ABI, manifest, and permission contract."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import struct
import sys
import zipfile
from check_android_policy import android_options, validate

validate()
options = android_options()
package = options["package/unique_name"].strip('"')
version_code = int(options["version/code"])
version_name = options["version/name"].strip('"')
apk, aapt = map(Path, sys.argv[1:3])


def check_arm64_layout(data, name):
    """Check 16 KB LOAD alignment and RELRO separation, not runtime behavior.

    Android permits a non-page-ending RELRO in its own LOAD segment when its
    rounded protection range does not cover subsequent writable data.
    https://developer.android.com/guide/practices/page-sizes
    """
    assert data[:6] == b"\x7fELF\x02\x01", "Expected little-endian ELF64: " + name
    offset = struct.unpack_from("<Q", data, 32)[0]
    entry_size, count = struct.unpack_from("<HH", data, 54)
    assert entry_size >= 56 and offset + entry_size * count <= len(data), "Invalid ELF program headers"
    headers = [struct.unpack_from("<IIQQQQQQ", data, offset + i * entry_size) for i in range(count)]
    loads = [header for header in headers if header[0] == 1]
    assert loads, "ELF has no LOAD segments: " + name
    for header in loads:
        assert header[7] >= 16384 and (header[2] - header[3]) % 16384 == 0, "Unaligned ELF LOAD: " + name
    for relro in (header for header in headers if header[0] == 0x6474E552):
        end = relro[3] + relro[6]
        if end % 16384:
            same_load = lambda header: header[3] == relro[3] and header[6] == relro[6]
            assert any(same_load(header) for header in loads), "RELRO shares unaligned writable LOAD: " + name
            rounded_end = (end + 16383) // 16384 * 16384
            assert not any(header[1] & 2 and header[3] < rounded_end and header[3] + header[6] > end for header in loads if not same_load(header)), "RELRO overlaps writable data: " + name


with zipfile.ZipFile(apk) as archive:
    assert archive.testzip() is None, "Corrupt ZIP entry"
    names = set(archive.namelist())
    for required in ("AndroidManifest.xml", "classes.dex", "lib/arm64-v8a/libgodot_android.so", "lib/armeabi-v7a/libgodot_android.so"):
        assert required in names, required
    assert any("scripts/main.gd" in name for name in names), "Missing game script"
    assert not any(name.startswith("assets/tests/") for name in names), "Tests included in APK"
    for name in sorted(names):
        if name.startswith("lib/arm64-v8a/") and name.endswith(".so"):
            check_arm64_layout(archive.read(name), name)
alignment = subprocess.run([str(aapt.parent / "zipalign.exe"), "-c", "-P", "16", "4", str(apk)], capture_output=True, text=True)
assert alignment.returncode == 0, "APK ZIP alignment failed: " + alignment.stdout + alignment.stderr
manifest = subprocess.check_output([str(aapt), "dump", "badging", str(apk)], text=True, encoding="utf-8")
assert f"package: name='{package}' versionCode='{version_code}' versionName='{version_name}'" in manifest
assert "sdkVersion:'24'" in manifest and "targetSdkVersion:'36'" in manifest
assert "android.hardware.screen.portrait" in manifest
assert "application-debuggable" in manifest, "Expected a development APK"
assert not re.search(r"^uses-permission", manifest, re.MULTILINE), "Unexpected Android permission"
result = {
    "artifact": str(apk.resolve()), "bytes": apk.stat().st_size,
    "sha256": hashlib.file_digest(apk.open("rb"), "sha256").hexdigest(),
    "package": package, "versionCode": version_code, "versionName": version_name,
    "minSdk": 24, "targetSdk": 36, "abis": ["arm64-v8a", "armeabi-v7a"],
    "permissions": [], "debugBuild": True, "physicalDeviceTested": False, "platform": "Android",
    "nativeElf16KbLayoutChecked": True, "zipAlignment16KbChecked": True, "pageSizeRuntimeTested": False,
}
apk.with_suffix(".json").write_text(json.dumps(result, indent=2), encoding="utf-8")
apk.with_suffix(".manifest.txt").write_text(manifest, encoding="utf-8")
print(json.dumps(result, indent=2))
