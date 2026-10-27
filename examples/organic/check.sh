#!/usr/bin/env bash
set -euo pipefail

# Requires an existing WASM plugin; checks formatting and compiles examples.
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
output_root="${1:-$project_root/.temp/organic-examples}"
mkdir -p "$output_root"
typstyle --check --indent-width 2 "$project_root"/examples/organic/support/*.typ

for name in alpha-acidity lda-amides aldol-crossed aldol-intramolecular aldol-exocyclic aldol-bridged; do
  source_file="$project_root/examples/organic/$name.typ"
  typstyle --check --indent-width 2 "$source_file"
  typst compile --root "$project_root" "$source_file" "$output_root/$name.pdf"
  typst compile --root "$project_root" "$source_file" "$output_root/$name.png" -f png
done
