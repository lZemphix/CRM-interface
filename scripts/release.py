"""Small, dependency-free release helpers. No signing keys or API credentials."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import re
import shutil
import struct
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = re.compile(
    r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
)
REQUIRED_RUNTIME = ("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")


def metadata(root: Path, tag: str = "") -> dict[str, str]:
    match = re.search(
        r"^version:\s*([^\s#]+)",
        (root / "pubspec.yaml").read_text(encoding="utf-8"),
        re.MULTILINE,
    )
    if match is None:
        raise ValueError("pubspec.yaml must declare a version")
    declared = match[1].strip("\"'")
    version, separator, build = declared.partition("+")
    parsed = VERSION.fullmatch(version)
    if parsed is None or (separator and not re.fullmatch(r"[1-9]\d*", build)):
        raise ValueError("Use SemVer such as 1.2.3+4 or 1.2.3-rc.1+4")
    if parsed[4] and any(
        part.isdigit() and len(part) > 1 and part.startswith("0")
        for part in parsed[4].split(".")
    ):
        raise ValueError("Numeric prerelease identifiers must not have leading zeroes")
    if tag and tag != f"v{version}":
        raise ValueError(f"Release tag must be v{version}, matching pubspec.yaml")
    sdk = (root / ".flutter-version").read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", sdk):
        raise ValueError(".flutter-version must contain one exact Flutter version")
    return {"version": version, "build_number": build or "1", "flutter_version": sdk}


def filename(version: str, platform: str) -> str:
    if VERSION.fullmatch(version) is None or platform not in {
        "windows-x64",
        "macos-arm64",
    }:
        raise ValueError("Invalid archive identity")
    return f"CRM-interface-v{version}-{platform}.zip"


def require_file(path: Path) -> None:
    if not path.is_file() or path.is_symlink():
        raise ValueError(f"Required regular file missing: {path}")


def verify_windows_x64(executable: Path) -> None:
    require_file(executable)
    with executable.open("rb") as stream:
        if stream.read(2) != b"MZ":
            raise ValueError("Windows executable is not PE")
        stream.seek(0x3C)
        offset_bytes = stream.read(4)
        if len(offset_bytes) != 4:
            raise ValueError("Truncated Windows executable")
        stream.seek(struct.unpack("<I", offset_bytes)[0])
        if stream.read(6) != b"PE\0\0\x64\x86":
            raise ValueError("Expected a Windows x64 executable")


def package_windows(root: Path, runtime: Path) -> Path:
    info = metadata(root)
    bundle = root / "build/windows/x64/runner/Release"
    verify_windows_x64(bundle / "crm_interface.exe")
    for name in ("flutter_windows.dll", "data/icudtl.dat", "data/app.so"):
        require_file(bundle / name)
    if not (bundle / "data/flutter_assets").is_dir():
        raise ValueError("Flutter assets are missing")
    for name in REQUIRED_RUNTIME:
        require_file(runtime / name)
    for library in runtime.glob("*.dll"):
        verify_windows_x64(library)
    output = root / "dist/release" / filename(info["version"], "windows-x64")
    output.parent.mkdir(parents=True, exist_ok=True)
    # 'x' refuses silent replacement of an already prepared release package.
    with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED) as archive:
        runtime_files = {path.name.lower(): path for path in runtime.glob("*.dll")}
        for source in sorted(bundle.rglob("*")):
            if source.is_symlink():
                raise ValueError("Symlinks are not allowed in the Windows bundle")
            if source.is_file():
                relative = source.relative_to(bundle)
                if len(relative.parts) == 1 and source.name.lower() in runtime_files:
                    continue
                archive.write(source, f"CRM-interface/{relative.as_posix()}")
        for name, source in sorted(runtime_files.items()):
            require_file(source)
            archive.write(source, f"CRM-interface/{name}")
        archive.write(root / "packaging/windows/README.txt", "CRM-interface/README.txt")
    return output


def package_macos(root: Path) -> Path:
    info = metadata(root)
    source = root / "dist/CRM-macos.zip"
    require_file(source)
    with zipfile.ZipFile(source) as archive:
        required = "CRM-macos/CRM-interface.app/Contents/MacOS/CRM-interface"
        if required not in archive.namelist():
            raise ValueError("Expected .app bundle is missing from the macOS archive")
        if archive.testzip() is not None:
            raise ValueError("Corrupted macOS archive")
    output = root / "dist/release" / filename(info["version"], "macos-arm64")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise ValueError("Refusing to overwrite the macOS release archive")
    shutil.copyfile(source, output)
    return output


def verify_entitlements(path: Path) -> None:
    with path.open("rb") as stream:
        values = plistlib.load(stream)
    for key in ("com.apple.security.app-sandbox", "com.apple.security.network.client"):
        if values.get(key) is not True:
            raise ValueError(f"Required entitlement missing: {key}")
    if values.get("com.apple.security.get-task-allow") is True:
        raise ValueError("Release application must not grant debugger access")


def checksums(root: Path, tag: str = "") -> str:
    info = metadata(root, tag)
    directory = root / "dist/release"
    expected = {
        filename(info["version"], platform)
        for platform in ("windows-x64", "macos-arm64")
    }
    actual = {path.name for path in directory.iterdir()}
    if actual != expected:
        raise ValueError(
            f"Expected exactly two platform archives; got {sorted(actual)}"
        )
    entries = []
    for name in sorted(expected):
        path = directory / name
        require_file(path)
        with zipfile.ZipFile(path) as archive:
            if archive.testzip() is not None:
                raise ValueError(f"Corrupted archive: {name}")
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        entries.append(f"{digest.hexdigest()}  {name}\n")
    build_info = json.dumps(
        {
            **info,
            "commit": os.environ.get("GITHUB_SHA", "unknown"),
            "targets": ["windows-x64", "macos-arm64"],
            "apple_notarization": False,
        },
        indent=2,
    )
    # Keep diagnostics in the job report, never alongside downloadable packages.
    return (
        "## Desktop release verification\n\n"
        f"```json\n{build_info}\n```\n\n"
        "### SHA-256\n\n```text\n" + "".join(entries) + "```\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    meta = commands.add_parser("metadata")
    meta.add_argument("--tag", default="")
    meta.add_argument("--github-output", type=Path)
    windows = commands.add_parser("windows")
    windows.add_argument("--runtime-directory", type=Path, required=True)
    commands.add_parser("macos")
    verify = commands.add_parser("verify-entitlements")
    verify.add_argument("path", type=Path)
    sums = commands.add_parser("checksums")
    sums.add_argument("--tag", default="")
    sums.add_argument("--summary", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "metadata":
            info = metadata(ROOT, args.tag)
            print(json.dumps(info, indent=2))
            if args.github_output:
                with args.github_output.open(
                    "a", encoding="utf-8", newline="\n"
                ) as stream:
                    for key, value in info.items():
                        stream.write(f"{key}={value}\n")
        elif args.command == "windows":
            print(package_windows(ROOT, args.runtime_directory))
        elif args.command == "macos":
            print(package_macos(ROOT))
        elif args.command == "verify-entitlements":
            verify_entitlements(args.path)
        else:
            report = checksums(ROOT, args.tag)
            if args.summary:
                public_directory = (ROOT / "dist/release").resolve()
                destination = args.summary.resolve()
                if (
                    destination == public_directory
                    or public_directory in destination.parents
                ):
                    raise ValueError(
                        "Job summary must be outside the release assets directory"
                    )
                with args.summary.open("a", encoding="utf-8", newline="\n") as stream:
                    stream.write(report)
            print(report)
    except (
        ValueError,
        OSError,
        zipfile.BadZipFile,
        plistlib.InvalidFileException,
    ) as error:
        print(f"Release preparation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
