#import "mse-thesis-template.typ": appendix, report-template

#show: report-template.with(
  title: "Portage du Bytestream Decoder sur Coyote",
  author: "Abivarman Kandiah",
  orientation: "Computer Science",
  teacher: "Andres Upegui Posada, Quentin Berthet",
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

=== XRT

*XRT* est le framework officiel d'AMD/Xilinx qui va cibler principalement leurs cartes FPGA @xrt. 
La programmation de la couche logique applicative repose sur des kernels généralement décrits en HLS.
La transition des données entre l'hôte et le FPGA suit un schéma comme celui-ci :

// Image montrant RAM Hote -> DDR/HBM FPGA -> Application logique -> DDR/HBM FPGA -> RAM Hote

XRT bénéficie d'un écosystème mature, intégré à la toolchain Vitis, mais malheureusement ne supporte pas les cartes plus récentes comme la V80.

=== Coyote

*Coyote* est un framework open source développé à l'ETH Zürich qui adopte une
approche radicalement différente @coyote. L'idée centrale est une séparation
stricte _shell/role_ : le _shell_ regroupe toute l'infrastructure générique
(contrôleur PCIe, DMA, gestion mémoire, interruptions, hugepages, support
multi-locataire et RDMA optionnel) et est livré pré-implémenté ; le _role_
correspond à la logique applicative écrite par l'utilisateur, qui dialogue avec
le shell via une ou plusieurs interfaces AXI-Stream de 512 bits. Le driver
noyau associé est générique et rechargeable sans reflasher le FPGA. Cette
architecture cible explicitement les déploiements _dataplane_ et _smartNIC_, et
le support de cartes récentes — notamment la V80 — y est ajouté plus rapidement
que dans XRT. En contrepartie, la documentation est plus parcellaire et la
maturité de l'outil reste inférieure à celle de XRT.

Le tableau @tab-xrt-coyote synthétise les principales différences.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    table.header([], [*XRT*], [*Coyote*]),
    [Modèle], [Offload batch], [Pipeline shell/role],
    [Interface vers le _role_], [Buffers + kernels], [AXI-Stream 512 bits],
    [Support V80], [Non], [Oui],
    [Toolchain requise], [Vitis], [Vivado seul],
    [Maturité], [Élevée], [En cours],
    [Cible privilégiée], [Calcul accéléré], [Dataplane / smartNIC],
  ),
  caption: [Comparaison synthétique de XRT et Coyote.],
) <tab-xrt-coyote>

== Le _Bytestream Decoder_ comme algorithme de référence

L'algorithme retenu pour évaluer Coyote sur un cas réaliste est le _Bytestream
Decoder_, un décodeur initialement développé dans le cadre de l'expérience ATLAS
au CERN, plus précisément pour la chaîne de lecture du calorimètre à argon
liquide (LAr) @atlas-lar. Sans entrer dans la physique sous-jacente, il suffit
de retenir que les cartes _Front-End Boards_ (FEB) du détecteur émettent à
chaque collision un flux compressé décrivant l'énergie déposée dans chaque
cellule du calorimètre ; le décodeur reconstruit, à la volée, une représentation
structurée de ces cellules.

Ce choix est doublement pertinent. D'une part, l'algorithme constitue un cas
d'usage représentatif d'une large famille de traitements _dataplane_ :
décompression et parsing à la volée, consultation de tables (LUT), correction
en arithmétique flottante, fusion de plusieurs flux d'entrée. D'autre part, le
décodeur existe déjà sous la forme d'un design VHDL validé sous XRT @upegui-bsd
sur Alveo U55C, ce qui en fait un point de comparaison idéal pour mesurer le
coût et les bénéfices d'un portage vers Coyote.

Le pipeline VHDL s'organise en plusieurs étages successifs. Un _FEB Parser_
extrait les en-têtes et les champs utiles du flux brut, puis des décodeurs
spécialisés reconstituent le gain, l'énergie et le temps de chaque cellule. Une
table CAM associée à une LUT hachée fournit les coefficients de correction, qui
sont appliqués par une unité flottante (FPU) avant qu'un _Output Merger_ ne
sérialise le résultat dans une FIFO de sortie. En interne, le bus est large de
32 bits ; le module expose deux flux AXI-Stream en entrée (données brutes et
corrections initiales) et produit en sortie une structure de quatre mots de 32
bits par cellule (_Gain+ID_, _Energy_, _Time_, _Quality_). Cette largeur de 32
bits, héritée du contexte XRT, jouera un rôle central dans l'analyse de
performance présentée au chapitre 5.


// ─────────────────────────────────────────────────────────────────────────────
= Prise en main et évaluation de Coyote
// ─────────────────────────────────────────────────────────────────────────────

// Ce chapitre est indépendant du Bytestream Decoder : il documente l'expérience
// de mise en route de Coyote en tant que framework, avant tout portage applicatif.

== Mise en place de l'environnement

// Build hardware : CMake + Vivado 2024.2, flags -DFDEV_NAME=u55c / v80
// Compilation du driver kernel (TARGET_PLATFORM=versal pour V80)
// Cycle de déploiement : synthèse/impl → bitstream → programmation FPGA →
//   rescan PCIe → chargement driver → test hôte
// Exemple de référence utilisé : 01_hello_world (transfert simple hôte↔FPGA)
#lorem(40)

== Tests sur U55C — difficultés rencontrées

// Problème 1 : "Invalid module format" au chargement du driver
//   → cause : driver compilé pour une version de kernel différente
//   → solution : recompiler le driver avec les headers du kernel courant
// Problème 2 : programme hôte bloquant (transfert ne se termine jamais)
//   → cause : IOMMU non activé en mode pass-through
//   → solution partielle : amd_iommu=on iommu=pt dans les bootargs
//   → instabilité résiduelle : le problème n'est pas totalement résolu sur U55C
// Bilan U55C : comportement non déterministe, difficile à utiliser pour des
// mesures reproductibles
#lorem(60)

== Tests sur V80 — stabilisation

// Contexte : la V80 vient d'être officiellement supportée dans Coyote au
// moment du projet → validation de ce support était un objectif secondaire
// Problème principal : échec de chargement du driver (MSI-X, manque de mémoire
// PCI lors de l'allocation des vecteurs d'interruption)
//   → solution : ajouter pci=realloc dans les bootargs GRUB
// Résultat : comportement stable et reproductible à chaque cycle de test
// Bilan V80 : carte retenue comme plateforme principale pour les mesures
#lorem(60)

== Retour d'expérience sur Coyote comme framework

// Ce que Coyote apporte par rapport à XRT du point de vue du développeur :
//   - modèle shell/role clair, pas de dépendance à Vitis
//   - driver kernel générique, rechargeable sans reflasher le FPGA
//   - API hôte C++ (cThread, cBench) relativement simple pour les flux
// Ce qui complexifie la prise en main :
//   - documentation moins fournie que XRT/Vitis
//   - problèmes de compatibilité kernel/driver fréquents
//   - AXI-Stream 512 bits impose d'adapter tout design 32 bits (cf. chapitre suivant)
// Rapport au cas smartNIC :
//   - l'architecture shell/role et la gestion PCIe native sont directement
//     adaptées à un déploiement en dataplane (pas de dépendance à un OS Xilinx)
//   - la V80 (PCIe 5.0) est un facteur de forme pertinent pour ce type d'usage
#lorem(60)


// ─────────────────────────────────────────────────────────────────────────────
= Portage du Bytestream Decoder sur Coyote
// ─────────────────────────────────────────────────────────────────────────────

== Adaptation du wrapper hardware (Design 1)

// Problème d'interface : Coyote expose un bus AXI-Stream de 512 bits ;
// le design original travaille en mots de 32 bits.
// Réécriture du wrapper vfpga_top.svh :
//   - côté entrée : extraction d'un mot 32 bits par beat 512 bits (1/16 utilisé)
//   - instanciation du ByteStream_Decoder_Wrapper VHDL inchangé
//   - côté sortie : encapsulation d'un mot 32 bits dans un beat 512 bits
// Intégration de l'ILA pour l'instrumentation :
//   - script init_ip.tcl : IP ILA, 8 sondes sur tvalid/tready des deux AXI-S
//   - permettra de mesurer les duty cycles et de localiser les goulots
#lorem(60)

== Adaptation du code hôte

// API Coyote utilisée :
//   - coyote::cThread (gestion du thread de communication PCIe)
//   - coyote::cBench (mesures de performance répétées)
// Chargement des données :
//   - fichier .raw : 174 736 mots de 32 bits (données brutes bytestream)
//   - fichier .bin : 1 833 mots de 32 bits (valeurs de correction)
// Packing pour le bus 512 bits :
//   - un mot 32 bits par beat (sous-utilisation ×16 volontaire pour le Design 1)
// Deux streams distincts :
//   - stream 0 : données brutes, stream 1 : corrections initiales
// Récupération et unpacking de la sortie :
//   - structure CaloCell { Gain_and_ID, Energy, Time, Quality }
//   - un mot 32 bits par beat → une composante par cellule
// Comparer avec le code hôte XRT d'origine (Upegui) :
//   - différences API (xclbin vs driver Coyote, buffers vs hugepages)
//   - volume de boilerplate similaire, paradigme légèrement différent
#lorem(80)


// ─────────────────────────────────────────────────────────────────────────────
= Analyse des performances et optimisation
// ─────────────────────────────────────────────────────────────────────────────

== Méthodologie de mesure (ILA)

// Protocole ILA :
//   - trigger sur tvalid du récepteur, 512 échantillons post-trigger
//   - script ila_utilization.py : parsage CSV Vivado, calcul ratios high/total
//     pour tvalid et tready sur chaque interface AXI-S
// Interprétation des signaux :
//   - tready entrée faible → FPGA ne peut pas consommer assez vite (goulot aval)
//   - tvalid sortie élevé → pipeline produit des données sans blocage
#lorem(40)

== Design 1 — diagnostic du goulot

// Résultats ILA Design 1 (250 MHz, sortie 32 bits) :
//   - tready entrée (axis_host_recv[0]) : 20.9 %
//   - tvalid sortie (axis_host_send[0]) : 100 %
// Interprétation : le pipeline FPGA est prêt en sortie en permanence, mais
// ne peut absorber l'entrée que 21 % du temps → goulot à la sortie
// Cause identifiée : Output Merger 32 bits émet une seule composante par cycle
// (4 cycles nécessaires pour émettre une cellule complète)
#lorem(40)

== Design 2 — sortie 128 bits

// Modification : Output Merger réécrit pour émettre les 4 mots d'une cellule
// simultanément (128 bits) en un seul beat
// Adaptation hôte : lecture 128 bits par beat, extraction des 4 composantes
// Résultats à 250 MHz :
//   - tready entrée : 88.7 % (+×4.2)
//   - tvalid sortie : 99.4 %
//   - temps de transfert : 0.83 ms (vs 3.17 ms → ×3.8)
//   - correctness : 195 072 cellules identiques entre Design 1 et Design 2
#lorem(60)

== Montée en fréquence à 400 MHz

// Démarche : paramétrage CMake, analyse timing Vivado (WNS, TNS)
// Résultats :
//   - tready entrée : 90.0 %, tvalid sortie : 99.4 %
//   - temps de transfert : 0.82 ms (gain marginal de ~1 % vs 250 MHz)
// Interprétation : le goulot restant n'est plus dans le pipeline FPGA mais
// dans le transfert PCIe ou dans la sous-utilisation du bus d'entrée (1/16)
// → monter la fréquence n'aide plus ; il faut élargir le bus d'entrée
#lorem(40)

== Tableau comparatif et bilan

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: center,
    table.header(
      [*Design*], [*Fréquence*], [*Sortie*], [*Temps transfert*], [*tready entrée*],
    ),
    [Design 1], [250 MHz], [32 bits],  [3.17 ms], [20.9 %],
    [Design 2], [250 MHz], [128 bits], [0.83 ms], [88.7 %],
    [Design 2], [400 MHz], [128 bits], [0.82 ms], [90.0 %],
  ),
  caption: [Comparaison des performances des trois configurations testées sur V80.],
)

// Synthèse : l'optimisation principale vient de l'alignement entre la largeur
// de sortie du pipeline et celle du bus Coyote, pas de la fréquence.
// La prochaine optimisation naturelle serait d'élargir le bus d'entrée (×16).
#lorem(30)


// ─────────────────────────────────────────────────────────────────────────────
= Discussion : Coyote face à XRT et perspectives smartNIC
// ─────────────────────────────────────────────────────────────────────────────

// Ce chapitre prend du recul sur les résultats pour répondre à la question
// centrale : qu'apporte Coyote par rapport à XRT sur ce type d'algorithme ?

== Coyote vs XRT — bilan du portage

// Effort de portage :
//   - côté hardware : réécriture du wrapper (interface 512 bits) est le seul
//     changement structurel ; le cœur VHDL est inchangé
//   - côté hôte : API différente mais volume de code comparable
// Fonctionnalité :
//   - Coyote reproduit fidèlement les résultats XRT (même sortie, même algo)
// Support matériel :
//   - XRT absent sur V80 → Coyote est la seule option viable sur cette carte
//   - avantage concret et non trivial dans un contexte de déploiement matériel récent
// Performance :
//   - goulot non lié au framework mais à la sous-utilisation du bus 512 bits
//   - à iso-design, pas de raison de penser que XRT serait plus rapide
#lorem(60)

== Pertinence pour des cas d'usage de type smartNIC

// Un smartNIC = FPGA embarqué dans une carte réseau, traitement in-line
// des flux de données sans impliquer le CPU host (ou de façon minimale).
// En quoi Coyote convient à ce modèle :
//   - shell/role → isolation claire entre le réseau/PCIe (shell) et l'appli (role)
//   - pas de dépendance à XRT/Vitis au runtime → déployable plus facilement
//   - gestion des hugepages + bus 512 bits → adapté aux débits élevés
//   - PCIe 5.0 sur V80 → bande passante suffisante pour des charges réseau réelles
// Limites identifiées dans ce projet applicables au cas smartNIC :
//   - sous-utilisation potentielle du bus si l'algorithme n'est pas conçu pour
//     des mots larges (nécessite un travail de packing/unpacking)
//   - maturité moindre (bugs de driver, instabilité U55C) à surveiller en prod
// Conclusion intermédiaire : Coyote est un candidat sérieux pour des déploiements
// dataplane sur FPGAs récents là où XRT n'est pas disponible ou trop rigide.
#lorem(60)

== Perspectives d'amélioration

// Élargissement du bus d'entrée :
//   actuellement 1 mot de 32 bits sur 512 disponibles (ratio 1/16) ;
//   packer 16 mots par beat multiplierait le débit d'ingestion par 16
// Pipeline multi-événement :
//   traiter plusieurs bytestreams en parallèle dans le même shell Coyote
// Stabilisation U55C :
//   investigation plus poussée du chemin PCIe/IOMMU nécessaire
// Comparaison XRT directe sur U55C :
//   mesurer les mêmes métriques ILA sous XRT pour un tableau comparatif complet
#lorem(40)


// ─────────────────────────────────────────────────────────────────────────────
= Conclusion
// ─────────────────────────────────────────────────────────────────────────────

// Rappeler l'objectif central : évaluer Coyote comme alternative à XRT sur
// un algorithme dataplane réel, et valider son support sur la V80.
// Bilan des trois objectifs :
//   1. Coyote pris en main et validé ; V80 stable, U55C instable (problème connu)
//   2. Portage réussi : design VHDL inchangé, wrapper et hôte adaptés
//      → Design 2 offre ×3.8 de gain par rapport au Design 1 naïf
//   3. Coyote viable sur V80 là où XRT est absent ; architecture pertinente
//      pour des cas smartNIC/dataplane
// Difficultés principales :
//   - problème MSI-X V80 (pci=realloc)
//   - interface 512 bits vs 32 bits (impose un travail de packing)
//   - instabilité U55C non résolue
// Questions ouvertes :
//   - sous-utilisation du bus d'entrée (1/16)
//   - pipeline multi-événement
//   - benchmark XRT vs Coyote à iso-design sur U55C
#lorem(60)


// ─────────────────────────────────────────────────────────────────────────────
// Bibliographie & Annexes
// ─────────────────────────────────────────────────────────────────────────────

#pagebreak()
#bibliography(full: true, "bibliography.bib", style: "ieee")
#pagebreak()

#show: appendix

= Code — Wrapper vfpga_top.svh

// Insérer ici des extraits commentés du wrapper SystemVerilog.
#lorem(30)

= Script d'analyse ILA

// Insérer ici le script ila_utilization.py ou des extraits pertinents.
#lorem(30)
