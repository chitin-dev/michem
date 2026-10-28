//! Chitin-backed chemical drawing with a stable JSON boundary for Typst.
//!
//! Molecular topology, layout and depiction are delegated to Chitin. This crate
//! translates caller-owned names into graph-local handles and returns portable
//! geometry without retaining state between plugin calls. [`draw`] produces a
//! standalone SVG; [`mechanism`] splits multi-molecule layout into preparation
//! and composition so Typst can measure and arrange content between the calls.
//!
//! Normalized molecular coordinates use y-up bond units. SVG and mechanism
//! scenes use y-down drawing units; one drawing unit is 0.75 Typst points at
//! natural size. Standalone [`Anchor`] coordinates instead use a y-up unit box
//! relative to the final framed SVG, including debug labels and padding.
//!
//! # Examples
//! ```
//! let request = michem_core::decode(
//!   br#"{"molecule":{"kind":"smiles","value":"CCO"}}"#,
//! )?;
//! let drawing = michem_core::draw(&request)?;
//! assert_eq!(drawing.atoms.len(), 3);
//! assert!(drawing.svg.contains("<svg"));
//! # Ok::<(), michem_core::Error>(())
//! ```

mod debug;
mod host_font;
pub mod mechanism;
pub mod model;
pub mod options;
pub use host_font::{Label, Measurement};

use chitin_chemdraw::{depict, layout, svg};
use serde::{Deserialize, Serialize};

use model::Molecule;
use options::{Layout, Style};

/// Invalid input or a failure in the chemical drawing pipeline.
#[derive(Debug, thiserror::Error)]
pub enum Error {
  /// Instance resolution or authored mechanism geometry is invalid.
  #[error(transparent)]
  Mechanism(#[from] chitin_chemdraw::diagram::DiagramError),
  /// A request violates the public input contract.
  #[error("{0}")]
  Input(String),
  /// JSON decoding or encoding failed.
  #[error(transparent)]
  Json(#[from] serde_json::Error),
  /// Host font measurements are invalid or incomplete.
  #[error(transparent)]
  Font(#[from] chitin_chemdraw::font::FontError),
  /// Chemical topology is invalid.
  #[error(transparent)]
  Graph(#[from] chitin_chem::GraphError),
  /// Coordinate geometry is invalid.
  #[error(transparent)]
  Geometry(#[from] chitin_chemdraw::geometry::GeometryError),
  /// Automatic molecular layout failed.
  #[error(transparent)]
  Layout(#[from] layout::LayoutError),
  /// Chemical depiction failed.
  #[error(transparent)]
  Depict(#[from] depict::DepictError),
  /// SVG export failed.
  #[error(transparent)]
  Svg(#[from] svg::SvgError),
}

/// One molecule and independent layout and paint configuration.
///
/// Unknown JSON fields are rejected; omitted layout and style fields use their
/// defaults. A named font requires a prior [`label_requests`] round trip through
/// Typst and matching [`Measurement`] rows. Deserialization alone does not check
/// graph validity, dimensions or font coverage; drawing performs those checks.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
  /// SMILES or an explicit graph, optionally with complete authored coordinates.
  pub molecule: Molecule,
  /// Automatic layout configuration; authored coordinates bypass layout.
  #[serde(default)]
  pub layout: Layout,
  /// Depiction and SVG framing configuration.
  #[serde(default)]
  pub style: Style,
  /// Exact label metrics supplied by Typst for a named font.
  #[serde(default)]
  pub measurements: Vec<Measurement>,
  /// Additional exact font-size requests needed by a positive instance scale.
  #[serde(default = "unit_scale", rename = "measurement-scale")]
  pub measurement_scale: f64,
}

/// Supplies the unscaled default for the optional font-measurement multiplier.
fn unit_scale() -> f64 {
  1.
}

/// A stable atom name and its normalized position within the framed SVG.
#[derive(Debug, Serialize)]
pub struct Anchor {
  /// Manual atom name or zero-based SMILES parse index as a string.
  pub id: String,
  /// Horizontal position, from zero at the left to one at the right.
  pub x: f64,
  /// Vertical position, from zero at the bottom to one at the top.
  pub y: f64,
}

/// A portable vector drawing and geometry for placing it in other canvases.
///
/// Atom IDs preserve input order and names, independently of layout. Width and
/// height describe the SVG view box, not a Typst image resized by the caller.
#[derive(Debug, Serialize)]
pub struct Diagram {
  /// SVG; named-font labels reference the selected family.
  pub svg: String,
  /// Natural SVG width in drawing units (SVG pixels).
  pub width: f64,
  /// Natural SVG height in drawing units (SVG pixels).
  pub height: f64,
  /// Coordinates for CeTZ atom anchors in the same framed image.
  pub atoms: Vec<Anchor>,
  /// Layout quality reports; these do not imply invalid chemical input.
  pub diagnostics: Vec<String>,
}

/// Draws a molecule and preserves anchors in the exact SVG coordinate frame.
///
/// # Parameters
/// - `request`: molecular input, layout limits, paint options and, for a named
///   font, exact host measurements for all required text runs.
///
/// # Returns
/// A framed SVG and input-order atom anchors normalized to that same frame.
/// Complete authored coordinates bypass layout; debug annotations enlarge ink
/// bounds without moving atoms. Layout diagnostics are advisory.
///
/// # Errors
/// Rejects invalid chemistry, incomplete authored positions, exceeded atom or
/// layout budgets, malformed colors, missing font metrics and export failures.
pub fn draw(request: &Request) -> Result<Diagram, Error> {
  let mut options = request.style.depict_options()?;
  if let Some(family) = &request.style.font {
    options.font = host_font::face(family, &request.measurements)?;
  }
  let framing = request.style.svg_options()?;
  let input = request.molecule.build(request.layout.max_atoms)?;
  let coordinates = match input.positions {
    Some(positions) => layout::Layout2d::from_positions(positions)?,
    None => layout::generate(&input.graph, &request.layout.options())?,
  };
  let drawing = depict::depict(&input.graph, &coordinates, &options)?;
  let drawing = if request.style.debug {
    let atoms = input
      .names
      .iter()
      .map(|(id, name)| {
        let point = coordinates
          .position(*id)
          .ok_or_else(|| Error::Input(format!("missing position for atom {name}")))?;
        Ok((
          name.as_str(),
          chitin_chemdraw::geometry::Point::new(
            point.x * options.bond_length,
            -point.y * options.bond_length,
          ),
        ))
      })
      .collect::<Result<Vec<_>, Error>>()?;
    debug::overlay(drawing, &options, &atoms, 1.)?
  } else {
    drawing
  };
  let svg = match &request.style.font {
    Some(family) => host_font::export(&drawing, &framing, family)?,
    None => svg::export(&drawing, &framing)?,
  };
  let bounds = drawing
    .bounds()
    .ok_or_else(|| Error::Input("empty drawing".into()))?;
  // Mirror Chitin's SVG framing, including its minimum one-unit canvas.
  let width = bounds.width().max(1.) + 2. * framing.padding;
  let height = bounds.height().max(1.) + 2. * framing.padding;
  let left = bounds.min().x - framing.padding;
  let top = bounds.min().y - framing.padding;
  let mut atoms = Vec::with_capacity(input.names.len());
  for (id, name) in input.names {
    let point = coordinates
      .position(id)
      .ok_or_else(|| Error::Input(format!("missing position for atom {name}")))?;
    atoms.push(Anchor {
      id: name,
      x: (point.x * options.bond_length - left) / width,
      y: 1. - (-point.y * options.bond_length - top) / height,
    });
  }
  Ok(Diagram {
    svg,
    width,
    height,
    atoms,
    diagnostics: coordinates
      .diagnostics()
      .iter()
      .map(|item| format!("{item:?}"))
      .collect(),
  })
}

/// Lists deduplicated label runs before Typst measures the requested font.
///
/// # Parameters
/// - `request`: the same molecular input and style used for drawing. Its
///   `measurement_scale` adds text sizes needed by a scaled mechanism instance.
///   Existing measurement rows are not needed for this discovery step.
///
/// # Returns
/// Unique text/size pairs, including debug IDs and both base and scaled sizes.
/// Each size has a hexadecimal IEEE-754 token that the host must echo unchanged
/// to preserve exact lookup across JSON number conversions.
///
/// # Errors
/// Rejects nonpositive or nonfinite scale, invalid molecular input, unsupported
/// depiction text and invalid text-request sizes.
pub fn label_requests(request: &Request) -> Result<Vec<Label>, Error> {
  if !request.measurement_scale.is_finite() || request.measurement_scale <= 0. {
    return Err(Error::Input(
      "measurement scale must be finite and positive".into(),
    ));
  }
  let input = request.molecule.build(request.layout.max_atoms)?;
  let options = request.style.depict_options()?;
  let mut requests: std::collections::BTreeSet<_> =
    depict::measurement_requests(&input.graph, &options)?
      .into_iter()
      .collect();
  if request.style.debug {
    for (_, name) in &input.names {
      requests.insert(chitin_chemdraw::font::TextRequest::new(
        name,
        options.font_size * debug::SIZE_RATIO,
      )?);
    }
  }
  for item in requests.clone() {
    requests.insert(chitin_chemdraw::font::TextRequest::new(
      item.content(),
      item.font_size() * request.measurement_scale,
    )?);
  }
  Ok(
    requests
      .iter()
      .map(|item| host_font::Label {
        text: item.content().to_owned(),
        size: item.font_size(),
        key: format!("{:016x}", item.font_size().to_bits()),
      })
      .collect(),
  )
}

/// Decodes a bounded JSON request before entering the drawing pipeline.
///
/// # Parameters
/// - `input`: UTF-8 JSON encoding of [`Request`], at most 4 MiB.
///
/// # Returns
/// A deserialized request with defaults applied. Call [`draw`] or
/// [`label_requests`] to validate chemical and geometric inputs.
///
/// # Errors
/// Rejects oversized input, malformed JSON, unknown fields and incorrect field
/// types. No graph construction or layout is performed here.
pub fn decode(input: &[u8]) -> Result<Request, Error> {
  if input.len() > 4 * 1024 * 1024 {
    return Err(Error::Input("request exceeds 4 MiB".into()));
  }
  Ok(serde_json::from_slice(input)?)
}
