#!/usr/bin/env python3
"""Package existing Web and Linux exports with notices and installation notes."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def package() -> None:
    version = re.search(r'config/version="([^"]+)"', (ROOT / "game/project.godot").read_text())[1]
    target = ROOT / "builds/releases"
    target.mkdir(parents=True, exist_ok=True)
    result = []
    for platform, entry in (("web", "index.html"), ("linux", "chill-town.x86_64")):
        source = ROOT / "builds" / platform
        if not (source / entry).is_file():
            raise SystemExit(f"Missing {source / entry}; export both platforms first")
        files = sorted(p for p in source.rglob("*") if p.is_file() and not p.name.startswith(".") and p.name not in ("LICENSE", "LICENSE-ASSETS.md", "README.md") and not re.match(r"index\.pck-",p.name))
        if platform == "web" and (len(files) > 990 or sum(p.stat().st_size for p in files) > 500_000_000 or any(p.stat().st_size > 200_000_000 for p in files)):
            raise SystemExit("Web package exceeds itch.io upload limits")
        if platform == "web":
            release = json.loads((source / "release.json").read_text())
            files = [p for p in files if p.suffix != ".pck" or p.name == release["pack"]]
        archive = target / f"Chill_Town_{version}_{platform}.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
            for path in files:
                bundle.write(path, path.relative_to(source))
            for name in ("LICENSE", "LICENSE-ASSETS.md", "THIRD_PARTY_NOTICES.md", "licenses/CC-BY-4.0.txt", "licenses/GODOT-THIRD-PARTY.txt", "game/GODOT-LICENSE.txt"):
                if Path(name).name not in [p.name for p in files]:
                    bundle.write(ROOT / name, Path(name).name)
            bundle.write(ROOT / "docs/RELEASE.md", "README.md")
        with zipfile.ZipFile(archive) as bundle:
            if bundle.testzip() is not None or entry not in bundle.namelist():
                raise SystemExit("Release archive validation failed")
        result.append({"file": archive.name, "bytes": archive.stat().st_size, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()})
        print(archive)
    (target / "checksums.json").write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    package()
