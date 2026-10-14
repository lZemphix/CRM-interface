import hashlib
import contextlib
import io
import plistlib
import struct
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import release


def pe(machine=b"\x64\x86"):
    return b"MZ" + bytes(58) + struct.pack("<I", 128) + bytes(64) + b"PE\0\0" + machine


class ReleaseToolsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="crm-release-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "pubspec.yaml").write_text(
            "name: fixture\nversion: 1.2.3+4\n", encoding="utf-8"
        )
        (self.root / ".flutter-version").write_text("3.47.2\n", encoding="utf-8")

    def make_bundle(self):
        bundle = self.root / "build/windows/x64/runner/Release"
        (bundle / "data/flutter_assets").mkdir(parents=True)
        (bundle / "crm_interface.exe").write_bytes(pe())
        for name in (
            "flutter_windows.dll",
            "secure_storage_plugin.dll",
            "data/icudtl.dat",
            "data/app.so",
            "data/flutter_assets/AssetManifest.bin",
        ):
            (bundle / name).write_bytes(b"fixture")
        runtime = self.root / "runtime"
        runtime.mkdir()
        for name in release.REQUIRED_RUNTIME:
            (runtime / name).write_bytes(pe())
        docs = self.root / "packaging/windows"
        docs.mkdir(parents=True)
        (docs / "README.txt").write_text("Instructions", encoding="utf-8")
        return bundle, runtime

    def make_macos(self, valid=True):
        directory = self.root / "dist"
        directory.mkdir(exist_ok=True)
        with zipfile.ZipFile(directory / "CRM-macos.zip", "w") as archive:
            archive.writestr(
                "CRM-macos/CRM-interface.app/Contents/MacOS/CRM-interface"
                if valid
                else "wrong.app",
                b"fixture",
            )
        return directory / "CRM-macos.zip"

    def test_version_and_sdk_are_explicit_and_tag_must_match(self):
        self.assertEqual(
            release.metadata(self.root, "v1.2.3"),
            {
                "version": "1.2.3",
                "build_number": "4",
                "flutter_version": "3.47.2",
            },
        )
        for tag in ("v1.2.4", "1.2.3", "v1.2.3;echo bad", "../v1.2.3"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release.metadata(self.root, tag)

    def test_prerelease_and_default_build_number(self):
        (self.root / "pubspec.yaml").write_text(
            "version: 2.0.0-rc.1\n", encoding="utf-8"
        )
        self.assertEqual(
            release.metadata(self.root, "v2.0.0-rc.1")["build_number"], "1"
        )

    def test_invalid_versions_are_rejected_before_any_build_or_shell_output(self):
        for value in (
            "",
            "01.2.3",
            "1.2",
            "1.2.3+0",
            "1.2.3+01",
            "1.2.3-rc.01",
            "../1.2.3",
            "1.2.3+4+5",
        ):
            with self.subTest(value=value):
                (self.root / "pubspec.yaml").write_text(
                    f"version: {value}\n", encoding="utf-8"
                )
                with self.assertRaises(ValueError):
                    release.metadata(self.root)

    def test_moving_sdk_channel_is_not_allowed(self):
        (self.root / ".flutter-version").write_text("stable\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            release.metadata(self.root)

    def test_only_requested_platform_names_are_supported(self):
        self.assertEqual(
            release.filename("1.2.3", "macos-arm64"),
            "CRM-interface-v1.2.3-macos-arm64.zip",
        )
        for platform in ("linux", "macos-x64", "windows-arm64", "../windows-x64"):
            with self.subTest(platform=platform), self.assertRaises(ValueError):
                release.filename("1.2.3", platform)

    def test_windows_packaging_contains_whole_bundle_and_app_local_runtime(self):
        bundle, runtime = self.make_bundle()
        (bundle / "msvcp140.dll").write_bytes(b"stale CRT")
        output = release.package_windows(self.root, runtime)
        with zipfile.ZipFile(output) as archive:
            for name in (
                "crm_interface.exe",
                "flutter_windows.dll",
                "secure_storage_plugin.dll",
                "data/app.so",
                "data/flutter_assets/AssetManifest.bin",
                "README.txt",
                *release.REQUIRED_RUNTIME,
            ):
                self.assertIn(f"CRM-interface/{name}", archive.namelist())
            self.assertEqual(archive.read("CRM-interface/msvcp140.dll"), pe())
            self.assertEqual(archive.testzip(), None)
        with self.assertRaises(FileExistsError):
            release.package_windows(self.root, runtime)

    def test_incomplete_windows_bundle_is_not_published(self):
        bundle, runtime = self.make_bundle()
        (bundle / "data/app.so").unlink()
        with self.assertRaises(ValueError):
            release.package_windows(self.root, runtime)
        self.assertFalse((self.root / "dist/release").exists())

    def test_missing_runtime_and_wrong_architecture_are_rejected(self):
        bundle, runtime = self.make_bundle()
        (runtime / "vcruntime140_1.dll").unlink()
        with self.assertRaises(ValueError):
            release.package_windows(self.root, runtime)
        (runtime / "vcruntime140_1.dll").write_bytes(pe(b"\x4c\x01"))
        with self.assertRaises(ValueError):
            release.package_windows(self.root, runtime)
        (runtime / "vcruntime140_1.dll").write_bytes(pe())
        (bundle / "crm_interface.exe").write_bytes(pe(b"\x64\xaa"))
        with self.assertRaises(ValueError):
            release.package_windows(self.root, runtime)

    def test_truncated_executable_is_not_accepted(self):
        executable = self.root / "fixture.exe"
        for data in (b"", b"MZ", pe()[:100]):
            with self.subTest(data=data):
                executable.write_bytes(data)
                with self.assertRaises(ValueError):
                    release.verify_windows_x64(executable)

    def test_macos_archive_preserves_ditto_bytes_and_refuses_overwrite(self):
        source = self.make_macos()
        output = release.package_macos(self.root)
        self.assertEqual(source.read_bytes(), output.read_bytes())
        with self.assertRaises(ValueError):
            release.package_macos(self.root)

    def test_invalid_macos_bundle_is_not_accepted(self):
        self.make_macos(valid=False)
        with self.assertRaises(ValueError):
            release.package_macos(self.root)

    def test_release_requires_both_archives_and_checksums_match(self):
        _, runtime = self.make_bundle()
        windows = release.package_windows(self.root, runtime)
        with self.assertRaises(ValueError):
            release.checksums(self.root, "v1.2.3")
        self.make_macos()
        macos = release.package_macos(self.root)
        report = release.checksums(self.root, "v1.2.3")
        for archive in (windows, macos):
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            self.assertIn(f"{digest}  {archive.name}", report)
        self.assertIn('"apple_notarization": false', report)
        self.assertIn('"flutter_version": "3.47.2"', report)
        self.assertEqual(
            {path.name for path in windows.parent.iterdir()},
            {windows.name, macos.name},
        )
        self.assertEqual(release.checksums(self.root, "v1.2.3"), report)

    def test_cli_writes_summary_outside_assets_and_preserves_existing_summary(self):
        _, runtime = self.make_bundle()
        release.package_windows(self.root, runtime)
        self.make_macos()
        release.package_macos(self.root)
        summary = self.root / "job-summary.md"
        summary.write_text("Existing job report\n", encoding="utf-8")
        args = ["release.py", "checksums", "--tag", "v1.2.3", "--summary", str(summary)]
        with (
            patch.object(release, "ROOT", self.root),
            patch.object(sys, "argv", args),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(release.main(), 0)
        content = summary.read_text(encoding="utf-8")
        self.assertTrue(content.startswith("Existing job report\n"))
        self.assertIn("Desktop release verification", content)
        self.assertEqual(len(list((self.root / "dist/release").iterdir())), 2)
        args[-1] = str(self.root / "dist/release/extra.md")
        with (
            patch.object(release, "ROOT", self.root),
            patch.object(sys, "argv", args),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            self.assertEqual(release.main(), 1)
        self.assertFalse((self.root / "dist/release/extra.md").exists())

    def test_crc_corruption_still_blocks_publication(self):
        _, runtime = self.make_bundle()
        release.package_windows(self.root, runtime)
        self.make_macos()
        archive = release.package_macos(self.root)
        data = archive.read_bytes().replace(b"fixture", b"fiXture", 1)
        archive.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "Corrupted archive"):
            release.checksums(self.root)

    def test_unexpected_files_block_release_upload(self):
        _, runtime = self.make_bundle()
        release.package_windows(self.root, runtime)
        self.make_macos()
        release.package_macos(self.root)
        (self.root / "dist/release/.env").write_text("fixture", encoding="utf-8")
        with self.assertRaises(ValueError):
            release.checksums(self.root)

    def test_release_entitlements_keep_network_and_sandbox_without_debug_access(self):
        path = self.root / "entitlements.plist"
        good = {
            "com.apple.security.app-sandbox": True,
            "com.apple.security.network.client": True,
        }
        path.write_bytes(plistlib.dumps(good))
        release.verify_entitlements(path)
        for bad in (
            {},
            {**good, "com.apple.security.app-sandbox": False},
            {**good, "com.apple.security.get-task-allow": True},
        ):
            with self.subTest(bad=bad):
                path.write_bytes(plistlib.dumps(bad))
                with self.assertRaises(ValueError):
                    release.verify_entitlements(path)

    def test_workflow_pins_actions_and_has_no_linux_or_intel_build(self):
        project = Path(__file__).resolve().parents[2]
        workflow = (project / ".github/workflows/desktop-release.yml").read_text(
            encoding="utf-8"
        )
        composite = (project / ".github/actions/setup-flutter/action.yml").read_text(
            encoding="utf-8"
        )
        for line in (workflow + "\n" + composite).splitlines():
            if "uses:" in line and "./" not in line:
                self.assertRegex(line, r"uses: [\w/-]+@[0-9a-f]{40}(?:\s|$)")
        self.assertNotIn("ubuntu", workflow)
        self.assertNotIn("macos-15-intel", workflow)
        self.assertNotIn("--clobber", workflow)
        self.assertIn("needs: [checks, windows, macos]", workflow)
        self.assertIn("types: [published]", workflow)
        self.assertIn('--summary "$GITHUB_STEP_SUMMARY"', workflow)
        self.assertIn('dist/release/*.zip --repo "$GITHUB_REPOSITORY"', workflow)


if __name__ == "__main__":
    unittest.main()
