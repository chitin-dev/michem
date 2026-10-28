#import "../lib.typ" as michem
#import "theme.typ": border, example, manual

#show: manual

= Getting started

Michem renders chemical structures using Chitin compiled to WebAssembly. The
Typst interface accepts SMILES and explicit molecular graphs. The package offers automatic reaction routes, authored electron-flow diagrams,
and an adapter for composition on a shared CeTZ canvas.

== Installation and import

Import the 0.1.0 package from Typst's preview namespace:

```typst
#import "@preview/michem:0.1.0" as michem
```

For a source checkout, build the plugin with `bash scripts/build-plugin.sh`
and import `lib.typ` by its relative path instead. This guide uses the local
entrypoint so it can be built and reviewed before the release is published.

== Your first molecule

The source in each example card is executed to produce its displayed result.
Choose the molecular font explicitly; document text rules do not set SVG fonts.

#example(```typst
#michem.smiles(
  "CC(=O)Oc1ccccc1C(=O)O",
  style: michem.style(font: "Libertinus Serif"),
)
```)

== Choose an interface

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.4pt + border,
  table.header([*Interface*], [*Use it for*]),
  [`smiles`], [An individual SMILES or authored molecular structure.],
  [`compound-grid`], [A gallery with uniform atom size and bond length.],
  [`reaction-route`], [Automatic chains, branches, joins and circular routes.],
  [`mechanism`], [Explicit atom-level electron flow and annotations.],
  [`cetz.molecule`], [Structures and atom anchors on a custom CeTZ canvas.],
)

Michem draws the structures and connectivity you supply. It does not infer
reaction products, reaction mechanisms, stoichiometry, or lone-pair counts.
The route templates arrange whole stages; electron-flow endpoints remain explicit.

= Molecular structures

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

#example(```typst
#let ethanol = michem.molecule(
  atoms: (
    michem.atom("c1", at: (0, 0)),
    michem.atom("c2", at: (0.866, 0.5)),
    michem.atom("o", element: "O", at: (1.732, 0)),
  ),
  bonds: (michem.bond("c1", "c2"), michem.bond("c2", "o")),
)
#michem.smiles(ethanol,
  style: michem.style(font: "Libertinus Serif"),
)
```)

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
  [`debug`], [Show original atom IDs in blue; default `false`],
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

#example(```typst
#michem.smiles("NCC(=O)O", style: michem.style(
  font: "Libertinus Serif",
  color-map: (O: rgb("#bf4b45"), N: rgb("#476ca8")),
  bond-colors: "uniform",
))
```)

== Inspecting atom indices

Use `style(debug: true)` to show the atom IDs accepted by `highlight`,
`atom-ref`, and `bond-ref`. All atoms are marked, including unlabeled carbons.
SMILES IDs are zero-based parse indices; branches count as atoms, while ring
closure digits and implicit hydrogens do not. Explicit hydrogen atoms such as
`[H]` have their own IDs. Manually authored molecules show their atom names.
For example, `CC(=O)O` has IDs `0`, `1`, `2`, `3`; its carbonyl bond is `(1, 2)`.
Bond highlights take two atom IDs, not a bond index.

#example(```typst
#michem.smiles("CC(=O)O", style: michem.style(
  font: "Libertinus Serif",
  debug: true,
))
```)

For `reaction-route` (linear or circular) and `compound-grid`, pass
`molecular-style: michem.style(debug: true)`. For a mechanism, set
`style: michem.style(debug: true, font: "Libertinus Serif")` on each `mol`.

Use the numbered view to select a bond, then supply the same endpoint IDs to a
highlight. This Suzuki product uses `(6, 7)` for the new biaryl C–C bond.
The route's molecular style applies to all participants, including peripheral
step reactants and products in a circular layout.

#example(```typst
#michem.reaction-route(
  michem.reaction-stage("substrate", "CC(=O)c1ccc(Br)cc1"),
  michem.reaction-stage("product", michem.compound(
    "CC(=O)c1ccc(-c2ccccc2)cc1",
    highlights: ((bonds: ((6, 7),),),),
  )),
  molecular-style: michem.style(debug: true),
)
```)

For a mechanism, debug is selected per occurrence. The following displays the
same indices used by `atom-ref("aldehyde", 1)` and
`bond-ref("aldehyde", 0, 1)`; named-font labels use the mechanism's chosen font.

#example(```typst
#michem.mechanism(
  michem.mol("aldehyde", "O=Cc1ccccc1",
    style: michem.style(debug: true)),
  font: "Libertinus Serif",
)
```)

Atom IDs are local to each molecular occurrence. Debug labels follow the
molecular font, are 65% of its size, and are included in measured bounds.
Short candidate offsets reduce collisions with text; dense structures may still
need a larger bond length for inspection. Debug mode does not change atom IDs,
chemical labels or atom positions. Disable it for final figures.

For programmatic inspection, `context { repr(michem.diagram(input).atoms) }`
returns IDs with normalized anchor positions. The numbered view is generally
easier when choosing references in branched or cyclic structures. A complete
inspection gallery is available in `examples/debug-indices.typ`.

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

= Reaction route templates

`reaction-route` composes named stages into an automatically arranged reaction
scheme. Each stage groups its participating compounds; plus signs, reaction
arrows, conditions and compound names are placed by the template.

#example(```typst
#michem.reaction-route(
  michem.reaction-stage("alcohol", michem.compound("CCO", name: [Alcohol])),
  michem.reaction-stage("aldehyde", michem.compound("CC=O", name: [Aldehyde])),
  michem.reaction-stage("acid", michem.compound("CC(=O)O", name: [Acid])),
  atom-size: 9pt,
  label-size: 10pt,
)
```)

- `compound(input, name: none, coefficient: none, highlights: ())` describes a SMILES string or
  manual molecular input with its displayed name and explicit coefficient.
- `reaction-stage(id, ..compounds, label: none)` groups one or more participants.
  The template inserts plus signs between compounds. Its optional label is a
  caption for the whole stage.
- `reaction-step(from, to, above: none, below: none, equilibrium: false,
  reactants: (), products: (), branch-curve: auto)` declares
  a connection using stage IDs. Pass an array as `steps: (...)`; omitted steps
  connect stages sequentially in declaration order. Branches and joins follow
  the explicitly supplied connections. Coefficients and reaction connectivity
  are never inferred or chemically balanced.
- `reaction-route(..stages, steps: auto, ...)` measures and paints the complete
  route. `font: "Libertinus Serif"`, `atom-size: 9pt`, `label-size: 10pt` and
  `bond-length: 18pt` apply consistently to every participant. Lengths here are
  physical Typst dimensions, not SVG pixels. No participant is independently
  resized to a cell width. Molecular names share reserved image and caption rows.
- `compound-grid(..compounds, columns: 3, ...)` displays related compounds with
  the same shared font, atom size, label size and bond length. Its measured image
  and name rows align even when structures have very different extents.

`direction: "auto"` selects horizontal flow, or vertical flow for a branching
graph that is too wide. Use `"right"` or `"down"` to select a direction explicitly.
Linear horizontal routes wrap to the available line width and receive continuation
arrows through reserved outer lanes. Branching directed acyclic graphs use
topological layers; skip connections pass outside intermediate stages.
This is deterministic graph layout, not a guarantee of a crossing-free drawing
for every graph. Layered modes require an acyclic graph; use circular layout
for a reaction cycle.

== Compound bond and fragment highlights

`compound(..., highlights: (...))` attaches local highlight regions to a
participant. Every region is a dictionary with `atoms`, `bonds`, `radius` and/or
`color`; omitted settings use the same defaults as `highlight`. `radius` is in
SVG pixels (default 4), while route atom sizes and bond lengths use physical
Typst dimensions. Atom references are zero-based SMILES parse indices or authored
atom names. Bond endpoints must identify an existing bond.

```typst
michem.compound("CC(=O)c1ccc(-c2ccccc2)cc1",
  name: [Biaryl product],
  highlights: ((bonds: ((6, 7),), color: rgb("#88c7a880")),),
)
```

Regions are painted beneath bonds and native labels, and their complete ink
bounds are included before placement. They work in `compound-grid`, linear or
circular route stages, and step `reactants`/`products`. Repeated compounds keep
their own regions; no occurrence ID is needed. Source atom identifiers and the
shared label size are preserved. Circular stages use compact measured cards;
only participants within the same stage share an image/name row.
See the highlighted medicinal structures, Suzuki coupling and urea-cycle product
in the README for complete source and rendered figures.

== Circular mechanism routes

Pass `layout: "circular"` to arrange two or more stages around a circle.
Omitting `steps` connects the stages in declaration order and closes the last
stage back to the first. Explicit steps can describe a single directed cycle;
the template follows its connectivity while keeping the first declared stage
at the initial angle. Partial explicit steps must connect neighboring stages.

#example(```typst
#michem.reaction-route(
  michem.reaction-stage("a", michem.compound("CCO", name: [Stage A])),
  michem.reaction-stage("b", michem.compound("CC=O", name: [Stage B])),
  michem.reaction-stage("c", michem.compound("CC(=O)O", name: [Stage C])),
  layout: "circular",
  center: [Reaction cycle],
)
```)

`clockwise: true` controls progression around the circle; `false` reverses it.
`start-angle: -90deg` places the first stage at the top; zero degrees is the right
side, with positive angles increasing clockwise in the diagram's y-down axes.
`radius: auto` increases the radius until the measured stage boxes, condition
text, optional center label and arrow paths clear each other. An explicit
positive radius fixes it; insufficient space returns an error rather than
shrinking fonts or silently changing the requested radius. Radius search has
64 trials and a 10,000pt upper bound.

Molecules, coefficients, names and conditions remain upright. `atom-size`,
`label-size` and `bond-length` retain the same physical units as linear routes.
Circular layout uses `clockwise` rather than the linear `direction` option;
`row-gap` has no role on a single ring.

Reaction connectors are true SVG circular arcs. Endpoints are clipped against
the complete measured stage bounds, including compound names. Arrowheads follow
the circle tangent. `above` places a condition outside the ring; `below` places
it inside. `equilibrium: true` adds an offset concentric return arc. Use it
instead of declaring overlapping opposing steps on the same arc.

`center: none` leaves the middle empty; otherwise it accepts native Typst
content, measured with the route's label font and size. `max-width` still limits
the final drawing: a circle is not flattened into an ellipse or individually
rescaled to fit. Provide more space or adjust the shared molecular sizes when
the selected clear circle is too large. Circular layout handles one ring, not
arbitrary chord connections or several intersecting cycles; split those into
separate panels. See `examples/circular-route.typ`.

=== Step inputs and outputs

In circular layout, put additional material inputs in a step's `reactants`
array and released products in its `products` array. These participants belong
to the transition; they do not become intermediate stages in the cycle.
Each array accepts SMILES strings or `compound(...)` values, including names
and coefficients. Multiple participants share a branch and receive plus signs.

```typst
michem.reaction-step("a", "b",
  above: [Catalyst],
  reactants: (michem.compound("O", name: [Water]),),
  products: (
    michem.compound("[H+]"),
    michem.compound("[Cl-]"),
  ),
)
```

Input arrows point from the outer participant group into the step; output
arrows leave the step and point toward the outer product group. By default,
`branch-curve: "tangent-circle"` uses true quarter-circle arcs externally tangent
to the circular track. The branch center and cycle center are separated by the
sum of their radii, and arrowheads follow the branch tangent.
Set `branch-curve: "bezier"` on `reaction-route` to use cubic Bezier branches
instead. Both modes join the circular track tangentially. For an equilibrium step they
attach to the outer track of the arrow pair. Molecules and names remain upright
and retain the same `font`, `atom-size`, `label-size` and `bond-length` as the
cycle's intermediates.

`reaction-step` also accepts `branch-curve: auto` (inherit the route setting),
`"tangent-circle"` or `"bezier"` to override both material branches for that step.
For example, `reaction-step("a", "b", products: ("O",), branch-curve: "bezier")`
uses a cubic branch even when the rest of the route uses tangent circles.

The layout tries nearby attachment positions and longer branches, then increases
an automatic radius when necessary. It reserves space for the complete molecular
groups, names, conditions and branch paths. `arrow-length` supplies the initial
branch radius for tangent circles, or the minimum radial space for Bezier branches;
`gap`, `compound-gap` and `name-gap` also apply to their
participants. A fixed radius must accommodate all branches, and `max-width`
includes the peripheral groups. Participant arrays currently require circular
layout. Solvents, catalysts and temperatures that are only annotations should
remain in `above` or `below`. All material participation is explicitly supplied,
without inferred stoichiometry or reaction chemistry. See
`examples/circular-branches.typ` for both curve modes.

#example(```typst
#michem.reaction-route(
  michem.reaction-stage("a", "CO"),
  michem.reaction-stage("b", "C=O"),
  michem.reaction-stage("c", "O=CO"),
  layout: "circular", center: [Cycle],
  atom-size: 8pt, bond-length: 15pt,
  steps: (
    michem.reaction-step("a", "b", products: ("O",)),
    michem.reaction-step("b", "c"),
    michem.reaction-step("c", "a"),
  ),
)
```)

`max-width: auto` uses the available line width. A physical length supplies an
explicit total width including padding; `none` allows natural width without wrapping. A stage that
cannot fit returns an error instead of shrinking its molecular labels. Enlarge
the available width or adjust the shared `atom-size` and `bond-length` together.

Spacing controls include `gap: 18pt`, `row-gap: 24pt`, `compound-gap: 8pt`,
`name-gap: 5pt`, `label-gap: 4pt` and `padding: 6pt`. Arrow controls are
`arrow-length: 36pt`, `arrow-width: 0.7pt`, `arrow-color: black` and
`head-size: 4pt`. Measured conditions may increase the gap to keep their text
inside connector lanes. `molecular-style: (:)` and `molecular-layout: (:)` pass
shared depiction and layout options to the chemical renderer; route typography
and bond length take precedence over these dictionaries.

Call `reaction-route-data(..stages, steps: auto, max-width: none, ...)` inside
`context` to inspect stage positions, compound scenes and connector points.
Its width limit applies to the drawing before optional paint padding.
Use `paint-reaction-route(data, padding: 6pt)` to paint the measured result.
`compound-grid` accepts `gutter: 18pt`, `row-gap: 18pt` and `name-gap: 5pt`;
its natural-width columns never rescale their molecular contents. Choose fewer
columns if the gallery does not fit the page.

See `examples/reaction-route.typ` for participant groups, a compound gallery,
branching routes and automatic continuation. These templates compose reaction
schemes; atom-level electron flow remains available through `mechanism` below.
Reaction-flow examples use these route templates for material inputs and outputs.
The organic teaching examples put authored electron-flow details in separate
labeled panels, retaining explicit atom references, new-bond highlights and bridge
crossing overlays. Resonance contributors retain their distinct double-headed
resonance arrows.

= Authored mechanisms

`mechanism(..items, font: none, gap: 24pt, padding: 6pt, label-gap: 4pt)`
composes named molecular occurrences, fragment highlights, electron-flow arrows,
and reaction connectors without requiring CeTZ. See `examples/mechanism.typ`.
It draws the supplied mechanism; it does not predict a reaction.

- `mol(id, input, at: none, offset: (0pt, 0pt), scale: 1, style: (:), layout: (:))`
  creates a unique occurrence. With no `at`, measured bounds follow the selected arrangement.
  Explicit `at` translates the local molecular origin, not the image corner.
- `near(id, side: "south", gap: 18pt, align: "center", atom: none)` can be passed as `at`.
  It places an occurrence outside an earlier occurrence's measured bounds.
  Sides are north, south, east and west; cross-axis alignment is start, center or end.
  Set `atom` to a manual atom name or zero-based SMILES index to position beside
  that atom instead of the full occurrence bounds, for example near an α-H.
- `atom-ref(id, atom, offset: (0, 0))` and `bond-ref(id, a, b, offset: (0, 0))`
  address original input atom names or zero-based SMILES indices. Offsets are
  local SVG pixels and follow the occurrence scale.
- `highlight(id, atoms: (), bonds: (), radius: 4, color: ...)` shades a fragment.
  Bonds are endpoint pairs; one request applies opacity once to its union.
- `electron-arrow(from, to, curve: "arc", arc-angle: 90deg, head: "pair", style: (:), route: "manual", routing: (:))` draws authored
  electron flow. Heads also support `"fishhook-left"` and `"fishhook-right"`.
  Circular arcs are the default. `arc-angle` is the signed central sweep, with
  magnitude 1 to 180 degrees; positive sweeps turn clockwise in y-down coordinates.
  Endpoint trimming follows the same circle and the arrowhead follows its tangent.
  Use `curve: "bezier"` explicitly for `bend: 30` or endpoint-relative `controls`.
  Arc mode ignores `bend` and rejects Bezier controls.
  `route: "auto"` searches clear curves against molecular ink, other fixed arrows,
  prior routed arrows, and measured conditions/notes. The chemical endpoints stay fixed.
- `lone-pair(reference, angle: 0deg, separation: 3, radius: 0.7, color: red,
  id: none, position: "manual", placement: (:))` places an explicitly requested pair.
  `position: "auto"` suggests its visual offset and dot orientation around molecular
  ink, reaction connectors, measured notes and earlier pairs. It does not infer valence
  or how many pairs exist. `pair-ref(molecule, id)` attaches an electron arrow to the
  exact resolved pair position, including automatically selected offsets.
- `reaction-arrow(from, to, equilibrium: false, above: none, below: none, style: (:))`
  adds a reaction connector and arbitrary Typst conditions. Endpoints accept
  coordinates or `edge(id, side: "east", gap: 3pt)` references to measured bounds.
- `mechanism-label(at, body)` adds centered native Typst content.

Coordinates accept physical lengths or SVG pixels, with x right and y down.
Bezier bend and style dimensions are shared SVG pixels; the arrow style accepts
`color`, `width`, `head-length`, `head-width`, and `clearance`. Molecular input
coordinates remain normalized y-up bond units. Reflections and reaction inference
are not performed.

#example(```typst
#michem.mechanism(
  michem.mol("base", "N"),
  michem.mol("proton", "[H+]", at: (85pt, 0pt)),
  michem.lone-pair(michem.atom-ref("base", 0), id: "pair"),
  michem.electron-arrow(
    michem.pair-ref("base", "pair"),
    michem.atom-ref("proton", 0),
    arc-angle: -60deg, route: "auto",
  ),
  font: "Libertinus Serif",
)
```)

== Layout and panels

`mechanism` and `mechanism-data` accept `arrangement: "row"`, `"column"`, or
`"grid"`, with `columns: 2`, `gap: 24pt`, `row-gap: 36pt` and `arrow-space: 0pt`.
Grid cells use the widest measured molecule per column and tallest per row;
`arrow-space` adds space on both sides of each inter-cell gap. Explicit and `near`
placements are outside the automatic grid, so callers remain responsible for their
relationship to automatic cells. Declarations referenced by `near` must appear earlier.

`mechanism-panels(..panels, columns: 2, gutter: 18pt)` arranges independently
rendered mechanism blocks with separate routing domains. Use local reacting-species
panels and separate product/byproduct panels to keep electron arrows local.
See `examples/mechanism-layout.typ` for measured grids, relative placement and
routing around a native Typst label.

== Bounded routing and suggestions

Arrow `routing` settings are `margin` (2), `max-bend` (192), `bend-step` (12),
`max-candidates` (65, at most 129), and `work-budget` (1,000,000).
These dimensions are shared SVG pixels and the bend limits apply to Bezier curves.
Arc routing tries the authored sweep, its reverse and signed sweeps at 30-degree
intervals up to a semicircle. Every arc candidate remains an exact circle.
Bezier routing tries the preferred bend when inside the allowed range, then straight
and progressively larger bends on both sides. Search is conservative, sequential
and limited to one circular arc or cubic curve;
it does not promise to find every possible path or globally rearrange molecules.
Highlights are excluded from collision checks. Atom attachments may consume the
extra spacing around their own labels, but never cross glyph ink. Local contact
with incident bonds is allowed, while the rest of the curve clears ink.
Automatic arrows are resolved after fixed annotations and painted last.

Pair `placement` settings are `preferred-angle` (0deg), `min-distance` (8),
`max-distance` (48), `distance-step` (4), `directions` (16, at most 64),
`margin` (2), `max-candidates` (256, at most 1024), and `work-budget` (1,000,000).
Distances are local SVG pixels and follow molecule scale. The helper tries increasing
radii and directions around the explicitly selected attachment; it conservatively
treats ink envelopes as obstacles. Explicit manual electron arrows are not rerouted
when a pair is suggested. Automatic arrows then account for resolved pairs.

One mechanism shares a ceiling of 16 million search comparisons across automatic
pairs and arrows. A blocked route or exhausted search returns an explicit error;
increase spacing, change placement or adjust search limits. Manual placement and
manual curve parameters preserve the authored geometry. Successful decisions are available in
`scene.routing` and `scene.lone_pairs` from `mechanism-data`.
Its `placements` field contains the measured occurrence envelopes and final
origins for host-side inspection.

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

= CeTZ canvas

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
arrows. Use `reaction-route` for automatic reaction schemes, and CeTZ's line,
bezier, mark, group, and content functions for custom atom annotations. See
`examples/reaction.typ` for a route followed by an independent atom-anchor canvas.

#example(```typst
#cetz.canvas({
  let molecule = michem.cetz.molecule.with(
    style: michem.style(font: "Libertinus Serif"),
  )
  molecule("NCC(=O)O", name: "glycine")
  cetz.draw.line("glycine.atom-0",
    (rel: (0, 1), to: "glycine.atom-0"), stroke: gray + 0.4pt)
  cetz.draw.content((rel: (0, 1.2), to: "glycine.atom-0"), [Amino group])
})
```)

= Architecture

`michem-core` owns the JSON schema and the Chitin adapter. `michem-wasm` exposes
the minimal Typst plugin protocol. The Typst package owns document content and
CeTZ composition. Chemical facts, stereochemistry, layout and depiction remain
in Chitin. Invalid SMILES, incomplete coordinates, unknown options, and
unsupported chemical depictions return errors instead of partial drawings.

== Example catalog

All paths below are relative to the repository root. Each standalone example
imports the local entrypoint. To use the published package, replace the local
package path with `"@preview/michem:0.1.0"`, preserving the example's import alias
or selected names.

#table(
  columns: (auto, 1fr),
  inset: 5pt,
  stroke: 0.4pt + border,
  table.header([*Source*], [*Demonstrates*]),
  [`examples/gallery.typ`],
  [Runnable source and output for the main interfaces.],

  [`examples/reaction-route.typ`],
  [Participant groups, branches, joins and wrapping.],

  [`examples/circular-route.typ`], [Clockwise and counterclockwise cycles.],
  [`examples/circular-branches.typ`],
  [Material inputs, outputs and both branch curves.],

  [`examples/mechanism.typ`], [Highlights, lone pairs and electron flow.],
  [`examples/mechanism-layout.typ`], [Measured placement, grids and panels.],
  [`examples/organic/`],
  [Aldol and deprotonation routes with local electron-flow panels.],

  [`examples/anchors.typ`], [CeTZ atom anchors and transformations.],
  [`examples/fonts.typ`], [Named-font selection and font comparisons.],
)

From a source checkout, `just docs` and `just gallery` build the plugin and
compile this guide and the example gallery. Other standalone examples compile
with `typst compile --root . examples/<name>.typ` after the plugin is built.
