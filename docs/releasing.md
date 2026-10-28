# Preparing a Michem release

## GitHub Actions

Branch pushes and pull requests run `Tests` and `Registry release check`.
Tests include Rust formatting, Clippy, workspace tests, a locked WASM build,
and every Typst assertion on 0.14.0 and 0.15.1. The Registry job prepares the
compact submission, compiles the manual, examples and README previews with both
compilers, and runs the pinned official package checker with network lints enabled.
Both workflows can also be started manually.

Download `release-assets` from a successful Registry workflow to review the
candidate. Its Registry archive expands to `packages/preview/michem/<version>/`;
its runtime archive contains only the downloadable package files. The artifact
also includes the WASM plugin, manual, gallery, quick start, validation report
and `SHA256SUMS`. Documentation PDFs are separate attachments, outside both packages.

To publish, commit the intended release, set the same version in `typst.toml`
and `Cargo.toml`, then push a matching tag such as `v0.1.0`:

```sh
git tag v0.1.0
git push origin v0.1.0
```

The `GitHub Release` workflow checks the tag against both manifests and reruns
tests and Registry validation at that tag. Only after both pass does a separate
job receive release write permission, verify attachment checksums and create the
GitHub Release with generated notes. It does not submit a Typst Registry PR.
If a release already exists, publication fails without overwriting its assets.

Static Cascadia Code fonts are downloaded from a fixed Microsoft release and
verified with SHA-256. Libertinus Serif comes with Typst. Fonts are used only
for CI rendering and are not bundled in either package.

## Local preparation

The source repository and the Typst Packages submission are separate trees.
Release preparation writes a new directory under `.temp/release/`, never edits
an existing candidate, and does not publish, commit or upload anything.

## Tools

- Rust with the `wasm32-unknown-unknown` target.
- Python 3.12 or newer; the preparation script uses only the standard library.
- Typst at the manifest's minimum version and the current supported version.
- The official `typst-package-check` tool.
- Libertinus Serif and Cascadia Code to compile the documentation. With Typst
  0.14, use static Cascadia Code fonts: that compiler warns about variable fonts.

The official checker can be installed into a temporary project directory:

```sh
cargo install --git https://github.com/typst/package-check.git --locked \
  --root .temp/release-tools --target-dir .temp/release-tools/target
```

## Prepare and verify

Unset `CHITIN_SOURCE` before preparing a release. Release builds reject the local
Chitin override and require `Cargo.lock` to resolve both Chitin crates to the
remote revisions specified in `Cargo.toml`.

```sh
python scripts/prepare-release.py \
  --typst /path/to/typst-0.14.0 \
  --typst typst \
  --checker .temp/release-tools/bin/typst-package-check
```

`just release` forwards its arguments to the same script. Supply both compilers
for a release review; `report.json` records whether the declared minimum compiler
was actually tested. Use `--checker-offline` only when network lints cannot run;
the report distinguishes this from a full checker pass.

The preparation script:

1. Builds the plugin from the locked remote dependencies.
2. Copies only the manifest, entrypoint, Typst modules, plugin, license and README
   into `packages/preview/michem/<version>/` inside the new candidate.
3. Copies documentation and example sources into a separate `validation/` work
   directory and rewrites their local Michem
   imports to `@preview/michem:<version>`. Internal package module imports remain
   relative. Example helpers and the documentation theme remain in that work
   directory, outside the submission tree.
4. Builds a runtime archive without documentation or development files, extracts
   it into an isolated package path, and compiles all README snippets, the
   self-contained quick start, the manual and every standalone example against
   that extracted runtime for each requested compiler.
5. Copies only the four rendered README PNGs into `assets/readme/` in the
   submission tree. It does not include `docs/`, `examples/`, `licenses/`, or
   `THIRD_PARTY_NOTICES.md`.
6. Runs the optional official package checker and records compiler versions,
   dependency revision and WASM/archive SHA-256 hashes in `report.json`.

README preview sources live in `assets/readme/` and evaluate the snippets from
the README itself. Run `just readme-assets` to regenerate their 192 PPI PNG files after
changing an example. Preparation copies these sources and regenerates the four
previews against the extracted runtime for each compiler. PNGs are included in
the submission tree and excluded from the runtime archive. Preview sources stay
in the separate validation work area.

The generated PDFs remain in the validation work area. The README links to the
upstream guide source. No source Rust, build cache, tests, Git
metadata, workspace agent configuration or credentials directories are copied.

## Review and submit

Review the candidate README, illustrations and validation report, and inspect
the PDFs in the validation work area.
When updating the guide, update the README's guide permalink to the corresponding
committed revision before publishing.
Both `minimum_compiler_tested: true` and a full checker pass should be present
before submission. A checker failure stops preparation; do not submit a partial
candidate without a completed report.

Copy the generated `packages/preview/michem/<version>/` directory into a fork of
`typst/packages` and open a pull request following its submission guidelines.
Copy the submission directory, not the surrounding verification work area or
runtime archive. The submission contains only `typst.toml`, `lib.typ`, `LICENSE`,
`README.md`, `typst/`, `wasm/`, and the rendered README illustrations under
`assets/readme/`. Existing `exclude` rules keep illustrations out of the
downloadable runtime.

The official guidance is at
<https://github.com/typst/packages/blob/main/docs/README.md>.
