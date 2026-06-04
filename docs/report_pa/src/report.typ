#import "mse-thesis-template.typ": appendix, report-template

#show: report-template.with(
  title: "Portage du Bytestream Decoder sur Coyote",
  author: "Abivarman Kandiah",
  orientation: "Computer Science",
  teacher: "Andres Upegui, Quentin Berthet",
  company: "",
  confidential: false,
)

= Context (Résumé Temporaire)

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


// ─────────────────────────────────────────────────────────────────────────────
= Introduction
// ─────────────────────────────────────────────────────────────────────────────

// Contextualiser la problématique centrale : le besoin de frameworks hôte-FPGA
// flexibles et portables, capable de s'adapter à des cartes modernes (V80) là où
// XRT reste limité.
// Présenter Coyote comme alternative prometteuse (shell/role, PCIe natif,
// hugepages, AXI-Stream 512 bits) et l'intérêt de l'évaluer sur un vrai algo.
// Motiver le choix du Bytestream Decoder comme algorithme de référence :
//   - design VHDL existant, déjà validé sous XRT (Upegui)
//   - pipeline de traitement de flux réel avec contraintes de débit
//   - représentatif des cas d'usage dataplane (smartNIC, DAQ temps réel)
// Énoncer les trois objectifs du projet :
//   1. Prendre en main Coyote et le valider sur les cartes disponibles (U55C, V80)
//   2. Porter le Bytestream Decoder de XRT vers Coyote, en évaluer les écarts
//   3. Identifier les forces, limites et perspectives de Coyote sur ce type
//      d'application (accélération PCIe, smartNIC)
// Terminer par le plan du rapport (une phrase par chapitre).
#lorem(80)

#pagebreak()
// ─────────────────────────────────────────────────────────────────────────────
= Contexte technique
// ─────────────────────────────────────────────────────────────────────────────

== Accélération matérielle par FPGA pour le traitement de flux

Les FPGAs sont des matériels utiles à des applications nécessitant des traitements de données à très faible latence, avec des exigences de débit élevées, et une flexibilité d'architecture

Contrairement aux CPUs et aux GPUs, dont l'architecture est figée et le parallélisme borné par le nombre de cœurs ou de threads, un FPGA permet de décrire une architecture sur mesure, dans laquelle chaque étage de traitement s'exécute en parallèle des autres. 
Cette propriété rend les FPGAs particulièrement adaptés au traitement de flux de données en continu.

Deux cartes ont été utilisées dans le cadre de ce projet. 
La première, l'Alveo U55C, est une carte d'accélération basée sur un FPGA UltraScale+; 
La seconde, la V80, est plus récente : 
elle repose sur l'architecture Versal (NoC matériel intégré, AI Engines), expose une interface PCIe Gen5 x8 et embarque également de la HBM @versal-v80. 

#let img1 = figure(
  image("imgs/xilinx_u55c.png", width: 80%),
  caption: [
    Xilinx Alveo U55C, une carte d'accélération basée sur un FPGA UltraScale+.
  ],
)

#let img2 = figure(
  image("imgs/xilinx_v80.png", width: 96%),
  caption: [
    Xilinx Versal V80, une carte d'accélération basée sur un FPGA Versal.
  ],
)

#grid(columns: 2, inset: 0.5em, stroke: none,
  img1,
  img2,
)

== Frameworks de développement hôte-FPGA

Pour faciliter le développement et le déploiement d'applications sur FPGA, ils existent des frameworks nous fournissant un shell qui est une sorte de système d'exploitation
pour FPGA, qui gére les aspects génériques de la communication avec l'hôte (PCIe, DMA, gestion mémoire, etc.) laissant à l'utilisateur la liberté de se concentrer sur la logique applicative. Le shell va généralement permettre à l'utilisateur de charger dynamiquement une application logique sur le FPGA, sans avoir à reprogrammer le FPGA en entier.

Ces frameworks fournissent également une API pour l'hôte, permettant de faciliter les interactions avec le FPGA tel que le chargement de la logique applicative et le transfert de données.

#pagebreak()
=== XRT

*XRT* est le framework officiel d'AMD/Xilinx qui va cibler principalement leurs cartes FPGA @xrt. 
La programmation de la couche logique applicative repose sur des kernels généralement décrits en HLS.
La transition des données entre l'hôte et le FPGA suit un schéma comme celui-ci :

// Image montrant RAM Hote -> DDR/HBM FPGA -> Application logique -> DDR/HBM FPGA -> RAM Hote

XRT bénéficie d'un écosystème mature, intégré à la toolchain Vitis, mais malheureusement ne supporte pas les cartes plus récentes comme la V80.

=== Coyote

*Coyote* est un framework open source développé à l'ETH Zürich @coyote.
La logique applicative y prend la forme d'un ou plusieurs *vFPGAs* (_virtual FPGAs_), qui dialoguent avec le shell via des interfaces AXI-Stream de 512 bits.
Plusieurs vFPGAs peuvent coexister dans le même shell, ce qui permet d'isoler plusieurs applications sur le même FPGA.

Le top-level du vFPGA s'écrit en SystemVerilog, mais la logique applicative en dessous peut être décrite en VHDL, Verilog, SystemVerilog, HLS, ou encore SpinalHDL.

Coyote propose également plusieurs modes de transfert de données entre l'hôte et le FPGA, comme illustré sur le schéma suivant :

// Image reprise de la doc Coyote montrant les différents modes de transfert hôte ↔ FPGA (host memory, card memory, RDMA, etc.)

Le mode de transfert qui va nous intéresser en particulier c'est le mode "Local Read/Write/Transfer" qui va permettre de streamer les données directement entre la mémoire de l'hôte et le vFGPA, sans passer par une mémoire intermédiaire sur la carte.
Enfin, Coyote supporte depuis récemment la V80, ce qui en fait à ce jour l'une des rares options viables pour exploiter cette carte.


== Bytestream Decoder

L'algorithme retenu pour tester Coyote sur un cas concret est le *Bytestream Decoder*, développé pour l'expérience ATLAS au CERN @atlas-lar.
Il sert dans la chaîne de lecture du calorimètre à argon liquide (LAr), en tête du pipeline d'accélération du *Topo-automaton clustering*.

Le flux d'entrée contient, sous forme brute, les données mesurées pour chaque cellule du calorimètre : gain, énergie, temps et qualité.
Le décodeur va lire ce flux et reconstruire à la volée une structure exploitable côté logiciel, appelée *CaloCell container*.

Cette implémentation est intéressante car le décodeur existe déjà sous la forme d'un design VHDL validé sous XRT sur des cartes Alveo @upegui-bsd, ce qui va nous donner un point de comparaison direct avec Coyote.

// Image reprise des slides Upegui : architecture du pipeline (FEB Parser → décodeurs Gain/Energy/Time/Quality + ID LUT → FIFO + Packet Merge)

Le pipeline prend en entrée deux flux : le ByteStream brut (~700 KB) et des données de correction (~7 KB).

En interne, le pipeline travaille sur un bus de 32 bits.
Le module expose donc deux flux AXI-Stream 32 bits en entrée, et produit en sortie quatre mots de 32 bits par cellule : Gain+ID, Energy, Time, Quality.
Cette largeur de 32 bits, héritée de l'implémentation XRT d'origine, va jouer un rôle important dans l'analyse de performance présentée plus loin.


#pagebreak()
// ─────────────────────────────────────────────────────────────────────────────
= Prise en main et évaluation de Coyote
// ─────────────────────────────────────────────────────────────────────────────

// Ce chapitre est indépendant du Bytestream Decoder : il documente l'expérience
// de mise en route de Coyote en tant que framework, avant tout portage applicatif.

== Mise en place de l'environnement

Le flot de développement avec Coyote se base sur CMake et Vivado 2024.2 (pour la V80).
Le design hardware se build via CMake en précisant la carte cible avec `-DFDEV_NAME=u55c` ou `-DFDEV_NAME=v80`.

Le driver noyau se compile à part. Pour la V80, il faut préciser `TARGET_PLATFORM=versal` au `make`, sinon le driver généré ne correspond pas à la carte.

Un cycle de déploiement complet ressemble donc à ça :
+ build du bitstream
+ programmation du FPGA via Vivado
+ remove et rescan du bus PCIe (sinon le device n'est pas redétecté après reprogrammation)
+ chargement du driver Coyote
+ exécution du programme hôte

Pour valider la chaîne, j'ai commencé par l'exemple `01_hello_world` fourni avec Coyote, qui réalise un simple transfert hôte ↔ FPGA. C'est sur cet exemple que la majorité des problèmes de mise en route ont été rencontrés.

== Tests sur U55C — difficultés rencontrées

Deux problèmes principaux sont apparus lors de la mise en route sur l'Alveo U55C.

*Device PCIe non détecté après reprogrammation du FPGA.*
Quand on reprogramme le FPGA, le device PCIe n'est plus directement utilisable côté hôte, ce qui fait planter le programme de test avec une erreur du type `cThread instance could not be obtained`.
Au départ, je ne faisais pas la bonne manipulation pour réinitialiser le bus PCIe. Il faut en réalité forcer un *remove* du device, puis un *rescan* du bus, avant de recharger le driver :

```bash
sudo sh -c "echo 1 > /sys/bus/pci/devices/0000:21:00.0/remove"
sudo sh -c "echo 1 > /sys/bus/pci/rescan"
```

*Programme hôte bloquant pendant le transfert.*
Le design est programmé, le driver se charge sans erreur, mais le programme hôte reste bloqué pendant le transfert.
Initialement, on pensait que le problème venait de l'IOMMU qui n'était pas en mode passthrough. Ajouter `amd_iommu=on iommu=pt` dans les bootargs GRUB semblait fixer le souci au début, mais au final non : le comportement est resté instable.

Dans certains cas, même avec le bitstream et le driver chargés correctement, le programme hôte se bloque toujours sur le transfert.
Une analyse avec l'ILA montre que le signal `tvalid` de l'interface réceptrice ne passe jamais à 1, donc le transfert ne démarre pas du tout côté FPGA.
La cause exacte n'a pas pu être identifiée dans le temps imparti.

Au final, la U55C n'est pas fiable pour faire des mesures reproductibles, ce qui nous a poussé à utiliser la V80 comme plateforme principale.

#pagebreak()
== Tests sur V80 — difficultés rencontrées

La V80 venait d'être officiellement supportée par Coyote au moment du projet, donc valider ce support faisait partie des objectifs.

Le problème principal rencontré était au chargement du driver, avec une erreur liée au MSI-X.
La carte expose un grand nombre de vecteurs d'interruption, et le BIOS ne réserve pas assez de mémoire PCI pour les allouer.
Le fix consiste à ajouter `pci=realloc=on` dans les bootargs GRUB pour forcer le kernel à réallouer les ressources PCI au boot.

Une fois ce problème réglé, la V80 fonctionne de manière stable et reproductible. À noter cependant qu'à chaque reprogrammation de la V80 via Vivado, il peut être nécessaire de redémarrer la machine hôte pour forcer une réallocation propre du PCI au boot, sinon on peut rencontrer à nouveau cette erreur.

C'est cette carte qui a servi de plateforme pour toutes les mesures de performance présentées plus loin.

#pagebreak()
// ─────────────────────────────────────────────────────────────────────────────
= Portage du Bytestream Decoder sur Coyote
// ─────────────────────────────────────────────────────────────────────────────

Le portage du Bytestream Decoder de XRT vers Coyote consiste à refaire le wrapper au format attendu par Coyote, et réécrire le code hôte autour de l'API Coyote.
Le coeur VHDL du décodeur, lui, reste identique à la version XRT d'origine.

== Adaptation du wrapper hardware (Design 1)

Le shell Coyote expose un bus AXI-Stream de 512 bits côté vFPGA, alors que le Bytestream Decoder travaille en interne sur des mots de 32 bits.
Le rôle du wrapper, écrit en SystemVerilog dans `vfpga_top.svh`, est donc d'instancier le module VHDL et de connecter ses ports 32 bits aux bits de poids faible de chaque interface AXI-Stream.

Concrètement :
- En entrée, seuls les bits `[31:0]` des flux `axis_host_recv[0]` (données brutes) et `axis_host_recv[1]` (corrections initiales) sont connectés au décodeur.
- En sortie, les bits `[31:0]` du flux `axis_host_send[0]` portent un mot de sortie par cycle.
- Les 480 bits restants de chaque bus ne sont pas utilisés. Le bus est donc sous-utilisé d'un facteur 16, ce qui est volontaire pour ce premier design.

Le wrapper instancie aussi une ILA décrit via le script `init_ip.tcl`, avec des sondes sur les signaux axi-stream des interfaces d'entrée et de sortie. Cela va permettre de mesurer les duty cycles côté FPGA et d'identifier les goulots dans l'analyse de performance présentée plus loin.

== Adaptation du code hôte

Le code hôte a été entièrement réécrit autour de l'API Coyote, à la place du modèle `xclbin` + buffers de XRT.

Le programme commence par charger les deux fichiers d'entrée :
- `Uncompressed_data_LAR_only.raw` : 174 736 mots de 32 bits (données brutes du bytestream)
- `initial_correction_values.bin` : 1 833 mots de 32 bits (valeurs de correction)

Coyote travaillant sur des blocs de 512 bits, chaque mot 32 bits est placé dans les bits de poids faible d'un bloc de 64 octets, les 60 octets restants étant remplis de zéros.

Les données sont ensuite envoyées au FPGA via deux flux distincts :
- Stream 0 : les données brutes du bytestream
- Stream 1 : les valeurs de correction, envoyées une seule fois en début d'exécution

Le transfert principal est déclenché par deux appels à `coyote_thread.invoke()` : un `LOCAL_READ` pour pousser les données brutes vers le FPGA, et un `LOCAL_WRITE` pour récupérer la sortie. Le programme attend ensuite la complétion des deux opérations.

Côté sortie, chaque CaloCell occupe quatre blocs de 512 bits successifs, à raison d'un mot 32 bits par bloc : Gain+ID, Energy, Time, puis Quality. L'unpacking parcourt donc le buffer de sortie quatre blocs à la fois pour reconstruire chaque cellule.

#pagebreak()
== Design 2 — sortie 128 bits

La sortie du décodeur, une cellule *CaloCell*, est constituée de 4 mots de 32 bits.
Dans le Design 1, ces 4 mots sont émis un par un par l'`Output_Merger_32`, ce qui demande 4 blocs de 512 bits sur le bus AXI-Stream pour transférer en réalité seulement 128 bits utiles.

L'idée du Design 2 est de les regrouper en un seul mot de 128 bits, et de les envoyer directement dans un seul bloc de 512 bits. On passe ainsi de 4 blocs à 1 bloc par cellule, soit un facteur ×4 sur la bande passante utile en sortie.

À noter que la variante 128 bits du merger (`Output_Merger_128`) était déjà présente dans le code source VHDL, mais c'est la variante 32 bits (`Output_Merger_32`) qui était utilisée pour le portage sous XRT. Les deux versions cohabitent donc dans `Byte_Stream_Decoder_parallel.vhd`, et il a suffi de swapper l'instanciation pour activer la variante 128 bits.

Côté wrapper, le changement se résume à connecter les bits `[127:0]` du flux de sortie au lieu des bits `[31:0]`. Les 384 bits restants du bloc ne sont toujours pas utilisés, mais le ratio passe de 1/16 à 4/16.

Côté hôte, l'unpacking est ajusté pour lire une cellule complète par bloc, en extrayant les 4 champs (Gain+ID, Energy, Time, Quality) dans les 16 octets de poids faible.

Le reste de la chaîne reste strictement identique au Design 1.

#pagebreak()
// ─────────────────────────────────────────────────────────────────────────────
= Analyse des performances et optimisation
// ─────────────────────────────────────────────────────────────────────────────

== Méthodologie de mesure (ILA)

Pour analyser le comportement du pipeline côté FPGA, une IP ILA (_Integrated Logic Analyzer_) a été instanciée dans le wrapper du vFPGA. Elle sonde les signaux `tvalid`, `tready`, `tlast` et `tdata` des interfaces AXI-Stream d'entrée (`axis_host_recv[0]`) et de sortie (`axis_host_send[0]`).

L'ILA est configurée pour déclencher sur le `tvalid` de l'interface de réception et capturer 512 échantillons post-trigger, ce qui couvre une fenêtre représentative du transfert.

Deux ratios sont particulièrement intéressants à observer :
- *tready entrée* : indique la proportion de cycles pendant lesquels le FPGA est prêt à consommer une donnée. S'il est faible, c'est que le pipeline interne ne peut pas suivre, et le goulot est en aval.
- *tvalid sortie* : indique la proportion de cycles pendant lesquels le FPGA a une donnée à émettre. S'il est élevé, c'est que le pipeline produit sans blocage.

Le `tvalid` côté entrée et le `tready` côté sortie sont eux quasiment toujours à 1 dans nos mesures : l'hôte Coyote a toujours des données prêtes à envoyer, et toujours assez de place pour absorber la sortie.

== Design 1 — diagnostic du goulot

Le Design 1 a été synthétisé à 250 MHz avec la sortie 32 bits héritée du portage XRT. Le temps total mesuré côté hôte pour le transfert principal est de 3.17 ms.

Pour comprendre où se situe le goulot, on regarde les 4 signaux de handshake AXI-Stream côté FPGA (@fig-ila-design1) :

#figure(
  image("imgs/ila_design1_signals.svg", width: 95%),
  caption: [Capture ILA des quatre signaux de handshake AXI-Stream du Design 1, à 250 MHz, sur 120 cycles post-trigger. Le `tready` de l'entrée est le seul signal qui pulse ; les trois autres restent collés à 1 sur toute la fenêtre.],
) <fig-ila-design1>

Sur la fenêtre complète de 512 échantillons capturés, le `tvalid` de l'entrée et les `tvalid` / `tready` de la sortie sont à 100 %. Seul le `tready` de l'entrée descend, à 20.9 %.

L'interprétation est directe. L'hôte a toujours des données à envoyer (`tvalid` entrée à 1), le FPGA a toujours une donnée à émettre (`tvalid` sortie à 1), et l'hôte est toujours prêt à recevoir (`tready` sortie à 1). Le seul facteur limitant est donc le FPGA qui ne peut absorber l'entrée que pendant environ un cinquième du temps. Le goulot est clairement en aval, plus loin dans le pipeline.

Cela correspond bien à ce qu'on attendait : la sortie émet un mot 32 bits par cycle, alors qu'une cellule complète en compte quatre. Le merger met donc 4 cycles pour évacuer une cellule, pendant lesquels les étages amont sont gelés.

== Design 2 — gain de performance

Avec l'`Output_Merger_128`, à la même fréquence de 250 MHz, le temps de transfert mesuré côté hôte chute de 3.17 ms à 0.83 ms, soit un gain d'un facteur ×3.8.

Côté ILA, les ratios deviennent : `tready` entrée à 88.7 % et `tvalid` sortie à 99.4 %. Le pipeline consomme maintenant l'entrée la quasi-totalité du temps, ce qui valide le diagnostic posé sur le Design 1.

La figure @fig-ila-comparison illustre visuellement cette différence de comportement entre les deux designs sur le signal `tready` de l'entrée.

#figure(
  image("imgs/ila_tready_comparison.svg", width: 95%),
  caption: [Capture ILA du signal `tready` de l'AXI-Stream d'entrée sur le Design 1 (haut) et le Design 2 (bas), à 250 MHz. Sur le Design 1, le signal pulse périodiquement (un cycle haut sur quatre) ; sur le Design 2, il reste à 1 la quasi-totalité du temps. La fenêtre affichée couvre 120 cycles post-trigger ; les ratios cités dans le texte (20.9 % / 88.7 %) sont calculés sur la fenêtre complète de 512 échantillons.],
) <fig-ila-comparison>

== Montée en fréquence à 400 MHz

Une fois le goulot de sortie levé, la question se pose de savoir si monter la fréquence du pipeline permet de gagner encore en débit. Le Design 2 a donc été resynthétisé à 400 MHz, en paramétrant la fréquence cible côté CMake.

Le temps de transfert tombe à 0.82 ms, soit un gain marginal d'environ 1 % par rapport au Design 2 à 250 MHz.

Côté ILA, les ratios sont eux aussi très proches du cas 250 MHz : `tready` entrée à 90.0 % et `tvalid` sortie à 99.4 %. Cela signifie que le pipeline FPGA n'est plus le facteur limitant. Le goulot restant est ailleurs : soit dans le transfert PCIe lui-même, soit dans la sous-utilisation persistante du bus d'entrée (toujours 1 mot 32 bits par bloc de 512 bits, soit 1/16). Monter la fréquence ne change rien à ces deux facteurs.

== Comparaison avec XRT

Pour situer ces résultats par rapport au point de départ, on peut les comparer à l'implémentation XRT d'origine du Bytestream Decoder, qui tournait sur une carte VCK5000 à 350 MHz avec une sortie 32 bits.

Sur cette implémentation, le programme hôte rapporte les temps suivants :
- écriture des données vers la DDR de la carte : 0.26 ms
- écriture des paramètres de correction : 0.28 ms
- temps total du kernel : 2.94 ms
- lecture des résultats depuis la DDR : 0.59 ms
- temps total bout-en-bout : 4.12 ms

Deux différences importantes sont à garder à l'esprit pour interpréter cette comparaison.

D'une part, les cartes ne sont pas les mêmes. Une partie des écarts de performance peut donc venir du matériel et non du framework.

D'autre part, le modèle de transfert n'est pas le même. Sous XRT, les données doivent transiter par la mémoire DDR/HBM de la carte avant d'être consommées par le kernel, et la sortie suit le chemin inverse. Coyote permet à l'inverse de streamer directement la mémoire hôte vers le vFPGA, ce qui évite les deux étapes d'écriture et de lecture en mémoire embarquée. C'est précisément le mode "Local Read/Write" mentionné dans le contexte technique.

À design équivalent (sortie 32 bits, fréquence comparable), le temps total bout-en-bout est dans le même ordre de grandeur : 4.12 ms sous XRT contre 3.17 ms pour le Design 1 sous Coyote. La différence vient principalement de l'élimination des copies DDR. Une fois le Design 2 introduit, l'écart se creuse nettement : 0.83 ms sous Coyote, soit environ ×5 par rapport à XRT.

== Tableau comparatif et bilan

Le tableau @tab-perf-comparison récapitule les configurations testées et leur point de comparaison XRT.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: center,
    table.header(
      [*Framework*], [*Carte*], [*Fréquence*], [*Sortie*], [*Temps total*], [*tready entrée*],
    ),
    [XRT],     [VCK5000], [350 MHz], [32 bits],  [4.12 ms], [—],
    [Coyote (Design 1)], [V80], [250 MHz], [32 bits],  [3.17 ms], [20.9 %],
    [Coyote (Design 2)], [V80], [250 MHz], [128 bits], [0.83 ms], [88.7 %],
    [Coyote (Design 2)], [V80], [400 MHz], [128 bits], [0.82 ms], [90.0 %],
  ),
  caption: [Comparaison des performances de l'implémentation XRT d'origine et des configurations Coyote testées sur V80.],
) <tab-perf-comparison>

Trois conclusions ressortent de cette analyse.

D'abord, à design équivalent (sortie 32 bits), Coyote est déjà légèrement plus rapide que XRT bout-en-bout, principalement grâce au streaming direct mémoire hôte ↔ vFPGA qui évite les copies DDR.

Ensuite, l'optimisation décisive vient de l'alignement entre la largeur de sortie du pipeline et celle du bus Coyote, pas de la fréquence. Passer de l'`Output_Merger_32` à l'`Output_Merger_128` apporte un facteur ×3.8 sur le temps de transfert, alors que doubler la fréquence n'apporte qu'environ 1 % supplémentaire.

La prochaine optimisation naturelle serait d'élargir aussi le bus d'entrée, qui n'utilise actuellement qu'un mot 32 bits sur 512 disponibles par bloc.


// ─────────────────────────────────────────────────────────────────────────────
= Conclusion
// ─────────────────────────────────────────────────────────────────────────────

L'objectif principal de ce projet était d'évaluer Coyote comme alternative à XRT, sur un cas d'usage concret, et de valider son support sur la V80 récemment ajouté. Sur les trois axes annoncés en introduction, le bilan est globalement positif.

D'abord, la *prise en main de Coyote* a été menée sur les deux cartes à disposition. La V80 fonctionne de manière stable et reproductible une fois le fix `pci=realloc=on` appliqué dans les bootargs GRUB, ce qui constitue une première validation pratique du support récent de cette carte par le framework. La U55C, en revanche, est restée instable : le bitstream se programme, le driver se charge, mais le `tvalid` de l'AXI-Stream d'entrée ne démarre jamais dans certains cas, sans cause identifiée dans le temps imparti.

Ensuite, le *portage du Bytestream Decoder* a abouti sans toucher au cœur VHDL du décodeur. L'essentiel du travail d'adaptation tient dans le wrapper SystemVerilog et dans la réécriture du code hôte autour de l'API Coyote. Une variante Design 2 a aussi été produite en élargissant la sortie de 32 à 128 bits, via le merger déjà présent dans le code VHDL d'origine. Cette modification, minime côté hardware, a apporté un facteur ×3.8 sur le temps de transfert.

Enfin, la *comparaison avec XRT* montre que Coyote est viable à design équivalent, et bénéficie en plus du streaming direct mémoire hôte ↔ vFPGA, qui évite les copies DDR imposées par XRT. Sur la V80 en particulier, c'est aujourd'hui l'une des seules options exploitables, vu que XRT ne supporte pas cette carte.

Plusieurs *difficultés* sont à signaler. Le problème MSI-X au chargement du driver V80 a demandé un fix dans les bootargs GRUB, et la reprogrammation de la carte peut encore exiger un redémarrage de la machine hôte pour que les ressources PCI soient réallouées proprement. Côté U55C, l'instabilité au démarrage des transferts reste sans explication satisfaisante : malgré plusieurs hypothèses testées (driver, IOMMU, rescan PCIe), le `tvalid` d'entrée ne démarre toujours pas dans certains cas, et la cause n'a pas pu être isolée dans le temps imparti.

Plusieurs *pistes* d'amélioration ressortent enfin des mesures. La plus directe serait d'élargir aussi le bus d'entrée : actuellement un seul mot de 32 bits sur 512 est utilisé par bloc, soit un ratio 1/16. Packer 16 mots par bloc devrait théoriquement multiplier d'autant le débit d'ingestion, à condition que le pipeline interne du décodeur puisse suivre. Au-delà, traiter plusieurs événements en parallèle dans un même shell Coyote, en exploitant le support multi-vFPGA, constituerait un prolongement naturel.

Une piste plus ambitieuse, et plus en phase avec l'esprit de Coyote, serait d'exploiter le scénario *smartNIC*. Actuellement, le Bytestream Decoder et l'ensemble du pipeline qui le suit tournent sur GPU, et les données détecteur transitent par une carte réseau classique avant d'être copiées vers le GPU. Un FPGA Coyote installé en lieu et place de la carte réseau pourrait ingérer directement le flux du détecteur, exécuter le Bytestream Decoder à la volée, et transférer ensuite le `CaloCell container` directement dans la mémoire du GPU, sans repasser par le CPU hôte. Ce type de déploiement correspond exactement aux cas d'usage dataplane visés par Coyote.


// ─────────────────────────────────────────────────────────────────────────────
// Bibliographie & Annexes
// ─────────────────────────────────────────────────────────────────────────────

#pagebreak()
#bibliography(full: true, "bibliography.bib", style: "ieee")
#pagebreak()

#show: appendix

= Dépôts de code

Le code complet du portage sous Coyote est disponible sur GitHub :

#link("https://github.com/Djokzer/coyote_pa")[`https://github.com/Djokzer/coyote_pa`]

Le design XRT d'origine du Bytestream Decoder, développé par Andres Upegui, est disponible sur le GitLab du CERN :

#link("https://gitlab.cern.ch/aupeguip/ATLAS_ByteStreamDecoding_FPGA")[`https://gitlab.cern.ch/aupeguip/ATLAS_ByteStreamDecoding_FPGA`]
