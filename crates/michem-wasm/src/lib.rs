//! Typst's minimal protocol: JSON requests in, SVG or diagram JSON out.
//!
//! Each export accepts a single byte buffer and reconstructs all state through
//! `michem-core`. The WASM protocol registration is target-specific so the same
//! Rust functions remain callable in native builds. Core errors are converted
//! into human-readable strings at this boundary; no native graph handles or
//! partially rendered scenes are exposed to Typst.
//!
//! Named fonts use a discovery round trip through [`labels`]. Mechanisms use
//! [`mechanism_prepare`] followed by [`mechanism`], with Typst choosing final
//! placements and freezing prepared coordinates between those calls.

/// Prepares measured local bounds, named anchors and complete frozen coordinates.
///
/// # Parameters
/// - `input`: versioned mechanism-request JSON, with molecular inputs and any
///   exact font metrics collected by the host.
///
/// # Returns
/// UTF-8 JSON for `michem_core::mechanism::model::Preparation`. Occurrence
/// translation is suppressed; scale applies to bounds and anchors. Atom
/// positions remain normalized y-up coordinates for the final request.
///
/// # Errors
/// Returns a string for malformed requests, exceeded limits, invalid chemistry,
/// incomplete metrics, layout failures or response-serialization failures.
#[cfg_attr(target_arch = "wasm32", wasm_minimal_protocol::wasm_func)]
pub fn mechanism_prepare(input: &[u8]) -> Result<Vec<u8>, String> {
  let request = michem_core::mechanism::decode(input).map_err(|e| e.to_string())?;
  let prepared = michem_core::mechanism::prepare(&request).map_err(|e| e.to_string())?;
  serde_json::to_vec(&prepared).map_err(|e| e.to_string())
}

/// Resolves annotations against frozen occurrences and returns portable scene layers.
///
/// # Parameters
/// - `input`: versioned mechanism-request JSON containing complete prepared atom
///   positions, final placements and explicitly supplied annotations.
///
/// # Returns
/// UTF-8 JSON for `michem_core::mechanism::model::Drawing`, including ordered
/// vector/text layers, absolute anchors and accepted automatic-routing choices.
///
/// # Errors
/// Returns a string for malformed input, missing frozen coordinates, unknown
/// references, font/geometry failures, unsuccessful searches or serialization
/// failures. Automatic layout is never rerun during final composition.
#[cfg_attr(target_arch = "wasm32", wasm_minimal_protocol::wasm_func)]
pub fn mechanism(input: &[u8]) -> Result<Vec<u8>, String> {
  let request = michem_core::mechanism::decode(input).map_err(|e| e.to_string())?;
  let drawing = michem_core::mechanism::compose(&request).map_err(|e| e.to_string())?;
  serde_json::to_vec(&drawing).map_err(|e| e.to_string())
}

#[cfg(target_arch = "wasm32")]
wasm_minimal_protocol::initiate_protocol!();

/// Renders a molecule into standalone SVG bytes.
///
/// # Parameters
/// - `input`: molecular-request JSON, including metrics when using a named font.
///
/// # Returns
/// UTF-8 SVG bytes with the requested standalone padding and background.
/// Named-font text references the family used by the measuring host.
///
/// # Errors
/// Returns decoding, chemical, layout, measurement and export failures as strings.
#[cfg_attr(target_arch = "wasm32", wasm_minimal_protocol::wasm_func)]
pub fn render(input: &[u8]) -> Result<Vec<u8>, String> {
  let request = michem_core::decode(input).map_err(|error| error.to_string())?;
  michem_core::draw(&request)
    .map(|diagram| diagram.svg.into_bytes())
    .map_err(|error| error.to_string())
}

/// Renders SVG together with dimensions, atom anchors and layout diagnostics.
///
/// # Parameters
/// - `input`: the same molecular-request JSON accepted by [`render`].
///
/// # Returns
/// UTF-8 JSON for `michem_core::Diagram`. Anchors use a normalized y-up unit box
/// relative to the final framed SVG, while dimensions use SVG drawing units.
///
/// # Errors
/// Returns rendering failures or response-serialization failures as strings.
#[cfg_attr(target_arch = "wasm32", wasm_minimal_protocol::wasm_func)]
pub fn diagram(input: &[u8]) -> Result<Vec<u8>, String> {
  let request = michem_core::decode(input).map_err(|error| error.to_string())?;
  let drawing = michem_core::draw(&request).map_err(|error| error.to_string())?;
  serde_json::to_vec(&drawing).map_err(|error| error.to_string())
}

/// Lists the exact label runs Typst must measure in the selected font family.
///
/// # Parameters
/// - `input`: molecular-request JSON with the final style and optional instance
///   measurement scale. Existing host measurements are not needed yet.
///
/// # Returns
/// UTF-8 JSON containing unique text/size requests, including debug IDs when
/// enabled. The host must echo each exact size token in its measurement reply.
///
/// # Errors
/// Returns decoding failures, invalid molecular input, invalid scale or text
/// requests, and serialization failures as strings. No SVG is rendered here.
#[cfg_attr(target_arch = "wasm32", wasm_minimal_protocol::wasm_func)]
pub fn labels(input: &[u8]) -> Result<Vec<u8>, String> {
  let request = michem_core::decode(input).map_err(|error| error.to_string())?;
  let labels = michem_core::label_requests(&request).map_err(|error| error.to_string())?;
  serde_json::to_vec(&labels).map_err(|error| error.to_string())
}
