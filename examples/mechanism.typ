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
  michem.mol("product", "CC(C)O.[I-]", at: (210pt, 25pt)),
  michem.lone-pair(pair),
  michem.electron-arrow(pair, michem.atom-ref("substrate", 1), bend: 25),
  michem.electron-arrow(
    michem.bond-ref("substrate", 1, 3),
    michem.atom-ref("substrate", 3),
    bend: -22,
  ),
  michem.reaction-arrow(
    (110pt, 25pt),
    (190pt, 25pt),
    above: [H₂O],
    below: [Substitution],
  ),
  font: "Libertinus Serif",
)

#v(16pt)

// Measured automatic packing, an equilibrium connector, and a second font.
#michem.mechanism(
  michem.mol("acid", "CC(=O)O"),
  michem.mol("base", "CC(=O)[O-]", scale: 1.25),
  michem.reaction-arrow(
    michem.edge("acid"),
    michem.edge("base", side: "west"),
    equilibrium: true,
    above: [−H⁺],
  ),
  font: "Libertinus Sans",
)
