"""Build install ZIPs and a Windows Workshop preparation kit. Does not publish anything."""
import json
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
NAMES = ("InfiniteProjects", "SpyRepeat", "BuilderAuto", "AutoTheme")


def write_zip(destination, files):
    destination.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(destination, "w", ZIP_DEFLATED) as archive:
        for source, relative in files:
            archive.write(source, str(relative))
    with ZipFile(destination) as archive:
        if archive.testzip() is not None:
            raise RuntimeError(f"Corrupt ZIP: {destination}")
    print(destination.relative_to(ROOT), destination.stat().st_size, "bytes")


def main():
    bundle, kit = [], []
    for name in NAMES:
        project = ROOT / name
        source = project / "src" / name
        material = project / "workshop"
        metadata = json.loads((material / "metadata.json").read_text(encoding="utf-8"))
        manifest = ET.parse(source / (name + ".modinfo"))
        for node in manifest.findall("./Files/File"):
            if not (source / node.text).is_file():
                raise FileNotFoundError(source / node.text)
        package = []
        for file in sorted(source.iterdir()):
            if file.is_file() and not file.name.startswith("."):
                package.append((file, Path(name) / file.name))
                kit.append((file, Path(name) / "content" / file.name))
        package.append((project / "README.md", Path("README.md")))
        write_zip(project / "dist" / f"{name}-{metadata['version']}.zip", package)
        bundle.extend(package[:-1])
        bundle.append((project / "README.md", Path(name) / "README.md"))
        kit.append((project / "README.md", Path(name) / "content" / "README.md"))
        for file in sorted(material.iterdir()):
            if file.is_file() and not file.name.startswith("."):
                kit.append((file, Path(name) / file.name))
        if not (material / metadata["preview"]).is_file():
            raise FileNotFoundError(material / metadata["preview"])
    bundle.append((ROOT / "INSTALL.md", Path("INSTALL.md")))
    kit.extend([(ROOT / "WORKSHOP.md", Path("UPLOAD.zh-CN.md")),
                (ROOT / "INSTALL.md", Path("INSTALL.md")),
                (ROOT / "LICENSE", Path("LICENSE")),
                (ROOT / "CREDITS.md", Path("CREDITS.md"))])
    write_zip(ROOT / "bundles" / "civ6-mods-preview.zip", bundle)
    destination = ROOT / "bundles" / "steam-workshop-upload-kit.zip"
    write_zip(destination, kit)
    # Verify exact uploader entry points without installing or running the mods.
    with tempfile.TemporaryDirectory(prefix="civ6-workshop-verify-") as temporary:
        with ZipFile(destination) as archive:
            archive.extractall(temporary)
        for name in NAMES:
            content = Path(temporary) / name / "content"
            manifest = ET.parse(content / (name + ".modinfo"))
            for node in manifest.findall("./Files/File"):
                if not (content / node.text).is_file():
                    raise FileNotFoundError(content / node.text)
    print("All four extracted Workshop entry points and manifest files verified.")


if __name__ == "__main__":
    main()
