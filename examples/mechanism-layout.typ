#import "../lib.typ" as michem

#set page(width: auto, height: auto, margin: 18pt)
#set text(font: "Libertinus Serif", size: 10pt)

= Measured mechanism layout

// Automatic cells reserve space between rows and columns for annotations.
#michem.mechanism(
  michem.mol("alcohol", "CCO"),
  michem.mol("aldehyde", "CC=O"),
  michem.mol("acid", "CC(=O)O"),
  michem.mol("ester", "CC(=O)OCC"),
  michem.reaction-arrow(
    michem.edge("alcohol"),
    michem.edge("aldehyde", side: "west"),
    above: [Oxidation],
  ),
  michem.reaction-arrow(
    michem.edge("acid"),
    michem.edge("ester", side: "west"),
    above: [EtOH, H⁺],
  ),
  arrangement: "grid",
  columns: 2,
  gap: 48pt,
  row-gap: 36pt,
  arrow-space: 12pt,
  font: "Libertinus Serif",
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
