// pcie_wrapper.sv — Enveloppe autour du Hard IP PCIe (WRAPPER SPÉCIFIQUE VENDEUR).
// Ce fichier isole TOUT ce qui dépend du composant : l'instanciation du Hard IP
// (Xilinx PCIe4C / Intel P-Tile / Lattice), les transceivers, les PLL. Le reste
// du cœur NVMe reste portable et ne voit que l'interface MMIO + requête mémoire
// ci-dessous (règle qualité 7 : séparer logique portable et wrappers IP).
//
// ÉTAT : squelette d'interface. Le link training, la négociation de largeur/
// vitesse, le Configuration Space (classe 0x010802, BAR, capacités MSI-X, PM)
// et le mapping TLP<->MMIO sont fournis par l'IP et à câbler lors de l'intégration
// (voir docs/phase1-architecture.md et docs/register-map.md). NE PAS présenter
// ce module comme fonctionnel sur matériel sans preuve de link-up.
import nvme_pkg::*;

module pcie_wrapper #(
  parameter int LANES = 4
)(
  // références physiques (vers le connecteur M.2 / carte de dev)
  input  logic              refclk_p,
  input  logic              refclk_n,
  input  logic              perst_n,     // PCIe reset
  input  logic [LANES-1:0]  rx_p, rx_n,
  output logic [LANES-1:0]  tx_p, tx_n,

  // horloge/raz "user" fournies par l'IP une fois le lien établi
  output logic              user_clk,
  output logic              user_rst_n,
  output logic              link_up,
  output logic [3:0]        link_width,
  output logic [2:0]        link_speed,

  // ---- MMIO décodé depuis les TLP (vers nvme_regs / doorbells) ----
  output logic              mmio_sel,
  output logic              mmio_we,
  output logic [REG_AW-1:0] mmio_addr,
  output logic [REG_DW-1:0] mmio_wdata,
  output logic [3:0]        mmio_wstrb,
  input  logic [REG_DW-1:0] mmio_rdata,
  input  logic              mmio_ack,

  // ---- requêtes mémoire hôte (depuis dma_engine) ----
  input  logic              mem_req_valid,
  output logic              mem_req_ready,
  input  logic              mem_req_we,
  input  logic [63:0]       mem_req_addr,
  input  logic [10:0]       mem_req_len_dw,
  input  logic [127:0]      mem_wdata,
  output logic [127:0]      mem_rdata,
  output logic              mem_rvalid,
  output logic              mem_err,

  // ---- interruptions ----
  input  logic              msix_req,
  input  logic [10:0]       msix_vector
);
  // --------------------------------------------------------------------------
  // TODO-IP : instancier ici le Hard IP PCIe du composant choisi.
  //   - Xilinx Artix-7/Kintex-7 : pcie_7x / PCIE4C (via IP catalog + XDC).
  //   - Intel Cyclone 10 GX / Agilex : P-Tile / H-Tile Avalon-ST.
  // Le bridge TLP->MMIO et le moteur de requêtes mémoire (Completer/Requester)
  // se branchent sur les ports ci-dessus. Les valeurs du Configuration Space
  // (VID/DID, classe 0x010802, BAR0 64 bits, MSI-X) se paramètrent dans l'IP.
  // --------------------------------------------------------------------------

  // Valeurs de repli pour que le module élabore et simule (NON représentatives
  // d'un lien réel). Le testbench d'intégration pilote ces signaux directement.
  assign user_clk      = refclk_p;      // placeholder
  assign user_rst_n    = perst_n;
  assign link_up       = 1'b0;
  assign link_width    = LANES[3:0];
  assign link_speed    = 3'd1;
  assign mmio_sel      = 1'b0;
  assign mmio_we       = 1'b0;
  assign mmio_addr     = '0;
  assign mmio_wdata    = '0;
  assign mmio_wstrb    = '0;
  assign mem_req_ready = 1'b0;
  assign mem_rdata     = '0;
  assign mem_rvalid    = 1'b0;
  assign mem_err       = 1'b0;
  assign tx_p = '0; assign tx_n = '0;
endmodule : pcie_wrapper
