# Registre des risques

Pour chaque risque : probabilité · gravité · détection · atténuation · alternative · impact budget.

| # | Risque | Prob. | Gravité | Détection | Atténuation | Alternative | Budget |
|---|---|---|---|---|---|---|---|
| R1 | stornvme rejette le contrôleur (CAP/Identify incohérents) | Élevée | Critique | Gestionnaire périph., Identify CQ | Aligner sur dump d'un vrai SSD ; relecture spec NVMe 2.0 | Tester d'abord sous Linux (`nvme-cli`) plus verbeux | Temps |
| R2 | PCIe link training échoue | Moyenne | Critique | Hard IP status, ILA | Carte M.2 du commerce (SI maîtrisée) ; brider x1/x2 | Rester en Gen1 x1 | Temps |
| R3 | Walk PRP / DMA incorrect (alignement, frontières de page) | Élevée | Haute | CRC/signatures, sim | Tests buffers réservés ; assertions ; cas 4 Go+ | Transferts bornés 1 page d'abord | Temps |
| R4 | Refus IOMMU mal géré | Moyenne | Haute | `mem_err`, logs | Traiter en complétion d'erreur ; test dédié J8 | Désactiver IOMMU pour bring-up (puis réactiver) | Temps |
| R5 | Timing closure non atteint (Artix-7) | Moyenne | Moyenne | Vivado WNS | Pipeliner FSM, réduire fréquence user_clk | FPGA plus gros/rapide | Matériel |
| R6 | Budget puissance dépassé au connecteur M.2 | Faible | Haute | XADC, pince | Mesurer tôt ; brider largeur lien | Alim externe en bench | Matériel |
| R7 | Persistance namespace mal déclarée (BRAM volatile) | Moyenne | Moyenne | Reboot + relecture | Déclarer explicitement non-persistant dans Identify | Passer DDR3/NAND | Matériel |
| R8 | Erreur de flash / brique de la carte | Faible | Moyenne | JTAG inaccessible | Garder image de secours ; mode fallback JTAG | Reprog via JTAG dédié | Temps |
| R9 | Indispo carte NiteFury (épuisée) | Élevée | Moyenne | Distributeurs | Sourcer équivalent Artix-7 M.2 ; carte dev + adaptateur M.2 | Autre famille (Cyclone 10 GX) | Matériel |
| R10 | Thermique en charge prolongée | Faible | Moyenne | GET_TEMPERATURE, capteur | Dissipateur ; throttle benchmark | Réduire QD/débit | Matériel |

Règle qualité 12 : **aucune** affirmation de furtivité/indétectabilité. Le DMA
reste borné aux PRP/buffers autorisés (R3/R4).
