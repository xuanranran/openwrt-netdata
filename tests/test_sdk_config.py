"""Keep Kconfig failures and missing base-feed libraries out of SDK builds."""

import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("sdk_config", ROOT / "scripts/check-sdk-config.py")
SDK_CONFIG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SDK_CONFIG)
SEED = "CONFIG_PACKAGE_netdata=m\nCONFIG_PACKAGE_netdata-plugin-otel=m\n"
CONFIG = ('CONFIG_TARGET_ARCH_PACKAGES="x86_64"\n' + SEED +
          "CONFIG_PACKAGE_zlib=m\nCONFIG_PACKAGE_libncurses=m\n")


class SDKConfig(unittest.TestCase):
    def check(self, config=CONFIG, log=""):
        return SDK_CONFIG.check_config(config, SEED, log, "x86_64")

    def test_valid_config_and_harmless_warning(self):
        self.assertEqual(self.check(log="Config-build.in:12:warning: defaults for choice values not supported"), [])

    def test_recursive_dependency_even_when_make_succeeds(self):
        self.assertTrue(self.check(log="tmp/.config-package.in:74403:error: recursive dependency detected!"))

    def test_missing_base_dependencies(self):
        for package in ("zlib", "libncurses"):
            with self.subTest(package=package):
                self.assertTrue(self.check(CONFIG.replace("CONFIG_PACKAGE_" + package + "=m\n", "")))

    def test_dropped_module_selection(self):
        self.assertTrue(self.check(CONFIG.replace("CONFIG_PACKAGE_netdata-plugin-otel=m\n", "")))

    def test_wrong_architecture(self):
        self.assertTrue(self.check(CONFIG.replace('"x86_64"', '"aarch64_generic"')))

    def test_global_defaults_do_not_enable_all_packages(self):
        for flag in ("ALL", "ALL_KMODS", "ALL_NONSHARED", "SIGN_EACH_PACKAGE"):
            with self.subTest(flag=flag):
                self.assertTrue(self.check(CONFIG + "CONFIG_" + flag + "=y\n"))


if __name__ == "__main__":
    unittest.main()
