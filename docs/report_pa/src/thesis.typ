#import "@preview/structured-mse-thesis:0.1.0": appendix, report-template

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

// Contexte général : expérience ATLAS au CERN, calorimètre LAr, volumes de
// données produits lors des collisions, besoin de traitement temps réel du
// bytestream.
// Présenter la motivation d'utiliser un FPGA pour accélérer ce traitement.
// Énoncer les objectifs du projet d'approfondissement :
//   1. Prise en main du framework Coyote
//   2. Portage du Bytestream Decoder (originellement sous XRT) vers Coyote
//   3. Validation et optimisation sur la carte V80
// Terminer par le plan du rapport (une phrase par chapitre).
#lorem(80)


// ─────────────────────────────────────────────────────────────────────────────
= Background
// ─────────────────────────────────────────────────────────────────────────────

== L'expérience ATLAS et le calorimètre à Argon liquide

// Présenter brièvement le LHC et l'expérience ATLAS.
// Décrire le rôle du calorimètre à Argon liquide (LAr) : mesure de l'énergie
// des particules issues des collisions.
// Expliquer comment le signal des cellules du calorimètre est numérisé et
// transmis sous forme de bytestream compressé par les cartes Front-End Boards
// (FEB).
#lorem(60)

== Accélération matérielle par FPGA

// Expliquer pourquoi les FPGAs sont bien adaptés au traitement de flux de
// données en temps réel (parallélisme, latence déterministe, débit élevé).
// Présenter la carte Xilinx V80 (Versal Premium) utilisée dans ce projet :
// famille, ressources disponibles, particularités (AI Engine, NoC, PCIe 5.0).
#lorem(60)

== Frameworks de développement hôte-FPGA

// Présenter XRT (Xilinx Runtime) :
//   - modèle de programmation (kernels, buffers)
//   - avantages : écosystème mature, outils Vitis
//   - limites : pas de support V80, modèle plus rigide
// Présenter Coyote :
//   - architecture shell/role, séparation infrastructure/logique applicative
//   - interface AXI-Stream 512 bits vers le FPGA
//   - communication PCIe, gestion des hugepages, driver kernel
// Comparaison synthétique XRT vs Coyote (tableau ou liste).
#lorem(80)


// ─────────────────────────────────────────────────────────────────────────────
= Le Bytestream Decoder original
// ─────────────────────────────────────────────────────────────────────────────

== Format du bytestream ATLAS

// Décrire la structure d'un paquet bytestream ATLAS :
//   - en-têtes FEB (Front-End Board)
//   - données compressées par canal (gain, énergie, temps, qualité)
//   - mots de 32 bits
// Mentionner les deux flux d'entrée : données brutes + valeurs de correction.
#lorem(50)

== Architecture du design VHDL

// Présenter la vue d'ensemble du design (insérer un schéma bloc).
// Décrire le pipeline de traitement module par module :
//
//   FEB Parser
//     Extrait les en-têtes FEB et synchronise les canaux entrants.
//
//   Gain Decoder / Energy Decoder / Time Decoder
//     Extraient respectivement le gain, l'énergie brute et le temps de chaque
//     cellule à partir des champs compressés du bytestream.
//
//   CAM ID & Online→Offline Hash LUT
//     Traduit les identifiants en ligne (online) des cellules vers leur
//     identifiant hors ligne (offline) via une mémoire adressable par contenu
//     et une table de hachage.
//
//   Correction LUT & fpu_sub
//     Applique une correction d'énergie flottante (soustraction FPU 32 bits)
//     à partir de valeurs pré-chargées dans une ROM.
//
//   Output Merger
//     Assemble les quatre composantes (Gain+ID, Énergie, Temps, Qualité) en
//     un ou plusieurs mots de sortie par cellule.
//
//   FIFO
//     Bufferise les données entre étages pour absorber les variations de débit.
#lorem(100)

== Interface et utilisation sous XRT

// Décrire l'interface d'origine :
//   - bus AXI-Stream 32 bits en entrée et en sortie
//   - deux kernels/flux : données brutes (stream 0) et corrections (stream 1)
// Mentionner le code hôte XRT original (Upegui) et son mode de fonctionnement.
#lorem(40)


// ─────────────────────────────────────────────────────────────────────────────
= Portage sur Coyote
// ─────────────────────────────────────────────────────────────────────────────

== Prise en main du framework

// Décrire la mise en place de l'environnement :
//   - build hardware avec CMake et Vivado 2024.2 (-DFDEV_NAME=v80)
//   - compilation du driver kernel (TARGET_PLATFORM=versal)
//   - programmation du FPGA et rescanning PCIe
// Tests initiaux sur U55C (exemple 01_hello_world) :
//   - problème "Invalid module format" → recompilation driver
//   - programme bloquant → activation IOMMU (amd_iommu=on iommu=pt)
//   - instabilité résiduelle non résolue sur U55C
// Tests sur V80 :
//   - passage au support officiel V80 dans Coyote
//   - problème MSI-X (manque de mémoire PCI) → solution pci=realloc dans grub
//   - comportement stable et reproductible sur V80
#lorem(80)

== Adaptation du design hardware (Design 1)

// Expliquer la différence clé d'interface :
//   - Coyote expose un bus AXI-Stream de 512 bits
//   - le design original utilise des mots de 32 bits
// Décrire la réécriture du wrapper vfpga_top.svh :
//   - packing côté entrée : extraction d'un mot 32 bits par beat 512 bits
//   - instanciation du ByteStream_Decoder_Wrapper VHDL
//   - unpacking côté sortie : encapsulation du mot 32 bits dans un beat 512 bits
// Décrire l'intégration de l'ILA (Integrated Logic Analyzer) :
//   - script init_ip.tcl : création de l'IP ILA, 8 sondes
//   - sondes sur tvalid/tready des deux interfaces AXI-S
//   - utilisation pour le débogage et la mesure des duty cycles
#lorem(80)

== Adaptation du code hôte

// Décrire les changements côté logiciel (main.cpp) :
//   API Coyote utilisée :
//     - coyote::cThread pour la gestion du thread de communication
//     - coyote::cBench pour les mesures de performance
//   Chargement des données :
//     - lecture du fichier .raw (174 736 mots de 32 bits)
//     - lecture du fichier .bin de corrections (1 833 mots de 32 bits)
//   Packing pour le bus 512 bits :
//     - un mot 32 bits par beat de 512 bits (16 mots auraient pu tenir)
//   Deux streams distincts :
//     - stream 0 : données brutes du bytestream
//     - stream 1 : valeurs de correction initiales
//   Récupération et unpacking de la sortie :
//     - structure CaloCell { Gain_and_ID, Energy, Time, Quality }
//     - un mot 32 bits par beat en sortie → une composante par cellule
#lorem(80)


// ─────────────────────────────────────────────────────────────────────────────
= Optimisation du Design
// ─────────────────────────────────────────────────────────────────────────────

== Analyse du goulot d'étranglement

// Présenter les résultats ILA du Design 1 :
//   - tready entrée (axis_host_recv[0]) : 20.9 %
//   - tvalid sortie (axis_host_send[0]) : 100 %
// Interpréter : le host envoie des données plus vite que le FPGA ne peut les
// consommer → goulot côté sortie du pipeline.
// Identifier la cause : Output Merger 32 bits émet une seule composante par
// cycle d'horloge, ce qui maintient le pipeline en attente la plupart du temps.
#lorem(40)

== Design 2 : sortie 128 bits

// Décrire la modification apportée :
//   - Output Merger réécrit pour émettre 4 mots de 32 bits simultanément
//     (gain, énergie, temps, qualité d'une cellule) en un seul mot de 128 bits
//   - adaptation du code hôte : lecture de 128 bits par beat, extraction des
//     4 composantes en une seule opération
// Résultats à 250 MHz :
//   - tready entrée : 88.7 % (vs 20.9 % → ×4.2)
//   - tvalid sortie : 99.4 %
//   - temps de transfert : 0.83 ms (vs 3.17 ms → ×3.8 plus rapide)
//   - correctness vérifiée : sortie identique sur 195 072 cellules
#lorem(60)

== Montée en fréquence : 400 MHz

// Décrire la démarche :
//   - paramétrage CMake pour cibler 400 MHz
//   - analyse des contraintes de timing Vivado (WNS, TNS)
// Résultats mesurés :
//   - tready entrée : 90.0 %
//   - tvalid sortie : 99.4 %
//   - temps de transfert : 0.82 ms (gain marginal vs 250 MHz)
// Interpréter : le goulot n'est plus dans le pipeline FPGA mais dans
// le transfert PCIe ou la largeur du bus d'entrée (32/512 bits sous-utilisé).
#lorem(40)


// ─────────────────────────────────────────────────────────────────────────────
= Résultats et Analyse
// ─────────────────────────────────────────────────────────────────────────────

== Tableau comparatif des designs

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: center,
    table.header(
      [*Design*], [*Fréquence*], [*Sortie*], [*Temps transfert*], [*tready entrée*],
    ),
    [Design 1], [250 MHz], [32 bits], [3.17 ms],  [20.9 %],
    [Design 2], [250 MHz], [128 bits], [0.83 ms], [88.7 %],
    [Design 2], [400 MHz], [128 bits], [0.82 ms], [90.0 %],
  ),
  caption: [Comparaison des performances des trois configurations testées sur V80.],
)

== Analyse des mesures ILA

// Expliquer le protocole de mesure :
//   - trigger sur tvalid du récepteur, 512 échantillons post-trigger
//   - script ila_utilization.py : parsage des exports CSV Vivado, calcul des
//     ratios high/total pour tvalid et tready
// Corréler les duty cycles au comportement du pipeline :
//   - tvalid = 100 % sortie Design 1 → pipeline toujours prêt à émettre
//   - tready = 20.9 % entrée Design 1 → host bloqué 80 % du temps en attente
//   - Design 2 : tready 88 % → quasi saturation du lien PCIe hôte→FPGA
#lorem(60)

== Correctness et validation fonctionnelle

// Décrire la démarche de validation :
//   - comparaison des 195 072 cellules de sortie entre Design 1 et Design 2
//   - valeurs identiques pour Gain_and_ID, Energy, Time, Quality
// Montrer un extrait des premières cellules décodées (peut reprendre la sortie
// de ./test du notes.md).
// Mentionner les cellules à temps non nul comme cas de test non trivial.
#lorem(40)

== Perspectives d'amélioration

// Pistes identifiées pour aller plus loin :
//
//   Élargissement du bus d'entrée
//     Actuellement, un mot de 32 bits est envoyé par beat de 512 bits
//     (ratio 1/16). Remplir le bus d'entrée permettrait un débit ×16 côté
//     ingestion, réduisant encore le temps de transfert.
//
//   Pipeline multi-événement
//     Traiter plusieurs événements en parallèle dans le pipeline FPGA.
//
//   Stabilisation U55C
//     Le problème de blocage résiduel sur U55C n'a pas été résolu ; une
//     investigation plus poussée du chemin PCIe/IOMMU serait nécessaire.
#lorem(40)


// ─────────────────────────────────────────────────────────────────────────────
= Conclusion
// ─────────────────────────────────────────────────────────────────────────────

// Bilan du projet :
//   - Coyote fonctionne de manière stable sur la carte V80
//   - Le Bytestream Decoder a été porté avec succès depuis XRT vers Coyote
//   - Le Design 2 offre un gain de performance ×3.8 par rapport au Design 1
//     grâce à l'élargissement de la sortie à 128 bits
// Difficultés majeures surmontées :
//   - problème MSI-X sur V80 (pci=realloc)
//   - adaptation de l'interface AXI-Stream (512 bits vs 32 bits)
//   - instabilité IOMMU sur U55C
// Ce qui reste ouvert :
//   - stabilité U55C toujours non résolue
//   - sous-utilisation du bus d'entrée (1/16 de la largeur disponible)
//   - optimisations supplémentaires possibles (pipeline multi-événement)
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
