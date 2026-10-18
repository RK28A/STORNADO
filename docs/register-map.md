# Carte des registres — PCIe Config Space & NVMe (BAR0)

> Valeurs à **revérifier dans les spécifications** avant gel (PCIe Base 4.0,
> NVMe Base 2.0c). Marquées [HYP] tant que non confrontées à la spec/au dump
> d'un vrai SSD de référence. Aucune valeur inventée : les champs incertains
> sont signalés.

## 1. PCIe Configuration Space (Type 0)

Classe cible : **Base 0x01 / Subclass 0x08 / Prog IF 0x02 = 0x010802** (NVMe).

| Champ | Offset | Largeur | Reset | Notes |
|---|---|---|---|---|
| Vendor ID | 0x00 | 16 | [HYP] | **ne pas usurper un fabricant** ; utiliser un VID légitime/alloué ou de test |
| Device ID | 0x02 | 16 | [HYP] | DID propre au projet |
| Command | 0x04 | 16 | 0x0000 | activer Memory Space (bit1) + Bus Master (bit2) pour le stockage |
| Status | 0x06 | 16 | — | capabilities list bit |
| Revision ID | 0x08 | 8 | [HYP] | |
| Class Code | 0x09 | 24 | **0x010802** | [SPEC] |
| BAR0/BAR1 | 0x10 | 64 | — | BAR 64 bits, non-préfetchable, mappe les registres NVMe |
| Capabilities Ptr | 0x34 | 8 | → liste | |
| PCI Express Cap | — | — | — | Device/Link Control, largeur/vitesse |
| MSI-X Cap | — | — | — | table de vecteurs (préféré à MSI) |
| Power Management | — | — | — | états D0/D3 |
| AER (option) | — | — | — | si implémenté |

Pour chaque champ : offset/largeur/reset/bits RW vs réservés/comportement/critère
d'énumération → **à compléter depuis PCIe Base** et depuis le paramétrage de l'IP
Xilinx (PG054). Référence : [PG054](https://docs.amd.com/r/en-US/pg054-7series-pcie).

## 2. Registres NVMe (BAR0) — NVMe 2.0 §3.1

Implémentés dans `rtl/nvme/nvme_regs.sv` (voir code pour les valeurs reset exactes).

| Registre | Offset | Largeur | Accès | Rôle |
|---|---|---|---|---|
| CAP | 0x00 | 64 | RO | capabilities (MQES, CQR, TO, DSTRD, CSS, MPSMIN/MAX) |
| VS | 0x08 | 32 | RO | version = 0x00020000 (2.0.0) |
| INTMS | 0x0C | 32 | RW1S | interrupt mask set |
| INTMC | 0x10 | 32 | RW1C | interrupt mask clear |
| CC | 0x14 | 32 | RW | EN, CSS, MPS, IOSQES, IOCQES |
| CSTS | 0x1C | 32 | RO | RDY, CFS, SHST |
| NSSR | 0x20 | 32 | RW | subsystem reset (si supporté) |
| AQA | 0x24 | 32 | RW | tailles Admin SQ/CQ |
| ASQ | 0x28 | 64 | RW | base DMA Admin SQ |
| ACQ | 0x30 | 64 | RW | base DMA Admin CQ |
| SQ0TDBL… | 0x1000+ | 32 | RW | doorbells (stride 4, DSTRD=0) |

**FSM d'init** (`nvme_regs.sv`) : `CC.EN 0→1` ⇒ après latence ⇒ `CSTS.RDY=1` ;
`CC.EN 1→0` ⇒ reset contrôleur ⇒ `CSTS.RDY=0`. Cohérence **CAP ⇔ Identify ⇔
fonctions annoncées** = condition de non-rejet par stornvme.

## 3. Commandes

### Admin (nécessaires à l'init Windows)
Identify (Controller 0x01 / Namespace 0x00 / NS list 0x02), Get/Set Features,
Create/Delete I/O SQ & CQ, Get Log Page (SMART/Health, Error, Firmware),
Abort, + rejet propre des opcodes non supportés (status *Invalid Command Opcode*).

### I/O (NVM Command Set)
| Cmd | Opcode | Champs clés | Validation |
|---|---|---|---|
| Flush | 0x00 | NSID | backend persiste si applicable |
| Write | 0x01 | SLBA, NLB, PRP1/2 | plage LBA, alignement, taille |
| Read | 0x02 | SLBA, NLB, PRP1/2 | idem |

Chaque commande : opcode / champs d'entrée / validation / flux de données /
code de complétion / test positif + négatif → détaillé dans `test-plan.md`.

## 4. Namespace
- Backend démo : **BRAM volatile** (non persistant — déclaré explicitement).
- LBA = 512 B (LBA_SHIFT=9). Capacité démo 1 MiB (BRAM) → DDR3 ensuite.
- Flush : no-op sur BRAM ; réel sur DDR/NAND avec gestion perte alimentation.
- Identify Namespace : NSZE/NCAP/NUSE, LBAF (LBADS=9), **persistance annoncée
  conforme au backend réel**.
