//! Debug annotations preserve graph identity and work without a host font.

use serde_json::json;

type TestResult = Result<(), Box<dyn std::error::Error>>;

#[test]
fn debug_should_keep_indices_and_bond_geometry_with_bundled_font() -> TestResult {
  let mut request = json!({"molecule":{"kind":"smiles","value":"CC(=O)Oc1ccccc1C(=O)O"}});
  let plain = michem_core::draw(&michem_core::decode(&serde_json::to_vec(&request)?)?)?;
  request["style"] = json!({"debug":true});
  let marked = michem_core::draw(&michem_core::decode(&serde_json::to_vec(&request)?)?)?;
  assert!(marked.svg.contains("#2563eb"));
  assert_eq!(plain.atoms.len(), marked.atoms.len());
  for (a, b) in plain.atoms.iter().zip(&marked.atoms) {
    assert_eq!(a.id, b.id);
    let dx = |atom: &michem_core::Anchor, frame: &michem_core::Diagram| {
      (atom.x - frame.atoms[0].x) * frame.width
    };
    let dy = |atom: &michem_core::Anchor, frame: &michem_core::Diagram| {
      (atom.y - frame.atoms[0].y) * frame.height
    };
    assert!((dx(a, &plain) - dx(b, &marked)).abs() < 1e-9);
    assert!((dy(a, &plain) - dy(b, &marked)).abs() < 1e-9);
  }
  Ok(())
}

#[test]
fn debug_should_measure_original_ids_at_both_instance_sizes() -> TestResult {
  let request = michem_core::decode(&serde_json::to_vec(&json!({
    "molecule":{"kind":"smiles","value":"CC(=O)O"},
    "style":{"debug":true,"font":"Libertinus Serif"},
    "measurement-scale":1.37
  }))?)?;
  let labels = michem_core::label_requests(&request)?;
  for id in ["0", "1", "2", "3"] {
    assert_eq!(labels.iter().filter(|label| label.text == id).count(), 2);
  }
  Ok(())
}
