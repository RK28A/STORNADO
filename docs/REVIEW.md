# Audit — bugs potentiels & constructions non supportées

Revue statique (aucun simulateur RTL disponible dans l'environnement de build :
la sim RTL se valide chez toi / en CI via Icarus + Verilator). Les tests Python
passent (`7 passed`). Classé en **corrigé** et **à surveiller**.

## Corrigé dans cette passe

| # | Problème | Fichiers | Correctif |
|---|---|---|---|
| C1 | **Ports tableaux non-packés** (`logic [15:0] x [N]` en ports) — mal/pas supportés par Icarus Verilog | `nvme_doorbells`, `nvme_queue_mgr`, `stornado_top`, `tb_init_sequence` | Passage en **bus packés** `[N*16-1:0]`, accès `[q*16 +: 16]` |
| C2 | `do … while` dans les tâches de testbench — non garanti sous Icarus | `tb_sync_fifo` | Remplacé par `while` avec attente d'horloge |
| C3 | `break` + `fork…join` pour le polling — fragile/non portable | `tb_nvme_regs` | Boucle `while` bornée par un compteur `guard` |
| C4 | **Framer USB non fonctionnel** : `MSG_TYPE/SEQ/PLEN` jamais extraits (payload jamais consommé) et CRC assemblé à l'envers | `usb_packet_framer` | Réécrit : extraction octet-à-octet, état `U_DECIDE`, CRC reçu assemblé little-endian |
| C5 | Déclaration de variable dans un `begin` non nommé de `case` — refusée par certains simulateurs | `usb_packet_framer` | Hoistée en `wire crc_rx_full` |
| C6 | **argparse** : `--json`/`--debug` placés avant la sous-commande étaient écrasés par le défaut du sous-parseur | `host/cli/nvme_tool.py` | `default=argparse.SUPPRESS` + `getattr` |
| C7 | Lecture mémoire **non alignée** `*(uint32_t*)payload` (UB sur archi stricte) | `firmware/stornado_diag.c` | `memcpy` dans un `uint32_t` aligné |

## À surveiller (nécessite sim ou matériel)

| # | Point | Où | Nature |
|---|---|---|---|
| S1 | `RDY_DELAY` symbolique (≠ vraie latence d'init NVMe) | `nvme_regs` | **[HYP]** — à caler sur le comportement réel |
| S2 | Wrap CQ simplifié (toggle de phase sur passage à 0, taille CQ réelle ignorée) | `nvme_queue_mgr` | squelette — à compléter avec la taille CQ |
| S3 | **Pas de vrai walk de PRP list** (PRP2 = pointeur de liste si >2 pages) ; avance DMA « par page » symbolique | `dma_engine` | `TODO` PARTIE G — le cœur du DMA reste à écrire |
| S4 | `async_fifo` **sans testbench** | `rtl/common` | CDC à prouver en sim (ajouter un tb 2 horloges) |
| S5 | Opérateur `inside` (classification opcodes) | `nvme_cmd_decoder` | supporté Verilator ; **confirmer sous Icarus -g2012** |
| S6 | `pcie_wrapper` = **stub** (`link_up=0` câblé) : le top n'établit aucun lien en l'état | `rtl/pcie` | normal — dépend du Hard IP (`TODO-IP`) |
| S7 | Backend `mem[65536]` ×128 b en sim (~1 MiB) | `storage_backend_ram` | lourd mais ok ; réduire `CAP_BYTES` pour sim rapide |
| S8 | Mapping adresse octet→mot du backend | `storage_backend_ram` | vérifier en sim (test read/write LBA) |
| S9 | Signaux non connectés au top (warnings lint attendus) | `stornado_top` | cosmétique ; brancher au fil de l'intégration |
| S10 | `make lint` utilise `rtl/**/*.sv` (nécessite `globstar`) | `Makefile` | utiliser `scripts/lint.sh` (find) à la place |

## Comment activer le debug

- **RTL** : `make sim-debug` (définit `STORNADO_DEBUG`) → traces FSM init NVMe,
  doorbells, DMA, trames USB.
- **Hôte** : `python3 host/cli/nvme_tool.py --debug <cmd>` → trace TX/RX des trames.
- **Firmware** : compiler avec `-DSTORNADO_DEBUG` et fournir `dbg_puts()`.

## Prochaines priorités de code
1. Implémenter le **walk PRP** réel (S3) — bloc le plus structurant.
2. Ajouter un **testbench async_fifo** (S4) et un tb backend read/write (S8).
3. Confirmer `inside` sous Icarus, sinon remplacer par comparaisons explicites (S5).
