#!/usr/bin/env python3
"""Materialize workspace inheritance for a vendored crate manifest.

Usage: materialize_workspace.py <crate-manifest-path> <workspace-root-manifest-path>
Reads [workspace.package] and [workspace.dependencies] from the root and
rewrites `<key>.workspace = true` and `<dep> = { workspace = true, ... }`
in the crate manifest with literal values.
"""
import re
import sys
from pathlib import Path


def parse_tomlish(text: str, section: str) -> dict:
    """Extract key -> raw value lines from one TOML section (line-based)."""
    out = {}
    inside = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            inside = stripped == f"[{section}]"
            continue
        if not inside or not stripped or stripped.startswith("#"):
            continue
        match = re.match(r'^([A-Za-z0-9_-]+)\s*=\s*(.+?)\s*$', stripped)
        if match:
            out[match.group(1)] = match.group(2)
    return out


def main() -> None:
    crate_path = Path(sys.argv[1])
    root_path = Path(sys.argv[2])
    crate = crate_path.read_text()
    root = root_path.read_text()

    # collapse multiline inline tables to one line so the line-based
    # materializer sees `key = { workspace = true }` as a single entry
    crate = re.sub(r"\{([^{}]*)\}",
                   lambda m: "{ " + " ".join(m.group(1).split()) + " }",
                   crate)

    ws_package = parse_tomlish(root, "workspace.package")
    ws_deps = parse_tomlish(root, "workspace.dependencies")

    changed = []
    out_lines = []
    in_lints_section = False
    for line in crate.splitlines():
        stripped = line.strip()
        # [lints] sections with `workspace = true`: lints are optional
        # metadata inherited via table form; drop until the next section
        if stripped.startswith("["):
            in_lints_section = stripped == "[lints]"
            if in_lints_section:
                changed.append("dropped [lints] section")
            out_lines.append(line)
            continue
        if in_lints_section:
            if stripped == "workspace = true":
                changed.append("dropped lints workspace = true")
            continue
        match = re.match(r'^([A-Za-z0-9_-]+)\.workspace\s*=\s*true\s*$', stripped)
        if match:
            key = match.group(1)
            if key in ws_package:
                out_lines.append(f"{key} = {ws_package[key]}")
                changed.append(f"{key}.workspace -> literal")
                continue
            # optional metadata without a workspace definition: drop it
            if key in ("authors", "keywords", "license", "repository",
                       "rust-version", "homepage", "documentation",
                       "categories", "exclude", "include", "publish"):
                changed.append(f"dropped {key}.workspace")
                continue
            raise SystemExit(f"unresolvable inheritance: {stripped!r}")
        dep_match = re.match(
            r'^([A-Za-z0-9_-]+)\s*=\s*\{\s*workspace\s*=\s*true(.*)\}\s*$', stripped)
        if dep_match:
            dep = dep_match.group(1)
            extra = dep_match.group(2).strip()
            if dep not in ws_deps:
                raise SystemExit(f"workspace dependency {dep!r} not defined in root")
            spec = ws_deps[dep]
            # merge extras (e.g. features = [...]) into the spec table/inline
            if extra.startswith(","):
                extra = extra[1:].strip()
            if spec.startswith("{"):
                # table spec: merge extras into braces
                inner = spec[1:-1].strip().rstrip(",")
                merged = inner + (", " + extra if extra else "")
                out_lines.append(f"{dep} = {{ {merged} }}")
            else:
                if extra:
                    out_lines.append(f"{dep} = {{ version = {spec}, {extra} }}")
                else:
                    out_lines.append(f"{dep} = {spec}")
            changed.append(f"dep {dep}.workspace -> literal")
            continue
        out_lines.append(line)

    crate_path.write_text("\n".join(out_lines) + "\n")
    for item in changed:
        print("materialized:", item)
    if not changed:
        print("nothing to materialize")


if __name__ == "__main__":
    main()
