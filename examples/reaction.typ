#import "@preview/cetz:0.5.2": canvas, draw
#import "../lib.typ" as michem

#set page(width: 23cm, height: auto, margin: 18pt)
#set text(font: "Libertinus Serif", size: 10pt)
#show raw: set text(font: "Cascadia Code")

= Automatic reaction route

#michem.reaction-route(
  michem.reaction-stage("alcohol", michem.compound("CCO", name: [Alcohol])),
  michem.reaction-stage("aldehyde", michem.compound("CC=O", name: [Aldehyde])),
  michem.reaction-stage("acid", michem.compound("CC(=O)O", name: [Acid])),
  michem.reaction-stage("ester", michem.compound("CC(=O)OCC", name: [Ester])),
  steps: (
    michem.reaction-step("alcohol", "aldehyde", above: [PCC], below: [CH₂Cl₂]),
    michem.reaction-step("aldehyde", "acid", above: [Oxidation]),
    michem.reaction-step("acid", "ester", above: [EtOH, H⁺]),
  ),
)

== Atom anchor on a CeTZ canvas

The route above handles the reaction flow. A separate canvas demonstrates an
atom annotation; the oxygen anchor follows the molecule's measured frame.

#canvas({
  import draw: *
  michem.cetz.molecule(
    "CCO",
    name: "alcohol",
    style: michem.style(font: "Libertinus Serif"),
  )
  line(
    "alcohol.atom-2",
    (rel: (0, 1), to: "alcohol.atom-2"),
    stroke: gray + 0.4pt,
  )
  content((rel: (0, 1.2), to: "alcohol.atom-2"), [Oxidation site])
})
