#import "../../../lib.typ" as michem

#let mechanism-style = michem.style(
  font: "Libertinus Serif",
  font-size: 14,
  bond-length: 24,
  stroke-width: 1.3,
  color-scheme: "monochrome",
  bond-colors: "uniform",
)
/// Applies consistent molecular typography without changing chemical facts.
#let mechanism-mol(id, value, ..options) = michem.mol(
  id,
  value,
  style: mechanism-style,
  ..options,
)
/// Builds authored topology from stable atom names and normalized y-up positions.
#let mechanism-graph(
  points,
  bonds,
  elements: (:),
  charges: (:),
  hydrogens: (:),
) = michem.molecule(
  atoms: points
    .pairs()
    .map(((id, p)) => michem.atom(
      id,
      at: p,
      element: elements.at(id, default: "C"),
      charge: charges.at(id, default: 0),
      hydrogens: hydrogens.at(id, default: none),
    )),
  bonds: bonds.map(b => michem.bond(
    b.at(0),
    b.at(1),
    order: if b.len() == 3 { b.at(2) } else { "single" },
  )),
)
/// Composes one measured row; arrows remain explicitly authored.
#let mechanism-row(..items, gap: 48pt) = michem.mechanism(
  ..items,
  gap: gap,
  font: "Libertinus Serif",
  padding: 10pt,
)
// Route participants and local mechanism panels use the same physical scale.
#let route-options = (
  font: "Libertinus Serif",
  atom-size: 10.5pt,
  label-size: 9pt,
  bond-length: 18pt,
  molecular-style: mechanism-style,
)
#let route(..stages, steps: auto) = michem.reaction-route(
  ..stages,
  steps: steps,
  ..route-options,
)
/// Keep atom-level annotations in a labeled panel below the automatic route.
#let with-electron-flow(route, detail) = stack(
  dir: ttb,
  spacing: 10pt,
  align(center, route),
  [*Electron flow*],
  align(center, detail),
)

/// Shared page settings for standalone, offline-compilable teaching examples.
#let setup(body) = {
  set page(width: 23cm, height: auto, margin: 16pt)
  set text(font: "Libertinus Serif", size: 10pt)
  show raw: set text(font: "Cascadia Code")
  set par(justify: false)
  set figure(numbering: none, gap: 6pt)
  body
}

/// Resonance uses a double-headed arrow, not a chemical-equilibrium connector.
/// These rows reserve a 40pt gap, placing the symbol halfway across that gap.
#let resonance-step(after) = michem.mechanism-label(
  michem.edge(after, gap: 20pt),
  text(size: 20pt)[↔],
)
