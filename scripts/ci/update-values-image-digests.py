#!/usr/bin/env python3
"""Update image tag and digest fields in a Helm values file."""

from __future__ import annotations

import argparse
from pathlib import Path

from values_lib import SERVICES


def update_values(path: Path, tag: str, digests: dict[str, str]) -> None:
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
                output.append(f"{line[:len(line) - len(line.lstrip())]}tag: {tag}")
                continue
            if stripped.startswith("digest:"):
                output.append(f"{line[:len(line) - len(line.lstrip())]}digest: {digests[service]}")
                continue

        output.append(line)

    path.write_text("\n".join(output) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--values", required=True, type=Path)
    parser.add_argument("--tag", required=True)
    for service in SERVICES:
        parser.add_argument(f"--{service}-digest", required=True)
    args = parser.parse_args()

    digests = {service: getattr(args, f"{service}_digest") for service in SERVICES}
    for service, digest in digests.items():
        if not digest.startswith("sha256:"):
            raise SystemExit(f"{service} digest must start with sha256:")

    update_values(args.values, args.tag, digests)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
