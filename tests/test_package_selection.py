"""Check module selection using GNU make without an OpenWrt SDK."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULES = {
    "apps": ("plugin-apps", "ENABLE_PLUGIN_APPS"),
    "debugfs": ("plugin-debugfs", "ENABLE_PLUGIN_DEBUGFS"),
    "perf": ("plugin-perf", "ENABLE_PLUGIN_PERF"),
    "slabinfo": ("plugin-slabinfo", "ENABLE_PLUGIN_SLABINFO"),
    "python": ("plugin-pythond", "ENABLE_PLUGIN_PYTHON"),
    "charts": ("plugin-chartsd", "ENABLE_PLUGIN_CHARTS"),
    "network-viewer": ("plugin-network-viewer", "ENABLE_PLUGIN_NETWORK_VIEWER"),
    "local-listeners": ("plugin-local-listeners", "ENABLE_PLUGIN_LOCAL_LISTENERS"),
    "cgroup-network": ("plugin-cgroup-network", "ENABLE_PLUGIN_CGROUP_NETWORK"),
    "nfacct": ("plugin-nfacct", "ENABLE_PLUGIN_NFACCT"),
    "cups": ("plugin-cups", "ENABLE_PLUGIN_CUPS"),
    "go": ("plugin-go", "ENABLE_PLUGIN_GO"),
    "scripts": ("plugin-scripts", "ENABLE_PLUGIN_SCRIPTS"),
    "statsd": ("plugin-statsd", "ENABLE_PLUGIN_STATSD"),
    "otel": ("plugin-otel", "ENABLE_PLUGIN_OTEL"),
    "netflow": ("plugin-netflow", "ENABLE_PLUGIN_NETFLOW"),
    "systemd-journal": ("plugin-systemd-journal", "ENABLE_PLUGIN_SYSTEMD_JOURNAL"),
    "ebpf": ("plugin-ebpf", "ENABLE_PLUGIN_EBPF"),
}


def evaluate(selected, core_features=True):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "include").mkdir()
        (root / "rules.mk").write_text("")
        (root / "include/cmake.mk").write_text("")
        (root / "include/nls.mk").write_text("")
        for language, content in [
            ("golang/golang-values.mk", "GO_ARCH:=amd64\n"),
            ("rust/rust-values.mk", "RUSTC_TARGET_ARCH:=x86_64-unknown-linux-musl\nRUSTC_TARGET_UPPER:=X86_64_UNKNOWN_LINUX_MUSL\n"),
        ]:
            path = root / "feeds/packages/lang" / language
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        (root / "include/package.mk").write_text(
            "BuildPackage = $(info PACKAGE=$(1))\n"
            "Download = $(info DOWNLOAD=$(1))\n"
        )
        harness = root / "check.mk"
        harness.write_text(
            "include Makefile\n"
            "$(info COMPONENTS=$(strip $(NETDATA_COMPONENTS)))\n"
            "$(info OPTIONS=$(strip $(CMAKE_OPTIONS)))\n"
            "$(info DEPENDS=$(PKG_BUILD_DEPENDS))\n"
            "$(info PYTHON=$(strip $(call Package/netdata-plugin-python)))\n"
            "$(info INSTALL=$(strip $(call Package/netdata-plugin-apps/install,/stage)))\n"
            "$(info MYSQL=$(strip $(call Package/netdata-collector-mysql/install,/stage)))\n"
            "all:;\n"
        )
        command = [shutil.which("make") or "make", "--no-print-directory", "-f", str(harness),
                   "TOPDIR=" + root.as_posix(), "INCLUDE_DIR=" + (root / "include").as_posix(),
                   "PKG_INSTALL_DIR=/install"]
        command.extend("CONFIG_PACKAGE_netdata-plugin-" + name + "=m" for name in selected)
        if core_features:
            command.extend(["CONFIG_NETDATA_DBENGINE=y", "CONFIG_NETDATA_LIBUNWIND=y"])
        if "dashboard" in selected:
            command.append("CONFIG_PACKAGE_netdata-dashboard-v3=m")
        result = subprocess.run(command, cwd=ROOT / "netdata", capture_output=True, text=True)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        return result.stdout


class PackageSelection(unittest.TestCase):
    def test_core_only(self):
        output = evaluate([])
        self.assertIn("COMPONENTS=netdata\n", output)
        self.assertNotIn("DOWNLOAD=", output)
        self.assertIn("DEPENDS=protobuf/host", output)
        self.assertNotIn("rust/host", output)
        self.assertIn("-DUSE_LTO=On", output)
        for component, option in MODULES.values():
            self.assertIn("-D" + option + "=Off", output)

    def test_individual_modules(self):
        for name, (component, option) in MODULES.items():
            with self.subTest(module=name):
                output = evaluate([name])
                self.assertIn("COMPONENTS=netdata " + component + "\n", output)
                self.assertIn("-D" + option + "=On", output)

    def test_minimal_core(self):
        output = evaluate([], core_features=False)
        self.assertIn("-DENABLE_DBENGINE=Off", output)
        self.assertIn("-DENABLE_LIBUNWIND=Off", output)

    def test_all_modules_and_dashboard(self):
        output = evaluate([*MODULES, "dashboard"])
        self.assertIn("DOWNLOAD=netdata-dashboard", output)
        self.assertIn("+python3-yaml", output)
        self.assertIn("/install/plugin-apps/. /stage/", output)
        for name in MODULES:
            self.assertIn("PACKAGE=netdata-plugin-" + name + "\n", output)
        self.assertIn("PACKAGE=netdata-collector-snmp\n", output)
        self.assertNotIn("PACKAGE=netdata-collector-systemdunits\n", output)
        self.assertIn("/install/plugin-go/usr/lib/netdata/conf.d/go.d/mysql.conf", output)
        self.assertIn("golang1.27/host", output)
        self.assertIn("rust/host", output)


if __name__ == "__main__":
    unittest.main()
