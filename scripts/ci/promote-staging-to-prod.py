#!/usr/bin/env python3
"""Copy verified staging image tags and digests into production values."""

from __future__ import annotations

import argparse
from pathlib import Path

from values_lib import SERVICES, read_images


def update_prod(path: Path, staging: dict[str, dict[str, str]]) -> None:
    lines = path.read_text().splitlines()
    output: list[str] = []
    in_images = False
    service: str | None = None

    for line in lines:
        stripped = line.strip()
        if stripped == "images:":
            in_images = True
            service = None
            output.append(line)
            continue
        if in_images and line and not line.startswith(" "):
            in_images = False
            service = None
        if in_images and line.startswith("  ") and not line.startswith("    ") and stripped.endswith(":"):
            candidate = stripped[:-1]
            service = candidate if candidate in SERVICES else None
            output.append(line)
            continue
        if in_images and service in SERVICES and line.startswith("    "):
            if stripped.startswith("tag:"):
                tag = staging[service].get("tag", "")
                output.append(f"{line[:len(line) - len(line.lstrip())]}tag: {tag}")
                continue
            if stripped.startswith("digest:"):
                digest = staging[service].get("digest", "")
                output.append(f"{line[:len(line) - len(line.lstrip())]}digest: {digest}")
                continue
        output.append(line)

    path.write_text("\n".join(output) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--staging", required=True, type=Path)
    parser.add_argument("--prod", required=True, type=Path)
    args = parser.parse_args()

    staging = read_images(args.staging)
    for service in SERVICES:
        digest = staging[service].get("digest", "")
        if not digest.startswith("sha256:"):
            raise SystemExit(f"staging {service} digest is missing or invalid")

    update_prod(args.prod, staging)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
