#import "../../../lib.typ" as michem
#import "common.typ": (
  mechanism-graph, mechanism-mol, mechanism-row, mechanism-style, route,
  route-options, with-electron-flow,
)
#let chemistry = mechanism-style
// Named atoms persist across stages, so all arrow endpoints are explicit.
#let graph = mechanism-graph
#let mol = mechanism-mol
// Michem's authored coordinates do not carry a front/rear crossing annotation.
// This native Typst mask separates the rear stroke without changing topology.
/// Separates the rear stroke at the explicitly authored bridge crossing.
#let bridge-gap(item) = {
  let data = michem.diagram(item.value, style: chemistry)
  let upper-anchor = data.atoms.find(a => a.id == "r2")
  let lower-anchor = data.atoms.find(a => a.id == "b")
  // Intersection of q-l1 with r2-b in the authored bridge projection.
  let fraction = 0.2 / 1.05
  let x = upper-anchor.x
  let y = upper-anchor.y + fraction * (lower-anchor.y - upper-anchor.y)
  let mask = box(width: 6pt, height: 6pt)[
    #place(top + left, circle(radius: 3pt, fill: white, stroke: none))
    #place(top + left, dx: 3pt, line(end: (0pt, 6pt), stroke: (
      paint: rgb("#202124"),
      thickness: 0.975pt,
    )))
  ]
  michem.mechanism-label(
    michem.edge(item.id, side: "center"),
    move(
      dx: (x - 0.5) * data.width * 0.75pt,
      dy: (0.5 - y) * data.height * 0.75pt,
      mask,
    ),
  )
}
/// Explicit crossing overlays are opt-in presentation for the bridged projection.
/// Their white background is intentional; chemical connectivity is unchanged.
#let drawing(..items, gap: 64pt, crossings: ()) = context {
  let objects = items.pos()
  for item in items.pos() {
    if item.type == "molecule" and item.id in crossings {
      objects.push(bridge-gap(item))
    }
  }
  mechanism-row(..objects, gap: gap)
}
/// Paint the explicitly authored bridge crossing over the measured route card.
#let bridged-route(..stages, steps: auto, crossings: ()) = layout(size => {
  let data = michem.reaction-route-data(
    ..stages,
    steps: steps,
    max-width: size.width - 12pt,
    ..route-options,
  )
  for (i, stage) in data.stages.enumerate() {
    if stage.id not in crossings { continue }
    assert(stage.cards.len() == 1)
    let card = stage.cards.first()
    let local = michem.mechanism-data(michem.mol(
      "bridge",
      card.input.value,
      style: chemistry,
    ))
    let placement = local.placements.first()
    let upper = placement.atoms.find(atom => atom.id == "r2").position
    let lower = placement.atoms.find(atom => atom.id == "b").position
    let fraction = 0.2 / 1.05
    let p = (upper.at(0), upper.at(1) + fraction * (lower.at(1) - upper.at(1)))
    let low = local.scene.bounds.min
    let x = (
      (card.width - card.image-width) / 2
        + (p.at(0) + placement.origin.at(0) - low.at(0)) * 0.75pt
    )
    let y = (
      (stage.image-height - card.image-height) / 2
        + (p.at(1) + placement.origin.at(1) - low.at(1)) * 0.75pt
    )
    let body = stage.body
    stage.body = box(width: stage.width, height: stage.height, {
      body
      place(top + left, dx: x - 3pt, dy: y - 3pt, box(width: 6pt, height: 6pt)[
        #place(top + left, circle(radius: 3pt, fill: white, stroke: none))
        #place(top + left, dx: 3pt, line(
          end: (0pt, 6pt),
          stroke: 0.975pt + rgb("#202124"),
        ))
      ])
    })
    data.stages.at(i) = stage
  }
  michem.paint-reaction-route(data)
})
/// Overall synthesis uses automatic route arrows, conditions and participant groups.
#let scheme(start, product, above: none, below: none, crossings: ()) = {
  let stages = (
    michem.reaction-stage("s", michem.compound(start)),
    michem.reaction-stage("p", michem.compound(product)),
  )
  let steps = (michem.reaction-step("s", "p", above: above, below: below),)
  if crossings.len() > 0 {
    bridged-route(..stages, steps: steps, crossings: crossings)
  } else { route(..stages, steps: steps) }
}
#let crossed-scheme(donor, acceptor, product, above: none, below: none) = route(
  michem.reaction-stage(
    "reactants",
    michem.compound(donor),
    michem.compound(acceptor),
  ),
  michem.reaction-stage("product", michem.compound(product)),
  steps: (
    michem.reaction-step("reactants", "product", above: above, below: below),
  ),
)
/// Shows the two electron movements and highlights the newly formed C-C bond.
#let crossed-addition(
  donor,
  acceptor,
  product,
  oxygen-arrow: (arc-angle: 90deg, arc-path: "major"),
) = with-electron-flow(
  crossed-scheme(donor, acceptor, product, above: [C–C addition]),
  stack(
    dir: ttb,
    spacing: 6pt,
    drawing(
      mol("d", donor),
      mol("e", acceptor),
      michem.electron-arrow(
        michem.atom-ref("d", "a"),
        michem.atom-ref("e", "b"),
        arc-angle: 90deg,
      ),
      michem.electron-arrow(
        michem.bond-ref("e", "b", "ob"),
        michem.atom-ref("e", "ob"),
        ..oxygen-arrow,
      ),
      gap: 58pt,
    ),
    [*New bond in the product*],
    drawing(mol("p", product), michem.highlight("p", bonds: (("a", "b"),))),
  ),
)
/// Keep intramolecular electron flow local and show the product on the route.
#let cyclic-addition(
  enolate,
  product,
  arc-angle: 90deg,
  oxygen-arrow: (arc-angle: 90deg, arc-path: "major"),
  crossings: (),
) = with-electron-flow(
  scheme(enolate, product, above: [intramolecular addition], crossings: if "p"
    in crossings { ("p",) } else { () }),
  stack(
    dir: ttb,
    spacing: 6pt,
    drawing(
      mol("e", enolate),
      michem.electron-arrow(
        michem.atom-ref("e", "a"),
        michem.atom-ref("e", "b"),
        arc-angle: arc-angle,
      ),
      michem.electron-arrow(
        michem.bond-ref("e", "b", "ob"),
        michem.atom-ref("e", "ob"),
        ..oxygen-arrow,
      ),
    ),
    [*New bond in the product*],
    drawing(
      mol("p", product),
      michem.highlight("p", bonds: (("a", "b"),)),
      crossings: crossings,
    ),
  ),
)

#let a-points = (
  k: (0, 0),
  ok: (0, 1),
  i: (-1, -0.5),
  l: (-2, 0),
  m: (-1, -1.5),
  a: (1, -0.5),
)
#let a-bonds = (
  ("k", "ok", "double"),
  ("k", "i"),
  ("i", "l"),
  ("i", "m"),
  ("k", "a"),
)
#let a-donor = graph(a-points, a-bonds, elements: (ok: "O"))
#let a-enolate = graph(
  a-points,
  a-bonds,
  elements: (ok: "O"),
  charges: (a: -1),
  hydrogens: (a: 2),
)
/// Selects ethanal or propanal while preserving named carbonyl anchors.
#let aldehyde(ethyl: false) = graph(
  if ethyl { (b: (0, 0), ob: (0, 1), t: (1, -0.5), u: (2, 0)) } else {
    (b: (0, 0), ob: (0, 1), t: (1, -0.5))
  },
  if ethyl { (("b", "ob", "double"), ("b", "t"), ("t", "u")) } else {
    (("b", "ob", "double"), ("b", "t"))
  },
  elements: (ob: "O"),
)
/// Builds the alkoxide, alcohol, conjugate base or enone for the acyclic route.
#let a-product(alkoxide: false, enone: false, e1cb: false) = {
  let points = a-points + (b: (2, 0), ob: (2, 1), t: (3, -0.5))
  let bonds = (
    a-bonds + (("a", "b", if enone { "double" } else { "single" }), ("b", "t"))
  )
  if enone { let _ = points.remove("ob") } else { bonds.push(("b", "ob")) }
  graph(
    points,
    bonds,
    elements: (ok: "O", ob: "O"),
    charges: if alkoxide { (ob: -1) } else if e1cb { (a: -1) } else { (:) },
    hydrogens: if e1cb { (a: 1) } else { (:) },
  )
}

// A folded ketoaldehyde, not a methyl-substituted ring, starts route (b).
#let b-points = (
  k: (0, 0),
  ok: (0, 1),
  a: (1, -0.5),
  t: (2, 0),
  c6: (-1, -0.5),
  c5: (-1, -1.5),
  c4: (0, -2),
  b: (1, -1.5),
  ob: (2.1, -1.5),
)
#let b-backbone = (
  ("k", "ok", "double"),
  ("k", "a"),
  ("a", "t"),
  ("k", "c6"),
  ("c6", "c5"),
  ("c5", "c4"),
  ("c4", "b"),
)
/// Builds folded 5-oxoheptanal or its six-membered aldol products.
#let b-stage(enolate: false, cyclic: false, alkoxide: false, enone: false) = {
  let points = b-points
  let bonds = b-backbone
  if cyclic { bonds.push(("a", "b", if enone { "double" } else { "single" })) }
  if enone { let _ = points.remove("ob") } else {
    bonds.push(("b", "ob", if cyclic { "single" } else { "double" }))
  }
  graph(
    points,
    bonds,
    elements: (ok: "O", ob: "O"),
    charges: if enolate { (a: -1) } else if alkoxide { (ob: -1) } else { (:) },
    hydrogens: if enolate { (a: 1) } else { (:) },
  )
}

#let c-points = (
  k: (0, 0),
  ok: (0, 1),
  a: (1, -0.5),
  c3: (1, -1.5),
  c4: (0, -2),
  c5: (-1, -1.5),
  c6: (-1, -0.5),
)
#let c-bonds = (
  ("k", "ok", "double"),
  ("k", "a"),
  ("a", "c3"),
  ("c3", "c4"),
  ("c4", "c5"),
  ("c5", "c6"),
  ("c6", "k"),
)
/// Builds cyclohexanone-derived intermediates and the exocyclic enone.
#let c-stage(enolate: false, addition: false, alkoxide: false, enone: false) = {
  let points = c-points
  let bonds = c-bonds
  if addition {
    points += (b: (2, 0), ob: (2, 1), t: (3, -0.5), u: (4, 0))
    bonds += (
      ("a", "b", if enone { "double" } else { "single" }),
      ("b", "t"),
      ("t", "u"),
    )
    if enone { let _ = points.remove("ob") } else { bonds.push(("b", "ob")) }
  }
  graph(
    points,
    bonds,
    elements: (ok: "O", ob: "O"),
    charges: if enolate { (a: -1) } else if alkoxide { (ob: -1) } else { (:) },
    hydrogens: if enolate { (a: 1) } else { (:) },
  )
}

// q and b are the bridgeheads; three paths each have two internal carbons.
#let d-start-points = (
  q: (0, 0),
  m: (-0.5, 1),
  l1: (-1, -0.5),
  l2: (-1, -1.5),
  b: (0, -2),
  ob: (0, -3),
  r1: (1, -0.5),
  r2: (1, -1.5),
  k: (1, 0.7),
  ok: (1, 1.7),
  a: (2, 0.2),
)
#let d-backbone = (
  ("q", "m"),
  ("q", "l1"),
  ("l1", "l2"),
  ("l2", "b"),
  ("b", "r2"),
  ("r2", "r1"),
  ("r1", "q"),
  ("q", "k"),
  ("k", "ok", "double"),
  ("k", "a"),
)
#let d-product-points = (
  q: (0.4, 0.5),
  m: (0.9, 1.45),
  l1: (-0.7, 0.2),
  l2: (-1.25, -0.8),
  b: (-0.15, -0.5),
  ob: (-0.15, -1.6),
  r1: (0.4, 1.55),
  r2: (-0.15, 0.55),
  k: (1.45, 0.2),
  ok: (2.25, 0.8),
  a: (0.9, -0.85),
)
/// Builds the precursor or authored bicyclo[2.2.2] aldol projection.
#let d-stage(enolate: false, cyclic: false, alkoxide: false) = graph(
  if cyclic { d-product-points } else { d-start-points },
  d-backbone
    + (("b", "ob", if cyclic { "single" } else { "double" }),)
    + if cyclic { (("a", "b"),) } else { () },
  elements: (ok: "O", ob: "O"),
  charges: if enolate { (a: -1) } else if alkoxide { (ob: -1) } else { (:) },
  hydrogens: if enolate { (a: 2) } else { (:) },
)
