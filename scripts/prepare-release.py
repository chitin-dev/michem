#!/usr/bin/env python3
"""Build, stage and verify a self-contained Typst Packages submission.

Uses only the Python 3.12+ standard library. No files are uploaded or committed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tarfile
import tempfile
import tomllib
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
LICENSE_PREFIXES = ("LICENSE", "COPYING", "NOTICE", "UNLICENSE")


def run(args: list[str], *, cwd: Path = ROOT) -> None:
    """Run a release step and stop on failure."""
    print("+ " + " ".join(args), flush=True)
    subprocess.run(args, cwd=cwd, check=True)


def copy_file(source: Path, destination: Path) -> None:
    """Copy a regular, non-symlink file to a newly staged tree."""
    if source.is_symlink() or not source.is_file():
        raise ValueError(f"Expected a regular file: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def collect_licenses(metadata: dict[str, Any], destination: Path) -> None:
    """Retain dependency notices from the exact Cargo-resolved source trees."""
    lines = [
        "# Third-party notices",
        "",
        "Michem's original code is Apache-2.0. The precompiled WASM plugin uses",
        "the following dependencies. This inventory also includes build-time",
        "and procedural-macro dependencies; their license texts are retained.",
        "",
        "| Component | Declared license | License texts |",
        "| --- | --- | --- |",
    ]
    packages = sorted(metadata["packages"], key=lambda package: package["name"])
    for package in packages:
        if package["source"] is None:
            continue
        source = Path(package["manifest_path"]).parent
        files: list[Path] = []
        for folder in (source, *list(source.parents)[:2]):
            files = sorted(
                item
                for item in folder.iterdir()
                if item.is_file() and item.name.upper().startswith(LICENSE_PREFIXES)
            )
            if files:
                break
        if package.get("license_file"):
            declared = source / package["license_file"]
            if declared not in files:
                files.append(declared)
        if not files:
            raise ValueError(f"No license text found for {package['name']}")
        component = f"{package['name']}-{package['version']}"
        links = []
        for license_file in files:
            relative = Path("licenses") / component / license_file.name
            copy_file(license_file, destination / relative)
            links.append(f"[{license_file.name}]({relative.as_posix()})")
        license_name = package["license"]
        if license_name is None and package["name"] == "wasm-minimal-protocol":
            license_name = "Unlicense (from its LICENSE file)"
        if license_name is None:
            raise ValueError(f"Review undeclared license for {component}")
        lines.append(f"| {component} | {license_name} | {', '.join(links)} |")
        if package["name"] == "chitin-chemdraw":
            relative = Path("licenses/NotoSans/OFL-1.1.txt")
            copy_file(source / "assets/NotoSans-OFL-1.1.txt", destination / relative)
            lines.append(
                f"| Embedded Noto Sans | OFL-1.1 | [Font license]({relative}) |"
            )
    lines.extend(
        [
            "",
            "Chitin's component attribution follows its upstream release. This inventory",
            "preserves its declared licenses and the license files provided by the",
            "exact pinned source trees.",
            "",
            "CeTZ is imported separately as @preview/cetz:0.5.2; it is not embedded in",
            "this WASM plugin. Named document/system fonts are not distributed here.",
            "",
        ]
    )
    (destination / "THIRD_PARTY_NOTICES.md").write_text("\n".join(lines))


def package_sources(destination: Path, specification: str) -> None:
    """Copy documentation sources and rewrite only their local Michem imports."""
    for directory in ("docs", "examples", "assets/readme"):
        for source in sorted((ROOT / directory).rglob("*.typ")):
            relative = source.relative_to(ROOT)
            text = source.read_text()
            text = re.sub(
                r'(#import\s+)"(?:\.\./)+lib\.typ"', rf'\1"{specification}"', text
            )
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)


def main() -> None:
    """Prepare a new candidate, compile it in isolation and optionally lint it."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        help="New/empty output directory; defaults to .temp/release",
    )
    parser.add_argument(
        "--typst",
        action="append",
        help="Compiler executable; repeat to check multiple versions",
    )
    parser.add_argument(
        "--checker", type=Path, help="Optional typst-package-check executable"
    )
    parser.add_argument(
        "--checker-offline",
        action="store_true",
        help="Skip the checker's network-only lints",
    )
    args = parser.parse_args()
    if os.environ.get("CHITIN_SOURCE"):
        raise ValueError(
            "Unset CHITIN_SOURCE: release builds must use the pinned remote dependencies"
        )

    manifest = tomllib.loads((ROOT / "typst.toml").read_text())["package"]
    cargo = tomllib.loads((ROOT / "Cargo.toml").read_text())["workspace"]
    name, version = manifest["name"], manifest["version"]
    if version != cargo["package"]["version"]:
        raise ValueError("Typst and Cargo versions differ")
    if not manifest.get("authors") or not manifest.get("repository"):
        raise ValueError("Release metadata requires authors and repository")
    base = ROOT / ".temp/release"
    base.mkdir(parents=True, exist_ok=True)
    output = (
        args.output.resolve()
        if args.output
        else Path(tempfile.mkdtemp(prefix=f"{name}-{version}-", dir=base))
    )
    if output.exists() and any(output.iterdir()):
        raise ValueError(
            f"Refusing to overwrite a nonempty release directory: {output}"
        )
    output.mkdir(parents=True, exist_ok=True)

    run(["bash", "scripts/build-plugin.sh"])
    metadata = json.loads(
        subprocess.check_output(
            ["cargo", "metadata", "--locked", "--format-version", "1"],
            cwd=ROOT,
            text=True,
        )
    )
    for dependency in ("chitin-chem", "chitin-chemdraw"):
        package = next(
            package for package in metadata["packages"] if package["name"] == dependency
        )
        revision = cargo["dependencies"][dependency]["rev"]
        if package["source"] is None or not package["source"].endswith("#" + revision):
            raise ValueError(
                f"{dependency} did not resolve to the pinned remote revision"
            )

    submission = output / "packages/preview" / name / version
    submission.mkdir(parents=True)
    for filename in ("typst.toml", "lib.typ", "LICENSE", "README.md"):
        copy_file(ROOT / filename, submission / filename)
    for source in sorted((ROOT / "typst").rglob("*.typ")):
        copy_file(source, submission / source.relative_to(ROOT))
    copy_file(ROOT / "wasm/michem.wasm", submission / "wasm/michem.wasm")
    collect_licenses(metadata, submission)
    specification = f"@preview/{name}:{version}"
    package_sources(submission, specification)

    # Check the downloadable runtime alone: documentation is deliberately absent.
    runtime = output / "runtime/preview" / name / version
    runtime.mkdir(parents=True)
    for source in sorted(submission.rglob("*")):
        if source.is_file() and source.relative_to(submission).parts[0] not in (
            "docs",
            "examples",
            "assets",
        ):
            copy_file(source, runtime / source.relative_to(submission))
    consumer = output / "consumer"
    consumer.mkdir()
    smoke = consumer / "smoke.typ"
    smoke.write_text(
        f'#import "{specification}" as michem\n'
        "#set page(width: auto, height: auto)\n"
        '#michem.smiles("CCO")\n'
        '#michem.reaction-route(michem.reaction-stage("a", "CCO"), '
        'michem.reaction-stage("b", "CC=O"))\n'
    )
    consumer_sources = [smoke]
    quick_start = consumer / "quick-start.typ"
    copy_file(submission / "examples/quick-start.typ", quick_start)
    consumer_sources.append(quick_start)
    for index, block in enumerate(
        re.findall(
            r"```typst\n(.*?)\n```", (submission / "README.md").read_text(), re.S
        ),
        1,
    ):
        source = consumer / f"readme-{index}.typ"
        source.write_text(block + "\n")
        consumer_sources.append(source)

    # Verify the actual downloadable archive, not just the pre-archive directory.
    archive = output / f"{name}-{version}.tar.gz"
    with tarfile.open(archive, "w:gz") as bundle:
        for source in sorted(runtime.rglob("*")):
            if source.is_file():
                bundle.add(source, arcname=source.relative_to(runtime), recursive=False)
    extracted = output / "verified-runtime/preview" / name / version
    extracted.mkdir(parents=True)
    with tarfile.open(archive, "r:gz") as bundle:
        bundle.extractall(extracted, filter="data")
    sources = [
        submission / "docs/manual.typ",
        *sorted((submission / "examples").rglob("*.typ")),
    ]
    sources = [source for source in sources if "support" not in source.parts]
    previews = sorted(
        source
        for source in (submission / "assets/readme").glob("*.typ")
        if source.name != "theme.typ"
    )
    report: dict[str, Any] = {
        "package": specification,
        "chitin_revision": cargo["dependencies"]["chitin-chemdraw"]["rev"],
        "wasm_sha256": hashlib.sha256(
            (runtime / "wasm/michem.wasm").read_bytes()
        ).hexdigest(),
        "compilers": [],
    }
    for compiler in args.typst or ["typst"]:
        executable = shutil.which(compiler)
        if executable is None:
            raise ValueError(f"Compiler not found: {compiler}")
        compiler_version = subprocess.check_output(
            [executable, "--version"], text=True
        ).strip()
        for source in consumer_sources:
            run(
                [
                    executable,
                    "compile",
                    "--root",
                    str(consumer),
                    "--package-path",
                    str(output / "verified-runtime"),
                    str(source),
                    str(source.with_suffix(".pdf")),
                ]
            )
        for source in sources:
            run(
                [
                    executable,
                    "compile",
                    "--root",
                    str(submission),
                    "--package-path",
                    str(output / "verified-runtime"),
                    str(source),
                    str(source.with_suffix(".pdf")),
                ]
            )
        for source in previews:
            run(
                [
                    executable,
                    "compile",
                    "--root",
                    str(submission),
                    "--package-path",
                    str(output / "verified-runtime"),
                    str(source),
                    str(source.with_suffix(".png")),
                    "--ppi",
                    "192",
                ]
            )
        report["compilers"].append(
            {
                "version": compiler_version,
                "documents": len(sources) + len(consumer_sources),
                "readme_assets": len(previews),
            }
        )
    report["minimum_compiler_tested"] = any(
        compiler["version"].split()[1] == manifest["compiler"]
        for compiler in report["compilers"]
    )
    if args.checker:
        command = [str(args.checker.resolve()), "check"]
        if args.checker_offline:
            command.append("--offline")
        run(command, cwd=submission)
        report["package_checker"] = (
            "passed (offline)" if args.checker_offline else "passed"
        )
    else:
        report["package_checker"] = "not run; supply --checker"

    report["archive_sha256"] = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(
        f"\nSubmission: {submission}\nRuntime archive: {archive}\nReport: {output / 'report.json'}"
    )


if __name__ == "__main__":
    main()
