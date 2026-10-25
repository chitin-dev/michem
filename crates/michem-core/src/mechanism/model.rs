//! Versioned host requests without serialized graph-local handles.

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
}

/// A named atom or bond; bond endpoints may be given in either order.
#[derive(Debug, Deserialize)]
#[serde(tag = "kind", rename_all = "kebab-case", deny_unknown_fields)]
pub enum Target {
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
#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case", deny_unknown_fields)]
pub enum Annotation {
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
    /// Source reference.
    from: Reference,
    /// Destination reference.
    to: Reference,
    /// Signed perpendicular curve displacement in shared drawing units.
    bend: f64,
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
  },
}

/// Finite ink envelope in shared y-down drawing units.
#[derive(Debug, Clone, Copy, Serialize)]
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
}
