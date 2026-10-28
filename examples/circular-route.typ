#import "../lib.typ" as chem

#set page(width: 22cm, height: auto, margin: 18pt)
#set text(font: "Libertinus Serif", size: 10pt)

= Circular mechanism route template

// Structures and transitions are authored; this is a layout demonstration.
#chem.reaction-route(
  chem.reaction-stage("a", chem.compound("CCO", name: [Stage A])),
  chem.reaction-stage("b", chem.compound("CC=O", name: [Stage B])),
  chem.reaction-stage("c", chem.compound("CC(=O)O", name: [Stage C])),
  chem.reaction-stage("d", chem.compound("CC(=O)OCC", name: [Stage D])),
  layout: "circular",
  center: [*Reaction cycle*],
  steps: (
    chem.reaction-step("a", "b", above: [Condition 1], below: [Step 1]),
    chem.reaction-step("b", "c", above: [Condition 2]),
    chem.reaction-step("c", "d", above: [Condition 3], equilibrium: true),
    chem.reaction-step("d", "a", above: [Regeneration]),
  ),
)

== Counterclockwise with automatic closure

#chem.reaction-route(
  chem.reaction-stage("one", chem.compound("NCC(=O)O", name: [Intermediate 1])),
  chem.reaction-stage("two", chem.compound("NC(=O)N", name: [Intermediate 2])),
  chem.reaction-stage("three", chem.compound("[NH4+]", name: [Intermediate 3])),
  layout: "circular",
  clockwise: false,
  start-angle: 0deg,
)
