"""Keep Kconfig failures and missing base-feed libraries out of SDK builds."""

import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("sdk_config", ROOT / "scripts/check-sdk-config.py")
SDK_CONFIG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SDK_CONFIG)
PRESET_SPEC = importlib.util.spec_from_file_location("sdk_presets", ROOT / "scripts/clear-sdk-presets.py")
SDK_PRESETS = importlib.util.module_from_spec(PRESET_SPEC)
PRESET_SPEC.loader.exec_module(SDK_PRESETS)
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

    def test_external_toolchain_mode_cannot_be_silently_dropped(self):
        seed = SEED + "CONFIG_NETDATA_EXTERNAL_TOOLCHAINS=y\n"
        self.assertTrue(SDK_CONFIG.check_config(CONFIG, seed, "", "x86_64"))
        self.assertEqual(SDK_CONFIG.check_config(
            CONFIG + "CONFIG_NETDATA_EXTERNAL_TOOLCHAINS=y\n", seed, "", "x86_64"), [])
        self.assertTrue(SDK_CONFIG.check_config(
            CONFIG + "CONFIG_NETDATA_EXTERNAL_TOOLCHAINS=y\nCONFIG_NETDATA_FEED_TOOLCHAINS=y\n",
            seed, "", "x86_64"))

    def test_wrong_architecture(self):
        self.assertTrue(self.check(CONFIG.replace('"x86_64"', '"aarch64_generic"')))

    def test_global_defaults_do_not_enable_all_packages(self):
        for flag in ("ALL", "ALL_KMODS", "ALL_NONSHARED", "SIGN_EACH_PACKAGE"):
            with self.subTest(flag=flag):
                self.assertTrue(self.check(CONFIG + "CONFIG_" + flag + "=y\n"))

    def test_physical_sdk_path_fits_python_install_limit(self):
        for target in ("x86-64", "armsr-armv8"):
            with self.subTest(target=target):
                root = "/home/runner/work/_temp/netdata-sdk/" + target + "/" + "a" * 12
                self.assertEqual(SDK_CONFIG.check_sdk_path(root), [])
                old = "/home/runner/work/openwrt-netdata/openwrt-netdata/.sdk/" + target + "/" + "a" * 64
                self.assertTrue(SDK_CONFIG.check_sdk_path(old))

    def test_clear_only_unrequested_package_presets(self):
        sdk = ('config PACKAGE_kmod-unrelated\n\ttristate\n\tdefault m\n'
               'config PACKAGE_zlib\n\tbool\n\tdefault y\n'
               'config GCC_VERSION\n\tstring\n\tdefault "14.4.0"\n')
        seed = 'CONFIG_PACKAGE_zlib=m\nCONFIG_TARGET_x86=y\n'
        result = SDK_PRESETS.clear_presets(seed, sdk)
        self.assertIn('CONFIG_PACKAGE_zlib=m\n', result)
        self.assertIn('# CONFIG_PACKAGE_kmod-unrelated is not set\n', result)
        self.assertNotIn('# CONFIG_PACKAGE_zlib is not set', result)
        self.assertNotIn('CONFIG_GCC_VERSION', result)
        self.assertIn('CONFIG_TARGET_x86=y\n', result)
        self.assertEqual(SDK_PRESETS.clear_presets(result, sdk), result)


if __name__ == "__main__":
    unittest.main()
