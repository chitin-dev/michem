#import "../lib.typ" as michem

#set page(width: auto, height: auto, margin: 16pt)
#set text(font: "Libertinus Serif", size: 10pt)

// Each molecule is measured in the selected font, then arranged by Typst.
#michem.mechanism(
  michem.mol("amine", "c1ccccc1OCCN", at: (0pt, 0pt), scale: 1.3),
  michem.highlight("amine", bonds: (
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (4, 5),
    (5, 0),
  )),
  michem.highlight(
    "amine",
    atoms: (6, 9),
    bonds: ((5, 6), (6, 7), (7, 8), (8, 9)),
    color: rgb("#eeab5880"),
  ),
  font: "Libertinus Serif",
)

#v(16pt)

#let pair = michem.atom-ref("hydroxide", 0, offset: (9, 7))

== Substitution route

#michem.reaction-route(
  michem.reaction-stage("reactants", "[OH-]", "CC(C)I"),
  michem.reaction-stage("products", "CC(C)O", "[I-]"),
  steps: (
    michem.reaction-step(
      "reactants",
      "products",
      above: [H₂O],
      below: [Substitution],
    ),
  ),
)

=== Electron flow at the reacting atoms

#michem.mechanism(
  michem.mol("hydroxide", "[OH-]", at: (0pt, 0pt)),
  michem.mol(
    "substrate",
    michem.smiles-input("CC(C)I", positions: (
      (-0.866, 0.5),
      (0, 0),
      (0.866, 0.5),
      (0, -1),
    )),
    at: (85pt, 25pt),
  ),
  michem.lone-pair(pair),
  michem.electron-arrow(
    pair,
    michem.atom-ref("substrate", 1),
    arc-angle: -90deg,
  ),
  michem.electron-arrow(
    michem.bond-ref("substrate", 1, 3),
    michem.atom-ref("substrate", 3),
    arc-angle: 90deg,
  ),
  font: "Libertinus Serif",
)

#v(16pt)

== Reversible deprotonation

#michem.reaction-route(
  michem.reaction-stage("acid", "CC(=O)O"),
  michem.reaction-stage("base", "CC(=O)[O-]", "[H+]"),
  steps: (michem.reaction-step("acid", "base", equilibrium: true),),
)
