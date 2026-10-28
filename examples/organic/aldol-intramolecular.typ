#import "../../lib.typ" as michem
#import "support/common.typ": route, setup
#import "support/aldol-structures.typ": *
#show: setup

= Intramolecular aldol: six-membered ring closure

*Starting material:* *5-oxoheptanal*,
$"OHC"("CH"_2)_3"C"(= "O")"CH"_2"CH"_3$.
Treat it with dilute aqueous NaOH in ethanol, then warm to promote aldol
condensation. The ethyl-side alpha carbon of the ketone attacks the terminal
aldehyde carbonyl, closing a six-membered ring.

The methyl group is already present at the end of the ketone's ethyl group;
it becomes the methyl substituent on the enone's alpha carbon.

#figure(
  align(center, route(
    michem.reaction-stage("s", michem.compound(b-stage())),
    michem.reaction-stage("alcohol", michem.compound(b-stage(cyclic: true))),
    michem.reaction-stage(
      "p",
      michem.compound(b-stage(cyclic: true, enone: true)),
      michem.compound("O"),
    ),
    steps: (
      michem.reaction-step(
        "s",
        "alcohol",
        above: [dilute NaOH],
        below: [ethanol/water],
      ),
      michem.reaction-step("alcohol", "p", above: [base, warming]),
    ),
  )),
  caption: [The starting ketoaldehyde is folded to show the missing ring bond.
    Addition and protonation give the beta-hydroxy ketone; dehydration gives the enone.],
)

After alpha-deprotonation, the carbon-centered ketone enolate closes the ring.
The aldehyde oxygen becomes an alkoxide:

#figure(
  align(center, cyclic-addition(
    b-stage(enolate: true),
    b-stage(cyclic: true, alkoxide: true),
    arc-angle: 120deg,
  )),
  caption: [The curved arrows form the shaded C–C bond and convert the
    aldehyde C=O bond to the cyclic alkoxide. Water then protonates oxygen.],
)

The favored closure makes a six-membered ring. Forming the enolate on the
other side of the ketone would require a strained four-membered closure.
Following protonation, dehydration proceeds by the alpha-deprotonation
and E1cb elimination shown in the crossed-aldol example.

*Retrosynthetic check:* disconnect the target's alpha–beta C=C bond and
restore the beta carbon to an aldehyde. Tracing the remaining chain gives
5-oxoheptanal. Check that the methyl substituent remains on the alpha carbon
of the cyclic enone.
