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
        "CKV_AWS_130",
        "CKV_AWS_136",
        "CKV_AWS_161",
        "CKV_AWS_23",
        "CKV_AWS_260",
        "CKV_AWS_338",
        "CKV_AWS_341",
        "CKV_AWS_38",
        "CKV_AWS_382",
        "CKV_AWS_39",
        "CKV_AZURE_109",
        "CKV_AZURE_110",
        "CKV_AZURE_114",
        "CKV_AZURE_115",
        "CKV_AZURE_117",
        "CKV_AZURE_136",
        "CKV_AZURE_139",
        "CKV_AZURE_141",
        "CKV_AZURE_160",
        "CKV_AZURE_163",
        "CKV_AZURE_164",
        "CKV_AZURE_165",
        "CKV_AZURE_166",
        "CKV_AZURE_167",
        "CKV_AZURE_168",
        "CKV_AZURE_170",
        "CKV_AZURE_171",
        "CKV_AZURE_172",
        "CKV_AZURE_189",
        "CKV_AZURE_226",
        "CKV_AZURE_227",
        "CKV_AZURE_232",
        "CKV_AZURE_233",
        "CKV_AZURE_237",
        "CKV_AZURE_41",
        "CKV_AZURE_42",
        "CKV_AZURE_6",
        "CKV2_AWS_12",
        "CKV2_AWS_5",
        "CKV2_AWS_50",
        "CKV2_AWS_57",
        "CKV2_AWS_64",
        "CKV2_AZURE_31",
        "CKV2_AZURE_32",
        "CKV2_AZURE_57",
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
