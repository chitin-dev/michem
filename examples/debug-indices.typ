#import "../lib.typ" as michem

#set page(width: 170mm, height: auto, margin: 12mm)
#set text(font: "Libertinus Serif", size: 10pt)
#show raw: set text(font: "Cascadia Code")

= Inspecting atom indices

Blue IDs identify the atoms used by highlights. A bond is addressed by its two
endpoint IDs. Ring closure digits in SMILES do not create additional atoms.

#michem.compound-grid(
  michem.compound("CC(=O)O", name: [Acetic acid]),
  michem.compound("CC(=O)Oc1ccccc1C(=O)O", name: [Aspirin]),
  michem.compound("Cn1c(=O)c2c(ncn2C)n(C)c1=O", name: [Caffeine]),
  molecular-style: michem.style(debug: true),
)

== Selecting a bond in a reaction route

The ester bond in methyl acetate connects atoms 1 and 3. Each participant has
its own indices, starting at zero.

#michem.reaction-route(
  michem.reaction-stage("ester", michem.compound(
    "CC(=O)OC",
    name: [Methyl acetate],
    highlights: ((bonds: ((1, 3),), color: rgb("#88c7a880")),),
  )),
  michem.reaction-stage("products", "CC(=O)[O-]", "CO"),
  molecular-style: michem.style(debug: true),
)
