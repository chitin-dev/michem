#import "../lib.typ" as michem

#set page(width: auto, height: auto, margin: 16pt)
#set text(font: "Libertinus Serif", size: 10pt)

= Route-attached mechanisms

The route remains the single source of truth for the intermediate sequence.
Each step draws its electron flow on the stage it leaves; `stage-mol` reuses the
stage compound instead of restating its SMILES.

#michem.reaction-route(
  michem.reaction-stage("acid", michem.compound(
    "CC(=O)O",
    name: [Acetic acid],
  )),
  michem.reaction-stage("protonated", michem.compound(
    "CC(=[OH+])O",
    name: [Protonated acid],
  )),
  michem.reaction-stage("ester", michem.compound(
    "CC(=O)OC",
    name: [Methyl acetate],
  )),
  steps: (
    michem.reaction-step(
      "acid",
      "protonated",
      above: [H⁺],
      mechanism: michem.reaction-mechanism(
        michem.stage-mol("acid"),
        michem.mol("proton", "[H+]", at: michem.near(
          "acid",
          side: "south",
          gap: 24pt,
        )),
        michem.electron-arrow(
          michem.atom-ref("acid", 2),
          michem.atom-ref("proton", 0),
          arc-angle: -55deg,
        ),
      ),
    ),
    michem.reaction-step(
      "protonated",
      "ester",
      above: [MeOH],
      below: [H⁺],
      mechanism: michem.reaction-mechanism(
        michem.stage-mol("protonated"),
        michem.mol("methanol", "CO", at: michem.near(
          "protonated",
          side: "south",
          gap: 28pt,
        )),
        michem.electron-arrow(
          michem.atom-ref("methanol", 1),
          michem.atom-ref("protonated", 1),
          arc-angle: -55deg,
        ),
        michem.electron-arrow(
          michem.bond-ref("protonated", 1, 2),
          michem.atom-ref("protonated", 2),
          arc-angle: 55deg,
        ),
      ),
    ),
  ),
)
