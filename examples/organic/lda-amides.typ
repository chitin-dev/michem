#import "../../lib.typ" as michem
#import "support/common.typ": *
#show: setup

= LDA: alpha C-H versus N-H deprotonation

#let lda-points = (
  n: (0, 0),
  left: (-1, -0.5),
  left-methyl1: (-2, -0.5),
  left-methyl2: (-1, -1.5),
  right: (1, -0.5),
  right-methyl1: (2, -0.5),
  right-methyl2: (1, -1.5),
)
#let lda = mechanism-graph(
  lda-points,
  (
    ("n", "left"),
    ("left", "left-methyl1"),
    ("left", "left-methyl2"),
    ("n", "right"),
    ("right", "right-methyl1"),
    ("right", "right-methyl2"),
  ),
  elements: (n: "N"),
  charges: (n: -1),
  hydrogens: (n: 0),
)
#let diisopropylamine = mechanism-graph(
  lda-points,
  (
    ("n", "left"),
    ("left", "left-methyl1"),
    ("left", "left-methyl2"),
    ("n", "right"),
    ("right", "right-methyl1"),
    ("right", "right-methyl2"),
  ),
  elements: (n: "N"),
  hydrogens: (n: 1),
)

#let tertiary-points = (
  alpha: (-1, -0.5),
  alpha-h: (-2, -0.5),
  k: (0, 0),
  o: (0, 1),
  n: (1, -0.5),
  n-methyl1: (2, -0.5),
  n-methyl2: (1, -1.5),
)
#let tertiary-amide(formed: false) = {
  let points = tertiary-points
  if formed { let _ = points.remove("alpha-h") }
  mechanism-graph(
    points,
    if formed {
      (
        ("k", "o"),
        ("k", "n"),
        ("k", "alpha", "double"),
        ("n", "n-methyl1"),
        ("n", "n-methyl2"),
      )
    } else {
      (
        ("k", "o", "double"),
        ("k", "n"),
        ("k", "alpha"),
        ("alpha", "alpha-h"),
        ("n", "n-methyl1"),
        ("n", "n-methyl2"),
      )
    },
    elements: (k: "C", o: "O", n: "N", "alpha-h": "H"),
    charges: if formed { (o: -1) } else { (:) },
    hydrogens: if formed { (alpha: 2) } else { (alpha: 2, "alpha-h": 0) },
  )
}
#let tertiary-pair = michem.atom-ref("lda", "n", offset: (0, 12))
#let tertiary-amide-deprotonation = figure(
  align(center, mechanism-row(
    mechanism-mol("lda", lda),
    mechanism-mol("amide", tertiary-amide()),
    mechanism-mol("enolate", tertiary-amide(formed: true)),
    mechanism-mol("dipa", diisopropylamine),
    michem.lone-pair(tertiary-pair, angle: 180deg, color: black),
    michem.electron-arrow(
      tertiary-pair,
      michem.atom-ref("amide", "alpha-h"),
      arc-angle: -120deg,
    ),
    michem.electron-arrow(
      michem.bond-ref("amide", "alpha", "alpha-h"),
      michem.bond-ref("amide", "k", "alpha"),
      arc-angle: 150deg,
    ),
    michem.electron-arrow(
      michem.bond-ref("amide", "k", "o"),
      michem.atom-ref("amide", "o"),
      arc-angle: 90deg,
      arc-path: "major",
    ),
    reaction-step("amide", "enolate"),
    component-plus("lda"),
    component-plus("enolate"),
    gap: 38pt,
  )),
  caption: [LDA removes an alpha proton from the tertiary amide. The products
    are an oxygen-centered enolate and diisopropylamine. Lithium ions are omitted.],
)

#let primary-points = (
  alpha: (-1, -0.5),
  k: (0, 0),
  o: (0, 1),
  n: (1, -0.5),
  h-removed: (0, -1.5),
  h-retained: (1, -1.5),
)
#let primary-amide(deprotonated: false) = mechanism-graph(
  if deprotonated {
    (
      alpha: (-1, -0.5),
      k: (0, 0),
      o: (0, 1),
      n: (1, -0.5),
      h-retained: (1, -1.5),
    )
  } else { primary-points },
  if deprotonated {
    (("alpha", "k"), ("k", "o", "double"), ("k", "n"), ("n", "h-retained"))
  } else {
    (
      ("alpha", "k"),
      ("k", "o", "double"),
      ("k", "n"),
      ("n", "h-removed"),
      ("n", "h-retained"),
    )
  },
  elements: (o: "O", n: "N", "h-removed": "H", "h-retained": "H"),
  charges: if deprotonated { (n: -1) } else { (:) },
  hydrogens: (n: 0, "h-removed": 0, "h-retained": 0),
)
#let primary-pair = michem.atom-ref("lda", "n", offset: (0, 12))
#let primary-amide-deprotonation = figure(
  align(center, mechanism-row(
    mechanism-mol("lda", lda),
    mechanism-mol("amide", primary-amide()),
    mechanism-mol("amidate", primary-amide(deprotonated: true)),
    mechanism-mol("dipa", diisopropylamine),
    michem.lone-pair(primary-pair, angle: 180deg, color: black),
    michem.electron-arrow(
      primary-pair,
      michem.atom-ref("amide", "h-removed"),
      arc-angle: -120deg,
    ),
    michem.electron-arrow(
      michem.bond-ref("amide", "n", "h-removed"),
      michem.atom-ref("amide", "n"),
      arc-angle: 150deg,
    ),
    reaction-step("amide", "amidate", above: [LDA]),
    component-plus("lda"),
    component-plus("amidate"),
    gap: 38pt,
  )),
  caption: [LDA preferentially removes an N-H proton from the primary amide,
    giving the amidate anion and diisopropylamine. Lithium ions are omitted.],
)

== Tertiary amide

The substrate has no N-H bond. The authored arrows remove an alpha hydrogen
and move the carbonyl pi electrons onto oxygen. Lithium ions are omitted.

#tertiary-amide-deprotonation

== Primary amide

The comparison shows N-H deprotonation and an amidate product instead.
The transferred and retained hydrogens are distinct named atoms.

#primary-amide-deprotonation
