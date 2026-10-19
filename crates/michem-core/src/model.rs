//! Explicit molecular input without exposing Chitin's graph-local handles.

use std::collections::{BTreeMap, BTreeSet};

use chitin_chem::{
  Atom, AtomId, BondOrder, Element, ImplicitHydrogenPolicy, Isotope, MolecularGraph,
};
use chitin_chemdraw::geometry::Point;
use serde::Deserialize;

use crate::Error;

/// Molecular input; manual positions use x-right, y-up normalized bond units.
#[derive(Debug, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum Molecule {
  /// A SMILES string and optional complete coordinates in parse order.
  Smiles {
    /// Chemical line notation supported by Chitin.
    value: String,
    /// One position per parsed atom; partial coordinates are rejected.
    #[serde(default)]
    positions: Option<Vec<[f64; 2]>>,
  },
  /// Explicit atoms and bonds, with optional complete authored coordinates.
  Manual {
    /// Atom records with unique names.
    atoms: Vec<AtomInput>,
    /// Bonds refer to atom names, independently of insertion order.
    bonds: Vec<BondInput>,
  },
}

/// One authored atom; zero charge and inferred H are explicit input defaults.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AtomInput {
  /// Unique, nonempty name for bonds and CeTZ anchors.
  pub id: String,
  /// Case-sensitive element symbol.
  pub element: String,
  /// Normalized y-up coordinate, or absent for automatic layout.
  #[serde(default)]
  pub position: Option<[f64; 2]>,
  /// Supplied formal charge.
  #[serde(default)]
  pub charge: i16,
  /// Fixed attached-H declaration; absent enables model-based inference.
  #[serde(default)]
  pub hydrogens: Option<u8>,
  /// Optional isotope mass number.
  #[serde(default)]
  pub isotope: Option<u16>,
  /// Supplied aromatic designation.
  #[serde(default)]
  pub aromatic: bool,
}

/// A bond between named atoms.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BondInput {
  /// First atom name.
  pub from: String,
  /// Second atom name.
  pub to: String,
  /// Chemical bond order.
  #[serde(default)]
  pub order: Order,
}

/// Supported explicit bond orders.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Order {
  /// Single bond.
  #[default]
  Single,
  /// Double bond.
  Double,
  /// Triple bond.
  Triple,
  /// Supplied aromatic bond.
  Aromatic,
}

pub(crate) struct Built {
  pub graph: MolecularGraph,
  pub names: Vec<(AtomId, String)>,
  pub positions: Option<BTreeMap<AtomId, Point>>,
}

fn input(error: impl std::fmt::Display) -> Error {
  Error::Input(error.to_string())
}

impl Molecule {
  pub(crate) fn build(&self, max_atoms: usize) -> Result<Built, Error> {
    let built = match self {
      Self::Smiles { value, positions } => {
        if value.len() > 64 * 1024 {
          return Err(input("SMILES exceeds 64 KiB"));
        }
        let graph = chitin_chem::io::smiles::read_smiles(value)
          .map_err(input)?
          .into_graph();
        let names: Vec<_> = graph
          .atoms()
          .enumerate()
          .map(|(index, (id, _))| (id, index.to_string()))
          .collect();
        let positions = if let Some(points) = positions {
          if points.len() != names.len() {
            return Err(input(
              "SMILES positions must cover every atom in parse order",
            ));
          }
          Some(
            names
              .iter()
              .zip(points)
              .map(|((id, _), p)| (*id, Point::new(p[0], p[1])))
              .collect(),
          )
        } else {
          None
        };
        Built {
          graph,
          names,
          positions,
        }
      }
      Self::Manual { atoms, bonds } => {
        if atoms.len() > max_atoms {
          return Err(input(format!(
            "atom budget exceeded: {} > {max_atoms}",
            atoms.len()
          )));
        }
        let mut graph = MolecularGraph::new();
        let mut names = Vec::with_capacity(atoms.len());
        let mut ids = BTreeMap::new();
        let mut seen = BTreeSet::new();
        let mut points = BTreeMap::new();
        for atom in atoms {
          if atom.id.is_empty() || atom.id.contains('.') || !seen.insert(&atom.id) {
            return Err(input(
              "atom names must be unique, nonempty and contain no dots",
            ));
          }
          let element = Element::from_symbol(&atom.element).map_err(input)?;
          let mut chemical = if let Some(mass) = atom.isotope {
            Atom::from_isotope(Isotope::new(element, mass).map_err(input)?)
          } else {
            Atom::new(element)
          };
          chemical = chemical
            .with_formal_charge(Some(atom.charge))
            .with_unpaired_electrons(Some(0))
            .with_aromatic(atom.aromatic);
          chemical = if let Some(count) = atom.hydrogens {
            chemical
              .with_declared_hydrogens(Some(count))
              .with_implicit_hydrogen_policy(ImplicitHydrogenPolicy::Fixed(0))
          } else {
            chemical
              .with_declared_hydrogens(Some(0))
              .with_implicit_hydrogen_policy(ImplicitHydrogenPolicy::Infer)
          };
          let id = graph.add_atom(chemical)?;
          names.push((id, atom.id.clone()));
          ids.insert(atom.id.as_str(), id);
          if let Some(p) = atom.position {
            points.insert(id, Point::new(p[0], p[1]));
          }
        }
        if !points.is_empty() && points.len() != atoms.len() {
          return Err(input("manual coordinates must cover every atom, or none"));
        }
        for bond in bonds {
          let resolve = |name: &str| {
            ids
              .get(name)
              .copied()
              .ok_or_else(|| input(format!("unknown bond endpoint: {name}")))
          };
          let order = match bond.order {
            Order::Single => BondOrder::Single,
            Order::Double => BondOrder::Double,
            Order::Triple => BondOrder::Triple,
            Order::Aromatic => BondOrder::Aromatic,
          };
          graph.add_bond(resolve(&bond.from)?, resolve(&bond.to)?, order)?;
        }
        Built {
          graph,
          names,
          positions: (!points.is_empty()).then_some(points),
        }
      }
    };
    if built.graph.is_empty() || built.graph.atom_count() > max_atoms || max_atoms == 0 {
      return Err(input(format!(
        "molecule must contain 1..={max_atoms} atoms"
      )));
    }
    Ok(built)
  }
}
