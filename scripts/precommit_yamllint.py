#!/usr/bin/env python3
"""Run yamllint locally when the CLI is available."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys


CONFIG = "{extends: relaxed, rules: {new-lines: disable, line-length: disable}}"


def main() -> int:
    yamllint = shutil.which("yamllint")
    if not yamllint:
        print("yamllint CLI not found locally; skipping.")
        return 0

    files = [f for f in sys.argv[1:] if not f.replace("\\", "/").startswith("k8s/templates/")]
    if not files:
        return 0

    env = os.environ.copy()
    env["PYTHONUTF8"] = "1"
    return subprocess.call([yamllint, "-d", CONFIG, *files], env=env)


if __name__ == "__main__":
    raise SystemExit(main())
