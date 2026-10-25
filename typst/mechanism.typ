// Measured molecules and authored annotations share one y-down vector canvas.
#import "molecule.typ" as chemical

/// A named occurrence. `at` is its local drawing origin, not its image corner.
/// Positions accept lengths or SVG pixels; `none` enables measured row packing.
#let mol(
  id,
  value,
  at: none,
  offset: (0pt, 0pt),
  scale: 1,
  style: (:),
  layout: (:),
) = (
  type: "molecule",
  id: id,
  value: value,
  at: at,
  offset: offset,
  scale: scale,
  style: style,
  layout: layout,
)

/// An atom reference scoped to one named occurrence; offsets use local pixels.
#let atom-ref(molecule, atom, offset: (0, 0)) = (
  molecule: molecule,
  target: (kind: "atom", atom: str(atom)),
  offset: offset,
)

/// A logical bond reference, addressed by original atom names or parse indices.
#let bond-ref(molecule, from, to, offset: (0, 0)) = (
  molecule: molecule,
  target: (kind: "bond", from: str(from), to: str(to)),
  offset: offset,
)

/// Atom disks, measured labels and rounded bond bands under a molecular fragment.
#let highlight(
  molecule,
  atoms: (),
  bonds: (),
  radius: 4,
  color: rgb("#88c7a880"),
) = (
  type: "highlight",
  molecule: molecule,
  atoms: atoms.map(str),
  bonds: bonds.map(pair => pair.map(str)),
  radius: radius,
  color: chemical.color-value(color),
)

#let paint(style) = {
  let result = style
  if "color" in result {
    result.insert("color", chemical.color-value(result.color))
  }
  result
}

/// Authored electron movement. Bend and arrow style sizes use shared SVG pixels.
/// Head is `pair`, `fishhook-left` or `fishhook-right`.
#let electron-arrow(from, to, bend: 30, head: "pair", style: (:)) = (
  type: "electron-arrow",
  from: from,
  to: to,
  bend: bend,
  head: head,
  style: paint(style),
)

/// Explicit lone-pair dots; use the same displaced reference as an arrow source.
#let lone-pair(anchor, angle: 0deg, separation: 3, radius: 0.7, color: red) = (
  type: "lone-pair",
  anchor: anchor,
  angle: angle / 1rad,
  separation: separation,
  radius: radius,
  color: chemical.color-value(color),
)

/// A measured occurrence edge, resolved after host packing and offsets.
#let edge(molecule, side: "east", gap: 3pt) = (
  molecule: molecule,
  side: side,
  gap: gap,
)

/// A reaction-step connector with arbitrary Typst conditions; not electron flow.
#let reaction-arrow(
  from,
  to,
  equilibrium: false,
  above: none,
  below: none,
  style: (:),
) = (
  type: "connector",
  from: from,
  to: to,
  equilibrium: equilibrium,
  above: above,
  below: below,
  style: paint(style),
)

/// A centered Typst label at a diagram point or measured occurrence edge.
#let mechanism-label(at, body) = (type: "note", at: at, body: body)

#let pixels(value) = if type(value) == length { value / 0.75pt } else { value }
#let point(value, placed) = {
  if type(value) == array { return value.map(pixels) }
  let item = placed.find(item => item.id == value.molecule)
  assert(
    item != none,
    message: "Unknown molecule occurrence: " + value.molecule,
  )
  let low = item.bounds.min.zip(item.origin).map(((a, b)) => a + b)
  let high = item.bounds.max.zip(item.origin).map(((a, b)) => a + b)
  let x = (low.at(0) + high.at(0)) / 2
  let y = (low.at(1) + high.at(1)) / 2
  let gap = pixels(value.gap)
  let sides = (
    east: (high.at(0) + gap, y),
    west: (low.at(0) - gap, y),
    north: (x, low.at(1) - gap),
    south: (x, high.at(1) + gap),
    center: (x, y),
  )
  assert(value.side in sides, message: "Unknown molecule edge: " + value.side)
  sides.at(value.side)
}

#let note(at, body) = {
  let size = measure(body)
  (at: at, body: body, width: size.width / 0.75pt, height: size.height / 0.75pt)
}

/// Builds versioned scene data inside a Typst context. Layout coordinates are
/// frozen between preparation and final composition; no second layout occurs.
#let mechanism-data(..items, font: none, gap: 24pt, label-gap: 4pt) = {
  assert(items.named().len() == 0, message: "Unknown mechanism option")
  assert(
    pixels(gap) >= 0 and pixels(label-gap) >= 0,
    message: "Mechanism gaps must be nonnegative",
  )
  let items = items.pos()
  let molecules = ()
  for item in items.filter(item => item.type == "molecule") {
    assert(item.scale > 0, message: "Molecule scale must be positive")
    let style = item.style
    if font != none and style.at("font", default: none) == none {
      style.insert("font", font)
    }
    molecules.push((
      id: item.id,
      drawing: json(chemical.request(
        item.value,
        style: style,
        layout: item.layout,
        scale: item.scale,
      )),
      placement: (origin: (0, 0), scale: item.scale),
    ))
  }
  let request = (version: 1, molecules: molecules, annotations: ())
  let prepared = json(chemical
    .backend()
    .mechanism_prepare(bytes(json.encode(request))))
  assert(
    prepared.version == 1,
    message: "Unsupported mechanism preparation version",
  )
  let placed = ()
  let frozen = ()
  let cursor = 0
  for (i, item) in items.filter(item => item.type == "molecule").enumerate() {
    let prepared = prepared.molecules.at(i)
    let bounds = prepared.bounds
    let origin = if item.at == none {
      (cursor - bounds.min.at(0), -(bounds.min.at(1) + bounds.max.at(1)) / 2)
    } else { point(item.at, ()) }
    origin = origin.zip(item.offset.map(pixels)).map(((a, b)) => a + b)
    cursor = calc.max(cursor, origin.at(0) + bounds.max.at(0) + pixels(gap))
    let instance = molecules.at(i)
    let drawing = instance.drawing
    let molecule = drawing.molecule
    if molecule.kind == "smiles" {
      molecule.insert("positions", prepared.positions)
    } else {
      molecule.insert("atoms", molecule
        .atoms
        .enumerate()
        .map(((i, atom)) => {
          let result = atom
          result.insert("position", prepared.positions.at(i))
          result
        }))
    }
    drawing.insert("molecule", molecule)
    instance.insert("drawing", drawing)
    instance.insert("placement", (origin: origin, scale: item.scale))
    frozen.push(instance)
    placed.push((id: item.id, origin: origin, bounds: bounds))
  }
  let annotations = ()
  let notes = ()
  for item in items.filter(item => item.type != "molecule") {
    if item.type == "note" {
      notes.push(note(point(item.at, placed), item.body))
    } else if item.type == "connector" {
      let start = point(item.from, placed)
      let end = point(item.to, placed)
      annotations.push((
        type: "reaction-arrow",
        start: start,
        end: end,
        equilibrium: item.equilibrium,
        style: item.style,
      ))
      let delta = end.zip(start).map(((a, b)) => a - b)
      let distance = calc.sqrt(delta.map(x => x * x).sum())
      assert(distance > 0, message: "Reaction arrow endpoints must differ")
      let normal = (-delta.at(1) / distance, delta.at(0) / distance)
      let center = start.zip(end).map(((a, b)) => (a + b) / 2)
      for (sign, body) in ((-1, item.above), (1, item.below)) {
        if body == none { continue }
        let label = note(center, body)
        let support = (
          calc.abs(normal.at(0)) * label.width / 2
            + calc.abs(normal.at(1)) * label.height / 2
        )
        label.insert(
          "at",
          center
            .zip(normal)
            .map(((p, n)) => p + sign * n * (support + pixels(label-gap))),
        )
        notes.push(label)
      }
    } else { annotations.push(item) }
  }
  request.insert("molecules", frozen)
  request.insert("annotations", annotations)
  let scene = json(chemical.backend().mechanism(bytes(json.encode(request))))
  assert(scene.version == 1, message: "Unsupported mechanism scene version")
  (scene: scene, notes: notes)
}

/// Paints portable vector layers interleaved with native, identically measured text.
#let paint-mechanism(data, padding: 6pt) = {
  assert(padding >= 0pt, message: "Mechanism padding must be nonnegative")
  let low = data.scene.bounds.min
  let high = data.scene.bounds.max
  for note in data.notes {
    low = low
      .zip(note.at.zip((note.width, note.height)))
      .map(((a, (p, size))) => calc.min(a, p - size / 2))
    high = high
      .zip(note.at.zip((note.width, note.height)))
      .map(((a, (p, size))) => calc.max(a, p + size / 2))
  }
  let origin = low.map(x => x - pixels(padding))
  let dimensions = high.zip(low).map(((a, b)) => (a - b) * 0.75pt + 2 * padding)
  box(width: dimensions.at(0), height: dimensions.at(1), {
    for layer in data.scene.layers {
      let position = layer.origin.zip(origin).map(((a, b)) => (a - b) * 0.75pt)
      if layer.kind == "vector" {
        place(top + left, dx: position.at(0), dy: position.at(1), image(
          bytes(layer.svg),
          format: "svg",
          width: layer.width * 0.75pt,
          height: layer.height * 0.75pt,
        ))
      } else {
        let body = chemical.host-text(
          layer.font,
          layer.size,
          layer.text,
          fill: rgb(layer.color),
        )
        place(
          top + left,
          dx: position.at(0),
          dy: position.at(1) + layer.top * 0.75pt,
          scale(
            x: layer.stretch * 100%,
            origin: top + left,
            reflow: true,
            body,
          ),
        )
      }
    }
    for note in data.notes {
      place(
        top + left,
        dx: (note.at.at(0) - note.width / 2 - origin.at(0)) * 0.75pt,
        dy: (note.at.at(1) - note.height / 2 - origin.at(1)) * 0.75pt,
        note.body,
      )
    }
  })
}

/// A measured reaction diagram with fragment highlights and authored electron flow.
#let mechanism(
  ..items,
  font: none,
  gap: 24pt,
  padding: 6pt,
  label-gap: 4pt,
) = context {
  assert(items.named().len() == 0, message: "Unknown mechanism option")
  paint-mechanism(
    mechanism-data(..items.pos(), font: font, gap: gap, label-gap: label-gap),
    padding: padding,
  )
}
