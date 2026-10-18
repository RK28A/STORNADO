# constraints/

Placement/timing constraints, **specific to the board and the device**.
Documented placeholders - to complete with your board's master file (NiteFury:
see the RHS Research repo) and the PCIe Hard IP setup.

- `stornado_artix7.xdc` - XDC skeleton (clocks, PCIe, USB, reset). The real pins
  depend on the board: do not use as-is.
