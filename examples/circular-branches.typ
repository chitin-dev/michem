#import "../lib.typ" as chem

#set page(width: auto, height: auto, margin: 18pt)
#set text(font: "Libertinus Serif", size: 10pt)

= Circular route with material inputs and outputs

// A layout demonstration: connectivity and participants are supplied explicitly.
#let cycle(branch-curve: "tangent-circle") = chem.reaction-route(
  chem.reaction-stage("a", chem.compound("CCO", name: [Intermediate A])),
  chem.reaction-stage("b", chem.compound("CC=O", name: [Intermediate B])),
  chem.reaction-stage("c", chem.compound("CC(=O)O", name: [Intermediate C])),
  layout: "circular",
  branch-curve: branch-curve,
  center: [*Reaction cycle*],
  max-width: none,
  steps: (
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
  ),
)

== Tangent circles (default)

#cycle()

#pagebreak()

== Cubic Bezier branches

#cycle(branch-curve: "bezier")
