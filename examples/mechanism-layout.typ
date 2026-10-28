#import "../lib.typ" as michem

#set page(width: auto, height: auto, margin: 18pt)
#set text(font: "Libertinus Serif", size: 10pt)

= Measured mechanism layout

// Independent transformations use measured route layers.
#michem.reaction-route(
  michem.reaction-stage("alcohol", michem.compound("CCO", name: [Alcohol])),
  michem.reaction-stage("aldehyde", michem.compound("CC=O", name: [Aldehyde])),
  michem.reaction-stage("acid", michem.compound("CC(=O)O", name: [Acid])),
  michem.reaction-stage("ester", michem.compound("CC(=O)OCC", name: [Ester])),
  steps: (
    michem.reaction-step("alcohol", "aldehyde", above: [Oxidation]),
    michem.reaction-step("acid", "ester", above: [EtOH, H⁺]),
  ),
)

== Bezier routing around measured text

#context {
  let data = michem.mechanism-data(
    michem.mol("donor", "[OH-]", at: (0pt, 0pt)),
    michem.mol("acceptor", "[CH3+]", at: (140pt, 0pt)),
    michem.mechanism-label((70pt, 0pt), [Reserved annotation]),
    michem.lone-pair(
      michem.atom-ref("donor", 0),
      id: "donation",
      position: "auto",
    ),
    michem.electron-arrow(
      michem.pair-ref("donor", "donation"),
      michem.atom-ref("acceptor", 0),
      curve: "bezier",
      bend: 0,
      route: "auto",
    ),
    font: "Libertinus Serif",
  )
  assert(data.scene.routing.len() == 1)
  assert(data.scene.routing.first().bend != 0)
  michem.paint-mechanism(data)
}

== Relative placement and independent panels

#michem.mechanism-panels(
  [*Reacting species* #parbreak()
    #michem.mechanism(
      michem.mol("substrate", "CC=O"),
      michem.mol("base", "[OH-]", at: michem.near(
        "substrate",
        side: "north",
        gap: 18pt,
        align: "start",
      )),
      font: "Libertinus Serif",
    )
  ],
  [*Products* #parbreak()
    #michem.mechanism(
      michem.mol("enolate", "C=C[O-]"),
      michem.mol("water", "O", at: michem.near(
        "enolate",
        side: "south",
        gap: 18pt,
      )),
      font: "Libertinus Serif",
    )
  ],
  columns: 2,
)
