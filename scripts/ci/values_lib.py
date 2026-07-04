"""Small helpers for fixed Helm image values files."""

from __future__ import annotations

from pathlib import Path


SERVICES = ("vote", "result", "worker")


def read_images(path: Path) -> dict[str, dict[str, str]]:
    values: dict[str, dict[str, str]] = {service: {} for service in SERVICES}
    in_images = False
    service: str | None = None

    for line in path.read_text().splitlines():
        stripped = line.strip()
        if stripped == "images:":
            in_images = True
            service = None
            continue
        if in_images and line and not line.startswith(" "):
            in_images = False
            service = None
        if not in_images:
            continue
        if line.startswith("  ") and not line.startswith("    ") and stripped.endswith(":"):
            candidate = stripped[:-1]
            service = candidate if candidate in SERVICES else None
            continue
        if service and line.startswith("    ") and ":" in stripped:
            key, value = stripped.split(":", 1)
            values[service][key] = value.strip().strip('"').strip("'")

    return values
