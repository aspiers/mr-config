#!/usr/bin/env python3

import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "scripts/install-octobox-sync-watchdog"


class InstallTest(unittest.TestCase):
    def test_scoped_install_is_reproducible_without_activation(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            home = pathlib.Path(temporary)
            repo = home / "checkout"
            repo.mkdir()
            (repo / "docker-compose.yml").write_text("services: {}\n")
            environment = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config")}
            command = ["bash", str(INSTALLER), str(repo), "--no-activate"]
            subprocess.run(command, env=environment, check=True)
            units = home / ".config/systemd/user"
            first = {path.name: path.read_text() for path in units.iterdir()}
            subprocess.run(command, env=environment, check=True)
            self.assertEqual(first, {path.name: path.read_text() for path in units.iterdir()})
            link = home / "bin/octobox-sync-watchdog"
            self.assertEqual((ROOT / "scripts/octobox-sync-watchdog").resolve(), link.resolve())
            service = first["octobox-sync-watchdog.service"]
            timer = first["octobox-sync-watchdog.timer"]
            self.assertNotIn("EnvironmentFile", service)
            self.assertIn("TimeoutStartSec=55s", service)
            self.assertIn("OnUnitActiveSec=1min", timer)
            self.assertIn("AccuracySec=1s", timer)
            subprocess.run(["systemd-analyze", "--user", "verify", *(str(path) for path in units.iterdir())],
                           env=environment, check=True)

    def test_install_refuses_to_overwrite_an_existing_script(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            home = pathlib.Path(temporary)
            repo = home / "checkout"
            repo.mkdir()
            (repo / "docker-compose.yml").write_text("services: {}\n")
            (home / "bin").mkdir()
            script = home / "bin/octobox-sync-watchdog"
            script.write_text("keep me\n")
            result = subprocess.run(["bash", str(INSTALLER), str(repo), "--no-activate"],
                                    env={**os.environ, "HOME": str(home)}, capture_output=True, text=True)
            self.assertNotEqual(0, result.returncode)
            self.assertEqual("keep me\n", script.read_text())


if __name__ == "__main__":
    unittest.main()
