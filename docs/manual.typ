#import "../lib.typ" as michem

#set page(paper: "a4", margin: 2cm)
#set text(font: "Libertinus Serif", size: 10pt)
#show raw: set text(font: "Cascadia Mono")
#set heading(numbering: "1.")

= Michem 0.1.0

Michem renders chemical structures using Chitin compiled to WebAssembly. The
Typst interface accepts SMILES and explicit molecular graphs. CeTZ handles
reaction arrows, labels, branching, and composition on a shared canvas.

== Quick start

Build the plugin with `bash scripts/build-plugin.sh`, then import `lib.typ`.

```typst
#import "../lib.typ" as michem
#michem.smiles("CC(=O)Oc1ccccc1C(=O)O", style: michem.style(font: "Libertinus Serif"))
```

#align(center)[#michem.smiles(
  "CC(=O)Oc1ccccc1C(=O)O",
  style: michem.style(font: "Libertinus Serif"),
)]

== Molecular input

`smiles`, `svg`, `diagram`, and `cetz.molecule` accept either a raw SMILES
string, `smiles-input(value, positions: none)`, or `molecule(atoms: ..., bonds: ...)`.

`atom(id, element: "C", at: none, charge: 0, hydrogens: none,
isotope: none, aromatic: false)` creates a named atom. Names must be unique,
nonempty and contain no dots. `bond(from, to, order: "single")` connects names;
supported orders are `single`, `double`, `triple`, and `aromatic`.

With no coordinates, Chitin computes a layout. With authored coordinates, every
atom must have a position. A coordinate unit is one nominal bond; x points right
and y points up. SMILES positions follow zero-based parse order. Manual topology
defaults to neutral, closed-shell atoms with inferred hydrogens; `hydrogens`
fixes the attached-H count. Use SMILES for stereochemical descriptors.

== Style

Pass `style: michem.style(...)` to any renderer. Dimensions below use SVG
pixels; at natural size one pixel equals 0.75pt. The bond length defaults to 24.
Changing it scales default font size, stroke width, wedge width, bond spacing,
and label padding together. Explicit overrides are absolute drawing dimensions.

#table(
  columns: (1fr, 2fr),
  inset: 5pt,
  stroke: 0.3pt + gray,
  [*Option*], [*Value*],
  [`bond-length`], [Nominal drawing bond length; default 24],
  [`font-size`, `stroke-width`], [Positive drawing dimensions],
  [`font`], [Any font family available to Typst, e.g. `"Libertinus Serif"`],
  [`wedge-width`, `bond-spacing`], [Positive drawing dimensions],
  [`short-bond-ratio`], [Secondary stroke fraction; Chitin default 0.8],
  [`label-padding`], [Clearance around atom labels],
  [`foreground`], [Typst RGB color or hex string; default `#202124`],
  [`color-scheme`], [`"element"` or `"monochrome"`],
  [`color-map`], [Element-symbol dictionary; overrides builtin palette entries],
  [`bond-colors`], [`"split"` or `"uniform"`],
  [`aromatic`], [`"kekule"` or `"circle"`],
  [`chiral-hydrogens`], [`"implicit"` or `"explicit"`],
  [`padding`, `background`],
  [SVG padding defaults to 4; background defaults to transparent],
)

Hex colors use `#RRGGBB` or `#RRGGBBAA`. Convert non-RGB Typst colors to RGB
before passing them. In monochrome mode, color-map entries are ignored. Circle
aromatic style applies to eligible independent rings; other rings retain Kekule
strokes. With `font: "Libertinus Serif"`, Typst measures every required label
in that font and Chitin uses those metrics for layout and clipping. SVG labels
reference the same family. Any family available to Typst can be selected by name;
no font file is passed to the plugin. See `examples/fonts.typ`.
Without `font`, labels retain Chitin's bundled Noto Sans outlines.
Document `set text` rules do not override the molecule font.

== Layout

Pass `layout: michem.layout(...)`. Supported options are `max-atoms` (default
512), `component-gap`, `minimum-spacing`, `refinement-passes`,
`refinement-budget`, `stereo-budget`, and `work-budget`. The shared `work-budget`
bounds native topology, ring construction, search and simulation. It replaces
the former `ring-search-budget`, `backbone-budget`, `optimization-iterations`,
and `optimization-budget` options. Defaults other than
max-atoms follow the pinned Chitin version. Authored coordinates bypass
automatic layout but retain the atom limit. The request limit is 4 MiB and the
SMILES text limit is 64 KiB.

== Outputs

`smiles(mol, style: (:), layout: (:), width: auto, height: auto)` produces Typst
content. `svg(mol, ...)` returns SVG bytes. `diagram(mol, ...)` returns a
dictionary containing `svg`, `width`, `height`, `atoms`, and `diagnostics`. Each
atom has an `id` and normalized `x`, `y` in the framed image, with origin at the
bottom left. Layout diagnostics describe unresolved crowding, crossings, or work
exhaustion. They are available to callers and are not automatically typeset.
When selecting a named font, direct calls to `svg` and `diagram` require
`context { ... }` for text measurement. `smiles` and CeTZ handle this automatically.
Named-font SVG exports reference fonts, so a standalone viewer needs the same
font family. The default outlined SVG remains independent of viewer fonts.

== Authored mechanisms

`mechanism(..items, font: none, gap: 24pt, padding: 6pt, label-gap: 4pt)`
composes named molecular occurrences, fragment highlights, electron-flow arrows,
and reaction connectors without requiring CeTZ. See `examples/mechanism.typ`.
It draws the supplied mechanism; it does not predict a reaction.

- `mol(id, input, at: none, offset: (0pt, 0pt), scale: 1, style: (:), layout: (:))`
  creates a unique occurrence. With no `at`, measured bounds are packed in a row.
  Explicit `at` translates the local molecular origin, not the image corner.
- `atom-ref(id, atom, offset: (0, 0))` and `bond-ref(id, a, b, offset: (0, 0))`
  address original input atom names or zero-based SMILES indices. Offsets are
  local SVG pixels and follow the occurrence scale.
- `highlight(id, atoms: (), bonds: (), radius: 4, color: ...)` shades a fragment.
  Bonds are endpoint pairs; one request applies opacity once to its union.
- `electron-arrow(from, to, bend: 30, head: "pair", style: (:))` draws authored
  electron flow. Heads also support `"fishhook-left"` and `"fishhook-right"`.
- `lone-pair(reference, angle: 0deg, separation: 3, radius: 0.7, color: red)`
  places explicit electron dots without inferring valence.
- `reaction-arrow(from, to, equilibrium: false, above: none, below: none, style: (:))`
  adds a reaction connector and arbitrary Typst conditions. Endpoints accept
  coordinates or `edge(id, side: "east", gap: 3pt)` references to measured bounds.
- `mechanism-label(at, body)` adds centered native Typst content.

Coordinates accept physical lengths or SVG pixels, with x right and y down.
Arrow bend and style dimensions are shared SVG pixels; the arrow style accepts
`color`, `width`, `head-length`, `head-width`, and `clearance`. Molecular input
coordinates remain normalized y-up bond units. Reflections, automatic arrow
routing, and reaction inference are not performed.

`mechanism-data(..items, ...)` is available inside `context` for inspection; its
`scene.molecules` contains absolute named atom and bond anchors. Pass the result
to `paint-mechanism(data, padding: 6pt)` to draw it. Preparation freezes all atom
coordinates before final composition. Wire version 1 never exposes internal
graph handles. Named-font runs are measured and painted by Typst, interleaved
with vector layers in painter order; opaque size tokens survive numeric codecs.
Standalone molecule SVG framing options do not frame the shared mechanism.

For local development against an unpublished Chitin checkout, run
`CHITIN_SOURCE=/path/to/chitin bash scripts/build-plugin.sh`, or set the same
environment variable when running `just mechanism`. This uses a local Cargo
override without modifying the pinned remote revision. Publish and pin the
matching Chitin changes before using a normal release build.

== CeTZ canvas

Inside `cetz.canvas`, call `michem.cetz.molecule(mol, at: (0, 0), name: none,
scale: 1, unit: 0.75pt, style: (:), layout: (:))`. The molecule is embedded as
outlined vector SVG. The named group exposes its standard boundary anchors and
`name.atom-ID` anchors, where ID is the manual name or zero-based SMILES index.
Physical size and atom anchors scale together. CeTZ translation, planar
rotation, and positive uniform scaling apply to the image and anchors together;
see `examples/anchors.typ`. Shear and 3D projection are outside this image
adapter's contract.

`michem.cetz.reaction(from, to, above: none, below: none, name: none,
stroke: 0.7pt, label-gap: 3pt, label-side: "north")` creates an arrow with Typst
labels. `label-side` selects the side for the `above` label: north, south, east,
or west; the `below` label uses the opposite side. Use east or west for vertical
arrows. Use CeTZ's line, bezier, mark, group, and content functions for more
elaborate mechanisms, curved arrows and branched reaction schemes. See
`examples/reaction.typ`.

== Architecture

`michem-core` owns the JSON schema and the Chitin adapter. `michem-wasm` exposes
the minimal Typst plugin protocol. The Typst package owns document content and
CeTZ composition. Chemical facts, stereochemistry, layout and depiction remain
in Chitin. Invalid SMILES, incomplete coordinates, unknown options, and
unsupported chemical depictions return errors instead of partial drawings.
