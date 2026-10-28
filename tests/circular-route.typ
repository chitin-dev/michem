#import "../lib.typ" as chem
#import "../typst/route.typ" as routes
#import "../typst/circular-route.typ" as circular

#set text(font: "Libertinus Serif", size: 10pt)

#context {
  let a = chem.reaction-stage("a", chem.compound("CCO", name: [Stage A]))
  let b = chem.reaction-stage("b", chem.compound("CC=O", name: [Stage B]))
  let c = chem.reaction-stage("c", chem.compound("CC(=O)O", name: [Stage C]))
  let d = chem.reaction-stage("d", chem.compound("CC(=O)OCC", name: [Stage D]))
  let ring = chem.reaction-route-data(
    a,
    b,
    c,
    d,
    layout: "circular",
    center: [Cycle],
  )
  assert(ring.layout == "circular")
  assert(ring.steps.len() == 4)
  assert(ring.steps.last().from == "d" and ring.steps.last().to == "a")
  for node in ring.stages {
    let x = (node.x + node.width / 2) / 1pt
    let y = (node.y + node.height / 2) / 1pt
    assert(calc.abs(calc.sqrt(x * x + y * y) * 1pt - ring.radius) < 0.001pt)
    let labels = node
      .cards
      .first()
      .scene
      .layers
      .filter(layer => layer.kind == "label")
    if labels.len() > 0 {
      assert(labels.map(label => label.size).fold(0, calc.max) == 12)
    }
  }
  assert(ring.stages.first().y < 0pt)
  assert(ring.stages.at(1).x > 0pt)
  for (i, node) in ring.stages.enumerate() {
    for other in ring.stages.slice(i + 1) {
      assert(
        not circular.overlaps(
          circular.bounds(node),
          circular.bounds(other),
          gap: 18pt,
        ),
      )
    }
  }
  for edge in ring.steps {
    assert(edge.arc.sweep > 0deg)
    for p in edge.points {
      assert(
        calc.abs(
          calc.sqrt(
            (p.at(0) / 1pt) * (p.at(0) / 1pt)
              + (p.at(1) / 1pt) * (p.at(1) / 1pt),
          )
            * 1pt
            - ring.radius,
        )
          < 0.001pt,
      )
    }
    let end = edge.points.last()
    let back = circular.tangent(edge.arc, ring.head-size)
    let dot = (
      (end.at(0) / 1pt) * ((end.at(0) - back.at(0)) / 1pt)
        + (end.at(1) / 1pt) * ((end.at(1) - back.at(1)) / 1pt)
    )
    assert(calc.abs(dot) < 0.001)
  }
  let svg = str(routes.connector-svg(ring))
  assert(svg.matches(" A ").len() == 4)
  assert(not svg.contains("−"))

  let reverse = chem.reaction-route-data(
    a,
    b,
    c,
    d,
    layout: "circular",
    clockwise: false,
  )
  assert(reverse.stages.at(1).x < 0pt)
  assert(reverse.steps.all(edge => edge.arc.sweep < 0deg))
  let rotated = chem.reaction-route-data(
    a,
    b,
    c,
    d,
    layout: "circular",
    start-angle: 0deg,
  )
  assert(rotated.stages.first().x > 0pt)
  assert(
    calc.abs(rotated.stages.first().y + rotated.stages.first().height / 2)
      < 0.001pt,
  )
  let explicit = chem.reaction-route-data(
    a,
    b,
    c,
    d,
    layout: "circular",
    radius: ring.radius + 30pt,
  )
  assert(explicit.radius == ring.radius + 30pt)

  // An explicitly connected cycle is ordered by its edges, not its declarations.
  let ordered = chem.reaction-route-data(
    a,
    c,
    b,
    d,
    layout: "circular",
    steps: (
      chem.reaction-step("a", "b"),
      chem.reaction-step("b", "c"),
      chem.reaction-step("c", "d"),
      chem.reaction-step("d", "a"),
    ),
  )
  assert(ordered.stages.map(node => node.id) == ("a", "b", "c", "d"))
  let annotated = chem.reaction-route-data(
    a,
    b,
    c,
    d,
    layout: "circular",
    center: [Catalyst],
    steps: (
      chem.reaction-step(
        "a",
        "b",
        above: [Long outer condition],
        below: [Inner note],
      ),
      chem.reaction-step("b", "c"),
      chem.reaction-step("c", "d", equilibrium: true),
      chem.reaction-step("d", "a"),
    ),
  )
  let notes = annotated.steps.map(edge => edge.notes).flatten()
  assert(notes.len() == 2)
  assert(notes.first().side == "outside" and notes.last().side == "inside")
  for note in notes {
    assert(
      not circular.overlaps(circular.note-box(note), circular.note-box(
        annotated.center,
      )),
    )
    assert(annotated.stages.all(node => {
      not circular.overlaps(circular.bounds(node), circular.note-box(note))
    }))
  }
  assert(str(routes.connector-svg(annotated)).matches(" A ").len() == 5)
  let two = chem.reaction-route-data(a, b, layout: "circular")
  assert(two.steps.len() == 2)
  assert(two.steps.all(edge => calc.abs(edge.arc.sweep) < 180deg))
  assert(two.steps.first().points.any(p => p.at(0) > 0pt))
  assert(two.steps.last().points.any(p => p.at(0) < 0pt))
  [All circular route assertions passed.]
}
