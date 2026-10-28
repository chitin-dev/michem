#import "../lib.typ" as chem
#import "../typst/route.typ" as routes

#set text(font: "Libertinus Serif", size: 10pt)

#context {
  let a = chem.reaction-stage("a", chem.compound("[NH4+]", name: [Ammonium]))
  let b = chem.reaction-stage("b", chem.compound(
    "NC(=O)N",
    name: [Urea],
    coefficient: 2,
  ))
  let c = chem.reaction-stage("c", chem.compound("NCC(=O)O", name: [Glycine]))
  let d = chem.reaction-stage("d", chem.compound("CC(=O)OCC", name: [Ester]))
  let data = chem.reaction-route-data(a, b, c, atom-size: 9pt, max-width: 500pt)
  assert(data.steps.len() == 2)
  assert(data.stages.map(stage => stage.id) == ("a", "b", "c"))
  // Real host text commands retain a shared size, not a per-molecule image fit.
  for stage in data.stages {
    let card = stage.cards.first()
    let labels = card.scene.layers.filter(layer => layer.kind == "label")
    assert(labels.len() > 0)
    assert(
      calc.abs(labels.map(label => label.size).fold(0, calc.max) - 12) < 0.001,
    )
    assert(labels.all(label => label.font == "Libertinus Serif"))
    assert(
      calc.abs(
        card.image-width
          - (card.scene.bounds.max.at(0) - card.scene.bounds.min.at(0))
            * 0.75pt,
      )
        < 0.001pt,
    )
  }
  assert(data.stages.at(1).cards.first().coefficient != none)
  assert(data.stages.all(stage => (
    stage.image-height == data.stages.first().image-height
  )))

  let small = chem.reaction-route-data(a, b, c, d, max-width: 200pt)
  assert(small.width <= 200pt)
  assert(small.stages.last().row > 0)
  assert(small.steps.any(edge => edge.points.len() == 6))
  // Negative outer lanes must use SVG-compatible ASCII minus signs.
  assert(not str(routes.connector-svg(small)).contains("−"))
  assert(str(routes.connector-svg(small)).contains("L -"))
  for edge in small.steps {
    for (p, q) in edge.points.windows(2) {
      assert(p.at(0) == q.at(0) or p.at(1) == q.at(1))
    }
  }

  let branch = chem.reaction-route-data(
    a,
    b,
    c,
    d,
    steps: (
      chem.reaction-step("a", "b", above: [Upper condition]),
      chem.reaction-step("a", "c", below: [Lower condition]),
      chem.reaction-step("b", "d"),
      chem.reaction-step("c", "d"),
    ),
    direction: "right",
  )
  let upper = branch.stages.find(stage => stage.id == "b")
  let lower = branch.stages.find(stage => stage.id == "c")
  let product = branch.stages.find(stage => stage.id == "d")
  assert(upper.rank == lower.rank)
  assert(upper.y + upper.height <= lower.y)
  assert(product.rank > upper.rank)
  // Conditions are placed on distinct branch legs, rather than the shared stem.
  assert(
    branch.steps.at(0).notes.first().y < branch.steps.at(1).notes.first().y,
  )

  let vertical = chem.reaction-route-data(a, b, c, direction: "down")
  assert(vertical.stages.at(1).y > vertical.stages.at(0).y)
  assert(
    vertical.stages.at(1).y
      >= vertical.stages.at(0).y + vertical.stages.at(0).height,
  )
  let skip = chem.reaction-route-data(
    a,
    b,
    c,
    steps: (
      chem.reaction-step("a", "b"),
      chem.reaction-step("b", "c"),
      chem.reaction-step("a", "c"),
    ),
    direction: "right",
  )
  assert(skip.steps.last().points.any(p => p.at(1) < 0pt))
  for edge in skip.steps {
    for node in skip.stages.filter(node => (
      node.id not in (edge.from, edge.to)
    )) {
      for (p, q) in edge.points.windows(2) {
        let crosses = if p.at(1) == q.at(1) {
          (
            p.at(1) > node.y
              and p.at(1) < node.y + node.height
              and calc.min(p.at(0), q.at(0)) < node.x + node.width
              and calc.max(p.at(0), q.at(0)) > node.x
          )
        } else {
          (
            p.at(0) > node.x
              and p.at(0) < node.x + node.width
              and calc.min(p.at(1), q.at(1)) < node.y + node.height
              and calc.max(p.at(1), q.at(1)) > node.y
          )
        }
        assert(
          not crosses,
          message: "Skip connector crossed an intermediate stage",
        )
      }
    }
  }
  let single = chem.reaction-route-data(chem.reaction-stage(
    "group",
    a.compounds.first(),
    b.compounds.first(),
  ))
  assert(single.steps.len() == 0)
  assert(
    single.stages.first().width
      > single.stages.first().cards.map(card => card.width).sum(),
  )
  let equilibrium = chem.reaction-route-data(a, b, steps: (
    chem.reaction-step("a", "b", equilibrium: true, above: [Equilibrium]),
  ))
  assert(str(routes.connector-svg(equilibrium)).matches("<polygon").len() == 2)
  let changed = chem.reaction-route-data(a, b, atom-size: 12pt)
  for stage in changed.stages {
    assert(
      stage
        .cards
        .first()
        .scene
        .layers
        .filter(layer => layer.kind == "label")
        .map(layer => layer.size)
        .fold(0, calc.max)
        == 16,
    )
  }
  let narrow-branch = chem.reaction-route-data(
    a,
    b,
    c,
    d,
    max-width: 220pt,
    steps: (
      chem.reaction-step("a", "b"),
      chem.reaction-step("a", "c"),
      chem.reaction-step("b", "d"),
      chem.reaction-step("c", "d"),
    ),
  )
  assert(narrow-branch.direction == "down")
  assert(narrow-branch.width <= 220pt)
  assert(
    measure(chem.reaction-route(a, b, c, d, max-width: 200pt)).width <= 200pt,
  )
  [All reaction route assertions passed.]
}
