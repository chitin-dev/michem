#import "../lib.typ" as michem
#import "@preview/cetz:0.5.2": canvas

#set page(width: 16cm, height: auto, margin: 1cm)
#set text(font: "Libertinus Serif", size: 10pt)

= Configurable molecule fonts

#let mol = "[13NH3+]CC(=O)[O-]"

#for family in ("Libertinus Serif", "Liberation Sans", "Liberation Mono") [
  *#family*
  #michem.render(mol, style: michem.style(font: family, bond-length: 40))
  #parbreak()
]

== CeTZ

#canvas({
  michem.cetz.molecule(
    "NCC(=O)O",
    name: "glycine",
    style: michem.style(font: "Libertinus Serif"),
  )
})
