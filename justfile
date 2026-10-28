build:
    bash scripts/build-plugin.sh

fmt:
    cargo fmt --all
    typstyle --inplace --indent-width 2 lib.typ typst/*.typ examples/*.typ docs/*.typ tests/*.typ

docs: build
    typst compile --root . docs/manual.typ docs/manual.pdf

gallery: build
    typst compile --root . examples/gallery.typ examples/gallery.pdf

mechanism: build
    typst compile --root . examples/mechanism.typ examples/mechanism.pdf

mechanism-layout: build
    typst compile --root . examples/mechanism-layout.typ examples/mechanism-layout.pdf

reaction-route: build
    typst compile --root . examples/reaction-route.typ examples/reaction-route.pdf

circular-route: build
    typst compile --root . examples/circular-route.typ examples/circular-route.pdf

circular-branches: build
    typst compile --root . examples/circular-branches.typ examples/circular-branches.pdf
