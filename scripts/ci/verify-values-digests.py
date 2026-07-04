#!/usr/bin/env python3
"""Verify values files pin immutable image digests and emit image refs."""

from __future__ import annotations

import argparse
from pathlib import Path

from values_lib import SERVICES, read_images


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--values", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()

    base = read_images(args.base)
    overlay = read_images(args.values)
    refs: dict[str, str] = {}

    for service in SERVICES:
        repository = overlay[service].get("repository") or base[service].get("repository")
        digest = overlay[service].get("digest") or base[service].get("digest")
        if not repository:
            raise SystemExit(f"{service} repository is missing")
        if not digest or not digest.startswith("sha256:"):
            raise SystemExit(f"{args.values}: {service} must pin a sha256 digest")
        refs[service] = f"{repository}@{digest}"

    text = "\n".join(f"{service}={refs[service]}" for service in SERVICES) + "\n"
    print(text, end="")
    if args.output:
        args.output.write_text(text)
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as handle:
            for service in SERVICES:
                handle.write(f"{service}_ref={refs[service]}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
