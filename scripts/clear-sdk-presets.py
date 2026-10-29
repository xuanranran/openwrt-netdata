#!/usr/bin/env python3
"""Clear inherited SDK package selections without changing its ABI settings."""

from pathlib import Path
import re
import sys


def clear_presets(seed, sdk_config):
    explicit = set(re.findall(r"^(?:# )?CONFIG_(PACKAGE_[A-Za-z0-9_-]+)(?:=| is not set$)",
                              seed, re.MULTILINE))
    inherited = set(re.findall(r"^config (PACKAGE_[A-Za-z0-9_-]+)$",
                               sdk_config, re.MULTILINE))
    disabled = "".join("# CONFIG_" + name + " is not set\n"
                       for name in sorted(inherited - explicit))
    return seed.rstrip() + "\n" + disabled


if __name__ == "__main__":
    seed_path, sdk_path = map(Path, sys.argv[1:])
    seed_path.write_text(clear_presets(seed_path.read_text(), sdk_path.read_text()))
