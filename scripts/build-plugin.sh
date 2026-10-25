#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Local cross-repository development must not publish or rewrite a remote pin.
cargo_options=(--locked)
if [[ -n "${CHITIN_SOURCE:-}" ]]; then
  chitin_source="$(cd -- "$CHITIN_SOURCE" && pwd)"
  cargo_options=(
    --config "patch.\"https://github.com/chitin-dev/chitin\".chitin-chem.path=\"$chitin_source/crates/chitin-chem\""
    --config "patch.\"https://github.com/chitin-dev/chitin\".chitin-chemdraw.path=\"$chitin_source/crates/chitin-chemdraw\""
  )
fi

cargo build --manifest-path "$project_root/Cargo.toml" \
  --package michem-wasm --release --target wasm32-unknown-unknown \
  "${cargo_options[@]}" \
  --target-dir "$project_root/target" "$@"

mkdir -p "$project_root/wasm"
cp "$project_root/target/wasm32-unknown-unknown/release/michem_wasm.wasm" \
  "$project_root/wasm/michem.wasm"
