#import "../lib.typ" as michem

#set text(font: "Libertinus Serif")

#context {
  let font = "Libertinus Serif"
  let min-point(item) = item.origin.zip(item.bounds.min).map(((a, b)) => a + b)
  let max-point(item) = item.origin.zip(item.bounds.max).map(((a, b)) => a + b)
  let items = (
    michem.mol("a", "CCO"),
    michem.mol("b", "CC(=O)O", scale: 1.5),
    michem.mol("c", "[NH4+]"),
    michem.mol("d", "c1ccccc1"),
  )
  let data = michem.mechanism-data(
    ..items,
    font: font,
    arrangement: "grid",
    columns: 2,
    gap: 18pt,
    row-gap: 24pt,
    arrow-space: 6pt,
  )
  let (a, b, c, d) = data.placements
  // Measured ink envelopes, including scaled labels, must not overlap cells.
  assert(min-point(b).at(0) - max-point(a).at(0) >= 40 - 0.001)
  assert(min-point(c).at(1) - max-point(a).at(1) >= 48 - 0.001)
  assert(min-point(d).at(1) - max-point(b).at(1) >= 48 - 0.001)
  assert(calc.abs(min-point(a).at(0) - min-point(c).at(0)) < 0.001)

  let column = michem
    .mechanism-data(..items, font: font, arrangement: "column", row-gap: 24pt)
    .placements
  for i in range(1, column.len()) {
    assert(
      min-point(column.at(i)).at(1) - max-point(column.at(i - 1)).at(1)
        >= 32 - 0.001,
    )
  }

  let relative = michem
    .mechanism-data(
      michem.mol("substrate", "CC=O", at: (100, 75)),
      michem.mol("base", "[OH-]", at: michem.near(
        "substrate",
        side: "north",
        gap: 18pt,
        align: "start",
      )),
      michem.mol("water", "O", at: michem.near(
        "substrate",
        side: "south",
        gap: 12pt,
      )),
      font: font,
    )
    .placements
  let (substrate, base, water) = relative
  assert(substrate.origin == (100, 75))
  assert(
    calc.abs(min-point(substrate).at(1) - max-point(base).at(1) - 24) < 0.001,
  )
  assert(
    calc.abs(min-point(water).at(1) - max-point(substrate).at(1) - 16) < 0.001,
  )
  assert(calc.abs(min-point(substrate).at(0) - min-point(base).at(0)) < 0.001)

  let anchored = michem
    .mechanism-data(
      michem.mol("substrate", "CC=O", at: (100, 75)),
      michem.mol("base", "[OH-]", at: michem.near(
        "substrate",
        atom: 0,
        side: "north",
        gap: 18pt,
      )),
      font: font,
    )
    .placements
  let atom = anchored.first().atoms.find(atom => atom.id == "0")
  let at = atom.position.zip(anchored.first().origin).map(((a, b)) => a + b)
  assert(calc.abs(at.at(1) - max-point(anchored.last()).at(1) - 24) < 0.001)

  [All mechanism layout assertions passed.]
}
