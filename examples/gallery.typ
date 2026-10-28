#import "../lib.typ" as michem
#import "../docs/theme.typ": example, example-page, version

#show: example-page

= Michem #version

Chemical structures, reaction routes and authored mechanisms. Each card executes
the source shown above its output. Import the published package with
`#import "@preview/michem:0.1.0" as michem`; this source gallery uses the
repository entrypoint for release verification.

#block(breakable: false)[
  == SMILES and a shared molecular scale

  #example(```typst
  #michem.compound-grid(
    michem.compound("CCO", name: [Ethanol]),
    michem.compound("CC(=O)Oc1ccccc1C(=O)O", name: [Aspirin]),
    michem.compound("c1ccccc1", name: [Benzene]),
    columns: 3,
  )
  ```)
]

#block(breakable: false)[
  == Palette and aromatic bonds

  #example(```typst
  #michem.smiles("Nc1ccc(O)cc1", style: michem.style(
    font: "Libertinus Serif",
    color-map: (O: rgb("#bf4b45"), N: rgb("#476ca8")),
    aromatic: "circle", bond-colors: "uniform",
  ))
  ```)
]

#block(breakable: false)[
  == Authored coordinates

  #example(```typst
  #let ethanol = michem.molecule(
    atoms: (
      michem.atom("c1", at: (0, 0)),
      michem.atom("c2", at: (0.866, 0.5)),
      michem.atom("o", element: "O", at: (1.732, 0)),
    ),
    bonds: (michem.bond("c1", "c2"), michem.bond("c2", "o")),
  )
  #michem.smiles(ethanol,
    style: michem.style(font: "Libertinus Serif"),
  )
  ```)
]

#block(breakable: false)[
  == Stereochemistry

  #example(```typst
  #michem.compound-grid(
    michem.compound("N[C@@H](C)C(=O)O", name: [Alanine]),
    michem.compound("F/C=C/F", name: [Alkene configuration]),
    columns: 2,
  )
  ```)
]

#block(breakable: false)[
  == Automatic reaction routes

  The route supplies the plus signs, arrows, conditions and names at a shared
  physical scale. Its stages and connectivity are supplied explicitly.

  #example(```typst
  #michem.reaction-route(
    michem.reaction-stage("a",
      michem.compound("CCO", name: [Alcohol])),
    michem.reaction-stage("b",
      michem.compound("CC=O", name: [Aldehyde])),
    michem.reaction-stage("c",
      michem.compound("CC(=O)O", name: [Acid])),
    steps: (
      michem.reaction-step("a", "b", above: [PCC]),
      michem.reaction-step("b", "c", above: [Oxidation]),
    ),
  )
  ```)
]

#block(breakable: false)[
  == Circular routes and released products

  This is a layout demonstration. The product branch defaults to a circular arc
  externally tangent to the cycle. Select `branch-curve: "bezier"` for cubic
  branches; `examples/circular-branches.typ` compares the two modes.

  #example(```typst
  #michem.reaction-route(
    michem.reaction-stage("a", "CO"),
    michem.reaction-stage("b", "C=O"),
    michem.reaction-stage("c", "O=CO"),
    layout: "circular", center: [Cycle],
    atom-size: 8pt, bond-length: 15pt,
    steps: (
      michem.reaction-step("a", "b", products: ("O",)),
      michem.reaction-step("b", "c"),
      michem.reaction-step("c", "a"),
    ),
  )
  ```)
]

#block(breakable: false)[
  == Explicit electron flow

  Both the lone pair and its electron-flow destination are authored. Automatic
  routing chooses a clear curve between those fixed endpoints.

  #example(```typst
  #michem.mechanism(
    michem.mol("base", "N"),
    michem.mol("proton", "[H+]", at: (85pt, 0pt)),
    michem.lone-pair(michem.atom-ref("base", 0), id: "pair"),
    michem.electron-arrow(
      michem.pair-ref("base", "pair"),
      michem.atom-ref("proton", 0),
      arc-angle: -60deg, route: "auto",
    ),
    font: "Libertinus Serif",
  )
  ```)
]

#block(breakable: false)[
  == Custom CeTZ composition

  #example(```typst
  #cetz.canvas({
    let molecule = michem.cetz.molecule.with(
      style: michem.style(font: "Libertinus Serif"),
    )
    molecule("NCC(=O)O", name: "glycine")
    cetz.draw.line("glycine.atom-0",
      (rel: (0, 1), to: "glycine.atom-0"), stroke: gray + 0.4pt)
    cetz.draw.content((rel: (0, 1.2), to: "glycine.atom-0"), [Amino group])
  })
  ```)

  More examples: `reaction-route.typ` for branches and wrapping,
  `circular-route.typ` for cycle direction and equilibrium arrows,
  `mechanism-layout.typ` for measured panels, and `anchors.typ` for CeTZ anchors.
]
