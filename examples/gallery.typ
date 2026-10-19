#import "../lib.typ" as michem

#set page(width: 19cm, height: auto, margin: 1.3cm)
#set text(font: "Libertinus Serif", size: 10pt)

#let sample(mol, caption, style: (:), height: 3cm) = align(center)[
  #block(height: height, width: 100%)[#align(center + horizon)[#michem.smiles(
    mol,
    style: (font: "Libertinus Serif") + style,
  )]]
  #caption
]

= Michem
Chemical structures from SMILES and authored coordinates.

== SMILES

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 12pt,
  sample("CCO", [Ethanol]),
  sample("CC(=O)Oc1ccccc1C(=O)O", [Aspirin]),
  sample("c1ccccc1", [Benzene], style: michem.style(aromatic: "circle")),
)

== Colors and drawing parameters

#let palette = michem.style(
  color-map: (O: rgb("#bf4b45"), N: rgb("#476ca8")),
  foreground: rgb("#30333a"),
  bond-length: 30,
  stroke-width: 1.1,
  bond-colors: "uniform",
)
#grid(
  columns: (1fr, 1fr),
  gutter: 12pt,
  sample(
    "NCC(=O)O",
    [Custom palette and proportions],
    style: palette,
    height: 2.4cm,
  ),
  sample(
    "NCC(=O)O",
    [Monochrome],
    style: michem.style(color-scheme: "monochrome"),
    height: 2.4cm,
  ),
)

== Manual drawing

#let authored = michem.molecule(
  atoms: (
    michem.atom("c1", at: (0, 0)),
    michem.atom("c2", at: (0.866, 0.5)),
    michem.atom("o", element: "O", at: (1.732, 0)),
  ),
  bonds: (michem.bond("c1", "c2"), michem.bond("c2", "o")),
)
#michem.smiles(authored, style: michem.style(font: "Libertinus Serif"))

== Stereochemistry

#grid(
  columns: (1fr, 1fr),
  gutter: 12pt,
  sample("N[C@@H](C)C(=O)O", [Tetrahedral center], height: 2.4cm),
  sample("F/C=C/F", [Double-bond configuration], height: 2.4cm),
)
