//! Instance-qualified reaction diagrams and annotations backed by Chitin.
//!
//! Preparation returns normalized coordinates and measured local bounds. The host
//! arranges those bounds, freezes every atom position, then composes against the
//! same named instances. Every call reconstructs its graph-local handle mapping;
//! neither process-local IDs nor mutable WASM state cross the protocol boundary.

mod layers;
pub mod model;

use crate::{Error, host_font, options};
use chitin_chem::{AtomId, MolecularGraph};
use chitin_chemdraw::{
  diagram as core,
  geometry::Point,
  layout::{self, Layout2d},
};
use model::{
  Anchors, Annotation, AtomAnchor, BondAnchor, Drawing, Head, Instance, Paint, Preparation,
  Prepared, Reference, Request, Target, VERSION,
};
use std::collections::{BTreeMap, BTreeSet};

struct Entry {
  id: core::MoleculeId,
  graph: MolecularGraph,
  coordinates: Layout2d,
  names: Vec<(AtomId, String)>,
}

/// Decodes one bounded versioned request, rejecting unsupported versions.
///
/// # Errors
/// Rejects malformed JSON, unknown fields, oversized requests, invalid versions,
/// duplicate occurrence names, and excessive molecule or annotation counts.
pub fn decode(bytes: &[u8]) -> Result<Request, Error> {
  if bytes.len() > 4 * 1024 * 1024 {
    return Err(Error::Input("mechanism request exceeds 4 MiB".into()));
  }
  let request: Request = serde_json::from_slice(bytes)?;
  validate(&request)?;
  Ok(request)
}

fn validate(request: &Request) -> Result<(), Error> {
  if request.version != VERSION {
    return Err(Error::Input(format!(
      "unsupported mechanism protocol version {}",
      request.version
    )));
  }
  if request.molecules.is_empty()
    || request.molecules.len() > 128
    || request.annotations.len() > 4096
  {
    return Err(Error::Input(
      "mechanism requires 1..=128 molecules and at most 4096 annotations".into(),
    ));
  }
  let mut names = BTreeSet::new();
  for instance in &request.molecules {
    if instance.id.is_empty()
      || instance.id.len() > 128
      || instance.id.chars().any(char::is_control)
      || !names.insert(&instance.id)
    {
      return Err(Error::Input(
        "molecule occurrence IDs must be unique, nonempty names of at most 128 bytes".into(),
      ));
    }
    if !instance.placement.scale.is_finite()
      || instance.placement.scale <= 0.
      || !instance.placement.origin.into_iter().all(f64::is_finite)
    {
      return Err(Error::Input(
        "molecule placement must be finite with positive scale".into(),
      ));
    }
    if instance.drawing.layout.max_atoms > 4096 {
      return Err(Error::Input("per-molecule atom limit exceeds 4096".into()));
    }
  }
  Ok(())
}

fn add(diagram: &mut core::Diagram, instance: &Instance, local: bool) -> Result<Entry, Error> {
  let input = instance
    .drawing
    .molecule
    .build(instance.drawing.layout.max_atoms)?;
  if !local && input.positions.is_none() {
    return Err(Error::Input(
      "compose requires prepared coordinates for every atom".into(),
    ));
  }
  let coordinates = match input.positions {
    Some(positions) => Layout2d::from_positions(positions)?,
    None => layout::generate(&input.graph, &instance.drawing.layout.options())?,
  };
  let mut options = instance.drawing.style.depict_options()?;
  if let Some(family) = &instance.drawing.style.font {
    options.font = host_font::face(family, &instance.drawing.measurements)?;
  }
  let origin = if local {
    Point::new(0., 0.)
  } else {
    Point::new(instance.placement.origin[0], instance.placement.origin[1])
  };
  let id = diagram.add_molecule(
    &input.graph,
    &coordinates,
    &options,
    core::Placement {
      origin,
      scale: instance.placement.scale,
    },
  )?;
  Ok(Entry {
    id,
    graph: input.graph,
    coordinates,
    names: input.names,
  })
}

fn atom(entry: &Entry, name: &str) -> Result<AtomId, Error> {
  entry
    .names
    .iter()
    .find(|(_, n)| n == name)
    .map(|(id, _)| *id)
    .ok_or_else(|| Error::Input(format!("unknown atom {name:?} in molecule occurrence")))
}

fn bond(entry: &Entry, from: &str, to: &str) -> Result<chitin_chem::BondId, Error> {
  entry
    .graph
    .bond_between(atom(entry, from)?, atom(entry, to)?)
    .ok_or_else(|| Error::Input(format!("no bond between {from:?} and {to:?}")))
}

fn anchors(diagram: &core::Diagram, entry: &Entry, id: &str) -> Result<Anchors, Error> {
  let mut atoms = Vec::new();
  let names: BTreeMap<_, _> = entry.names.iter().map(|(id, name)| (*id, name)).collect();
  for &(atom, ref name) in &entry.names {
    let p = diagram.resolve(core::Anchor::atom(entry.id, atom))?;
    atoms.push(AtomAnchor {
      id: name.clone(),
      position: [p.x, p.y],
    });
  }
  let mut bonds = Vec::new();
  for (id, edge) in entry.graph.bonds() {
    let [a, b] = edge.atoms();
    let name = |atom| {
      names
        .get(&atom)
        .map(|s| (*s).clone())
        .ok_or_else(|| Error::Input("missing bond endpoint name".into()))
    };
    let p = diagram.resolve(core::Anchor::bond(entry.id, id))?;
    bonds.push(BondAnchor {
      atoms: [name(a)?, name(b)?],
      position: [p.x, p.y],
    });
  }
  Ok(Anchors {
    id: id.into(),
    atoms,
    bonds,
  })
}

/// Prepares local molecular geometry for a measuring and arranging host.
///
/// # Returns
/// Measured bounds, instance-qualified anchors and complete normalized y-up atom
/// positions in input order. Translation is ignored here; positive scale applies.
/// Standalone SVG padding/background do not participate in the shared canvas.
///
/// # Errors
/// Rejects invalid requests, chemical or font failures, and missing coordinates.
pub fn prepare(request: &Request) -> Result<Preparation, Error> {
  validate(request)?;
  let mut molecules = Vec::new();
  let mut total = 0;
  for instance in &request.molecules {
    let mut diagram = core::Diagram::new();
    let entry = add(&mut diagram, instance, true)?;
    total += entry.graph.atom_count();
    if total > 8192 {
      return Err(Error::Input("mechanism exceeds 8192 atoms".into()));
    }
    let drawing = diagram.render()?;
    let bounds = drawing
      .bounds()
      .ok_or_else(|| Error::Input("empty molecular drawing".into()))?;
    let positions = entry
      .names
      .iter()
      .map(|(id, _)| {
        let p = entry
          .coordinates
          .position(*id)
          .ok_or_else(|| Error::Input("missing prepared atom position".into()))?;
        Ok([p.x, p.y])
      })
      .collect::<Result<_, Error>>()?;
    molecules.push(Prepared {
      id: instance.id.clone(),
      bounds: layers::envelope(bounds),
      positions,
      anchors: anchors(&diagram, &entry, &instance.id)?,
    });
  }
  Ok(Preparation {
    version: VERSION,
    molecules,
  })
}

fn reference(input: &Reference, entries: &BTreeMap<&str, Entry>) -> Result<core::Anchor, Error> {
  let entry = entries
    .get(input.molecule.as_str())
    .ok_or_else(|| Error::Input(format!("unknown molecule occurrence {:?}", input.molecule)))?;
  let anchor = match &input.target {
    Target::Atom { atom: name } => core::Anchor::atom(entry.id, atom(entry, name)?),
    Target::Bond { from, to } => core::Anchor::bond(entry.id, bond(entry, from, to)?),
  };
  Ok(anchor.with_offset(Point::new(input.offset[0], input.offset[1])))
}

fn paint(input: &Paint) -> Result<core::ArrowStyle, Error> {
  Ok(core::ArrowStyle {
    color: options::color(&input.color)?,
    width: input.width,
    head_length: input.head_length,
    head_width: input.head_width,
    clearance: input.clearance,
  })
}

fn annotation(
  input: &Annotation,
  entries: &BTreeMap<&str, Entry>,
) -> Result<core::Annotation, Error> {
  Ok(match input {
    Annotation::Highlight {
      molecule,
      atoms,
      bonds,
      radius,
      color,
    } => {
      let entry = entries
        .get(molecule.as_str())
        .ok_or_else(|| Error::Input(format!("unknown molecule occurrence {molecule:?}")))?;
      core::Annotation::Highlight(core::Highlight {
        molecule: entry.id,
        atoms: atoms
          .iter()
          .map(|n| atom(entry, n))
          .collect::<Result<_, _>>()?,
        bonds: bonds
          .iter()
          .map(|[a, b]| bond(entry, a, b))
          .collect::<Result<_, _>>()?,
        radius: *radius,
        color: options::color(color)?,
      })
    }
    Annotation::ElectronArrow {
      from,
      to,
      bend,
      head,
      style,
    } => core::Annotation::ElectronArrow(core::ElectronArrow {
      from: reference(from, entries)?,
      to: reference(to, entries)?,
      bend: *bend,
      head: match head {
        Head::Pair => core::ElectronHead::Pair,
        Head::FishhookLeft => core::ElectronHead::FishhookLeft,
        Head::FishhookRight => core::ElectronHead::FishhookRight,
      },
      style: paint(style)?,
    }),
    Annotation::ReactionArrow {
      start,
      end,
      equilibrium,
      style,
    } => core::Annotation::ReactionArrow(core::ReactionArrow {
      start: Point::new(start[0], start[1]),
      end: Point::new(end[0], end[1]),
      kind: if *equilibrium {
        core::ReactionArrowKind::Equilibrium
      } else {
        core::ReactionArrowKind::Forward
      },
      style: paint(style)?,
    }),
    Annotation::LonePair {
      anchor,
      angle,
      separation,
      radius,
      color,
    } => core::Annotation::LonePair(core::LonePair {
      anchor: reference(anchor, entries)?,
      angle: *angle,
      separation: *separation,
      radius: *radius,
      color: options::color(color)?,
    }),
  })
}

/// Composes frozen molecular geometry after the host has chosen final placements.
///
/// # Returns
/// Painter-ordered vector and host-text layers plus absolute named anchors. No
/// native layout is rerun and no host font is replaced by viewer-resolved text.
///
/// # Errors
/// Rejects incompatible versions, missing frozen coordinates, foreign names,
/// incomplete fonts, invalid annotations, and unrepresentable scene geometry.
pub fn compose(request: &Request) -> Result<Drawing, Error> {
  validate(request)?;
  let mut diagram = core::Diagram::new();
  let mut entries = BTreeMap::new();
  let mut total = 0;
  for instance in &request.molecules {
    let entry = add(&mut diagram, instance, false)?;
    total += entry.graph.atom_count();
    if total > 8192 {
      return Err(Error::Input("mechanism exceeds 8192 atoms".into()));
    }
    entries.insert(instance.id.as_str(), entry);
  }
  for item in &request.annotations {
    diagram.annotate(annotation(item, &entries)?);
  }
  let drawing = diagram.render()?;
  let bounds = drawing
    .bounds()
    .ok_or_else(|| Error::Input("empty mechanism drawing".into()))?;
  let molecules = request
    .molecules
    .iter()
    .map(|m| {
      let entry = entries
        .get(m.id.as_str())
        .ok_or_else(|| Error::Input("missing occurrence".into()))?;
      anchors(&diagram, entry, &m.id)
    })
    .collect::<Result<_, Error>>()?;
  Ok(Drawing {
    version: VERSION,
    bounds: layers::envelope(bounds),
    layers: layers::encode(&drawing)?,
    molecules,
  })
}
