#!/usr/bin/env python3
"""Run Hadolint locally when available."""

from __future__ import annotations

import shutil
import subprocess
import sys


def main() -> int:
    hadolint = shutil.which("hadolint")
    if not hadolint:
        print("hadolint CLI not found locally; skipping. CI still scans Dockerfiles.")
        return 0

    files = sys.argv[1:]
    if not files:
        return 0

    return subprocess.call([hadolint, *files])


if __name__ == "__main__":
    raise SystemExit(main())
