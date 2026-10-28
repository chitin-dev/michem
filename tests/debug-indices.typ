#import "../lib.typ" as chem

#set text(font: "Libertinus Serif", size: 10pt)

#context {
  let debug = chem.style(debug: true, font: "Libertinus Serif")
  let input = "CC(=O)O"
  let diagram = chem.diagram(input, style: debug)
  assert(diagram.atoms.map(atom => atom.id) == ("0", "1", "2", "3"))
  assert(diagram.svg.contains("#2563eb"))
  let plain = chem.diagram(input, style: chem.style(font: "Libertinus Serif"))
  assert(not plain.svg.contains("#2563eb"))
  let ids(scene) = scene.layers.filter(layer =>
    layer.kind == "label" and layer.color == "#2563ebff"
  ).map(layer => layer.text)
  let marked = chem.compound(input, highlights: ((bonds: ((1, 2),),),))
  for layout in ("auto", "layered", "circular") {
    let route = chem.reaction-route-data(
      chem.reaction-stage("a", marked),
      chem.reaction-stage("b", "CC(=O)[O-]", "[H+]"),
      layout: layout,
      molecular-style: debug,
    )
    assert(ids(route.stages.first().cards.first().scene) == ("0", "1", "2", "3"))
    assert(ids(route.stages.last().cards.last().scene) == ("0",))
    chem.paint-reaction-route(route)
  }
  let graph = chem.molecule(
    atoms: (chem.atom("carbon", at: (0, 0)), chem.atom("oxygen", element: "O", at: (1, 0))),
    bonds: (chem.bond("carbon", "oxygen"),),
  )
  let named = chem.mechanism-data(
    chem.mol("named", graph, style: debug, scale: 1.37),
  )
  assert(ids(named.scene) == ("carbon", "oxygen"))
  let large = chem.mechanism-data(chem.mol("large", input, style: debug, scale: 1.37)).scene
  assert(ids(large) == ("0", "1", "2", "3"))
  chem.paint-mechanism(named)
  chem.smiles(input, style: debug)
}
