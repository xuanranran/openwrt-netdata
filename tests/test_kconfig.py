"""Exercise optional library constraints with a real Kconfig evaluator."""

from pathlib import Path
import subprocess
import tempfile
import unittest
import importlib.util

import kconfiglib


ROOT = Path(__file__).resolve().parents[1]
PRESET_SPEC = importlib.util.spec_from_file_location("sdk_presets", ROOT / "scripts/clear-sdk-presets.py")
SDK_PRESETS = importlib.util.module_from_spec(PRESET_SPEC)
PRESET_SPEC.loader.exec_module(SDK_PRESETS)
NETDATA = """
config USE_MUSL
    bool
    default y
config powerpc
    bool
config PACKAGE_libunwind
    bool
    depends on !(USE_MUSL && powerpc)
config PACKAGE_netdata
    bool "Netdata"
    depends on !NETDATA_LIBUNWIND || !(USE_MUSL && powerpc)
    select PACKAGE_libunwind if NETDATA_LIBUNWIND
config PACKAGE_netdata-plugin-go
    bool
    depends on PACKAGE_netdata
"""
CURL = """
config USE_UCLIBC
    bool
config PACKAGE_libopenldap
    bool
    depends on !USE_UCLIBC
config PACKAGE_libcurl
    bool "libcurl"
    depends on !LIBCURL_LDAP || !USE_UCLIBC
    select PACKAGE_libopenldap if LIBCURL_LDAP
"""
CURL_MENU = """if PACKAGE_libcurl

comment "SSL support"

config LIBCURL_LDAP
    bool "LDAP protocol"
    default n

config LIBCURL_HTTP_AUTH
	bool "Enable HTTP authentication support"
	default y
endif
"""


class KconfigMenus(unittest.TestCase):
    def load(self, root, content):
        path = root / "Kconfig"
        path.write_text(content)
        return kconfiglib.Kconfig(path.as_posix(), warn=False)

    def test_netdata_libunwind_is_optional_without_a_dependency_cycle(self):
        menu = (ROOT / "netdata/Config.in").read_text()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            broken = menu.replace('menu "Core features"',
                                  'menu "Core features"\n    depends on PACKAGE_netdata', 1)
            with self.assertRaises(kconfiglib.KconfigError):
                self.load(root, NETDATA + broken)
            config = self.load(root, NETDATA + menu)
            self.assertEqual(config.syms["NETDATA_FEED_TOOLCHAINS"].tri_value, 2)
            config.syms["NETDATA_EXTERNAL_TOOLCHAINS"].set_value(2)
            self.assertEqual(config.syms["NETDATA_FEED_TOOLCHAINS"].tri_value, 0)
            config.syms["PACKAGE_netdata"].set_value(2)
            self.assertEqual(config.syms["PACKAGE_libunwind"].tri_value, 2)
            config.syms["NETDATA_LIBUNWIND"].set_value(0)
            self.assertEqual(config.syms["PACKAGE_netdata"].tri_value, 2)
            self.assertEqual(config.syms["PACKAGE_libunwind"].tri_value, 0)

    def test_curl_patch_preserves_optional_ldap_without_a_cycle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(kconfiglib.KconfigError):
                self.load(root, CURL + CURL_MENU)
            menu = root / "net/curl/Config.in"
            menu.parent.mkdir(parents=True)
            menu.write_text(CURL_MENU)
            patch = ROOT / "scripts/sdk-patches/curl-menu-visibility.patch"
            with patch.open() as source:
                subprocess.run(["patch", "-p1"], cwd=root, stdin=source,
                               check=True, capture_output=True, text=True)
            config = self.load(root, CURL + menu.read_text())
            config.syms["PACKAGE_libcurl"].set_value(2)
            self.assertEqual(config.syms["LIBCURL_LDAP"].tri_value, 0)
            config.syms["LIBCURL_LDAP"].set_value(2)
            self.assertEqual(config.syms["PACKAGE_libopenldap"].tri_value, 2)

    def test_sdk_presets_do_not_force_unrelated_kernel_modules(self):
        sdk = ('config PACKAGE_kmod-unrelated\n    bool\n    default y\n'
               'config PACKAGE_zlib\n    bool\n    default y\n'
               'config GCC_VERSION\n    string\n    default "14.4.0"\n')
        packages = ('config PACKAGE_kmod-unrelated\n    bool "Unrelated kernel module"\n'
                    'config PACKAGE_zlib\n    bool "Zlib"\n'
                    'config PACKAGE_netdata\n    bool "Netdata"\n    select PACKAGE_zlib\n')
        seed = SDK_PRESETS.clear_presets('CONFIG_PACKAGE_netdata=y\n', sdk)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = self.load(root, sdk + packages)
            path = root / '.config'
            path.write_text(seed)
            config.load_config(path.as_posix())
            self.assertEqual(config.syms['PACKAGE_netdata'].tri_value, 2)
            self.assertEqual(config.syms['PACKAGE_zlib'].tri_value, 2)
            self.assertEqual(config.syms['PACKAGE_kmod-unrelated'].tri_value, 0)
            self.assertEqual(config.syms['GCC_VERSION'].str_value, '14.4.0')


if __name__ == "__main__":
    unittest.main()
