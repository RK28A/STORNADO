# Variantes, coûts et compromis

> Aucun prix inventé. Les coûts non sourcés sont marqués *à sourcer* ; le temps
> est une estimation d'effort solo, pas un engagement.

## Variante A — Banc économique (validation PCIe/NVMe)
Carte FPGA de dev + lien PCIe, backend BRAM, pas d'USB.
- **But** : prouver link training, Config Space 0x010802, init registres, Identify.
- Composants : carte Artix-7 (NiteFury M.2 ou carte dev + slot PCIe), JTAG.
- Outils : Vivado WebPACK (gratuit), ce repo.
- PCB/assemblage : aucun.
- Coût : carte ~329 USD *(NiteFury historique, épuisé — équivalent à sourcer)*.
- Conso/thermique : faibles (lien + logique).
- Temps : élevé sur la logique NVMe Admin.
- Risques : R1, R2.

## Variante B — Prototype fonctionnel (namespace + USB)
A + namespace réel (BRAM→DDR3) + diagnostics USB (PC #2).
- **But** : disque montable sous Windows, aller-retour fichier, CLI diagnostic.
- Composants : + PHY USB (FT2232H USB2 **ou** FT601 USB3) + câblage.
- Outils : + toolchain C/Python (ce repo).
- PCB : éventuel petit adaptateur USB si non intégré.
- Coût : A + PHY USB *à sourcer*.
- Temps : + chemin DMA complet + bring-up Windows.
- Risques : R3, R4, R7.

## Variante C — Carte M.2 2280 intégrée (miniaturisation)
PCB custom : FPGA nu + DDR3 + PMIC + USB + connector edge M.2.
- **But** : format final, autonome dans un slot M.2.
- Composants : BOM complète (voir phase1 §1.3, étendue).
- Outils : + CAO PCB (KiCad), fab PCB HDI, assemblage CMS.
- Coût : FPGA + mémoires + PMIC + PCB HDI + assemblage — **à chiffrer après A/B**.
- Temps : le plus élevé (SI, alim, thermique, bring-up matériel).
- Risques : R5, R6, R8, R10 + tous les précédents.

## Compromis clés
| Axe | Option prudente | Option ambitieuse | Choix STORNADO |
|---|---|---|---|
| Largeur PCIe | x1 (bring-up) | x4 (perf) | x4 cible, x1/x2 en secours |
| USB | 2.0 HS | 3.x | 2.0 HS d'abord |
| Backend | BRAM (volatile) | DDR3/NAND (persistant) | BRAM → DDR3 |
| PCIe IP | Hard IP (incluse) | soft (ECP5) | **Hard IP** (règle B.1) |
| Support | carte dev du commerce | PCB M.2 custom | carte dev → PCB en dernier |

Justification : minimiser le risque de **fabrication inutile** — on ne grave un PCB
(variante C) qu'après un namespace monté et un aller-retour fichier validés (A/B).
