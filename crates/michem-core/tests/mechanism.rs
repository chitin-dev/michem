//! Protocol isolation, frozen geometry and host-font scene transfer.

use michem_core::{mechanism, mechanism::model::Layer};
use serde_json::{Value, json};

type TestResult = Result<(), Box<dyn std::error::Error>>;

#[test]
fn automatic_arc_routes_should_report_the_selected_path_and_honor_preference() -> TestResult {
  for (prefer, expected) in [("minor", "minor"), ("major", "major")] {
    let mut b = instance("b", "C");
    b["placement"] = json!({"origin":[180,0]});
    let mut value = prepare(json!({"version":1,"molecules":[instance("a","C"),b]}))?;
    value["annotations"] = json!([{"type":"electron-arrow","curve":"arc","arc-angle":90,
      "arc-path":"auto","arc-prefer":prefer,"route":"auto",
      "from":{"molecule":"a","target":{"kind":"atom","atom":"0"},"offset":[0,40]},
      "to":{"molecule":"b","target":{"kind":"atom","atom":"0"},"offset":[0,40]}}]);
    let scene = mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?)?;
    assert_eq!(scene.routing[0].arc_path, Some(expected));
    value["annotations"][0]["arc-path"] = json!("unknown");
    assert!(mechanism::decode(&serde_json::to_vec(&value)?).is_err());
  }
  Ok(())
}

#[test]
fn default_arc_routes_should_preserve_native_geometry_and_report_selected_sweeps() -> TestResult {
  let mut b = instance("b", "C");
  b["placement"] = json!({"origin":[180,0]});
  let mut value = prepare(json!({"version":1,"molecules":[instance("a","C"),b]}))?;
  value["obstacles"] = json!([{"min":[65,-60],"max":[115,-5]}]);
  value["annotations"] = json!([{"type":"electron-arrow","arc-angle":90,"route":"auto",
    "from":{"molecule":"a","target":{"kind":"atom","atom":"0"}},
    "to":{"molecule":"b","target":{"kind":"atom","atom":"0"}}}]);
  let scene = mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?)?;
  assert!(scene.routing[0].arc_angle.is_some_and(|a| a < 0.));
  assert!(
    scene
      .layers
      .iter()
      .any(|l| matches!(l, Layer::Vector { svg, .. } if svg.contains(" A")))
  );
  value["annotations"][0]["controls"] = json!([[20, 30], [-20, 30]]);
  assert!(mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?).is_err());
  value["annotations"][0]
    .as_object_mut()
    .ok_or("annotation")?
    .remove("controls");
  value["annotations"][0]["arc-angle"] = json!(0);
  assert!(mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?).is_err());
  Ok(())
}

#[test]
fn explicit_controls_circled_charges_and_reactive_sites_should_compose() -> TestResult {
  let mut a = instance("a", "[OH-]");
  a["drawing"]["style"] = json!({"charge-style":"circled"});
  let mut b = instance("b", "[H+]");
  b["drawing"]["style"] = json!({"charge-style":"circled"});
  b["placement"] = json!({"origin":[180,0]});
  let mut value = prepare(json!({"version":1,"molecules":[a,b]}))?;
  value["annotations"] = json!([
    {"type":"electron-dot","anchor":{"molecule":"a","target":{"kind":"radical","atom":"0"},"offset":[15,12]},"radius":0.7,"color":"#000000"},
    {"type":"electron-arrow","curve":"bezier","from":{"molecule":"a","target":{"kind":"radical","atom":"0"},"offset":[15,12]},"to":{"molecule":"a","target":{"kind":"bond-formation","atom":"0","other_molecule":"b","other_atom":"0"}},"bend":0,"controls":[[25,30],[-10,30]],"head":"fishhook-left"}
  ]);
  let drawing = mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?)?;
  let svg = drawing
    .layers
    .iter()
    .filter_map(|l| match l {
      Layer::Vector { svg, .. } => Some(svg.as_str()),
      _ => None,
    })
    .collect::<String>();
  assert!(svg.matches("<circle").count() >= 3);
  assert!(svg.contains(" C"));
  value["annotations"][1]["to"]["target"]["other_molecule"] = json!("unknown");
  assert!(mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?).is_err());
  Ok(())
}

fn instance(id: &str, smiles: &str) -> Value {
  json!({"id":id,"drawing":{"molecule":{"kind":"smiles","value":smiles}}})
}

fn prepare(mut value: Value) -> Result<Value, Box<dyn std::error::Error>> {
  let request = mechanism::decode(&serde_json::to_vec(&value)?)?;
  let prepared = mechanism::prepare(&request)?;
  for (instance, prepared) in value["molecules"]
    .as_array_mut()
    .ok_or("missing molecules")?
    .iter_mut()
    .zip(prepared.molecules)
  {
    instance["drawing"]["molecule"]["positions"] = serde_json::to_value(prepared.positions)?;
  }
  Ok(value)
}

#[test]
fn versions_unknown_fields_and_duplicate_instances_should_be_rejected() -> TestResult {
  for value in [
    json!({"version":2,"molecules":[instance("a","CO")]}),
    json!({"version":1,"molecules":[instance("a","CO")],"typo":true}),
    json!({"version":1,"molecules":[instance("a","CO"),instance("a","CO")]}),
  ] {
    assert!(mechanism::decode(&serde_json::to_vec(&value)?).is_err());
  }
  Ok(())
}

#[test]
fn composition_should_require_complete_frozen_coordinates() -> TestResult {
  let value = json!({"version":1,"molecules":[instance("a","CO")]});
  let request = mechanism::decode(&serde_json::to_vec(&value)?)?;
  assert!(mechanism::compose(&request).is_err());
  Ok(())
}

#[test]
fn composition_should_not_rerun_layout_or_alias_repeated_graphs() -> TestResult {
  let mut value =
    prepare(json!({"version":1,"molecules":[instance("left","CO"),instance("right","CO")]}))?;
  value["molecules"][0]["drawing"]["layout"] = json!({"work-budget":0});
  value["molecules"][1]["drawing"]["layout"] = json!({"work-budget":0});
  value["molecules"][1]["placement"] = json!({"origin":[150,30],"scale":1});
  let drawing = mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?)?;
  for (a, b) in drawing.molecules[0]
    .atoms
    .iter()
    .zip(&drawing.molecules[1].atoms)
  {
    assert_eq!(a.id, b.id);
    assert!((b.position[0] - a.position[0] - 150.).abs() < 1e-10);
    assert!((b.position[1] - a.position[1] - 30.).abs() < 1e-10);
  }
  let text = serde_json::to_string(&drawing)?;
  assert!(!text.contains("namespace"));
  assert!(!text.contains("AtomId"));
  Ok(())
}

#[test]
fn references_should_reject_unknown_occurrences_atoms_and_nonexistent_bonds() -> TestResult {
  for from in [
    json!({"molecule":"foreign","target":{"kind":"atom","atom":"0"}}),
    json!({"molecule":"a","target":{"kind":"atom","atom":"99"}}),
    json!({"molecule":"a","target":{"kind":"bond","from":"0","to":"2"}}),
  ] {
    let mut value =
      prepare(json!({"version":1,"molecules":[instance("a","CCO"),instance("b","CCO")]}))?;
    value["annotations"] = json!([{"type":"electron-arrow","from":from,"to":{"molecule":"b","target":{"kind":"atom","atom":"0"}},"bend":50}]);
    assert!(mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?).is_err());
  }
  Ok(())
}

#[test]
fn named_host_text_should_stay_between_highlights_and_electron_arrows() -> TestResult {
  let mut item = instance("a", "[OH-]");
  item["drawing"]["style"] = json!({"font":"Host Serif"});
  item["placement"] = json!({"scale":1.5});
  let request = michem_core::decode(&serde_json::to_vec(&item["drawing"])?)?;
  let labels = michem_core::label_requests(&request)?;
  let mut entries = std::collections::BTreeMap::new();
  for label in labels {
    for size in [label.size, label.size * 1.5] {
      let metrics = chitin_chemdraw::font::FontFace::NotoSans.measure(&label.text, size)?;
      entries.insert((label.text.clone(), size.to_bits()), json!({"text":label.text,"size":size,"advance":metrics.advance,"min":[metrics.min.x,metrics.min.y],"max":[metrics.max.x,metrics.max.y]}));
    }
  }
  item["drawing"]["measurements"] = json!(entries.into_values().collect::<Vec<_>>());
  let mut other = instance("b", "C");
  other["placement"] = json!({"origin":[160,0]});
  let mut value = prepare(json!({"version":1,"molecules":[item,other]}))?;
  value["annotations"] = json!([
    {"type":"highlight","molecule":"a","atoms":["0"],"radius":4,"color":"#88bb8880"},
    {"type":"electron-arrow","from":{"molecule":"a","target":{"kind":"atom","atom":"0"}},"to":{"molecule":"b","target":{"kind":"atom","atom":"0"}},"bend":40}
  ]);
  let drawing = mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?)?;
  assert!(matches!(drawing.layers.first(), Some(Layer::Vector { .. })));
  let index = drawing
    .layers
    .iter()
    .position(|l| matches!(l, Layer::Label { .. }))
    .ok_or("missing host label")?;
  assert!(
    drawing.layers[index + 1..]
      .iter()
      .any(|l| matches!(l, Layer::Vector { .. }))
  );
  for layer in &drawing.layers {
    match layer {
      Layer::Vector { svg, .. } => {
        assert!(!svg.contains("<text"));
      }
      Layer::Label { font, size, .. } => {
        assert_eq!(font, "Host Serif");
        assert!(*size > 0.);
      }
    }
  }
  Ok(())
}

#[test]
fn prepared_bounds_and_anchors_should_share_the_scaled_local_frame() -> TestResult {
  let mut item = instance("a", "CO");
  item["placement"] = json!({"origin":[100,200],"scale":2});
  let request = mechanism::decode(&serde_json::to_vec(
    &json!({"version":1,"molecules":[item]}),
  )?)?;
  let prepared = mechanism::prepare(&request)?;
  let result = &prepared.molecules[0];
  for (anchor, position) in result.anchors.atoms.iter().zip(&result.positions) {
    assert!((anchor.position[0] - position[0] * 48.).abs() < 1e-10);
    assert!((anchor.position[1] + position[1] * 48.).abs() < 1e-10);
  }
  Ok(())
}

#[test]
fn exact_measurement_tokens_should_survive_a_host_codec_rounding_one_bit() -> TestResult {
  let mut item = instance("a", "[OH-]");
  item["drawing"]["style"] = json!({"font":"Host Serif"});
  item["drawing"]["measurement-scale"] = json!(1.3);
  item["placement"] = json!({"scale":1.3});
  let request = michem_core::decode(&serde_json::to_vec(&item["drawing"])?)?;
  let labels = michem_core::label_requests(&request)?;
  let mut rows = Vec::new();
  for label in labels {
    let metrics = chitin_chemdraw::font::FontFace::NotoSans.measure(&label.text, label.size)?;
    rows.push(json!({"text":label.text,"size":f64::from_bits(label.size.to_bits() + 1),"key":label.key,"advance":metrics.advance,"min":[metrics.min.x,metrics.min.y],"max":[metrics.max.x,metrics.max.y]}));
  }
  item["drawing"]["measurements"] = json!(rows);
  let value = prepare(json!({"version":1,"molecules":[item]}))?;
  let drawing = mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?)?;
  assert!(
    drawing
      .layers
      .iter()
      .any(|l| matches!(l, Layer::Label { .. }))
  );
  Ok(())
}

#[test]
fn measurement_tokens_should_reject_a_different_size_instead_of_interpolating() -> TestResult {
  let mut item = instance("a", "O");
  item["drawing"]["style"] = json!({"font":"Host Serif"});
  item["drawing"]["measurements"] = json!([{"text":"O","size":9,"key":format!("{:016x}",18_f64.to_bits()),"advance":5,"min":[0,-7],"max":[5,1]}]);
  let request = mechanism::decode(&serde_json::to_vec(
    &json!({"version":1,"molecules":[item]}),
  )?)?;
  assert!(mechanism::prepare(&request).is_err());
  Ok(())
}

#[test]
fn repeated_stateless_composition_should_not_serialize_new_graph_namespaces() -> TestResult {
  let value = prepare(json!({"version":1,"molecules":[instance("a","CCO")]}))?;
  let request = mechanism::decode(&serde_json::to_vec(&value)?)?;
  let a = serde_json::to_string(&mechanism::compose(&request)?)?;
  let b = serde_json::to_string(&mechanism::compose(&request)?)?;
  assert_eq!(a, b);
  Ok(())
}

#[test]
fn automatic_routes_should_detour_around_reserved_host_labels() -> TestResult {
  let mut a = instance("a", "C");
  let mut b = instance("b", "C");
  a["placement"] = json!({"origin":[0,0]});
  b["placement"] = json!({"origin":[180,0]});
  let mut value = prepare(json!({"version":1,"molecules":[a,b]}))?;
  value["obstacles"] = json!([{"min":[70,-20],"max":[110,20]}]);
  value["annotations"] = json!([{"type":"electron-arrow","curve":"bezier","route":"auto","bend":0,
    "from":{"molecule":"a","target":{"kind":"atom","atom":"0"}},
    "to":{"molecule":"b","target":{"kind":"atom","atom":"0"}}}]);
  let scene = mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?)?;
  assert_eq!(scene.routing.len(), 1);
  assert_ne!(scene.routing[0].bend, 0.);
  assert_eq!(scene.routing[0].annotation, 0);
  Ok(())
}

#[test]
fn unrouteable_auto_arrows_should_fail_explicitly_instead_of_returning_overlap() -> TestResult {
  let mut b = instance("b", "C");
  b["placement"] = json!({"origin":[180,0]});
  let mut value = prepare(json!({"version":1,"molecules":[instance("a","C"),b]}))?;
  value["obstacles"] = json!([{"min":[-1000,-1000],"max":[1000,1000]}]);
  value["annotations"] = json!([{"type":"electron-arrow","route":"auto","bend":0,
    "from":{"molecule":"a","target":{"kind":"atom","atom":"0"}},
    "to":{"molecule":"b","target":{"kind":"atom","atom":"0"}}}]);
  let Err(error) = mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?) else {
    return Err("blocked route should fail".into());
  };
  assert!(error.to_string().contains("no clear electron-arrow route"));
  Ok(())
}

#[test]
fn manual_curves_should_preserve_the_authored_bend_even_when_obstructed() -> TestResult {
  let mut b = instance("b", "C");
  b["placement"] = json!({"origin":[180,0]});
  let mut value = prepare(json!({"version":1,"molecules":[instance("a","C"),b]}))?;
  value["obstacles"] = json!([{"min":[70,-20],"max":[110,20]}]);
  value["annotations"] = json!([{"type":"electron-arrow","curve":"bezier","bend":0,
    "from":{"molecule":"a","target":{"kind":"atom","atom":"0"}},
    "to":{"molecule":"b","target":{"kind":"atom","atom":"0"}}}]);
  let scene = mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?)?;
  assert!(scene.routing.is_empty());
  Ok(())
}

#[test]
fn auto_pair_references_should_follow_the_selected_position_in_stateless_requests() -> TestResult {
  let mut b = instance("b", "[CH3+]");
  b["placement"] = json!({"origin":[180,0]});
  let mut value = prepare(json!({"version":1,"molecules":[instance("a","[OH-]"),b]}))?;
  value["annotations"] = json!([
    {"type":"lone-pair","id":"donor","position":"auto","anchor":{"molecule":"a","target":{"kind":"atom","atom":"0"}},"angle":0,"separation":3,"radius":0.7,"color":"#000000"},
    {"type":"electron-arrow","curve":"bezier","route":"auto","bend":25,"from":{"molecule":"a","target":{"kind":"lone-pair","pair":"donor"}},"to":{"molecule":"b","target":{"kind":"atom","atom":"0"}}}
  ]);
  let request = mechanism::decode(&serde_json::to_vec(&value)?)?;
  let scene = mechanism::compose(&request)?;
  assert_eq!(scene.lone_pairs.len(), 1);
  assert_ne!(scene.lone_pairs[0].offset, [0., 0.]);
  assert_eq!(scene.routing.len(), 1);
  assert_eq!(
    serde_json::to_string(&scene)?,
    serde_json::to_string(&mechanism::compose(&request)?)?
  );
  Ok(())
}

#[test]
fn pair_references_should_reject_unknown_and_duplicate_ids() -> TestResult {
  let mut value = prepare(json!({"version":1,"molecules":[instance("a","[OH-]")]}))?;
  let pair = json!({"type":"lone-pair","id":"donor","anchor":{"molecule":"a","target":{"kind":"atom","atom":"0"},"offset":[15,0]},"angle":0,"separation":3,"radius":0.7,"color":"#000000"});
  value["annotations"] = json!([pair, pair]);
  assert!(mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?).is_err());
  value["annotations"] = json!([{"type":"electron-arrow","bend":30,"from":{"molecule":"a","target":{"kind":"lone-pair","pair":"missing"}},"to":{"molecule":"a","target":{"kind":"atom","atom":"0"}}}]);
  let Err(error) = mechanism::compose(&mechanism::decode(&serde_json::to_vec(&value)?)?) else {
    return Err("missing pair should fail".into());
  };
  assert!(error.to_string().contains("unknown lone pair"));
  Ok(())
}
