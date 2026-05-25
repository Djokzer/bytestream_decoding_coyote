#import "@preview/structured-mse-thesis:0.1.0": appendix, report-template

#show: report-template.with(
  title: "Portage du Bytestream Decoder sur Coyote",
  author: "Abivarman Kandiah",
  orientation: "Computer Science",
  teacher: "Andres Upegui Posada, Quentin Berthet",
  company: "",
  confidential: false,
)

= Introduction
Reference @reference

#figure(
  raw(
    "Console.log('Hello, world!');
",
    lang: "js",
    block: true,
  ),
  caption: "JavaScript example",
)

= Context (Résumé)

L'idée du projet était la prise en main de Coyote, et le test de celui-ci avec des algorithmes déjà implémenté sous XRT.
Si possible, aussi confirmer le fonctionemenet de celui-ci sur le FPGA V80 qui est nouvellement supporté par Coyote et que nous possedons mais qui était pas
vraiment utilisable car ne supporte pas XRT.

J'ai commencé par faire fonctionné Coyote avec le premier design d'exemple sur la U55C.
Durant celui-ci j'ai pu rencontré certains problèmes. certains ont été fixés, d'autres je pensais l'avoir fix mais en fait au final il n'est toujours pas stable.
En effet, le design se programme bien et le driver semble bien se charger, mais lors de l'execution de l'host, le programme bloque car n'arrive pas à executer le transfert avec le FPGA.

En parralèle, j'ai pu prendre en main en testant le programme qui a été fait par Upegui, qui est le bytestream decoder sous XRT qui est un projet dans le cadre du projet ATLAS.
Après avoir testé le bon fonctionemenet de celui-ci, j'ai pu commencé à porter le design et le code hote pour une utilisation sous coyote.

Entre temps, la V80 était officiellement supporté, donc j'ai pu aussi commencé à tester le design d'exemple sous la V80.
Avec la V80, j'avais rencontré un problème principal, ou je n'arrivais pas à charger correctement le driver.
J'avais un soucis de manque de mémoire pour MSI-X. J'ai pu réglé le problème en ajoutant dans les bootargs, le ``pci=realloc``.

Au final, la V80 marche assez bien sous coyote, j'arrive à reproduire correctement à chaque fois contrairement à la U55C.

Le travail du portage coté design est la réecriture du Wrapper, et le fait que coyote a un bus AXI-S de 512 bits, tandis que le design utilise des 32 bits.

#pagebreak()
#bibliography(full: true, "bibliography.bib", style: "ieee")
#pagebreak()

#show: appendix

= Proofs
#lorem(100)
