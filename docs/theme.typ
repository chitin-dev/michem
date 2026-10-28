// Shared presentation for the release guide and runnable examples.
#import "../lib.typ" as michem
#import "@preview/cetz:0.5.2" as cetz

#let version = toml("../typst.toml").package.version
#let accent = rgb("#237b86")
#let soft = rgb("#edf5f5")
#let border = rgb("#d7e1e2")

// Evaluate exactly the source printed in the card to keep examples reproducible.
#let example(source, side: false) = block(
  width: 100%,
  breakable: false,
  stroke: 0.5pt + border,
  radius: 3pt,
  above: 10pt,
  below: 12pt,
  {
    let code = block(width: 100%, fill: rgb("#f5f7f7"), inset: 10pt, source)
    let output = block(width: 100%, inset: 14pt, align(center, eval(
      source.text,
      mode: "markup",
      scope: (michem: michem, cetz: cetz),
    )))
    if side {
      grid(
        columns: (1fr, 1fr),
        code, output,
      )
    } else {
      code
      output
    }
  },
)

#let typography(body) = {
  set text(font: "Libertinus Serif", size: 10pt, lang: "en")
  set par(leading: 0.6em, spacing: 0.9em)
  show raw: set text(font: "Cascadia Code", size: 8pt)
  show raw.where(block: true): set block(breakable: false)
  show link: set text(fill: accent)
  show heading: set text(fill: accent)
  body
}

#let example-page(body) = {
  set document(title: "Michem " + version + " examples")
  set page(
    paper: "a4",
    margin: 2cm,
    header: text(size: 8pt, fill: gray)[Michem #version · Examples],
    footer: context align(center, text(
      size: 8pt,
      fill: gray,
      counter(page).display(),
    )),
  )
  typography(body)
}

#let manual(body) = {
  set document(title: "Michem " + version + " User Guide")
  set page(paper: "a4", margin: (x: 2cm, top: 2.1cm, bottom: 2cm))
  show: typography
  set heading(numbering: "1.1")
  show heading.where(level: 1): it => {
    block(width: 100%, sticky: true, above: 20pt, below: 12pt, {
      text(size: 19pt, weight: "bold", fill: accent)[
        #if it.numbering != none [#counter(heading).display() #h(
            0.4em,
          )] #it.body
      ]
      v(3pt)
      line(length: 100%, stroke: 0.6pt + accent)
    })
  }
  v(1fr)
  align(center)[
    #text(size: 46pt, weight: "bold", fill: accent)[Michem]
    #v(6pt)
    #text(size: 17pt)[Chemical structures and reaction diagrams in Typst]
    #v(12pt)
    #text(size: 13pt)[User Guide · Version #version]
    #v(28pt)
    #block(fill: soft, inset: 22pt, radius: 5pt, michem.compound-grid(
      michem.compound("CC(=O)Oc1ccccc1C(=O)O", name: [Aspirin]),
      michem.compound("Cn1c(=O)c2c(ncn2C)n(C)c1=O", name: [Caffeine]),
      columns: 2,
      gutter: 28pt,
    ))
    #v(24pt)
    SMILES · Authored structures · Reaction routes · Electron flow · CeTZ
  ]
  v(1fr)
  pagebreak()
  counter(page).update(1)
  set page(
    header: [
      #set text(size: 8pt, fill: gray)
      #grid(
        columns: (1fr, auto),
        [Michem · User Guide], [v#version],
      )
      #v(2pt)
      #line(length: 100%, stroke: 0.4pt + border)
    ],
    footer: context align(center, text(
      size: 8pt,
      fill: gray,
      counter(page).display(),
    )),
  )
  outline(title: [Contents], depth: 2, indent: 12pt)
  pagebreak()
  body
}
