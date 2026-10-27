#import "../../lib.typ" as michem
#import "support/common.typ": setup
#import "support/aldol-structures.typ": *
#show: setup

= Intramolecular aldol: a bridged addition product

*Starting material:* *4-acetyl-4-methylcyclohexanone*.
Use a base such as dilute aqueous NaOH in an aqueous alcoholic solvent to
promote intramolecular aldol addition, followed by protonation.
The methyl end of the acetyl group supplies the enolate donor; the ring
ketone supplies the electrophilic carbonyl.

#figure(
  align(center, drawing(
    mol("s", d-stage()),
    mol("p", d-stage(cyclic: true)),
    arrow("s", "p", above: [dilute NaOH], below: [aqueous ethanol]),
    michem.highlight("p", bonds: (("a", "b"),)),
    gap: 125pt,
    crossings: ("p",),
  )),
  caption: [4-Acetyl-4-methylcyclohexanone gives
    4-hydroxy-1-methylbicyclo[2.2.2]octan-2-one.
    The shaded C–C bond closes the bridge.],
)

The bridgeheads are connected by three separate paths, each containing two
carbon atoms: this is the meaning of *[2.2.2]*. There is no direct bond between
the methyl-bearing bridgehead and the OH-bearing bridgehead.

#figure(
  align(center, cyclic-addition(
    d-stage(enolate: true),
    d-stage(cyclic: true, alkoxide: true),
    arc-angle: 120deg,
    oxygen-arrow: (arc-angle: 90deg, arc-path: "major"),
    crossings: ("p",),
  )),
  caption: [The acetyl-side enolate attacks the ring carbonyl, giving the
    bridged alkoxide. The side-chain ketone remains a ketone.],
)

#figure(
  align(center, scheme(
    d-stage(cyclic: true, alkoxide: true),
    d-stage(cyclic: true),
    above: [water: proton transfer],
    below: [hydroxide regenerated],
    crossings: ("s", "p"),
  )),
  caption: [Protonation of the alkoxide gives the requested beta-hydroxy ketone.],
)

*Why retain OH?* A conventional dehydration would place a C=C bond at the
OH-bearing bridgehead. The geometry of this small bridged skeleton strongly
disfavors that bridgehead alkene (Bredt's rule). The target is the aldol
*addition* product.

*Retrosynthetic check:* break the shaded bond, and restore C=O at the
OH-bearing bridgehead. The opened structure is exactly
4-acetyl-4-methylcyclohexanone.
