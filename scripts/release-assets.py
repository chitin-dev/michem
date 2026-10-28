#!/usr/bin/env python3
"""Assemble GitHub Release attachments from a fully checked release candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tarfile
import tomllib
from pathlib import Path


def main() -> None:
    """Require full validation and export compact archives, PDFs and checksums."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    candidate, output = args.candidate.resolve(), args.output.resolve()
    report = json.loads((candidate / "report.json").read_text())
    if not report["minimum_compiler_tested"] or report["package_checker"] != "passed":
        raise ValueError(
            "Release attachments require minimum-compiler and online checker passes"
        )
    manifests = list((candidate / "packages/preview").glob("*/*/typst.toml"))
    if len(manifests) != 1:
        raise ValueError("Expected exactly one Registry submission")
    submission = manifests[0].parent
    package = tomllib.loads(manifests[0].read_text())["package"]
    name, version = package["name"], package["version"]
    if report["package"] != f"@preview/{name}:{version}":
        raise ValueError("Report does not match submission")
    allowed = {
        "typst.toml",
        "lib.typ",
        "LICENSE",
        "README.md",
        "typst",
        "wasm",
        "assets",
    }
    if {path.name for path in submission.iterdir()} != allowed:
        raise ValueError("Submission must contain only the compact Registry package")
    runtime = candidate / f"{name}-{version}.tar.gz"
    if hashlib.sha256(runtime.read_bytes()).hexdigest() != report["archive_sha256"]:
        raise ValueError("Runtime archive differs from the validated report")
    if (
        hashlib.sha256((submission / "wasm/michem.wasm").read_bytes()).hexdigest()
        != report["wasm_sha256"]
    ):
        raise ValueError("WASM plugin differs from the validated report")
    if output.exists() and any(output.iterdir()):
        raise ValueError("Attachment output must be new or empty")
    output.mkdir(parents=True, exist_ok=True)
    with tarfile.open(output / f"{name}-{version}-registry.tar.gz", "w:gz") as bundle:
        bundle.add(submission, arcname=f"packages/preview/{name}/{version}")
    files = {
        runtime: runtime.name,
        candidate / "report.json": "report.json",
        submission / "wasm/michem.wasm": "michem.wasm",
        candidate / "validation/docs/manual.pdf": f"{name}-{version}-manual.pdf",
        candidate / "validation/examples/gallery.pdf": f"{name}-{version}-gallery.pdf",
        candidate
        / "validation/examples/quick-start.pdf": f"{name}-{version}-quick-start.pdf",
    }
    for source, filename in files.items():
        shutil.copy2(source, output / filename)
    checksums = [
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n"
        for path in sorted(output.iterdir())
    ]
    (output / "SHA256SUMS").write_text("".join(checksums))
    print(f"Release attachments: {output}")


if __name__ == "__main__":
    main()
