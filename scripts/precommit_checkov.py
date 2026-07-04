#!/usr/bin/env python3
"""Run Checkov locally when the CLI is available.

CI remains the authoritative security gate. This wrapper avoids blocking
Windows developers when Checkov is not installed or when the upstream
pre-commit package hits platform-specific encoding issues.
"""

from __future__ import annotations

import os
import shutil
import subprocess


SKIP_CHECKS = ",".join(
    [
        "CKV_GHA_7",
    ]
)


def main() -> int:
    checkov = shutil.which("checkov")
    if not checkov:
        print("checkov CLI not found locally; skipping. CI enforces Checkov.")
        return 0

    env = os.environ.copy()
    env["PYTHONUTF8"] = "1"
    return subprocess.call(
        [
            checkov,
            "-d",
            ".",
            "--quiet",
            "--framework",
            "terraform,kubernetes,dockerfile,github_actions",
            "--skip-path",
            "tests/policy",
            "--skip-check",
            SKIP_CHECKS,
        ],
        env=env,
    )


if __name__ == "__main__":
    raise SystemExit(main())
