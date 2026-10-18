# Plan de test par jalons

Chaque test : **ID · prérequis · matériel · procédure · observable · attendu ·
logs · critère d'acceptation · diagnostic si échec.** Statut actuel : seuls les
tests de sim logique et les tests Python sont exécutables sans matériel.

## Jalon 1 — Sim unitaire (exécutable maintenant)
| ID | Objet | Fichier | Attendu |
|---|---|---|---|
| T1.1 | FIFO sync | `sim/unit/tb_sync_fifo.sv` | `PASS` |
| T1.2 | Registres + CC.EN→CSTS.RDY | `sim/unit/tb_nvme_regs.sv` | `PASS` |
| T1.3 | Init + doorbell | `sim/integration/tb_init_sequence.sv` | `PASS` |
| T1.4 | Protocole USB (codec/CRC) | `host/tests/test_protocol.py` | `7 passed` ✅ (exécuté) |

Procédure sim : `make sim` (iverilog) ou `make sim-verilator`.
Procédure Python : `make test-host` (exécuté : **7 passed**).

## Jalon 2 — Synthèse & timing
Vivado : synthèse Artix-7, timing closure, programmation carte NiteFury (JTAG).
Observable : rapport timing WNS ≥ 0 ; bitstream chargé. Diagnostic : contraintes XDC.

## Jalon 3 — PCIe link training & Config Space
Observable : `link_up`, largeur/vitesse ; device dans Gestionnaire de périph./`lspci`.
Critère : BAR0 mappé, classe 0x010802 lue.

## Jalon 4 — stornvme + Identify
Critère : pilote attaché ; Identify Controller/Namespace cohérents avec CAP.

## Jalon 5 — Disque Windows + montage namespace
Critère : disque visible dans Gestion des disques ; namespace partitionnable.

## Jalon 6 — Fichier aller-retour
Procédure : écrire un fichier, `certutil -hashfile`, relire, comparer.
Critère : **hash identique** (intégrité bout-en-bout).

## Jalon 7 — USB + logiciel secondaire
Procédure : `nvme-tool self-test`, `info`, `status` sur lien réel.
Critère : ACK sur toutes les commandes, CRC OK, logs horodatés.

## Jalon 8 — DMA sur buffers de test autorisés
Procédure : transferts vers buffers **réservés par le banc d'essai** ; signatures/CRC ;
essais 4 Go+ ; frontières de pages ; **inclure un cas de refus IOMMU** (doit être
rejeté proprement en complétion d'erreur). Aucun accès hors buffers autorisés.

## Jalon 9 — Endurance & récupération
Transferts prolongés ; injection d'erreurs ; reset contrôleur/PCIe ; coupure alim.
Critère : pas de corruption ; récupération propre (CSTS.CFS géré).

## Jalon 10 — PCB M.2 2280 (variante C)
Vérif électrique (rails, séquencement), thermique (ΔT), régression des jalons 1–9.

> Règle PARTIE J : l'absence de crash ne prouve **ni** la conformité PCIe/NVMe
> complète **ni** la sécurité. Ces affirmations restent distinctes et non acquises.
