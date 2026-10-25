build:
    bash scripts/build-plugin.sh

fmt:
    cargo fmt --all
    typstyle --inplace --indent-width 2 lib.typ typst/*.typ examples/*.typ docs/*.typ

docs: build
    typst compile --root . docs/manual.typ docs/manual.pdf

gallery: build
    typst compile --root . examples/gallery.typ examples/gallery.pdf

mechanism: build
    typst compile --root . examples/mechanism.typ examples/mechanism.pdf
