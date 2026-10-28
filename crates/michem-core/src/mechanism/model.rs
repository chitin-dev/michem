//! Versioned host requests without serialized graph-local handles.
//!
//! Occurrence IDs, atom names and pair IDs are the complete public reference
//! namespace. Preparation and composition rebuild native handles independently;
//! callers replay normalized positions rather than persisting a native graph.
//! Requests reject unknown fields and enum tags, while `serde(default)` marks
//! wire fields that older callers may omit.
//!
//! Unless stated otherwise, positions use y-down SVG drawing units. Prepared
//! atom positions are the exception: they retain normalized y-up bond units for
//! lossless reuse as molecular input. Local offsets scale with their occurrence;
//! reaction connectors and host text obstacles live in shared canvas units.

use crate::Request as MoleculeRequest;
use serde::{Deserialize, Serialize};

/// Wire version shared by preparation and final composition.
pub const VERSION: u32 = 1;

/// One occurrence; atom names are scoped to its unique, caller-assigned ID.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Instance {
  /// Unique nonempty occurrence name within this request.
  pub id: String,
  /// Existing molecular input, style, layout and exact font measurements.
  pub drawing: MoleculeRequest,
  /// Positive similarity transform in y-down SVG drawing units.
  #[serde(default)]
  pub placement: Placement,
}

/// Placement of a molecule's local drawing origin, not its padded image corner.
#[derive(Debug, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Placement {
  /// Translation in shared y-down drawing units.
  pub origin: [f64; 2],
  /// Positive scale shared by geometry, labels and local annotation offsets.
  pub scale: f64,
}

impl Default for Placement {
  fn default() -> Self {
    Self {
      origin: [0., 0.],
      scale: 1.,
    }
  }
}

/// Complete stateless request; preparation does not allocate persistent handles.
///
/// `version` selects the wire contract, not a package version. Occurrence IDs
/// must be unique within the request; reusing a SMILES string under another ID
/// creates a separately addressable occurrence. Annotation references are
/// resolved on composition and do not require declaration order for molecules.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
  /// Must equal the supported wire version.
  pub version: u32,
  /// Independently named molecular occurrences, possibly sharing the same input.
  pub molecules: Vec<Instance>,
  /// Authored annotations; ignored during preparation but validated on composition.
  #[serde(default)]
  pub annotations: Vec<Annotation>,
  /// Measured host text boxes reserved for routing, in shared diagram coordinates.
  #[serde(default)]
  pub obstacles: Vec<Envelope>,
}

/// Electron-arrow placement policy; authored curves remain the default.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Route {
  /// Preserve the authored curve parameters exactly.
  #[default]
  Manual,
  /// Search both sides while preserving the chemical endpoints.
  Auto,
}

/// Authored electron-arrow geometry, independent of electron count.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Curve {
  /// Explicit bend or endpoint-local Bezier controls.
  Bezier,
  /// Exact circular arc with a signed central angle; the default geometry.
  #[default]
  Arc,
}

/// Path selection on the circle defined by the authored minor sweep.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ArcPath {
  /// Preserve the minor path without complementary fallback.
  Minor,
  /// Preserve the complementary major path.
  Major,
  /// Consider readability and then the configured preference.
  #[default]
  Auto,
}

/// Tie-break preference between readable paths in automatic mode.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ArcPreference {
  /// Prefer the compact minor path.
  #[default]
  Minor,
  /// Prefer the complementary major path.
  Major,
}

impl ArcPath {
  /// Converts path policy without changing the caller's minor angle.
  pub(super) fn policy(&self, prefer: &ArcPreference) -> chitin_chemdraw::diagram::ArcPath {
    use chitin_chemdraw::diagram::ArcPath as Core;
    match (self, prefer) {
      (Self::Minor, _) => Core::Minor,
      (Self::Major, _) => Core::Major,
      (Self::Auto, ArcPreference::Minor) => Core::PreferMinor,
      (Self::Auto, ArcPreference::Major) => Core::PreferMajor,
    }
  }
}

/// Default quarter-circle sweep, in wire degrees.
fn arc_angle() -> f64 {
  90.
}

/// Finite resource and clearance settings for automatic arrow routing.
#[derive(Debug, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "kebab-case")]
pub struct Routing {
  /// Clearance beyond the arrow's ink width.
  pub margin: f64,
  /// Largest absolute candidate bend in shared SVG units.
  pub max_bend: f64,
  /// Difference between successive candidate bend magnitudes.
  pub bend_step: f64,
  /// Maximum curves to evaluate.
  pub max_candidates: usize,
  /// Maximum obstacle comparisons for one arrow.
  pub work_budget: usize,
}

impl Default for Routing {
  fn default() -> Self {
    let base = chitin_chemdraw::diagram::RoutingOptions::default();
    Self {
      margin: base.margin,
      max_bend: base.max_bend,
      bend_step: base.bend_step,
      max_candidates: base.max_candidates,
      work_budget: base.work_budget,
    }
  }
}

impl Routing {
  /// Copies per-arrow search limits; composition clamps work to its shared budget.
  pub(super) fn options(&self) -> chitin_chemdraw::diagram::RoutingOptions {
    chitin_chemdraw::diagram::RoutingOptions {
      margin: self.margin,
      max_bend: self.max_bend,
      bend_step: self.bend_step,
      max_candidates: self.max_candidates,
      work_budget: self.work_budget,
    }
  }
}

/// Successful automatic routing decision, indexed by original annotation order.
#[derive(Debug, Serialize)]
pub struct RoutedArrow {
  /// Selected explicit path; absent for Bezier curves. The angle remains the
  /// authored minor-circle parameter, so it can be replayed with this path.
  #[serde(skip_serializing_if = "Option::is_none")]
  pub arc_path: Option<&'static str>,
  /// Selected central sweep in degrees for an arc; absent for Bezier curves.
  #[serde(skip_serializing_if = "Option::is_none")]
  pub arc_angle: Option<f64>,
  /// Index of the annotation in the JSON request.
  pub annotation: usize,
  /// Selected signed perpendicular control displacement.
  pub bend: f64,
  /// Complete candidates evaluated before finding this clear curve.
  pub evaluated: usize,
  /// Segment/obstacle comparisons used.
  pub work_used: usize,
}

/// A named atom or bond; bond endpoints may be given in either order.
#[derive(Debug, Deserialize)]
#[serde(tag = "kind", rename_all = "kebab-case", deny_unknown_fields)]
pub enum Target {
  /// Explicit single-electron position relative to a source atom.
  Radical {
    /// Atom name or parse index.
    atom: String,
  },
  /// Midpoint between reacting atoms; no existing bond is required.
  BondFormation {
    /// Atom name in this occurrence.
    atom: String,
    /// Occurrence containing the other reacting atom.
    other_molecule: String,
    /// Atom name in the other occurrence.
    other_atom: String,
  },
  /// Atom name or zero-based SMILES parse index as a string.
  Atom {
    /// Input atom name.
    atom: String,
  },
  /// Logical bond axis, independent of colored halves or multiple strokes.
  Bond {
    /// First input atom name.
    from: String,
    /// Second input atom name.
    to: String,
  },
  /// A named explicitly authored lone pair on the same occurrence.
  LonePair {
    /// Lone-pair ID supplied in this request.
    pair: String,
  },
}

/// Geometric search settings for an explicitly requested lone pair.
#[derive(Debug, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "kebab-case")]
pub struct PairPlacement {
  /// Preferred radial direction in radians, in y-down axes.
  pub preferred_angle: f64,
  /// Minimum local atom-center distance.
  pub min_distance: f64,
  /// Maximum local atom-center distance.
  pub max_distance: f64,
  /// Local distance increment.
  pub distance_step: f64,
  /// Number of angular candidates per distance.
  pub directions: usize,
  /// Local space outside each dot.
  pub margin: f64,
  /// Maximum complete positions to check.
  pub max_candidates: usize,
  /// Maximum dot/obstacle comparisons.
  pub work_budget: usize,
}

impl Default for PairPlacement {
  fn default() -> Self {
    let o = chitin_chemdraw::diagram::LonePairOptions::default();
    Self {
      preferred_angle: o.preferred_angle,
      min_distance: o.min_distance,
      max_distance: o.max_distance,
      distance_step: o.distance_step,
      directions: o.directions,
      margin: o.margin,
      max_candidates: o.max_candidates,
      work_budget: o.work_budget,
    }
  }
}

impl PairPlacement {
  /// Copies local pair-search settings without applying occurrence transforms.
  pub(super) fn options(&self) -> chitin_chemdraw::diagram::LonePairOptions {
    chitin_chemdraw::diagram::LonePairOptions {
      preferred_angle: self.preferred_angle,
      min_distance: self.min_distance,
      max_distance: self.max_distance,
      distance_step: self.distance_step,
      directions: self.directions,
      margin: self.margin,
      max_candidates: self.max_candidates,
      work_budget: self.work_budget,
    }
  }
}

/// Resolved position of an explicit lone pair, available for host inspection.
#[derive(Debug, Serialize)]
pub struct PlacedPair {
  /// Index of the annotation in the JSON request.
  pub annotation: usize,
  /// Owning molecule occurrence name.
  pub molecule: String,
  /// Optional caller-assigned ID for electron-arrow attachment.
  pub id: Option<String>,
  /// Resolved local atom/bond attachment offset.
  pub offset: [f64; 2],
  /// Dot-axis orientation in radians.
  pub angle: f64,
}

/// Instance-qualified attachment with an optional local displacement.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Reference {
  /// Occurrence name in the same request.
  pub molecule: String,
  /// Atom or bond in that occurrence's own input namespace.
  pub target: Target,
  /// Displacement in local drawing units, before instance scaling.
  #[serde(default)]
  pub offset: [f64; 2],
}

/// Explicit electron-flow notation; no chemical mechanism is inferred.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Head {
  /// Full two-electron arrowhead.
  #[default]
  Pair,
  /// Left single-electron barb relative to the final tangent.
  FishhookLeft,
  /// Right single-electron barb relative to the final tangent.
  FishhookRight,
}

/// Arrow dimensions in shared drawing units, independent of molecular scale.
#[derive(Debug, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "kebab-case")]
pub struct Paint {
  /// Hexadecimal RGBA or RGB stroke color.
  pub color: String,
  /// Positive shaft width.
  pub width: f64,
  /// Positive head length.
  pub head_length: f64,
  /// Positive full head width.
  pub head_width: f64,
  /// Nonnegative additional attachment clearance.
  pub clearance: f64,
}

impl Default for Paint {
  fn default() -> Self {
    Self {
      color: "#202124".into(),
      width: 0.8,
      head_length: 4.,
      head_width: 3.,
      clearance: 1.5,
    }
  }
}

/// Annotation requests resolved anew against this request's graph namespaces.
///
/// This enum describes geometry and supplied electron notation, not reaction
/// inference. Composition installs fixed marks, then lone pairs, manual arrows
/// and automatic arrows. A named lone pair can therefore be used by an arrow
/// regardless of its position in the original annotation list.
#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case", deny_unknown_fields)]
pub enum Annotation {
  /// Authored single electron; does not infer spin or rewrite chemical facts.
  ElectronDot {
    /// Radical position, explicitly attached to an atom.
    anchor: Reference,
    /// Positive dot radius in local drawing units.
    radius: f64,
    /// Hexadecimal fill paint.
    color: String,
  },
  /// One isolated, uniformly translucent fragment highlight.
  Highlight {
    /// Selected occurrence.
    molecule: String,
    /// Atom names to shade.
    #[serde(default)]
    atoms: Vec<String>,
    /// Bond endpoint names to shade.
    #[serde(default)]
    bonds: Vec<[String; 2]>,
    /// Positive local band half-width.
    radius: f64,
    /// RGB or RGBA fill color.
    color: String,
  },
  /// Authored electron-flow curve, potentially connecting different occurrences.
  ElectronArrow {
    /// Exact circular geometry by default; Bezier geometry is opt-in.
    #[serde(default)]
    curve: Curve,
    /// Signed central sweep in degrees; absolute value 1..=180 for arc mode.
    #[serde(default = "arc_angle", rename = "arc-angle")]
    arc_angle: f64,
    /// Minor, major or automatic path selection; defaults to automatic.
    #[serde(default, rename = "arc-path")]
    arc_path: ArcPath,
    /// Preferred readable path in automatic mode; defaults to minor.
    #[serde(default, rename = "arc-prefer")]
    arc_prefer: ArcPreference,
    /// Endpoint-local departure/arrival control offsets; absent uses `bend`.
    #[serde(default)]
    controls: Option<[[f64; 2]; 2]>,
    /// Source reference.
    from: Reference,
    /// Destination reference.
    to: Reference,
    /// Signed perpendicular curve displacement in shared drawing units.
    #[serde(default)]
    bend: f64,
    /// Preserve the bend, or request bounded obstacle-aware routing.
    #[serde(default)]
    route: Route,
    /// Search resource limits and clearance; used only for automatic routing.
    #[serde(default)]
    routing: Routing,
    /// Explicit electron count notation.
    #[serde(default)]
    head: Head,
    /// Arrow dimensions and paint.
    #[serde(default)]
    style: Paint,
  },
  /// A forward or equilibrium reaction-step connector.
  ReactionArrow {
    /// Beginning in shared y-down drawing units.
    start: [f64; 2],
    /// End in the same units.
    end: [f64; 2],
    /// Whether to draw two opposing half-headed arrows.
    #[serde(default)]
    equilibrium: bool,
    /// Arrow dimensions and paint.
    #[serde(default)]
    style: Paint,
  },
  /// Explicit electron dots; the host chooses their attachment and orientation.
  LonePair {
    /// Pair center, usually an atom reference with an offset.
    anchor: Reference,
    /// Radians in y-down axes.
    angle: f64,
    /// Local center-to-center separation.
    separation: f64,
    /// Positive local dot radius.
    radius: f64,
    /// RGB or RGBA fill color.
    color: String,
    /// Optional ID for instance-scoped electron-arrow attachment.
    #[serde(default)]
    id: Option<String>,
    /// Preserve the explicit offset/orientation, or suggest a free position.
    #[serde(default)]
    position: Route,
    /// Local search settings for an automatic position.
    #[serde(default)]
    placement: PairPlacement,
  },
}

/// Finite ink envelope in shared y-down drawing units.
#[derive(Debug, Clone, Copy, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Envelope {
  /// Componentwise minimum coordinate.
  pub min: [f64; 2],
  /// Componentwise maximum coordinate.
  pub max: [f64; 2],
}

/// A named chemical anchor; no process-local handle is exposed.
#[derive(Debug, Serialize)]
pub struct AtomAnchor {
  /// Manual name or SMILES parse index.
  pub id: String,
  /// Absolute or local coordinate as documented by the enclosing reply.
  pub position: [f64; 2],
}

/// A logical bond anchor associated with its original endpoint names.
#[derive(Debug, Serialize)]
pub struct BondAnchor {
  /// Original endpoint names.
  pub atoms: [String; 2],
  /// Logical axis midpoint.
  pub position: [f64; 2],
}

/// Per-occurrence anchors, qualified by the same caller-assigned ID.
#[derive(Debug, Serialize)]
pub struct Anchors {
  /// Occurrence name.
  pub id: String,
  /// Named atom positions.
  pub atoms: Vec<AtomAnchor>,
  /// Named bond-axis positions.
  pub bonds: Vec<BondAnchor>,
}

/// Prepared geometry; the host freezes these coordinates before final placement.
///
/// Bounds and anchors already include occurrence scale, but `positions` do not.
/// Reuse those positions with the same style and scale on composition; applying
/// the scale to the positions as well would scale molecular geometry twice.
#[derive(Debug, Serialize)]
pub struct Prepared {
  /// Occurrence name.
  pub id: String,
  /// Scaled local ink envelope, with translation deliberately set to zero.
  pub bounds: Envelope,
  /// Complete normalized y-up positions in original input atom order.
  pub positions: Vec<[f64; 2]>,
  /// Scaled local anchors for host layout and inspection.
  pub anchors: Anchors,
}

/// First-stage result for deterministic host-side packing or authored placement.
#[derive(Debug, Serialize)]
pub struct Preparation {
  /// Wire version.
  pub version: u32,
  /// Prepared occurrences in request order.
  pub molecules: Vec<Prepared>,
}

/// Painter-ordered transferable commands; geometry is portable vector SVG.
///
/// Origins remain in the scene's coordinate frame, including negative values.
/// The host translates by the scene's minimum bound when painting into a box.
/// Labels must be drawn as literal content with the supplied family and metrics;
/// vector layers may be interleaved with them and cannot be reordered by kind.
#[derive(Debug, Serialize)]
#[serde(tag = "kind", rename_all = "kebab-case")]
pub enum Layer {
  /// A complete isolated vector layer; SVG contains no externally measured text.
  Vector {
    /// Position of the image's top-left corner.
    origin: [f64; 2],
    /// Image width in drawing units.
    width: f64,
    /// Image height in drawing units.
    height: f64,
    /// Standalone SVG without framing padding or background.
    svg: String,
  },
  /// Literal text drawn by the same host and font that supplied its metrics.
  Label {
    /// Left baseline position.
    origin: [f64; 2],
    /// Literal Unicode run, never interpreted as Typst markup.
    text: String,
    /// Host font family identity.
    font: String,
    /// Final font size in drawing units.
    size: f64,
    /// Measured baseline-relative top of the host text box.
    top: f64,
    /// Horizontal multiplier preserving the scene's explicit target advance.
    stretch: f64,
    /// Hexadecimal RGBA color.
    color: String,
  },
}

/// Final measured scene, independent of page layout or a particular canvas library.
///
/// Bounds describe actual molecular and annotation ink, including debug labels.
/// Host obstacles reserve routing space but are not painted by this scene.
/// Routing reports record accepted geometric choices; absent reports mean no
/// automatic arrow was requested, not that reaction chemistry was inferred.
#[derive(Debug, Serialize)]
pub struct Drawing {
  /// Wire version.
  pub version: u32,
  /// Complete scene envelope, before Typst adds conditions or outer padding.
  pub bounds: Envelope,
  /// Painting order, including text interleaved with vector layers.
  pub layers: Vec<Layer>,
  /// Absolute named anchors after all placements.
  pub molecules: Vec<Anchors>,
  /// Automatic arrow decisions in routing order; no unresolved route is returned.
  pub routing: Vec<RoutedArrow>,
  /// Final explicit lone-pair positions, including automatic suggestions.
  pub lone_pairs: Vec<PlacedPair>,
}
