//! Typst's minimal protocol: JSON requests in, SVG or diagram JSON out.

/// Prepares measured local bounds, named anchors and complete frozen coordinates.
#[cfg_attr(target_arch = "wasm32", wasm_minimal_protocol::wasm_func)]
pub fn mechanism_prepare(input: &[u8]) -> Result<Vec<u8>, String> {
  let request = michem_core::mechanism::decode(input).map_err(|e| e.to_string())?;
  let prepared = michem_core::mechanism::prepare(&request).map_err(|e| e.to_string())?;
  serde_json::to_vec(&prepared).map_err(|e| e.to_string())
}

/// Resolves annotations against frozen occurrences and returns portable scene layers.
#[cfg_attr(target_arch = "wasm32", wasm_minimal_protocol::wasm_func)]
pub fn mechanism(input: &[u8]) -> Result<Vec<u8>, String> {
  let request = michem_core::mechanism::decode(input).map_err(|e| e.to_string())?;
  let drawing = michem_core::mechanism::compose(&request).map_err(|e| e.to_string())?;
  serde_json::to_vec(&drawing).map_err(|e| e.to_string())
}

#[cfg(target_arch = "wasm32")]
wasm_minimal_protocol::initiate_protocol!();

/// Renders a molecule into standalone SVG bytes.
#[cfg_attr(target_arch = "wasm32", wasm_minimal_protocol::wasm_func)]
pub fn render(input: &[u8]) -> Result<Vec<u8>, String> {
  let request = michem_core::decode(input).map_err(|error| error.to_string())?;
  michem_core::draw(&request)
    .map(|diagram| diagram.svg.into_bytes())
    .map_err(|error| error.to_string())
}

/// Renders SVG together with dimensions, atom anchors and layout diagnostics.
#[cfg_attr(target_arch = "wasm32", wasm_minimal_protocol::wasm_func)]
pub fn diagram(input: &[u8]) -> Result<Vec<u8>, String> {
  let request = michem_core::decode(input).map_err(|error| error.to_string())?;
  let drawing = michem_core::draw(&request).map_err(|error| error.to_string())?;
  serde_json::to_vec(&drawing).map_err(|error| error.to_string())
}

/// Lists the exact label runs Typst must measure in the selected font family.
#[cfg_attr(target_arch = "wasm32", wasm_minimal_protocol::wasm_func)]
pub fn labels(input: &[u8]) -> Result<Vec<u8>, String> {
  let request = michem_core::decode(input).map_err(|error| error.to_string())?;
  let labels = michem_core::label_requests(&request).map_err(|error| error.to_string())?;
  serde_json::to_vec(&labels).map_err(|error| error.to_string())
}
