#import "../../lib.typ" as michem
#import "support/common.typ": setup
#import "support/aldol-structures.typ": *
#show: setup

= Crossed aldol: an exocyclic conjugated enone

*Starting materials:* cyclohexanone and propanal.
Pre-form the cyclohexanone enolate with LDA in THF at about −78 °C, add
propanal, and protonate the resulting alkoxide. Warm under suitable
acid- or base-catalyzed dehydration conditions to obtain the enone.

#figure(
  align(center, crossed-scheme(
    c-stage(),
    aldehyde(ethyl: true),
    c-stage(addition: true, enone: true),
    above: [LDA, THF],
    below: [work-up; heat],
  )),
  caption: [Cyclohexanone and propanal give the exocyclic enone target.],
)

The ring alpha carbon forms a bond to propanal's carbonyl carbon. This carbon
becomes the carbon outside the ring and retains its ethyl group:

#figure(
  align(center, crossed-addition(
    c-stage(enolate: true),
    aldehyde(ethyl: true),
    c-stage(addition: true, alkoxide: true),
  )),
  caption: [Crossed aldol addition gives the alkoxide, with its new C–C bond
    shaded. Protonation gives the beta-hydroxy ketone.],
)

#figure(
  align(center, scheme(
    c-stage(addition: true),
    c-stage(addition: true, enone: true),
    above: [base, heat],
    below: [−water; E1cb elimination],
  )),
  caption: [Dehydration forms the exocyclic conjugated C=C bond.],
)

Both starting compounds have alpha hydrogens. Simply mixing them with
hydroxide can give competing self-aldol reactions; controlled enolate
formation is the more explicit synthesis answer.
