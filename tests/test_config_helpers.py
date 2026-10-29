"""Exercise generated stock defaults and Go collector install/remove behavior."""

import configparser
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run_helper(name, *arguments):
    subprocess.run(["bash", (ROOT / "netdata/files" / name).as_posix(),
                    *[str(arg) for arg in arguments]], check=True)


class ConfigHelpers(unittest.TestCase):
    def test_go_collector_install_remove(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stock = root / "usr/lib/netdata/conf.d"
            configs = stock / "go.d"
            configs.mkdir(parents=True)
            user = root / "etc/netdata/go.d.conf"
            user.parent.mkdir(parents=True)
            user.write_text("custom user configuration")
            for name in ["mysql", "dnsmasq_dhcp"]:
                (configs / (name + ".conf")).write_text("# stock jobs template\n")
            run_helper("update-go-config", root.as_posix())
            output = (stock / "go.d.conf").read_text()
            self.assertIn("default_run: no", output)
            self.assertIn("  mysql: yes", output)
            self.assertIn("  dnsmasq_dhcp: yes", output)
            self.assertNotIn("snmp: yes", output)
            (configs / "mysql.conf").unlink()
            run_helper("update-go-config", root.as_posix())
            self.assertNotIn("mysql: yes", (stock / "go.d.conf").read_text())
            self.assertEqual(user.read_text(), "custom user configuration")

    def test_runtime_defaults_are_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "netdata.conf"
            config.write_text("[plugins]\nproc = yes\n[health]\nenabled = yes\n")
            for _ in range(2):
                run_helper("render-config", config.as_posix(), "PROC=no", "TC=yes", "HEALTH=no")
            parsed = configparser.ConfigParser()
            parsed.read(config)
            self.assertEqual(parsed["plugins"]["proc"], "no")
            self.assertEqual(parsed["plugins"]["tc"], "yes")
            self.assertEqual(parsed["health"]["enabled"], "no")
            self.assertEqual(config.read_text().count("proc ="), 1)


if __name__ == "__main__":
    unittest.main()
