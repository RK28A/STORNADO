# PHASE 2 — Énumération & stockage Windows

Chaîne vérifiable, avec pour chaque transition : trace attendue, test de sim ou
outil Windows, résultat attendu, diagnostic si échec.

| # | Transition | Observable / outil | Résultat attendu | Si échec |
|---|---|---|---|---|
| 1 | Alim → reset | LED/alim, JTAG | FPGA configuré | vérifier séquencement 3,3 V, bitstream |
| 2 | PERST# → link training | Hard IP status, ILA | `link_up=1`, largeur/vitesse négociées | revoir refclk, polarité lanes, SI |
| 3 | Énumération PCIe | `Gestionnaire de périph.`, `lspci` (Linux) | device visible, BAR0 mappé | Config Space, BAR size |
| 4 | Identification classe | propriétés périph. | classe **0x010802** | corriger Class Code dans l'IP |
| 5 | Chargement stornvme | Gestionnaire de périph. | pilote `stornvme.sys` attaché | classe/CAP/MSI-X incohérents → voir §cohérence |
| 6 | Init registres/queues | ILA sur CC/CSTS/AQA | `CC.EN→CSTS.RDY`, ASQ/ACQ posés | FSM `nvme_regs`, timeouts |
| 7 | Commandes Identify | trace Admin CQ | Identify Controller/Namespace cohérents | revoir structures Identify vs CAP |
| 8 | Découverte namespace | `Gestion des disques` | 1 disque non initialisé | Identify NS (NSZE/LBAF) |
| 9 | Partition + format | `diskpart` / GUI | volume NTFS monté | Read/Write/Flush I/O |
| 10 | Fichier aller-retour | copie + `certutil -hashfile` | **hash identique** | intégrité DMA/backend |

## Cohérence critique (condition de non-rejet)
`CAP` (MQES, DSTRD, CSS, MPS) **⇔** valeurs `Identify Controller/Namespace` **⇔**
fonctions réellement implémentées. Toute divergence = stornvme refuse ou le disque
n'apparaît pas. Plan B : aligner les valeurs sur un **dump d'un vrai SSD NVMe** pris
comme référence (lecture Config/CAP/Identify d'un SSD du commerce).

## Outils
Windows : Gestionnaire de périphériques, Gestion des disques, `diskpart`, `certutil`,
`winsat disk`. Linux (diagnostic) : `lspci -vvv`, `nvme-cli`, `dmesg`.
FPGA : Vivado ILA/ChipScope sur les bus internes.

---

PHASE 2 — Énumération & stockage Windows — **SPÉCIFIÉE (non exécutée)**
Décidé : chaîne de 10 transitions traçables ; cohérence CAP⇔Identify comme invariant.
Écarté : sauter la sim pour tester direct sur Windows (debug aveugle coûteux).
Implémentation : procédure + outils + diagnostics par transition.
Tests : exécution réelle = matériel (jalons 3–6 du plan de test).
Risque : rejet stornvme sur incohérence ; plan alt : calquer sur un dump de SSD réel.
Budget : nul (doc) ; coûts en temps de bring-up.
Prochaine action : brancher ILA sur CC/CSTS/doorbells une fois le lien établi.
Besoin de toi : accès au PC principal (droits admin, BIOS IOMMU, slot M.2).
