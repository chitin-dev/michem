//! Typst measures named fonts; the SVG viewer resolves the same family.

use crate::Error;
use chitin_chemdraw::{
  Drawing, Primitive,
  font::{FontFace, TextMetrics, TextRequest},
  geometry::Point,
  scene::{Color, Polygon},
  svg,
};
use serde::{Deserialize, Serialize};

/// One exact label run requested from the measuring host.
#[derive(Debug, Serialize)]
pub struct Label {
  /// Literal label content.
  pub text: String,
  /// Font size in SVG drawing units.
  pub size: f64,
}

/// Host-measured advance and baseline-relative ink bounds, in SVG units.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Measurement {
  /// Literal label content.
  pub text: String,
  /// Exact requested font size.
  pub size: f64,
  /// Horizontal advance.
  pub advance: f64,
  /// Minimum x and y in a y-down baseline coordinate frame.
  pub min: [f64; 2],
  /// Maximum x and y in the same frame.
  pub max: [f64; 2],
}

pub(crate) fn face(family: &str, rows: &[Measurement]) -> Result<FontFace, Error> {
  let entries = rows
    .iter()
    .map(|row| {
      Ok((
        TextRequest::new(&row.text, row.size)?,
        TextMetrics {
          advance: row.advance,
          min: Point::new(row.min[0], row.min[1]),
          max: Point::new(row.max[0], row.max[1]),
        },
      ))
    })
    .collect::<Result<Vec<_>, chitin_chemdraw::font::FontError>>()?;
  Ok(FontFace::from_measurements(family, entries)?)
}

fn escape(value: &str) -> String {
  value
    .replace('&', "&amp;")
    .replace('<', "&lt;")
    .replace('>', "&gt;")
    .replace('"', "&quot;")
    .replace('\'', "&apos;")
}

fn body(svg: &str) -> Result<&str, Error> {
  let start = svg
    .find('>')
    .ok_or_else(|| Error::Input("invalid SVG header".into()))?
    + 1;
  let end = svg
    .rfind("</svg>")
    .ok_or_else(|| Error::Input("invalid SVG closing tag".into()))?;
  Ok(&svg[start..end])
}

pub(crate) fn export(
  drawing: &Drawing,
  options: &svg::SvgOptions,
  family: &str,
) -> Result<String, Error> {
  let bounds = drawing
    .bounds()
    .ok_or_else(|| Error::Input("empty drawing".into()))?;
  // Let Chitin frame the exact measured envelope, including background/padding.
  let frame = Drawing::new(vec![Primitive::Polygon(Polygon {
    points: vec![
      bounds.min(),
      Point::new(bounds.max().x, bounds.min().y),
      bounds.max(),
      Point::new(bounds.min().x, bounds.max().y),
    ],
    color: Color {
      alpha: 0,
      ..Color::BLACK
    },
    source: None,
  })])
  .map_err(|error| Error::Input(error.to_string()))?;
  let mut output = svg::export(&frame, options)?;
  output.truncate(
    output
      .rfind("</svg>")
      .ok_or_else(|| Error::Input("invalid SVG framing".into()))?,
  );
  let geometry_options = svg::SvgOptions {
    padding: 0.,
    background: None,
  };
  for primitive in drawing.primitives() {
    match primitive {
      Primitive::Text(text) => {
        output.push_str(&format!(
          "<text x=\"{}\" y=\"{}\" font-family=\"{}\" font-size=\"{}\" font-weight=\"400\" font-style=\"normal\" style=\"font-kerning:none;font-variant-ligatures:none\" textLength=\"{}\" lengthAdjust=\"spacingAndGlyphs\" fill=\"#{:02x}{:02x}{:02x}\" fill-opacity=\"{}\">{}</text>\n",
          text.origin.x, text.origin.y, escape(family), text.font_size, text.width,
          text.color.red, text.color.green, text.color.blue, f64::from(text.color.alpha) / 255., escape(&text.content),
        ));
      }
      other => {
        let scene =
          Drawing::new(vec![other.clone()]).map_err(|error| Error::Input(error.to_string()))?;
        output.push_str(body(&svg::export(&scene, &geometry_options)?)?);
      }
    }
  }
  output.push_str("</svg>\n");
  Ok(output)
}
