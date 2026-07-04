#!/usr/bin/env python3
"""Small Terraform wrapper for local pre-commit."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


ENV_DIRS = [
    Path("terraform/openstack"),
]


def run(command: list[str]) -> int:
    print("+ " + " ".join(command))
    return subprocess.call(command)


def fmt() -> int:
    return run(["terraform", "fmt", "-check", "-recursive", "terraform"])


def validate() -> int:
    status = 0
    for env_dir in ENV_DIRS:
        if not (env_dir / ".terraform").exists():
            print(f"{env_dir}: not initialized; skipping local validate.")
            print("Run terraform init in this environment before relying on local validate.")
            continue
        status = run(["terraform", f"-chdir={env_dir}", "validate", "-no-color"]) or status
    return status


def main() -> int:
    if not shutil.which("terraform"):
        print("terraform CLI not found locally; skipping.")
        return 0

    if len(sys.argv) != 2 or sys.argv[1] not in {"fmt", "validate"}:
        print("usage: precommit_terraform.py [fmt|validate]")
        return 2

    return fmt() if sys.argv[1] == "fmt" else validate()


if __name__ == "__main__":
    raise SystemExit(main())
