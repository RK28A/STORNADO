# firmware/

Device-side dispatch of the diagnostic protocol (`stornado_diag.c`), for a
soft-core (RISC-V/MicroBlaze/Nios) or a small MCU driving the USB PHY.

- Encodes/decodes STORNADO frames (see `docs/usb-protocol.md`), with a **CRC32
  identical** to the Python codec and the RTL framer.
- Commands are bounded to **embedded buffers** (`diag_buffer[]`) and the test
  bench. No access to host memory.
- Platform stubs to implement: `usb_read/usb_write`, `hw_read_temperature_c`,
  `hw_read_nvme_state`. Not tested on target - compile it for your soft-core.
