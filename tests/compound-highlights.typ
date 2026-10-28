#import "../lib.typ" as chem

#set text(font: "Libertinus Serif", size: 10pt)

#context {
  let marked = chem.compound(
    "CCO",
    name: [Ethanol],
    coefficient: 2,
    highlights: ((bonds: ((1, 2),), color: rgb("#88c7a880")),),
  )
  let plain = chem.compound("CCO", name: [Ethanol], coefficient: 2)
  let data = chem.reaction-route-data(
    chem.reaction-stage("a", plain),
    chem.reaction-stage("b", marked),
  )
  let a = data.stages.first().cards.first()
  let b = data.stages.last().cards.first()
  let vectors(card) = card
    .scene
    .layers
    .filter(layer => layer.kind == "vector")
    .map(layer => layer.svg)
    .join()
  assert(vectors(a) != vectors(b))
  assert(vectors(b).contains("#88c7a8"))
  assert(not vectors(a).contains("#88c7a8"))
  assert(b.image-width >= a.image-width and b.image-height >= a.image-height)
  assert(b.coefficient != none and b.name != none)
  assert(
    b
      .scene
      .layers
      .filter(layer => layer.kind == "label")
      .all(label => label.size == 12),
  )
  assert(data.stages.last().width >= b.width)

  let graph = chem.molecule(
    atoms: (chem.atom("a", at: (0, 0)), chem.atom("b", at: (1, 0))),
    bonds: (chem.bond("a", "b"),),
  )
  let named = chem.compound(graph, highlights: (
    (bonds: (("a", "b"),), radius: 8, color: rgb("#e9b44c80")),
    (atoms: ("b",), color: rgb("#6aaed680")),
  ))
  let circle = chem.reaction-route-data(
    chem.reaction-stage("a", named),
    chem.reaction-stage("b", plain),
    layout: "circular",
    steps: (
      chem.reaction-step("a", "b", products: (marked,)),
      chem.reaction-step("b", "a"),
    ),
  )
  assert(vectors(circle.stages.first().cards.first()).contains("#e9b44c"))
  assert(vectors(circle.stages.first().cards.first()).contains("#6aaed6"))
  assert(
    vectors(circle.branches.first().group.cards.first()).contains("#88c7a8"),
  )
  assert(not vectors(circle.stages.last().cards.first()).contains("#88c7a8"))
  chem.compound-grid(marked, named, columns: 2)
  chem.paint-reaction-route(circle)
}
