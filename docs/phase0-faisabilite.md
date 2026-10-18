# PHASE 0 — Étude de faisabilité

> Convention : **[SPEC]** = valeur normative, **[HYP]** = hypothèse à vérifier,
> **[MES]** = mesure réelle (aucune à ce stade), **[OBJ]** = objectif.
> Aucun prix, débit ou puissance n'est inventé : les chiffres non sourcés sont
> marqués *à sourcer*.

## 0.1 Candidats FPGA / SoC

Trois familles réalistes pour une personne seule, du plus accessible au plus capable.

| Critère | **Xilinx Artix-7 XC7A200T** | **Lattice ECP5 (LFE5UM-85F)** | **Intel Cyclone 10 GX** |
|---|---|---|---|
| Hard IP PCIe | Oui — *7 Series Integrated Block for PCIe*, **Gen2, jusqu'à x4** [HYP, vérifier PG054] | **Non** — pas de hard IP PCIe ; SERDES 5 Gb/s + pile PCIe *soft* | Oui — Hard IP PCIe **Gen2 x4** (H-Tile/P-Tile selon variante) |
| Transceivers | GTP 6,6 Gb/s | SERDES 5 Gb/s | 10 Gb/s |
| LUT / FF | ~215k cellules logiques | ~84k LUT | ~80–220k LE |
| BRAM | ~13 Mb | ~3,7 Mb | variable |
| Mémoire externe | DDR3 (sur carte NiteFury : 512 MB) | DDR3 | DDR3/DDR4 |
| Outils | **Vivado** (WebPACK gratuit couvre Artix-7) | **open-source** (Yosys + nextpnr) ou Diamond | **Quartus Prime** (Lite/Standard) |
| Licence PCIe | Hard IP **incluse, sans licence payante** [HYP] | pile soft (open ou tierce) | Hard IP incluse |
| JTAG | Oui | Oui | Oui |
| Carte M.2 prête | **NiteFury** : M.2 2280 M-key, Gen2 x4, XC7A200T, ~329 USD (Crowd Supply, *épuisé*, prix historique) | cartes dev non-M.2 majoritairement | peu de cartes M.2 grand public |
| Dispo | distributeurs (Digi-Key/Mouser) *à sourcer* | bonne, low-cost | moyenne |

**Sources** : [NiteFury — Crowd Supply](https://www.crowdsupply.com/rhs-research/nitefury) ·
[7 Series Overview DS180](https://docs.amd.com/v/u/en-US/ds180_7Series_Overview) ·
[PG054 — 7 Series Integrated Block for PCIe](https://docs.amd.com/r/en-US/pg054-7series-pcie).

## 0.2 Difficulté et risque par bloc (/10)

| Bloc | Difficulté | Risque | Note |
|---|---:|---|---|
| PCB M.2 custom | 9 | élevé | repoussé en variante C ; utiliser une carte M.2 toute faite d'abord |
| Signal integrity (Gen2) | 7 | moyen | géré par la carte NiteFury en variantes A/B |
| Alimentation M.2 (3,3 V) | 6 | moyen | budget à valider (§ Phase 1) |
| PCIe link training | 5 | moyen | fourni par le Hard IP ; dépend du Configuration Space |
| Configuration Space (0x010802) | 6 | moyen | paramétrage IP + BAR64 + MSI-X |
| NVMe Admin (Identify, queues) | 8 | **élevé** | **bloc le plus susceptible d'échouer** côté logique |
| I/O queues SQ/CQ | 7 | élevé | couplé au DMA |
| DMA (PRP walk, 64 bits) | 8 | élevé | exactitude PRP + alignement |
| Backend stockage | 4 | faible | BRAM d'abord, DDR ensuite |
| USB diagnostic | 4 | faible | protocole déjà défini, PHY standard |
| Compat Windows / stornvme | 9 | **très élevé** | tolérance nulle sur CAP/Identify incohérents |
| Thermique | 4 | faible | Artix-7 modéré ; dissipateur NiteFury dispo |
| Validation | 7 | moyen | sim d'abord, matériel ensuite |

## 0.3 Architecture retenue

- **[OBJ]** Preuve de concept sur **carte M.2 du commerce (NiteFury, Artix-7 XC7A200T)** —
  pas de PCB custom avant d'avoir un namespace montable sous Windows.
- **[SPEC]** PCIe **Gen2 x4** via Hard IP (pas de PHY développée from scratch — règle B.1).
- **[HYP]** Backend namespace : **BRAM** en premier (volatile, non persistant, déclaré tel
  quel dans Identify), puis DDR3 de la carte.
- **[SPEC]** USB : lien diagnostic séparé du chemin stockage (aucun recouvrement).

Distinction nette :
- **PoC carte de dev** = variantes A puis B (validation PCIe/NVMe/Windows).
- **Carte finale M.2 2280 custom** = variante C (miniaturisation), seulement une fois A/B prouvées.

## 0.4 Réponses aux questions de démarrage

1. **FPGA/carte** : Artix-7 XC7A200T sur carte M.2 NiteFury. Limite : Gen2 x4 (pas Gen3), DDR3 modeste, PCB custom hors scope initial.
2. **Slot M.2 / IOMMU** : **[BESOIN]** à confirmer sur le PC principal (slot M-key libre, VT-d/AMD-Vi activable dans le BIOS).
3. **Coûts A/B/C** : voir `variants-costs.md` (chiffres sourcés ou marqués *à sourcer*).
4. **Bloc le plus à risque** : compat Windows/stornvme (CAP + Identify cohérents) et NVMe Admin.
5. **Progression anti-gaspillage** : sim → carte de dev → Windows → DMA buffers test → PCB custom en dernier.
6. **Sans licence IP payante** : Hard IP PCIe Xilinx (incluse), RTL NVMe/DMA/USB (ce repo), Vivado WebPACK.

---

PHASE 0 — Faisabilité — **TERMINÉE (analyse)**
Décidé : Artix-7 XC7A200T / carte M.2 NiteFury ; PCIe Gen2 x4 Hard IP ; backend BRAM→DDR3 ; USB séparé.
Écarté : ECP5 (pas de Hard IP PCIe → PCIe soft trop risqué en solo) ; PCB M.2 custom d'emblée (SI/alim/coût) ; Gen3 (hors Artix-7).
Implémentation : comparatif FPGA, tableau difficulté/risque, architecture de référence, réponses aux 6 questions.
Tests : revérifier PG054 (Gen2 x4 Artix-7) ; confirmer slot M.2 + IOMMU du PC principal.
Risque : incohérence CAP/Identify → stornvme refuse le contrôleur ; plan alt : coller sur un dump d'un vrai SSD comme référence de valeurs.
Budget : carte NiteFury ~329 USD (historique, épuisé) — équivalent à sourcer ; incertitude élevée sur dispo.
Prochaine action : PHASE 1 — schéma-bloc + BOM préliminaire + budget puissance.
Besoin de toi : composants réels (carte FPGA choisie + PC cible). Confirme slot M.2 M-key libre et IOMMU activable.
