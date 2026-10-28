#import "../lib.typ" as chem

#set page(width: 24cm, height: auto, margin: 18pt)
#set text(font: "Libertinus Serif", size: 10pt)

= Reaction route templates

== Participant groups and a shared molecular scale

#chem.reaction-route(
  chem.reaction-stage(
    "reactants",
    chem.compound("C[C@@H]([NH3+])C(=O)[O-]", name: [Alanine]),
    chem.compound("O=C([O-])C(=O)CCC(=O)[O-]", name: [α-ketoglutarate]),
  ),
  chem.reaction-stage(
    "products",
    chem.compound("CC(=O)C(=O)[O-]", name: [Pyruvate]),
    chem.compound("[NH3+][C@@H](CCC(=O)[O-])C(=O)[O-]", name: [Glutamate]),
  ),
  steps: (chem.reaction-step("reactants", "products", above: [ALT]),),
)

#chem.compound-grid(
  chem.compound("[NH4+]", name: [Ammonia excretion]),
  chem.compound("NC(=O)N", name: [Urea excretion]),
  chem.compound("O=C1NC(=O)C2=C(N1)NC(=O)N2", name: [Uric-acid excretion]),
)

== Automatic branches and a merge

#chem.reaction-route(
  chem.reaction-stage("start", chem.compound("CCO", name: [Starting material])),
  chem.reaction-stage("upper", chem.compound("CC=O", name: [Intermediate A])),
  chem.reaction-stage("lower", chem.compound(
    "CC(=O)O",
    name: [Intermediate B],
  )),
  chem.reaction-stage("product", chem.compound("CC(=O)OCC", name: [Product])),
  steps: (
    chem.reaction-step("start", "upper", above: [PCC]),
    chem.reaction-step("start", "lower", below: [Oxidation]),
    chem.reaction-step("upper", "product"),
    chem.reaction-step("lower", "product", below: [EtOH, H⁺]),
  ),
)

== Automatic continuation on a narrow line

#chem.reaction-route(
  chem.reaction-stage("a", chem.compound("CCO", name: [Alcohol])),
  chem.reaction-stage("b", chem.compound("CC=O", name: [Aldehyde])),
  chem.reaction-stage("c", chem.compound("CC(=O)O", name: [Acid])),
  chem.reaction-stage("d", chem.compound("CC(=O)OCC", name: [Ester])),
  max-width: 250pt,
)

== Vertical reversible route

#chem.reaction-route(
  chem.reaction-stage(
    "acid",
    chem.compound("CC(=O)O", name: [Acetic acid]),
    chem.compound("CCO", name: [Ethanol]),
  ),
  chem.reaction-stage(
    "ester",
    chem.compound("CC(=O)OCC", name: [Ethyl acetate]),
    chem.compound("O", name: [Water]),
  ),
  steps: (
    chem.reaction-step(
      "acid",
      "ester",
      equilibrium: true,
      above: [H⁺],
      below: [Heating],
    ),
  ),
  direction: "down",
)
