#!/usr/bin/env python3
"""Reject incomplete SDK configurations before starting an expensive build."""

from pathlib import Path
import re
import sys


def read_config(text):
    return dict(re.findall(r"^(CONFIG_[A-Za-z0-9_-]+)=(.*)$", text, re.MULTILINE))


def check_sdk_path(root):
    interpreter = str(root) + "/staging_dir/hostpkg/bin/python3.14"
    if len(interpreter) > 124:
        return ["SDK path too long for Python package installation: " + interpreter]
    return []


def check_config(config_text, seed_text, log, architecture):
    config = read_config(config_text)
    errors = []
    if re.search(r"(^|:)\s*error:", log, re.MULTILINE | re.IGNORECASE):
        errors.append("Kconfig reported an error; see netdata-defconfig.log")
    if config.get("CONFIG_TARGET_ARCH_PACKAGES") != '"' + architecture + '"':
        errors.append("SDK ABI mismatch: expected " + architecture)
    for flag in ("ALL", "ALL_KMODS", "ALL_NONSHARED", "SIGN_EACH_PACKAGE"):
        if config.get("CONFIG_" + flag) == "y":
            errors.append("Unexpected global SDK selection: CONFIG_" + flag)
    required = {name for name, value in read_config(seed_text).items()
                if name.startswith(("CONFIG_PACKAGE_", "CONFIG_NETDATA_")) and value in ("y", "m")}
    required.update(("CONFIG_PACKAGE_zlib", "CONFIG_PACKAGE_libncurses"))
    for name in sorted(required):
        if config.get(name) not in ("y", "m"):
            errors.append("Missing selected package, feature or dependency: " + name)
    return errors


def main():
    config, seed, log, architecture = sys.argv[1:]
    errors = check_config(Path(config).read_text(), Path(seed).read_text(),
                          Path(log).read_text(errors="replace"), architecture)
    errors.extend(check_sdk_path(Path(config).resolve().parent))
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("SDK configuration validated: " + architecture)
    return 0


if __name__ == "__main__":
    sys.exit(main())
