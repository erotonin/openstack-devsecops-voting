#!/usr/bin/env python3
"""Run Semgrep from pre-commit when the CLI is available locally.

GitHub Actions enforces Semgrep on Linux. This wrapper keeps local pre-commit
usable on Windows machines, where the upstream Semgrep pre-commit package does
not install natively.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    semgrep = shutil.which("semgrep")
    if not semgrep:
        print("semgrep CLI not found locally; skipping. CI enforces Semgrep.")
        return 0

    targets = [arg for arg in sys.argv[1:] if Path(arg).exists()]
    if not targets:
        targets = ["."]

    return subprocess.call([semgrep, "--config=auto", "--error", *targets])


if __name__ == "__main__":
    raise SystemExit(main())
