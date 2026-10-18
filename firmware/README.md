# firmware/

Dispatch du protocole diagnostic côté appareil (`stornado_diag.c`), pour un
soft-core (RISC-V/MicroBlaze/Nios) ou un petit MCU pilotant le PHY USB.

- Encode/décode les cadres STORNADO (voir `docs/usb-protocol.md`), **CRC32
  identique** au codec Python et au framer RTL.
- Commandes bornées aux **buffers embarqués** (`diag_buffer[]`) et au banc de test.
  Aucun accès à la mémoire hôte.
- Stubs plateforme à implémenter : `usb_read/usb_write`, `hw_read_temperature_c`,
  `hw_read_nvme_state`. Non testé sur cible — à compiler pour ton soft-core.
