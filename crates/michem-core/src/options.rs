//! Serializable layout and paint options; absent fields inherit Chitin defaults.
//!
//! JSON option names use kebab-case. Layout distances remain normalized bond
//! units, while paint dimensions use SVG drawing units. Conversion preserves
//! explicit dimensions and scales only unspecified dimensions with bond length.
//! Chitin validates geometry when constructing layouts and drawings.

use std::collections::BTreeMap;

use chitin_chem::Element;
use chitin_chemdraw::{Color, depict, layout, svg};
use serde::Deserialize;

use crate::Error;

/// Automatic layout limits and spacing, separate from drawing dimensions.
#[derive(Debug, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "kebab-case")]
pub struct Layout {
  /// Maximum molecule size, including manually positioned molecules.
  pub max_atoms: usize,
  /// Distance between disconnected components in normalized bond units.
  pub component_gap: f64,
  /// Threshold for reporting crowded atom centers.
  pub minimum_spacing: f64,
  /// Discrete overlap refinement passes.
  pub refinement_passes: usize,
  /// Shared work for optional overlap refinement.
  pub refinement_budget: usize,
  /// Shared work for double-bond stereochemistry.
  pub stereo_budget: usize,
  /// Shared work for native topology, ring construction, search and simulation.
  pub work_budget: usize,
}

impl Default for Layout {
  fn default() -> Self {
    let base = layout::LayoutOptions::default();
    Self {
      max_atoms: 512,
      component_gap: base.component_gap,
      minimum_spacing: base.minimum_spacing,
      refinement_passes: base.refinement_passes,
      refinement_budget: base.refinement_budget,
      stereo_budget: base.stereo_budget,
      work_budget: base.work_budget,
    }
  }
}

impl Layout {
  /// Copies layout limits and distances into Chitin's native options.
  pub(crate) fn options(&self) -> layout::LayoutOptions {
    layout::LayoutOptions {
      max_atoms: self.max_atoms,
      component_gap: self.component_gap,
      minimum_spacing: self.minimum_spacing,
      refinement_passes: self.refinement_passes,
      refinement_budget: self.refinement_budget,
      stereo_budget: self.stereo_budget,
      work_budget: self.work_budget,
    }
  }
}

/// Atom-label color policy.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ColorScheme {
  /// Builtin element colors with caller overrides.
  #[default]
  Element,
  /// All labels use foreground; ignores palette overrides.
  Monochrome,
}

/// Bond paint policy, independent from label color.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum BondColors {
  /// Two endpoint colors meet at the bond midpoint.
  #[default]
  Split,
  /// Every bond uses the foreground.
  Uniform,
}

/// Display policy for explicitly aromatic rings.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Aromatic {
  /// Alternating single and double strokes.
  #[default]
  Kekule,
  /// Inner circle for eligible rings; Chitin retains Kekule for other rings.
  Circle,
}

/// Chiral attached-hydrogen display policy.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ChiralHydrogens {
  /// Put the wedge on an existing bond.
  #[default]
  Implicit,
  /// Draw the declared hydrogen and a separate wedge.
  Explicit,
}

/// Formal-charge enclosure, independent of atom chemistry.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ChargeStyle {
  /// Ordinary charge superscript.
  Plain,
  /// Measured superscript enclosed by a vector circle.
  Circled,
}

/// Drawing dimensions are SVG pixels; colors are #RRGGBB or #RRGGBBAA.
///
/// At natural size one pixel equals 0.75 Typst points. `font` selects a host
/// measurement family; it is resolved separately after option conversion.
/// Debug labels and standalone SVG framing are Michem concerns and are not
/// passed into Chitin's molecular depiction options.
#[derive(Debug, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "kebab-case")]
pub struct Style {
  /// Show original atom IDs beside every atom, including unlabeled carbons.
  pub debug: bool,
  /// Enclosure of formal charges: `plain` or `circled`.
  pub charge_style: ChargeStyle,
  /// Font family resolved by Typst; absent retains Chitin's outlined default.
  pub font: Option<String>,
  /// Drawing units per normalized bond; dependent sizes scale with this value.
  pub bond_length: f64,
  /// Override label size; absent preserves Chitin's proportions.
  pub font_size: Option<f64>,
  /// Override bond stroke width.
  pub stroke_width: Option<f64>,
  /// Override stereochemical wedge width.
  pub wedge_width: Option<f64>,
  /// Override double/triple stroke separation.
  pub bond_spacing: Option<f64>,
  /// Fraction of a full bond used for shortened secondary strokes.
  pub short_bond_ratio: Option<f64>,
  /// Override clearance between bonds and labels.
  pub label_padding: Option<f64>,
  /// Fallback and uniform bond color.
  pub foreground: String,
  /// Element palette or monochrome.
  pub color_scheme: ColorScheme,
  /// Element-symbol overrides, retaining builtins for absent entries.
  pub color_map: BTreeMap<String, String>,
  /// Split endpoint colors or uniform foreground.
  pub bond_colors: BondColors,
  /// Aromatic ring display.
  pub aromatic: Aromatic,
  /// Declared H at annotated tetrahedral carbon.
  pub chiral_hydrogens: ChiralHydrogens,
  /// Nonnegative space outside the ink bounds.
  pub padding: f64,
  /// Absent means transparent background.
  pub background: Option<String>,
}

impl Default for Style {
  fn default() -> Self {
    Self {
      debug: false,
      charge_style: ChargeStyle::Plain,
      font: None,
      bond_length: 24.,
      font_size: None,
      stroke_width: None,
      wedge_width: None,
      bond_spacing: None,
      short_bond_ratio: None,
      label_padding: None,
      foreground: "#202124".into(),
      color_scheme: ColorScheme::default(),
      color_map: BTreeMap::new(),
      bond_colors: BondColors::default(),
      aromatic: Aromatic::default(),
      chiral_hydrogens: ChiralHydrogens::default(),
      padding: 4.,
      background: None,
    }
  }
}

/// Parses six- or eight-digit hexadecimal color notation, including its `#`.
///
/// # Returns
/// Straight RGBA channels; six-digit RGB notation receives full opacity.
///
/// # Errors
/// Rejects shorthand, named colors, missing prefixes and nonhexadecimal digits.
pub(crate) fn color(value: &str) -> Result<Color, Error> {
  let hex = value
    .strip_prefix('#')
    .filter(|hex| matches!(hex.len(), 6 | 8) && hex.bytes().all(|b| b.is_ascii_hexdigit()))
    .ok_or_else(|| Error::Input(format!("invalid color {value:?}; use #RRGGBB or #RRGGBBAA")))?;
  let channel = |index| {
    u8::from_str_radix(&hex[index..index + 2], 16).map_err(|error| Error::Input(error.to_string()))
  };
  Ok(Color {
    red: channel(0)?,
    green: channel(2)?,
    blue: channel(4)?,
    alpha: if hex.len() == 8 { channel(6)? } else { 255 },
  })
}

impl Style {
  /// Resolves paint policies and bond-relative defaults for native depiction.
  ///
  /// # Returns
  /// Options retaining Chitin's default font. Unspecified dimensions scale with
  /// `bond_length`; explicit overrides and the dimensionless short-bond ratio
  /// retain their supplied values. The caller installs any host font afterward.
  ///
  /// # Errors
  /// Rejects malformed foreground/palette colors and unknown element symbols.
  /// Numeric dimensions are validated later by Chitin's depiction pipeline.
  pub(crate) fn depict_options(&self) -> Result<depict::DepictOptions, Error> {
    let base = depict::DepictOptions::default();
    let ratio = self.bond_length / base.bond_length;
    let element_colors = self
      .color_map
      .iter()
      .map(|(symbol, value)| {
        Ok((
          Element::from_symbol(symbol).map_err(|error| Error::Input(error.to_string()))?,
          color(value)?,
        ))
      })
      .collect::<Result<_, Error>>()?;
    Ok(depict::DepictOptions {
      bond_length: self.bond_length,
      font_size: self.font_size.unwrap_or(base.font_size * ratio),
      stroke_width: self.stroke_width.unwrap_or(base.stroke_width * ratio),
      wedge_width: self.wedge_width.unwrap_or(base.wedge_width * ratio),
      bond_spacing: self.bond_spacing.unwrap_or(base.bond_spacing * ratio),
      short_bond_ratio: self.short_bond_ratio.unwrap_or(base.short_bond_ratio),
      label_padding: self.label_padding.unwrap_or(base.label_padding * ratio),
      foreground: color(&self.foreground)?,
      element_colors,
      color_scheme: match self.color_scheme {
        ColorScheme::Element => depict::ColorScheme::Element,
        ColorScheme::Monochrome => depict::ColorScheme::Monochrome,
      },
      bond_color_style: match self.bond_colors {
        BondColors::Split => depict::BondColorStyle::Split,
        BondColors::Uniform => depict::BondColorStyle::Uniform,
      },
      charge_style: match self.charge_style {
        ChargeStyle::Plain => depict::ChargeStyle::Plain,
        ChargeStyle::Circled => depict::ChargeStyle::Circled,
      },
      aromatic_style: match self.aromatic {
        Aromatic::Kekule => depict::AromaticStyle::Kekule,
        Aromatic::Circle => depict::AromaticStyle::Circle,
      },
      chiral_hydrogens: match self.chiral_hydrogens {
        ChiralHydrogens::Implicit => depict::ChiralHydrogenMode::Implicit,
        ChiralHydrogens::Explicit => depict::ChiralHydrogenMode::Explicit,
      },
      ..base
    })
  }

  /// Converts standalone SVG padding and optional background paint.
  ///
  /// # Errors
  /// Rejects malformed background colors. The SVG exporter validates padding;
  /// mechanism scenes do not use this standalone framing configuration.
  pub(crate) fn svg_options(&self) -> Result<svg::SvgOptions, Error> {
    Ok(svg::SvgOptions {
      padding: self.padding,
      background: self.background.as_deref().map(color).transpose()?,
    })
  }
}
