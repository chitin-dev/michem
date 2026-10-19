#import "@preview/cetz:0.5.2": canvas, draw
#import "../lib.typ" as michem

#set page(width: auto, height: auto, margin: 18pt)
#set text(font: "Libertinus Serif", size: 9pt)

// Rings mark exact atom anchors under a shared translation, rotation and scale.
#canvas({
  import draw: *
  scope({
    translate((2, 1))
    rotate(35deg)
    scale(1.5)
    michem.cetz.molecule(
      "CCO",
      name: "ethanol",
      style: michem.style(font: "Libertinus Serif"),
    )
    for id in ("0", "1", "2") {
      circle("ethanol.atom-" + id, radius: 2pt, stroke: blue + 0.4pt)
    }
  })
})
