#import "@preview/cetz:0.5.2": canvas, draw
#import "../lib.typ" as michem

#set page(width: auto, height: auto, margin: 18pt)
#set text(font: "Libertinus Serif", size: 9pt)

#let molecule = michem.cetz.molecule.with(
  style: michem.style(font: "Libertinus Serif"),
)

#canvas({
  import draw: *
  molecule("CCO", at: (0, 0), name: "alcohol")
  molecule("CC=O", at: (4.5, 0), name: "aldehyde")
  molecule("CC(=O)O", at: (9, 0), name: "acid")
  molecule("CC(=O)OCC", at: (9, -3), name: "ester")

  michem.cetz.reaction(
    (rel: (0.25, 0), to: "alcohol.east"),
    (rel: (-0.25, 0), to: "aldehyde.west"),
    above: [PCC],
    below: [CH₂Cl₂],
  )
  michem.cetz.reaction(
    (rel: (0.25, 0), to: "aldehyde.east"),
    (rel: (-0.25, 0), to: "acid.west"),
    above: [Oxidation],
  )
  michem.cetz.reaction(
    (rel: (0, -0.25), to: "acid.south"),
    (rel: (0, 0.25), to: "ester.north"),
    above: [EtOH, H⁺],
    label-side: "east",
  )

  // Atom 2 is the oxygen of CCO. The anchor follows the exact SVG frame.
  line(
    "alcohol.atom-2",
    (rel: (0, 1), to: "alcohol.atom-2"),
    stroke: gray + 0.4pt,
  )
  content((rel: (0, 1.2), to: "alcohol.atom-2"), [Oxidation site])
})
