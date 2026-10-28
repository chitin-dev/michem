//! Instance-qualified reaction diagrams and annotations backed by Chitin.
//!
//! Preparation returns normalized coordinates and measured local bounds. The host
//! arranges those bounds, freezes every atom position, then composes against the
//! same named instances. Every call reconstructs its graph-local handle mapping;
//! neither process-local IDs nor mutable WASM state cross the protocol boundary.
//!
//! Composition resolves fixed annotations first, then explicit lone pairs,
//! manual electron arrows and automatic electron arrows. Later searches see
//! earlier accepted annotations as obstacles. Pair placement and arrow routing
//! share a finite request-wide work allowance and fail explicitly if no clear
//! candidate is found. These searches choose geometry, not reaction chemistry.

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

/// One reconstructed occurrence and its request-local chemical namespace.
struct Entry {
  /// Handle valid only in the native diagram built for the current call.
  id: core::MoleculeId,
  /// Graph owning the atom and bond handles used by annotations.
  graph: MolecularGraph,
  /// Normalized y-up coordinates, before paint scaling and instance placement.
  coordinates: Layout2d,
  /// Original input-order atom IDs associated with this graph's handles.
  names: Vec<(AtomId, String)>,
}

/// Decodes one bounded versioned request, rejecting unsupported versions.
///
/// # Parameters
/// - `bytes`: UTF-8 JSON for a [`model::Request`], at most 4 MiB.
///
/// # Returns
/// A request with defaults applied and occurrence-level limits validated.
/// Graph construction, annotation references and routing obstacles are checked
/// later by [`prepare`] or [`compose`], as appropriate for each phase.
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

/// Checks wire version, occurrence names, transforms and top-level size limits.
///
/// Shared by direct Rust calls and decoded requests. Chemical graphs and
/// annotation-specific constraints are deliberately checked by their consumers.
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

/// Reconstructs and snapshots one occurrence in the current native diagram.
///
/// # Parameters
/// - `diagram`: diagram receiving the new occurrence and its fresh handle.
/// - `instance`: topology, font measurements and requested placement.
/// - `local`: preparation mode; suppresses translation and permits layout.
///
/// # Returns
/// The owning graph, coordinates and stable name mapping for later resolution.
/// Scale applies in both modes; composition requires complete frozen positions.
///
/// # Errors
/// Propagates input, layout, font and depiction failures. Missing coordinates in
/// composition are rejected rather than regenerated after host-side placement.
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

/// Resolves an original atom ID within one occurrence, rejecting unknown names.
fn atom(entry: &Entry, name: &str) -> Result<AtomId, Error> {
  entry
    .names
    .iter()
    .find(|(_, n)| n == name)
    .map(|(id, _)| *id)
    .ok_or_else(|| Error::Input(format!("unknown atom {name:?} in molecule occurrence")))
}

/// Adds optional atom IDs using final occurrence positions and scaled font sizes.
///
/// The same path is used during preparation and composition so debug ink
/// participates in measured bounds. Disabled debug mode returns the drawing
/// unchanged; missing positions or exact font metrics propagate as errors.
fn debug_overlay(
  drawing: chitin_chemdraw::Drawing,
  diagram: &core::Diagram,
  instance: &Instance,
  entry: &Entry,
) -> Result<chitin_chemdraw::Drawing, Error> {
  if !instance.drawing.style.debug {
    return Ok(drawing);
  }
  let mut options = instance.drawing.style.depict_options()?;
  if let Some(family) = &instance.drawing.style.font {
    options.font = host_font::face(family, &instance.drawing.measurements)?;
  }
  let atoms = entry
    .names
    .iter()
    .map(|(id, name)| {
      Ok((
        name.as_str(),
        diagram.resolve(core::Anchor::atom(entry.id, *id))?,
      ))
    })
    .collect::<Result<Vec<_>, Error>>()?;
  crate::debug::overlay(drawing, &options, &atoms, instance.placement.scale)
}

/// Resolves an existing logical bond by either ordering of its endpoint names.
///
/// Missing atoms or bonds fail explicitly; no new bond is inferred or inserted.
fn bond(entry: &Entry, from: &str, to: &str) -> Result<chitin_chem::BondId, Error> {
  entry
    .graph
    .bond_between(atom(entry, from)?, atom(entry, to)?)
    .ok_or_else(|| Error::Input(format!("no bond between {from:?} and {to:?}")))
}

/// Exports named atom centers and bond midpoints in the diagram's current frame.
///
/// Preparation uses a zero-translation frame; composition uses final placement.
/// Native handles are replaced by original input names before serialization.
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
/// # Parameters
/// - `request`: named occurrences with molecular inputs and exact host metrics.
///   Authored annotations and routing obstacles do not affect this phase.
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
    let drawing = debug_overlay(diagram.render()?, &diagram, instance, &entry)?;
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

/// Explicit lone-pair attachments, indexed first by occurrence, then by pair ID.
type Pairs<'a> = BTreeMap<&'a str, BTreeMap<&'a str, core::Anchor>>;

/// Resolves an occurrence-qualified attachment and adds its local displacement.
///
/// Formation references may span two occurrences. Lone-pair references retain
/// the resolved pair offset and add the caller's offset before instance scaling.
/// Unknown occurrences, atoms, bonds or pair IDs return input errors.
fn reference(
  input: &Reference,
  entries: &BTreeMap<&str, Entry>,
  pairs: &Pairs<'_>,
) -> Result<core::Anchor, Error> {
  let entry = entries
    .get(input.molecule.as_str())
    .ok_or_else(|| Error::Input(format!("unknown molecule occurrence {:?}", input.molecule)))?;
  let anchor = match &input.target {
    Target::Radical { atom: name } => {
      core::Anchor::radical(entry.id, atom(entry, name)?, Point::new(0., 0.))
    }
    Target::BondFormation {
      atom: name,
      other_molecule,
      other_atom,
    } => {
      let other = entries
        .get(other_molecule.as_str())
        .ok_or_else(|| Error::Input(format!("unknown molecule occurrence {other_molecule:?}")))?;
      core::Anchor::bond_formation(
        entry.id,
        atom(entry, name)?,
        other.id,
        atom(other, other_atom)?,
      )
    }
    Target::Atom { atom: name } => core::Anchor::atom(entry.id, atom(entry, name)?),
    Target::Bond { from, to } => core::Anchor::bond(entry.id, bond(entry, from, to)?),
    Target::LonePair { pair } => pairs
      .get(input.molecule.as_str())
      .and_then(|p| p.get(pair.as_str()))
      .copied()
      .ok_or_else(|| {
        Error::Input(format!(
          "unknown lone pair {pair:?} in {:?}",
          input.molecule
        ))
      })?,
  };
  Ok(anchor.with_offset(Point::new(
    anchor.offset.x + input.offset[0],
    anchor.offset.y + input.offset[1],
  )))
}

/// Converts arrow paint without scaling shared-canvas dimensions by a molecule.
///
/// Color syntax is checked here; native annotation rendering validates geometry.
fn paint(input: &Paint) -> Result<core::ArrowStyle, Error> {
  Ok(core::ArrowStyle {
    color: options::color(&input.color)?,
    width: input.width,
    head_length: input.head_length,
    head_width: input.head_width,
    clearance: input.clearance,
  })
}

/// Converts one wire annotation to native geometry using this call's namespaces.
///
/// Public angles in degrees become native radians only for circular sweeps;
/// lone-pair angles already use radians. Routing policies are handled by
/// composition, so this conversion itself performs no automatic search.
fn annotation(
  input: &Annotation,
  entries: &BTreeMap<&str, Entry>,
  pairs: &Pairs<'_>,
) -> Result<core::Annotation, Error> {
  Ok(match input {
    Annotation::ElectronDot {
      anchor,
      radius,
      color,
    } => core::Annotation::ElectronDot(core::ElectronDot {
      anchor: reference(anchor, entries, pairs)?,
      radius: *radius,
      color: options::color(color)?,
    }),
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
      curve,
      arc_angle,
      arc_path,
      arc_prefer,
      controls,
      from,
      to,
      bend,
      head,
      style,
      ..
    } => core::Annotation::ElectronArrow(core::ElectronArrow {
      curve: match curve {
        model::Curve::Bezier => core::ElectronCurve::Bezier,
        model::Curve::Arc => core::ElectronCurve::Arc {
          sweep: arc_angle.to_radians(),
          path: arc_path.policy(arc_prefer),
        },
      },
      controls: controls.map(|points| points.map(|p| Point::new(p[0], p[1]))),
      from: reference(from, entries, pairs)?,
      to: reference(to, entries, pairs)?,
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
      ..
    } => core::Annotation::LonePair(core::LonePair {
      anchor: reference(anchor, entries, pairs)?,
      angle: *angle,
      separation: *separation,
      radius: *radius,
      color: options::color(color)?,
    }),
  })
}

/// Composes frozen molecular geometry after the host has chosen final placements.
///
/// # Parameters
/// - `request`: complete frozen coordinates, final occurrence placements,
///   annotations and host-measured routing obstacles in shared y-down units.
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
  let mut obstacles = Vec::with_capacity(request.obstacles.len());
  if request.obstacles.len() > 4096 {
    return Err(Error::Input(
      "mechanism exceeds 4096 routing obstacles".into(),
    ));
  }
  for bounds in &request.obstacles {
    if bounds.min[0] > bounds.max[0] || bounds.min[1] > bounds.max[1] {
      return Err(Error::Input("routing obstacle bounds are reversed".into()));
    }
    obstacles.push(
      chitin_chemdraw::geometry::Bounds::from_points([
        Point::new(bounds.min[0], bounds.min[1]),
        Point::new(bounds.max[0], bounds.max[1]),
      ])?
      .ok_or_else(|| Error::Input("empty routing obstacle".into()))?,
    );
  }
  let mut pairs = Pairs::new();
  // Reaction connectors are fixed before pair suggestion and arrow routing.
  for item in &request.annotations {
    if matches!(
      item,
      Annotation::ReactionArrow { .. }
        | Annotation::Highlight { .. }
        | Annotation::ElectronDot { .. }
    ) {
      diagram.annotate(annotation(item, &entries, &pairs)?);
    }
  }
  let mut lone_pairs = Vec::new();
  // Clamp each search to the remaining request-wide allowance so individually
  // bounded annotations cannot multiply the intended request-wide work limit.
  let mut remaining_work = 16_000_000;
  for (index, item) in request.annotations.iter().enumerate() {
    let Annotation::LonePair {
      anchor,
      id,
      position,
      placement,
      ..
    } = item
    else {
      continue;
    };
    if matches!(anchor.target, Target::LonePair { .. }) {
      return Err(Error::Input(
        "lone pairs must attach to an atom or bond".into(),
      ));
    }
    let core::Annotation::LonePair(mut pair) = annotation(item, &entries, &pairs)? else {
      return Err(Error::Input("expected lone pair".into()));
    };
    if matches!(position, model::Route::Auto) {
      if remaining_work == 0 {
        return Err(Error::Input(
          "mechanism routing work budget exhausted".into(),
        ));
      }
      let mut options = placement.options();
      options.work_budget = options.work_budget.min(remaining_work);
      let suggestion = diagram.suggest_lone_pair(pair, &options, &obstacles)?;
      remaining_work -= suggestion.work_used;
      if !suggestion.clear {
        return Err(Error::Input(format!(
          "no clear lone-pair position for annotation {index} after {} candidates",
          suggestion.evaluated
        )));
      }
      pair = suggestion.pair;
    }
    if let Some(id) = id
      && (id.is_empty()
        || id.len() > 128
        || id.chars().any(char::is_control)
        || pairs
          .entry(anchor.molecule.as_str())
          .or_default()
          .insert(id.as_str(), pair.anchor)
          .is_some())
    {
      return Err(Error::Input(
        "lone-pair IDs must be unique within a molecule, nonempty and at most 128 bytes".into(),
      ));
    }
    diagram.annotate(core::Annotation::LonePair(pair));
    lone_pairs.push(model::PlacedPair {
      annotation: index,
      molecule: anchor.molecule.clone(),
      id: id.clone(),
      offset: [pair.anchor.offset.x, pair.anchor.offset.y],
      angle: pair.angle,
    });
  }
  // Resolve manual arrows first so automatic arrows also avoid authored curves.
  for item in &request.annotations {
    if matches!(
      item,
      Annotation::ElectronArrow {
        route: model::Route::Manual,
        ..
      }
    ) {
      diagram.annotate(annotation(item, &entries, &pairs)?);
    }
  }
  let mut routing = Vec::new();
  for (index, item) in request.annotations.iter().enumerate() {
    let Annotation::ElectronArrow {
      route: model::Route::Auto,
      routing: settings,
      ..
    } = item
    else {
      continue;
    };
    let core::Annotation::ElectronArrow(arrow) = annotation(item, &entries, &pairs)? else {
      return Err(Error::Input("expected electron arrow".into()));
    };
    if remaining_work == 0 {
      return Err(Error::Input(
        "mechanism routing work budget exhausted".into(),
      ));
    }
    let mut options = settings.options();
    options.work_budget = options.work_budget.min(remaining_work);
    let result = diagram.route_electron_arrow(arrow, &options, &obstacles)?;
    remaining_work -= result.work_used;
    if !result.clear {
      return Err(Error::Input(format!(
        "no clear electron-arrow route for annotation {index} after {} candidates and {} comparisons{}; adjust molecule placement or routing limits",
        result.evaluated,
        result.work_used,
        if result.limited {
          " (search limit reached)"
        } else {
          ""
        }
      )));
    }
    // Accepted arrows become obstacles for the next search. Failure above must
    // remain an error: returning an overlapping fallback would hide lost intent.
    diagram.annotate(core::Annotation::ElectronArrow(result.arrow));
    routing.push(model::RoutedArrow {
      arc_path: match result.arrow.curve {
        core::ElectronCurve::Bezier => None,
        core::ElectronCurve::Arc {
          path: core::ArcPath::Major,
          ..
        } => Some("major"),
        core::ElectronCurve::Arc { .. } => Some("minor"),
      },
      arc_angle: match result.arrow.curve {
        core::ElectronCurve::Bezier => None,
        core::ElectronCurve::Arc { sweep, .. } => Some(sweep.to_degrees()),
      },
      annotation: index,
      bend: result.arrow.bend,
      evaluated: result.evaluated,
      work_used: result.work_used,
    });
  }
  // Debug text is inspection ink, appended after routing; it does not alter the
  // authored chemical attachments or consume the automatic routing budget.
  let mut drawing = diagram.render()?;
  for instance in &request.molecules {
    let entry = entries
      .get(instance.id.as_str())
      .ok_or_else(|| Error::Input("missing occurrence".into()))?;
    drawing = debug_overlay(drawing, &diagram, instance, entry)?;
  }
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
    routing,
    lone_pairs,
  })
}
