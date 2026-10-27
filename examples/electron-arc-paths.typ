#import "../lib.typ" as michem

#set page(width: 18cm, height: auto, margin: 16pt)
#set text(font: "Libertinus Serif", size: 10pt)

= Circular paths and preferences

The same circle has a minor and a complementary major path. Automatic selection
checks the visible arc before applying the requested preference.

#let ink = michem.style(
  font: "Libertinus Serif",
  bond-length: 24,
  font-size: 14,
  color-scheme: "monochrome",
)
#let carbonyl = michem.molecule(
  atoms: (
    michem.atom("c", at: (0, 0)),
    michem.atom("o", element: "O", at: (0, 1), hydrogens: 0),
    michem.atom("a", at: (-0.866, -0.5)),
    michem.atom("b", at: (0.866, -0.5)),
  ),
  bonds: (
    michem.bond("c", "o", order: "double"),
    michem.bond("c", "a"),
    michem.bond("c", "b"),
  ),
)

/// Contrasts paths without changing the molecule, anchors, angle or arrow size.
#let panel(title, path, prefer: "minor") = block[
  *#title*

  #michem.mechanism(
    michem.mol("ketone", carbonyl, style: ink),
    michem.electron-arrow(
      michem.bond-ref("ketone", "c", "o"),
      michem.atom-ref("ketone", "o"),
      arc-angle: 90deg,
      arc-path: path,
      arc-prefer: prefer,
      style: (
        color: blue,
        width: 0.7,
        clearance: 0.5,
        head-length: 2.5,
        head-width: 2,
      ),
    ),
    font: "Libertinus Serif",
    padding: 12pt,
  )
]

== Short carbonyl arrow

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 12pt,
  panel("Minor", "minor"),
  panel("Major", "major"),
  panel("Auto; prefer minor", "auto"),
)

== Preference when both paths are readable

#for prefer in ("minor", "major") {
  block[
    *Auto; prefer #prefer*

    #michem.mechanism(
      michem.mol("donor", "[OH-]", style: ink),
      michem.mol("acceptor", "[H+]", style: ink),
      michem.electron-arrow(
        michem.atom-ref("donor", 0),
        michem.atom-ref("acceptor", 0),
        arc-angle: 120deg,
        arc-path: "auto",
        arc-prefer: prefer,
        style: (color: blue, width: 0.8, head-length: 4, head-width: 3),
      ),
      gap: 36pt,
      font: "Libertinus Serif",
      padding: 12pt,
    )
  ]
}

Collision-aware selection additionally uses #raw("route: \"auto\"").
