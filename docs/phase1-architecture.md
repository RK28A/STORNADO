# PHASE 1 — Architecture matérielle

## 1.1 Schéma-bloc

```
  Connecteur M.2 M-key (PCIe x4 + 3,3 V)
        │
        ▼
 ┌──────────────────┐   refclk 100 MHz
 │  Hard IP PCIe     │◄──────────────── oscillateur / clock M.2
 │  (Gen2 x4)        │
 │  link training,   │   user_clk / user_rst
 │  Config Space     │────────────┐
 │  0x010802         │            │
 └───────┬──────────┘            │
   TLP   │  MMIO (BAR0)          │ Requester (Memory Rd/Wr)
         ▼                       ▼
 ┌───────────────┐      ┌──────────────────┐
 │ nvme_regs     │      │  dma_engine      │  (PRP fournis par l'hôte)
 │ CAP/CC/CSTS…  │      │  SQE fetch,      │
 │ nvme_doorbells│      │  data transfer,  │
 └──────┬────────┘      │  CQE write       │
        │               └────────┬─────────┘
        ▼                        ▼
 ┌───────────────┐      ┌──────────────────┐
 │ nvme_queue_mgr│      │ storage_backend  │  BRAM → DDR3
 │ SQ/CQ, phase  │      │ (namespace réel) │
 └──────┬────────┘      └──────────────────┘
        ▼
 ┌───────────────┐
 │ nvme_cmd_dec  │  Admin/IO classification
 └───────────────┘

  ── Voie DIAGNOSTIC (séparée du chemin stockage) ──
 ┌───────────────┐   octet-stream   ┌──────────────┐   USB    ┌──────────┐
 │ usb_framer    │◄────────────────►│ PHY USB      │◄────────►│ PC #2    │
 │ (protocole)   │                  │ (FT601/ULPI) │          │ nvme-tool│
 └───────────────┘                  └──────────────┘          └──────────┘

  Supervision : reset_sync, cdc_sync/async_fifo (CDC lien↔cœur↔USB),
                capteurs température/tension (XADC), séquencement alim.
```

Flux : `M.2 → Hard IP PCIe → TLP/MMIO → nvme_regs/doorbells → cmd_decoder →
queue_mgr → dma_engine → backend`. La voie diagnostic (`usb_framer → PHY → PC #2`)
est **physiquement et logiquement distincte** du chemin stockage.

## 1.2 Domaines d'horloge

| Domaine | Source | Contenu |
|---|---|---|
| `user_clk` | Hard IP PCIe (125/250 MHz selon largeur) | regs, queues, DMA, backend |
| `usb_clk` | PHY USB | framer USB |
| CDC | `async_fifo` / `cdc_sync` | passages lien↔cœur et cœur↔USB |

## 1.3 BOM préliminaire

Références réelles, prix *à sourcer* (aucun inventé). Variante B (prototype).

| Poste | Référence | Source | Prix |
|---|---|---|---|
| Carte FPGA M.2 | NiteFury (Artix-7 XC7A200T, M.2 2280, Gen2 x4, DDR3) | [Crowd Supply](https://www.crowdsupply.com/rhs-research/nitefury) | ~329 USD *(historique, épuisé)* |
| PHY USB | FTDI FT601Q (USB 3.0 FIFO) **ou** FT2232H (USB 2.0 HS) | Digi-Key/Mouser | *à sourcer* |
| Programmateur JTAG | Xilinx Platform Cable / FT2232H | — | *à sourcer* |
| Dissipateur | option NiteFury (heatsink intégré) | Crowd Supply | *à sourcer* |
| PC principal | Windows 10/11 x64, slot M.2 M-key, IOMMU | — | fourni par toi |
| PC secondaire | Windows/Linux + USB | — | fourni par toi |

Pour un **PCB M.2 custom** (variante C) la BOM s'étend : FPGA nu, connector edge M.2,
DDR3, PMIC/régulateurs 3,3→1,0/1,8 V, oscillateurs, EEPROM config, protections ESD,
passifs, test pads/JTAG — à établir seulement si A/B réussissent.

## 1.4 Budget puissance (méthode)

> **[HYP]** — à remplacer par des mesures (XADC + pince) sur la carte réelle.
> Le plafond applicable au connecteur M.2 et au système hôte doit être validé
> **avant** de figer le design (règle PARTIE D).

| État | Poste | Hypothèse | À mesurer |
|---|---|---|---|
| Boot | config FPGA + PLL lock | pic transitoire | courant inrush 3,3 V |
| Idle | lien up, contrôleur disabled | statique + horloges | P_idle |
| Pleine charge | DMA + backend + USB actifs | dynamique logique + SERDES | P_max, ΔT |

Rendement DC/DC et marge (≥ 20 %) à intégrer une fois les régulateurs connus.

---

PHASE 1 — Architecture matérielle — **ÉBAUCHE (sur carte de dev)**
Décidé : schéma-bloc avec voie diagnostic séparée ; 3 domaines d'horloge + CDC par async_fifo ; BOM centrée sur carte M.2 du commerce.
Écarté : PCB custom immédiat (coût/risque) ; USB fondu dans le chemin stockage (viole la séparation A.2/B).
Implémentation : `rtl/top/stornado_top.sv` câble regs+doorbells+queue_mgr+cmd_decoder+dma+backend+usb ; wrapper PCIe isolé.
Tests : élaboration/lint du top ; sim regs+doorbells (`sim/`). Mesures puissance/thermique = matériel requis.
Risque : budget puissance non mesuré ; plan alt : brider la largeur de lien (x1/x2) en prototypage.
Budget : dominé par la carte FPGA (~329 USD historique) ; PHY USB + câbles *à sourcer*.
Prochaine action : relier le Hard IP PCIe réel (Vivado IP) au bridge TLP↔MMIO ; brancher le fetch SQE du DMA.
Besoin de toi : réf. exacte de la carte FPGA que tu achètes + choix PHY USB (2.0 HS suffisant pour le diagnostic).
