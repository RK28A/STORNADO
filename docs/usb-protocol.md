# Protocole diagnostic USB STORNADO (v1)

Lien **diagnostic uniquement**, séparé du chemin stockage. Les commandes agissent
sur des **buffers embarqués / réservés au banc de test** — jamais sur la mémoire
du PC principal. Aucune furtivité, aucun accès à des processus tiers.

## Choix de PHY
| Option | Débit | Coût | Routage | Verdict |
|---|---|---|---|---|
| USB 2.0 HS (FT2232H) | 480 Mb/s | bas | simple | **suffisant pour le diagnostic** |
| USB 3.x (FT601) | ~5 Gb/s | moyen | plus exigeant | si gros dumps de buffers |

Recommandé : **USB 2.0 HS** d'abord (budget thermique/électrique léger),
USB 3.x optionnel pour `READ_DIAGNOSTIC_BUFFER` volumineux.

## Cadre binaire (little-endian)

```
 Offset  Taille  Champ
 0       4       MAGIC   = "STRN" (0x53 0x54 0x52 0x4E)
 4       1       VERSION = 1
 5       1       HDR_LEN = 18
 6       2       MSG_TYPE
 8       2       FLAGS
 10      4       SEQ_ID
 14      4       PAYLOAD_LEN
 18      N       PAYLOAD
 18+N    4       CRC32 (IEEE 802.3, sur VERSION..PAYLOAD)
```

Endianness : little-endian partout. CRC calculé de l'octet `VERSION` (offset 4)
à la fin du `PAYLOAD`. Implémentations identiques en Python (`host/lib/protocol.py`),
C (`firmware/stornado_diag.c`) et RTL (`rtl/usb/usb_packet_framer.sv`).

## Types de message

| Nom | Valeur | Sens |
|---|---|---|
| PING | 0x0001 | écho |
| GET_INFO | 0x0002 | fw/bitstream/ids |
| GET_STATUS | 0x0003 | link/nvme/width/speed |
| GET_TEMPERATURE | 0x0004 | °C (int32) |
| GET_COUNTERS | 0x0005 | reads/writes/errors (u32×3) |
| GET_NVME_STATE | 0x0006 | CC.EN/CSTS.RDY/CSTS.CFS |
| GET_QUEUE_STATUS | 0x0007 | têtes/queues SQ/CQ |
| START_BENCHMARK | 0x0008 | banc de test interne |
| STOP_BENCHMARK | 0x0009 | |
| RESET_COUNTERS | 0x000A | |
| READ_DIAGNOSTIC_BUFFER | 0x000B | lit le buffer **embarqué** |
| WRITE_TEST_PATTERN | 0x000C | écrit le buffer **embarqué** |
| ACK | 0x8000 | réponse OK |
| ERROR | 0x8001 | payload = code (u16) |

## Codes d'erreur
`OK=0, BAD_CRC=1, BAD_MAGIC=2, BAD_VERSION=3, UNKNOWN_TYPE=4, BAD_LENGTH=5,
OUT_OF_RANGE=6, BUSY=7`.

## Robustesse
Resync sur `MAGIC`, timeout côté hôte, `SEQ_ID` pour apparier requête/réponse,
reconnexion idempotente, rejet de tout `PAYLOAD_LEN` dépassant la taille du buffer
embarqué (`OUT_OF_RANGE`). Segmentation des gros transferts par `SEQ_ID` croissant.
