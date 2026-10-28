//! Lossless paint-order transfer of host text and isolated vector geometry.
//!
//! Consecutive geometry is batched into standalone SVG layers. Every host text
//! run ends a batch so Typst can draw that run at exactly the same painter-order
//! position with the measured font. Opaque groups may be flattened for this
//! transfer; vector-only groups retain their original opacity and isolation.

use super::model::{Envelope, Layer};
use crate::Error;
use chitin_chemdraw::{Drawing, Primitive, geometry::Bounds, svg};

/// Copies a native y-down ink envelope into its serializable wire form.
pub(super) fn envelope(bounds: Bounds) -> Envelope {
  Envelope {
    min: [bounds.min().x, bounds.min().y],
    max: [bounds.max().x, bounds.max().y],
  }
}

/// Splits a measured scene into painter-ordered vector and native-text layers.
///
/// # Returns
/// Layers in the original coordinate frame, without standalone framing padding.
/// Each vector layer has its own ink origin; labels retain their left baseline.
///
/// # Errors
/// Propagates invalid geometry, missing host metrics and SVG export failures.
/// Rejects translucent groups containing host text because the wire format
/// cannot reproduce their isolated group compositing after flattening.
pub(super) fn encode(drawing: &Drawing) -> Result<Vec<Layer>, Error> {
  let mut result = Vec::new();
  let mut geometry = Vec::new();
  visit(drawing, &mut geometry, &mut result)?;
  flush(&mut geometry, &mut result)?;
  Ok(result)
}

/// Drains pending geometry into one unpadded vector layer, skipping empty ink.
///
/// The buffer is consumed before validation; a failure aborts the entire encode
/// call rather than exposing a partially encoded scene to the host.
fn flush(geometry: &mut Vec<Primitive>, output: &mut Vec<Layer>) -> Result<(), Error> {
  if geometry.is_empty() {
    return Ok(());
  }
  let drawing = Drawing::new(std::mem::take(geometry)).map_err(|e| Error::Input(e.to_string()))?;
  let Some(bounds) = drawing.bounds() else {
    return Ok(());
  };
  output.push(Layer::Vector {
    origin: [bounds.min().x, bounds.min().y],
    width: bounds.width().max(1.),
    height: bounds.height().max(1.),
    svg: svg::export(
      &drawing,
      &svg::SvgOptions {
        padding: 0.,
        background: None,
      },
    )?,
  });
  Ok(())
}

/// Visits groups recursively while keeping geometry buffered between text runs.
///
/// Geometry-only groups stay intact. Groups containing measured host text can
/// be visited recursively only when their group opacity is fully opaque.
fn visit(
  drawing: &Drawing,
  geometry: &mut Vec<Primitive>,
  output: &mut Vec<Layer>,
) -> Result<(), Error> {
  for primitive in drawing.primitives() {
    match primitive {
      Primitive::Text(text) if text.font.host_identity().is_some() => {
        flush(geometry, output)?;
        let metrics = text.font.measure(&text.content, text.font_size)?;
        let family = text
          .font
          .host_identity()
          .ok_or_else(|| Error::Input("missing host font identity".into()))?;
        output.push(Layer::Label {
          origin: [text.origin.x, text.origin.y],
          text: text.content.clone(),
          font: family.to_owned(),
          size: text.font_size,
          top: metrics.min.y,
          stretch: text.width / metrics.advance,
          color: format!(
            "#{:02x}{:02x}{:02x}{:02x}",
            text.color.red, text.color.green, text.color.blue, text.color.alpha
          ),
        });
      }
      Primitive::Group(group)
        if group
          .drawing
          .leaf_primitives()
          .any(|p| matches!(p, Primitive::Text(t) if t.font.host_identity().is_some())) =>
      {
        // Flattening a translucent text group would change overlap compositing.
        // Molecular instance groups are opaque; highlight groups contain no text.
        if group.opacity != 255 {
          return Err(Error::Input(
            "translucent host-text groups require host group compositing".into(),
          ));
        }
        visit(&group.drawing, geometry, output)?;
      }
      other => geometry.push(other.clone()),
    }
  }
  Ok(())
}
