#import "../../lib.typ" as michem
#import "support/common.typ": setup
#import "support/aldol-structures.typ": *
#show: setup

= Crossed aldol addition and E1cb dehydration

*Starting materials:* 3-methylbutan-2-one and ethanal (acetaldehyde).
Use LDA in THF at about −78 °C to form the less hindered, methyl-side enolate
of the ketone. Add ethanal, then protonate the alkoxide. Subsequent
base-catalyzed dehydration on warming gives the enone.

#figure(
  align(center, crossed-scheme(
    a-donor,
    aldehyde(),
    a-product(enone: true),
    above: [LDA, THF],
    below: [work-up; heat],
  )),
  caption: [The ketone and aldehyde, and the corresponding enone target.],
)

Pre-forming the ketone enolate avoids relying on an uncontrolled mixture of
two enolizable carbonyl compounds. Its alpha carbon attacks ethanal:

#figure(
  align(center, crossed-addition(
    a-enolate,
    aldehyde(),
    a-product(alkoxide: true),
  )),
  caption: [Aldol addition gives the alkoxide. The new C–C bond is shaded;
    protonation gives the beta-hydroxy ketone.],
)

Under basic conditions, removal of the remaining alpha proton gives the
conjugate base below. Its electron pair makes the C=C bond while the beta
C–O bond breaks: this is the elimination step of an *E1cb* mechanism.

#figure(
  align(center, drawing(
    mol("e", a-product(e1cb: true)),
    mol("p", a-product(enone: true)),
    mol("hydroxide", "[OH-]"),
    michem.electron-arrow(
      michem.atom-ref("e", "a", offset: (-5, 10)),
      michem.bond-ref("e", "a", "b"),
      arc-angle: 90deg,
    ),
    michem.electron-arrow(
      michem.bond-ref("e", "b", "ob"),
      michem.atom-ref("e", "ob", offset: (-8, 0)),
      arc-angle: 90deg,
    ),
    arrow("e", "p", above: [E1cb elimination]),
    plus("p"),
    gap: 64pt,
  )),
  caption: [Elimination gives the enone and releases hydroxide. Together with
    the preceding alpha-deprotonation step, this is dehydration overall.],
)
