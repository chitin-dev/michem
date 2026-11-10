#import "../lib.typ" as chem

#set text(font: "Libertinus Serif", size: 10pt)

#context {
  let stages = (
    chem.reaction-stage(
      "acid",
      chem.compound(
        "CC(=O)O",
        name: [Acid],
        highlights: ((bonds: ((1, 2),), color: rgb("#88c7a880")),),
      ),
    ),
    chem.reaction-stage("protonated", chem.compound(
      "CC(=[OH+])O",
      name: [Protonated],
    )),
  )
  let steps = (
    chem.reaction-step(
      "acid",
      "protonated",
      above: [H⁺],
      mechanism: chem.reaction-mechanism(
        chem.stage-mol("acid"),
        chem.mol("proton", "[H+]", at: chem.near(
          "acid",
          side: "south",
          gap: 24pt,
        )),
        chem.electron-arrow(
          chem.atom-ref("acid", 2),
          chem.atom-ref("proton", 0),
          arc-angle: -55deg,
        ),
      ),
    ),
  )
  let data = chem.reaction-route-data(..stages, steps: steps)
  let plain = chem.reaction-route-data(
    chem.reaction-stage("acid", chem.compound("CC(=O)O", name: [Acid])),
    chem.reaction-stage("protonated", chem.compound(
      "CC(=[OH+])O",
      name: [Protonated],
    )),
    steps: (chem.reaction-step("acid", "protonated", above: [H⁺]),),
  )
  // The mechanism is part of the leaving stage, not a second panel row.
  assert(data.stages.first().at("premeasured", default: false))
  assert(not data.stages.last().at("premeasured", default: false))
  assert(data.stages.first().height > plain.stages.first().height)
  assert(data.stages.first().width > plain.stages.first().width)
  assert(measure(chem.reaction-route(..stages, steps: steps)).height > 0pt)

  // A stage mechanism is drawn directly on that stage.
  let direct = chem.reaction-route-data(
    chem.reaction-stage(
      "alcohol",
      chem.compound("CCO", name: [Alcohol]),
      mechanism: (chem.stage-mol("alcohol"),),
    ),
    chem.reaction-stage("aldehyde", "CC=O"),
  )
  assert(direct.stages.first().at("premeasured", default: false))
  assert(not direct.stages.last().at("premeasured", default: false))

  // Multiple stage participants share the in-stage mechanism canvas.
  let multi = chem.reaction-route-data(
    chem.reaction-stage(
      "base",
      chem.compound("CC(=O)[O-]"),
      chem.compound("[H+]"),
      mechanism: chem.reaction-mechanism(
        chem.stage-mol("base", index: 1, id: "proton"),
        chem.electron-dot(chem.radical-ref("proton", 0)),
      ),
    ),
    chem.reaction-stage("ester", "CC(=O)OC"),
    steps: (chem.reaction-step("base", "ester"),),
  )
  assert(multi.stages.first().at("premeasured", default: false))

  // Circular step mechanisms follow their leaving stage too.
  let circle = chem.reaction-route-data(
    chem.reaction-stage("x", "CO"),
    chem.reaction-stage("y", "C=O"),
    layout: "circular",
    steps: (
      chem.reaction-step(
        "x",
        "y",
        mechanism: chem.reaction-mechanism(chem.stage-mol("x")),
      ),
      chem.reaction-step("y", "x"),
    ),
  )
  assert(
    circle
      .stages
      .find(stage => stage.id == "x")
      .at(
        "premeasured",
        default: false,
      ),
  )
  assert(
    not circle
      .stages
      .find(stage => stage.id == "y")
      .at(
        "premeasured",
        default: false,
      ),
  )

  [All route mechanism assertions passed.]
}
