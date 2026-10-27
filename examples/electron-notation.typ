#import "../lib.typ" as michem

#set page(width: 19cm, height: auto, margin: 16pt)
#set text(font: "Libertinus Serif", size: 10pt)

#let ink = michem.style(
  font: "Libertinus Serif",
  bond-length: 28,
  color-scheme: "monochrome",
  charge-style: "circled",
)
#let blue-arrow = (color: blue, width: 0.8, head-length: 4, head-width: 3)

= Endpoint-controlled electron flow

Each control is relative to its own endpoint, not a fixed page position.
Full arrowheads denote electron pairs; half arrowheads denote single electrons.

== Carbonyl addition and circled formal charges

#let ketone = michem.molecule(
  atoms: (
    michem.atom("c", at: (0, 0)),
    michem.atom("o", element: "O", at: (0, 1), hydrogens: 0),
    michem.atom("left", at: (-0.866, -0.5)),
    michem.atom("right", at: (0.866, -0.5)),
  ),
  bonds: (
    michem.bond("c", "o", order: "double"),
    michem.bond("c", "left"),
    michem.bond("c", "right"),
  ),
)
#let pair = michem.atom-ref("base", 0, offset: (0, 14))
#michem.mechanism(
  michem.mol("base", "[OH-]", style: ink),
  michem.mol("ketone", ketone, style: ink),
  michem.lone-pair(pair, color: black),
  michem.electron-arrow(
    pair,
    michem.atom-ref("ketone", "c"),
    curve: "bezier",
    controls: ((24, 34), (-24, 34)),
    style: blue-arrow,
  ),
  michem.electron-arrow(
    michem.bond-ref("ketone", "c", "o"),
    michem.atom-ref("ketone", "o"),
    curve: "bezier",
    controls: ((18, -2), (18, 0)),
    style: blue-arrow,
  ),
  gap: 64pt,
  font: "Libertinus Serif",
)

== A future bond between independent fragments

An intended bond is an annotation target: it does not add a chemical bond.
This protonation arrow terminates between oxygen and the incoming proton.

#let oxygen-pair = michem.atom-ref("hydroxide", 0, offset: (10, 8))
#michem.mechanism(
  michem.mol("hydroxide", "[OH-]", style: ink),
  michem.mol("proton", "[H+]", style: ink),
  michem.lone-pair(oxygen-pair, color: black),
  michem.electron-arrow(
    oxygen-pair,
    michem.formation-ref("hydroxide", 0, "proton", 0),
    curve: "bezier",
    controls: ((15, 22), (-5, 20)),
    style: blue-arrow,
  ),
  gap: 60pt,
  font: "Libertinus Serif",
)

== Explicit single-electron notation

The single-electron dots are authored annotations. They do not assign atomic
spin states or infer radical chemistry from a SMILES string.

#let chlorine = michem.molecule(atoms: (
  michem.atom("cl", element: "Cl", at: (0, 0), hydrogens: 0),
))
#let radical-a = michem.radical-ref("left", "cl", offset: (14, -8))
#let radical-b = michem.radical-ref("right", "cl", offset: (-14, -8))
#let site = michem.formation-ref("left", "cl", "right", "cl")
#michem.mechanism(
  michem.mol("left", chlorine, style: ink),
  michem.mol("right", chlorine, style: ink),
  michem.electron-dot(radical-a),
  michem.electron-dot(radical-b),
  michem.electron-arrow(
    radical-a,
    site,
    head: "fishhook-left",
    curve: "bezier",
    controls: ((12, -20), (-5, -20)),
    style: blue-arrow,
  ),
  michem.electron-arrow(
    radical-b,
    site,
    head: "fishhook-right",
    curve: "bezier",
    controls: ((-12, 20), (5, 20)),
    style: blue-arrow,
  ),
  gap: 72pt,
  font: "Libertinus Serif",
)
