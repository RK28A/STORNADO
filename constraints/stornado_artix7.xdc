# stornado_artix7.xdc - SKELETON (do not use as-is).
# Locations (LOC) and I/O standards depend on YOUR board. Get the board's master
# XDC (e.g. NiteFury) and fill in the real pins.

# ---- PCIe 100 MHz reference clock (from the M.2 connector) ----
# create_clock -name pcie_refclk -period 10.000 [get_ports refclk_p]
# set_property PACKAGE_PIN <PIN> [get_ports refclk_p]
# set_property PACKAGE_PIN <PIN> [get_ports refclk_n]

# ---- PCIe reset (PERST#) ----
# set_property PACKAGE_PIN <PIN> [get_ports perst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports perst_n]

# ---- PCIe lanes (GTP): handled by the IP, see the Vivado wrapper ----

# ---- USB PHY (FT2232H/FT601): clock + FIFO bus ----
# create_clock -name usb_clk -period 16.667 [get_ports usb_clk]   ;# e.g. 60 MHz

# ---- Dummy timing for off-board elaboration ----
# (leave empty: the real constraints come from the target board)
