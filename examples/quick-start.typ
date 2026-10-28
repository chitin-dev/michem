#import "../lib.typ" as michem

#set page(paper: "a4", margin: 2cm)
#set text(font: "Libertinus Serif", size: 10pt)
#show raw: set text(font: "Cascadia Code")

= Michem quick start

== A molecule

#michem.smiles(
  "CC(=O)Oc1ccccc1C(=O)O",
  style: michem.style(font: "Libertinus Serif"),
)

== An automatic reaction route

#michem.reaction-route(
  michem.reaction-stage("alcohol", michem.compound("CCO", name: [Alcohol])),
  michem.reaction-stage("aldehyde", michem.compound("CC=O", name: [Aldehyde])),
  michem.reaction-stage("acid", michem.compound("CC(=O)O", name: [Acid])),
  steps: (
    michem.reaction-step("alcohol", "aldehyde", above: [PCC]),
    michem.reaction-step("aldehyde", "acid", above: [Oxidation]),
  ),
)

== A circular layout with a released product

// Layout demonstration; all structures and transitions are explicitly authored.
#michem.reaction-route(
  michem.reaction-stage("a", "CO"),
  michem.reaction-stage("b", "C=O"),
  michem.reaction-stage("c", "O=CO"),
  layout: "circular",
  center: [Cycle],
  atom-size: 8pt,
  bond-length: 15pt,
  steps: (
    michem.reaction-step("a", "b", products: ("O",)),
    michem.reaction-step("b", "c"),
    michem.reaction-step("c", "a"),
  ),
)
