//! Atom identifiers are drawing annotations, independent of chemical labels.
//!
//! Labels use the molecular font and already resolved atom positions. Candidate
//! boxes are scored against chemical text and earlier debug boxes; this is a
//! local readability aid, not a bond- or arrow-routing pass. The returned drawing
//! owns the extra ink, so framing and host packing include the labels naturally.

use crate::Error;
use chitin_chemdraw::{
  Drawing, Primitive,
  depict::DepictOptions,
  geometry::Point,
  scene::{Color, Polygon, Text},
};

/// Debug font size relative to the molecular font, shared with label discovery.
pub(crate) const SIZE_RATIO: f64 = 0.65;

/// Appends measured ID labels without changing chemical geometry or provenance.
///
/// # Parameters
/// - `drawing`: existing scene in y-down drawing units.
/// - `options`: unscaled molecular font and font size.
/// - `atoms`: public atom IDs and their final, already scaled scene positions.
/// - `scale`: instance scale applied only to label size and candidate offsets.
///
/// # Returns
/// A new drawing retaining the original primitives before all debug annotations.
/// Semiopaque backgrounds improve contrast and carry no chemical source handle.
///
/// # Errors
/// Propagates missing font measurements and invalid scene geometry. Callers must
/// provide a positive finite scale, as validated by the molecular/instance path.
pub(crate) fn overlay(
  drawing: Drawing,
  options: &DepictOptions,
  atoms: &[(&str, Point)],
  scale: f64,
) -> Result<Drawing, Error> {
  // Match label_requests' multiplication order: exact size bits key host metrics.
  let size = options.font_size * SIZE_RATIO * scale;
  let mut primitives = drawing.primitives().to_vec();
  let mut occupied = drawing
    .leaf_primitives()
    .filter_map(|primitive| {
      if let Primitive::Text(text) = primitive {
        Some(text.envelope())
      } else {
        None
      }
    })
    .collect::<Result<Vec<_>, _>>()?;
  for &(id, point) in atoms {
    let metrics = options.font.measure(id, size)?;
    let gap = options.font_size * scale * 0.3;
    let width = metrics.max.x - metrics.min.x + 2. * size * 0.12;
    let height = metrics.max.y - metrics.min.y + 2. * size * 0.12;
    let candidates = [
      Point::new(point.x + gap, point.y - gap - height),
      Point::new(point.x + gap, point.y + gap),
      Point::new(point.x - gap - width, point.y - gap - height),
      Point::new(point.x - gap - width, point.y + gap),
      Point::new(
        point.x - width / 2.,
        point.y - options.font_size * scale - height,
      ),
      Point::new(point.x - width / 2., point.y + options.font_size * scale),
    ];
    // A finite candidate set keeps placement deterministic. If every candidate
    // collides, choose the least overlapping box rather than moving the atom.
    let overlap = |origin: Point| {
      occupied
        .iter()
        .map(|[min, max]| {
          (max.x.min(origin.x + width) - min.x.max(origin.x)).max(0.)
            * (max.y.min(origin.y + height) - min.y.max(origin.y)).max(0.)
        })
        .sum::<f64>()
    };
    let origin = candidates
      .into_iter()
      .min_by(|a, b| overlap(*a).total_cmp(&overlap(*b)))
      .ok_or_else(|| Error::Input("missing debug label position".into()))?;
    let max = Point::new(origin.x + width, origin.y + height);
    occupied.push([origin, max]);
    primitives.push(Primitive::Polygon(Polygon {
      points: vec![
        origin,
        Point::new(max.x, origin.y),
        max,
        Point::new(origin.x, max.y),
      ],
      color: Color {
        red: 255,
        green: 255,
        blue: 255,
        alpha: 230,
      },
      source: None,
    }));
    primitives.push(Primitive::Text(Text {
      font: options.font.clone(),
      origin: Point::new(
        origin.x + size * 0.12 - metrics.min.x,
        origin.y + size * 0.12 - metrics.min.y,
      ),
      content: id.to_owned(),
      font_size: size,
      width: metrics.advance,
      color: Color {
        red: 37,
        green: 99,
        blue: 235,
        alpha: 255,
      },
      source: None,
    }));
  }
  Drawing::new(primitives).map_err(|error| Error::Input(error.to_string()))
}
