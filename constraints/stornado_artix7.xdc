# stornado_artix7.xdc — SQUELETTE (ne pas utiliser tel quel).
# Les emplacements (LOC) et standards I/O dépendent de TA carte. Récupère le XDC
# maître de la carte (ex. NiteFury) et renseigne les broches réelles.

# ---- Référence d'horloge PCIe 100 MHz (depuis le connecteur M.2) ----
# create_clock -name pcie_refclk -period 10.000 [get_ports refclk_p]
# set_property PACKAGE_PIN <PIN> [get_ports refclk_p]
# set_property PACKAGE_PIN <PIN> [get_ports refclk_n]

# ---- PCIe reset (PERST#) ----
# set_property PACKAGE_PIN <PIN> [get_ports perst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports perst_n]

# ---- Lanes PCIe (GTP) : gérées par l'IP, voir le wrapper Vivado ----

# ---- USB PHY (FT2232H/FT601) : horloge + bus FIFO ----
# create_clock -name usb_clk -period 16.667 [get_ports usb_clk]   ;# ex. 60 MHz

# ---- Faux timing pour élaboration hors carte ----
# (laisser vide : les vraies contraintes viennent de la carte cible)
