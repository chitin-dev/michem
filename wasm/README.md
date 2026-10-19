# WASM artifact

Run `bash scripts/build-plugin.sh` from a source checkout. This produces
`wasm/michem.wasm`, loaded by the Typst package through the minimal plugin protocol.
The binary must be included when distributing a ready-to-use Typst package.
It is generated and ignored in the source repository.

The target is `wasm32-unknown-unknown`; this plugin does not use WASI or wasm-bindgen.

`labels` returns label measurement requests. Typst resolves the configured font
family and passes measured advances/bounds back to `render` or `diagram` in JSON.
