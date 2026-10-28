#import "../lib.typ" as chem
#import "../typst/route.typ" as routes
#import "../typst/circular-route.typ" as circular

#set text(font: "Libertinus Serif", size: 10pt)

#context {
  let stages = (
    chem.reaction-stage("a", chem.compound("CCO", name: [Intermediate A])),
    chem.reaction-stage("b", chem.compound("CC=O", name: [Intermediate B])),
    chem.reaction-stage("c", chem.compound("CC(=O)O", name: [Intermediate C])),
  )
  let steps = (
    chem.reaction-step(
      "a",
      "b",
      above: [Step 1],
      below: [Catalyst],
      reactants: (chem.compound("O", name: [Input]),),
      products: (chem.compound("[H+]"), chem.compound("[Cl-]")),
    ),
    chem.reaction-step("b", "c", above: [Step 2], products: (
      chem.compound("O=C=O", name: [Released product]),
    )),
    chem.reaction-step(
      "c",
      "a",
      above: [Regeneration],
      equilibrium: true,
      reactants: (chem.compound("N", name: [Additional reactant]),),
      products: (chem.compound("O", name: [Byproduct]),),
    ),
  )
  for (clockwise, mode) in (
    (true, "tangent-circle"),
    (false, "tangent-circle"),
    (true, "bezier"),
    (false, "bezier"),
  ) {
    let ring = chem.reaction-route-data(
      ..stages,
      steps: steps,
      layout: "circular",
      clockwise: clockwise,
      center: [Cycle],
      branch-curve: mode,
    )
    assert(ring.steps.len() == 3)
    assert(ring.branches.len() == 5)
    assert(
      ring.branches.map(branch => branch.kind)
        == (
          "reactants",
          "products",
          "products",
          "reactants",
          "products",
        ),
    )
    assert(ring.branches.at(1).group.cards.len() == 2)
    let all-notes = (
      ring.steps.map(edge => edge.notes).flatten() + (ring.center,)
    )
    for (i, branch) in ring.branches.enumerate() {
      let box = circular.bounds(branch.group)
      assert(not circular.points-hit(branch.points, box))
      assert(ring.stages.all(node => {
        not circular.overlaps(box, circular.bounds(node))
      }))
      assert(all-notes.all(note => {
        not circular.overlaps(box, circular.note-box(note))
      }))
      assert(all-notes.all(note => {
        not circular.points-hit(branch.points, circular.note-box(note))
      }))
      assert(ring.stages.all(node => {
        not circular.points-hit(branch.points, circular.bounds(node))
      }))
      for other in ring.branches.slice(i + 1) {
        assert(not circular.overlaps(box, circular.bounds(other.group)))
        assert(
          not circular.points-hit(branch.points, circular.bounds(other.group)),
        )
        assert(not circular.points-hit(other.points, box))
        assert(
          not circular.paths-hit(branch.points, other.points, ring.arrow-width),
        )
      }
      // Only the attachment point reaches the circular track. The terminal
      // direction at the junction follows the original step's flow tangent.
      let edge = ring.steps.find(edge => (
        edge.from == branch.from and edge.to == branch.to
      ))
      let junction = if branch.kind == "reactants" {
        branch.points.last()
      } else { branch.points.first() }
      let track = ring.radius + if edge.equilibrium { 3pt } else { 0pt }
      let r = (
        calc.sqrt(
          calc.pow(junction.at(0) / 1pt, 2) + calc.pow(junction.at(1) / 1pt, 2),
        )
          * 1pt
      )
      assert(calc.abs(r - track) < 0.001pt)
      for p in branch.points {
        let distance = (
          calc.sqrt(calc.pow(p.at(0) / 1pt, 2) + calc.pow(p.at(1) / 1pt, 2))
            * 1pt
        )
        assert(distance >= track - 0.001pt)
      }
      assert(branch.branch-curve == mode)
      let vector = if mode == "bezier" {
        assert("curve" in branch and "arc" not in branch)
        let control = if branch.kind == "reactants" {
          branch.curve.at(2)
        } else { branch.curve.at(1) }
        if branch.kind == "reactants" {
          (junction.at(0) - control.at(0), junction.at(1) - control.at(1))
        } else {
          (control.at(0) - junction.at(0), control.at(1) - junction.at(1))
        }
      } else {
        assert("arc" in branch and "curve" not in branch)
        let arc = branch.arc
        let distance(p, q) = (
          calc.sqrt(
            calc.pow((p.at(0) - q.at(0)) / 1pt, 2)
              + calc.pow((p.at(1) - q.at(1)) / 1pt, 2),
          )
            * 1pt
        )
        // Exact external tangency: centers are separated by the sum of radii.
        assert(
          calc.abs(distance(arc.center, (0pt, 0pt)) - (track + arc.radius))
            < 0.001pt,
        )
        assert(calc.abs(distance(junction, arc.center) - arc.radius) < 0.001pt)
        assert(calc.abs(arc.sweep) == 90deg)
        assert(branch.points.all(p => (
          calc.abs(distance(p, arc.center) - arc.radius) < 0.001pt
        )))
        let angle = (
          arc.start + if branch.kind == "reactants" { arc.sweep } else { 0deg }
        )
        let sign = if arc.sweep > 0deg { 1 } else { -1 }
        let tip = branch.points.last()
        let back = circular.tangent(arc, 1pt)
        let end-radius = (
          tip.at(0) - arc.center.at(0),
          tip.at(1) - arc.center.at(1),
        )
        assert(
          calc.abs(
            (end-radius.at(0) / 1pt) * ((tip.at(0) - back.at(0)) / 1pt)
              + (end-radius.at(1) / 1pt) * ((tip.at(1) - back.at(1)) / 1pt),
          )
            < 0.001,
        )
        (-sign * calc.sin(angle) * 1pt, sign * calc.cos(angle) * 1pt)
      }
      let dot = (
        (junction.at(0) / 1pt) * (vector.at(0) / 1pt)
          + (junction.at(1) / 1pt) * (vector.at(1) / 1pt)
      )
      let cross = (
        (junction.at(0) / 1pt) * (vector.at(1) / 1pt)
          - (junction.at(1) / 1pt) * (vector.at(0) / 1pt)
      )
      assert(calc.abs(dot) < 0.001)
      assert(if clockwise { cross > 0 } else { cross < 0 })
      for card in branch.group.cards {
        let labels = card.scene.layers.filter(layer => layer.kind == "label")
        assert(labels.map(label => label.size).fold(0, calc.max) == 12)
      }
      assert(box.min.at(0) >= ring.origin.at(0))
      assert(box.max.at(0) <= ring.origin.at(0) + ring.width)
      assert(box.min.at(1) >= ring.origin.at(1))
      assert(box.max.at(1) <= ring.origin.at(1) + ring.height)
    }
    let svg = str(routes.connector-svg(ring))
    assert(svg.matches(" C ").len() == if mode == "bezier" { 5 } else { 0 })
    assert(svg.matches(" A ").len() == if mode == "bezier" { 4 } else { 9 })
    assert(svg.matches("<polygon").len() == 9)
    assert(not svg.contains("−"))
    let fixed = chem.reaction-route-data(
      ..stages,
      steps: steps,
      layout: "circular",
      clockwise: clockwise,
      center: [Cycle],
      radius: ring.radius,
      branch-curve: mode,
    )
    assert(fixed.radius == ring.radius)
    assert(fixed.branches == ring.branches)
    if mode == "tangent-circle" {
      let default = chem.reaction-route-data(
        ..stages,
        steps: steps,
        layout: "circular",
        clockwise: clockwise,
        center: [Cycle],
      )
      assert(default.branches == ring.branches)
    }
    let two = chem.reaction-route-data(
      ..stages.slice(0, 2),
      layout: "circular",
      clockwise: clockwise,
      start-angle: 0deg,
      branch-curve: mode,
      atom-size: 11pt,
      font: "Libertinus Serif",
      steps: (
        chem.reaction-step(
          "a",
          "b",
          above: [Forward],
          reactants: (chem.compound("O", coefficient: 2),),
          products: ("N",),
        ),
        chem.reaction-step("b", "a", above: [Return], products: ("O=C=O",)),
      ),
    )
    assert(two.branches.len() == 3)
    assert(two.branches.first().group.cards.first().coefficient != none)
    for branch in two.branches {
      for card in branch.group.cards {
        let size = card
          .scene
          .layers
          .filter(layer => layer.kind == "label")
          .map(label => label.size)
          .fold(0, calc.max)
        assert(calc.abs(size - 11pt / 0.75pt) < 0.001)
      }
    }
  }
  let mixed = chem.reaction-route-data(
    ..stages,
    layout: "circular",
    branch-curve: "bezier",
    steps: (
      chem.reaction-step(
        "a",
        "b",
        reactants: ("O",),
        products: ("N",),
        branch-curve: "tangent-circle",
      ),
      chem.reaction-step("b", "c", products: ("O",)),
      chem.reaction-step("c", "a", products: ("N",), branch-curve: "bezier"),
    ),
  )
  assert(
    mixed.branches.map(branch => branch.branch-curve)
      == ("tangent-circle", "tangent-circle", "bezier", "bezier"),
  )
  assert(str(routes.connector-svg(mixed)).matches(" A ").len() == 5)
  assert(str(routes.connector-svg(mixed)).matches(" C ").len() == 2)
  [All circular input/output branch assertions passed.]
}
