# STORNADO

**STOR**age + tor**NADO** — un contrôleur de stockage **NVMe sur FPGA**, format
M.2 2280, qui s'énumère en PCIe classe `0x010802` et se monte sous Windows via le
pilote natif `stornvme.sys`, sans driver tiers. Clin d'œil assumé à `stornvme`.

> **Statut : squelette d'ingénierie + socle logiciel testé.** Ce dépôt contient
> une architecture de référence, du RTL SystemVerilog synthétisable de départ,
> des testbenches, les outils hôte (CLI/protocole) **fonctionnels**, et la doc
> complète par phase. **Rien n'est « prêt à flasher »** : les blocs dépendants du
> Hard IP PCIe et du matériel réel sont balisés `TODO-IP` / `TODO-SPEC`. Aucun
> résultat matériel (bitstream, oscillo, test Windows) n'est fourni tant qu'il
> n'a pas été mesuré.

## Ce que fait (et ne fait pas) le projet

- ✅ Vrai contrôleur NVMe : registres, queues Admin/IO, commandes, backend, DMA de stockage.
- ✅ DMA **borné** aux PRP/buffers fournis par l'hôte ou réservés au banc de test.
- ✅ Lien USB **diagnostic**, séparé du chemin stockage.
- 🚫 Aucun accès arbitraire à la RAM, aucune exfiltration, aucune furtivité. Bus
  Master ≠ droit de lecture mémoire arbitraire (voir `docs/risk-register.md`).

## Arborescence

```
rtl/        RTL SystemVerilog : top, pcie(wrapper IP), nvme, dma, memory, usb, common
firmware/   dispatch diagnostic (C) pour soft-core/MCU
host/        outils PC secondaire : lib (protocole+transport), cli, gui, tests
sim/         testbenches unit + integration (Icarus/Verilator)
constraints/ XDC/SDC (placeholders documentés)
pcb/         notes PCB M.2 (variante C)
scripts/     setup, sim, lint
docs/        phases 0→9, carte registres, protocole USB, risques, variantes, tests
tests/       emplacement tests d'intégration bout-en-bout
```

## Démarrage rapide (how-to-setup)

### 1. Prérequis
```bash
# Debian/Ubuntu — outils de simulation et Python
sudo apt-get install -y iverilog verilator python3 python3-pip
pip3 install -r host/requirements.txt    # pyserial, pytest
```
Pour la synthèse FPGA : **Xilinx Vivado** (édition WebPACK gratuite, couvre
l'Artix-7). Pour le lint : `verible-verilog-lint` (optionnel).

### 2. Lancer ce qui tourne sans matériel
```bash
make test-host      # tests du protocole USB (Python)  -> 7 passed
make sim            # testbenches RTL via Icarus        -> *: PASS
make cli            # démo CLI sur transport mock (sans FPGA)
```

### 3. CLI diagnostic (PC secondaire)
```bash
# sans matériel (émulateur in-process)
python3 host/cli/nvme_tool.py self-test --json
python3 host/cli/nvme_tool.py status

# avec le lien USB réel
python3 host/cli/nvme_tool.py --port /dev/ttyUSB0 info
```

### 4. Synthèse (quand tu as la carte)
Voir `docs/phase1-architecture.md` et `constraints/`. Le Hard IP PCIe s'instancie
dans `rtl/pcie/pcie_wrapper.sv` (seul fichier spécifique au composant).

## Feuille de route

| Phase | Doc | État |
|---|---|---|
| 0 Faisabilité | `docs/phase0-faisabilite.md` | ✅ analyse |
| 1 Architecture | `docs/phase1-architecture.md` | ✅ ébauche |
| 2 Énumération Windows | `docs/phase2-windows-enumeration.md` | ✅ spécifiée |
| 3 RTL & sim | `rtl/`, `sim/` | 🟡 socle + TODO-IP |
| 4 DMA & IOMMU | `rtl/dma/`, `docs/` | 🟡 squelette |
| 5 USB | `rtl/usb/`, `docs/usb-protocol.md` | ✅ protocole + framer |
| 6 Outils PC #2 | `host/` | ✅ CLI/lib testés |
| 7 Perf/fiabilité | `docs/test-plan.md` | ⬜ matériel requis |
| 8 Jalons de test | `docs/test-plan.md` | 🟡 J1/J4 ok |
| 9 Dossier final | `docs/` | 🟡 en cours |

## Matériel à te procurer
Voir `docs/variants-costs.md` et `docs/phase1-architecture.md` §BOM. Référence de
départ : carte M.2 Artix-7 (type NiteFury) + un PHY USB (FT2232H ou FT601).

## Licence
Code sous licence MIT (voir `LICENSE`). Projet pédagogique.
