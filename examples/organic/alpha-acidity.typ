#import "../../lib.typ" as michem
#import "support/common.typ": *
#show: setup

= Carbonyl resonance and alpha-carbon acidity

// Named atoms retain explicit roles while bond orders and formal charges change.
#let amide-points = (
  alpha: (-1, -0.5),
  k: (0, 0),
  o: (0, 1),
  n: (1, -0.5),
  n-methyl1: (2, -0.5),
  n-methyl2: (1, -1.5),
)
#let amide-bonds = (
  ("alpha", "k"),
  ("k", "o", "double"),
  ("k", "n"),
  ("n", "n-methyl1"),
  ("n", "n-methyl2"),
)
#let amide(ionic: false) = mechanism-graph(
  amide-points,
  if ionic {
    (
      ("alpha", "k"),
      ("k", "o"),
      ("k", "n", "double"),
      ("n", "n-methyl1"),
      ("n", "n-methyl2"),
    )
  } else { amide-bonds },
  elements: (o: "O", n: "N"),
  charges: if ionic { (o: -1, n: 1) } else { (:) },
)

#let ester-points = (
  alpha: (-1, -0.5),
  k: (0, 0),
  o: (0, 1),
  "or": (1, -0.5),
  r1: (2, -0.5),
  r2: (3, -1),
)
#let ester-bonds = (
  ("alpha", "k"),
  ("k", "o", "double"),
  ("k", "or"),
  ("or", "r1"),
  ("r1", "r2"),
)
#let ester(ionic: false) = mechanism-graph(
  ester-points,
  if ionic {
    (
      ("alpha", "k"),
      ("k", "o"),
      ("k", "or", "double"),
      ("or", "r1"),
      ("r1", "r2"),
    )
  } else { ester-bonds },
  elements: (o: "O", "or": "O"),
  charges: if ionic { (o: -1, "or": 1) } else { (:) },
  hydrogens: ("or": 0),
)

#let amide-pair = michem.atom-ref("amide", "n", offset: (8, 0))
#let ester-pair = michem.atom-ref("ester", "or", offset: (8, 0))
#let alpha-resonance = figure(
  align(center, mechanism-row(
    mechanism-mol("amide", amide()),
    mechanism-mol("amide-contributor", amide(ionic: true)),
    mechanism-mol("ester", ester()),
    mechanism-mol("ester-contributor", ester(ionic: true)),
    michem.lone-pair(amide-pair, angle: 0deg, color: black),
    michem.electron-arrow(
      amide-pair,
      michem.bond-ref("amide", "k", "n"),
      arc-angle: 150deg,
    ),
    michem.electron-arrow(
      michem.bond-ref("amide", "k", "o"),
      michem.atom-ref("amide", "o"),
      arc-angle: 90deg,
      arc-path: "major",
    ),
    michem.lone-pair(ester-pair, angle: 0deg, color: black),
    michem.electron-arrow(
      ester-pair,
      michem.bond-ref("ester", "k", "or"),
      arc-angle: 150deg,
    ),
    michem.electron-arrow(
      michem.bond-ref("ester", "k", "o"),
      michem.atom-ref("ester", "o"),
      arc-angle: 90deg,
      arc-path: "major",
    ),
    resonance-step("amide"),
    resonance-step("ester"),
    gap: 40pt,
  )),
  caption: [Resonance contributors of an amide (left) and an ester (right).
    Curved arrows show heteroatom lone-pair donation and carbonyl pi-electron
    movement onto oxygen.],
)

#let hydroxide = mechanism-graph(
  (o: (0, 0)),
  (),
  elements: (o: "O"),
  charges: (o: -1),
  hydrogens: (o: 1),
)
#let acetone-points = (
  k: (0, 0),
  o: (0, 1),
  alpha: (-1, -0.5),
  h: (-1, -1.5),
  methyl-right: (1, -0.5),
)
#let acetone-enolate(formed: false) = {
  let points = acetone-points
  if formed { let _ = points.remove("h") }
  mechanism-graph(
    points,
    if formed {
      (
        ("k", "o"),
        ("k", "alpha", "double"),
        ("k", "methyl-right"),
      )
    } else {
      (
        ("k", "o", "double"),
        ("k", "alpha"),
        ("alpha", "h"),
        ("k", "methyl-right"),
      )
    },
    elements: (o: "O", h: "H"),
    charges: if formed { (o: -1) } else { (:) },
    hydrogens: if formed { (alpha: 2) } else { (alpha: 2, h: 0) },
  )
}
#let hydroxide-pair = michem.atom-ref("base", "o", offset: (-6, 0))
#let alpha-acetone-deprotonation = figure(
  align(center, with-electron-flow(
    route(
      michem.reaction-stage(
        "reactants",
        michem.compound(hydroxide),
        michem.compound(acetone-enolate()),
      ),
      michem.reaction-stage(
        "products",
        michem.compound(acetone-enolate(formed: true)),
        michem.compound("O"),
      ),
      steps: (
        michem.reaction-step("reactants", "products", above: [deprotonation]),
      ),
    ),
    mechanism-row(
      mechanism-mol("base", hydroxide),
      mechanism-mol("acetone", acetone-enolate()),
      michem.lone-pair(
        hydroxide-pair,
        angle: 180deg,
        separation: 3,
        color: black,
      ),
      michem.electron-arrow(
        hydroxide-pair,
        michem.atom-ref("acetone", "h"),
        arc-angle: -90deg,
      ),
      michem.electron-arrow(
        michem.bond-ref("acetone", "alpha", "h"),
        michem.bond-ref("acetone", "k", "alpha"),
        arc-angle: 150deg,
      ),
      michem.electron-arrow(
        michem.bond-ref("acetone", "k", "o"),
        michem.atom-ref("acetone", "o"),
        arc-angle: 90deg,
        arc-path: "major",
      ),
      gap: 40pt,
    ),
  )),
  caption: [Base-promoted deprotonation of acetone. The C-H electrons form
    the C=C bond, the carbonyl pi electrons move onto oxygen, and hydroxide
    becomes water.],
)

== Lone-pair donation

The two drawings of each compound are resonance contributors, not separate
species in an equilibrium. Electron-flow arrows connect explicit atoms and bonds.

#alpha-resonance

== Removing an alpha hydrogen

The proton being transferred is an explicit atom. The product enolate and water
are separate molecular occurrences; no reaction is inferred by the renderer.

#alpha-acetone-deprotonation
