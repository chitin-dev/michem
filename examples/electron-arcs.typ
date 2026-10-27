#import "../lib.typ" as michem

#set page(width: 18cm, height: auto, margin: 16pt)
#set text(font: "Libertinus Serif", size: 10pt)

#let ink = michem.style(
  font: "Libertinus Serif",
  font-size: 16,
  charge-style: "circled",
  color-scheme: "monochrome",
)
#let arrow-ink = (color: blue, width: 0.9, head-length: 4, head-width: 3)

= Exact circular electron arrows

Signed central angles control the circular sweep. Clipping retains the circle's
radius; arrowheads follow its terminal tangent. Electron arrows default to arcs.

#for angle in (60deg, 120deg, -120deg) {
  heading(level: 2)[Arc: #(str(angle / 1deg))°]
  michem.mechanism(
    michem.mol("donor", "[OH-]", style: ink),
    michem.mol("acceptor", "[H+]", style: ink),
    michem.electron-arrow(
      michem.atom-ref("donor", 0),
      michem.atom-ref("acceptor", 0),
      curve: "arc",
      arc-angle: angle,
      style: arrow-ink,
    ),
    gap: 85pt,
    font: "Libertinus Serif",
    padding: 12pt,
  )
}

== Single-electron heads

#let chlorine = michem.molecule(atoms: (
  michem.atom("cl", element: "Cl", at: (0, 0), hydrogens: 0),
))
#let left = michem.radical-ref("left", "cl", offset: (14, -8))
#let right = michem.radical-ref("right", "cl", offset: (-14, -8))
#let site = michem.formation-ref("left", "cl", "right", "cl")
#michem.mechanism(
  michem.mol("left", chlorine, style: ink),
  michem.mol("right", chlorine, style: ink),
  michem.electron-dot(left),
  michem.electron-dot(right),
  michem.electron-arrow(
    left,
    site,
    curve: "arc",
    arc-angle: 120deg,
    head: "fishhook-left",
    style: arrow-ink,
  ),
  michem.electron-arrow(
    right,
    site,
    curve: "arc",
    arc-angle: 120deg,
    head: "fishhook-right",
    style: arrow-ink,
  ),
  gap: 85pt,
  font: "Libertinus Serif",
  padding: 12pt,
)
